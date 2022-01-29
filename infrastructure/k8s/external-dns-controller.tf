#################################
# External DNS Controller       #
#################################
# https://github.com/kubernetes-sigs/external-dns/tree/master/charts/external-dns
# https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md

resource "helm_release" "external-dns-controller" {
  name       = "external-dns-controller"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  version    = "1.7.1"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = "external-dns-controller"
  }

  set {
    name  = "nameOverride"
    value = "external-dns-controller"
  }

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "priorityClassName"
    value = kubernetes_priority_class_v1.medium-priority-system-service.metadata.0.name
  }

  values = [yamlencode({
    serviceAccount = {
      create = true
      name   = "external-dns-controller-sa"
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.external-dns-controller-assume-role.arn
      }
    }

    resources = {
      limits = {
        cpu    = "50m"
        memory = "64Mi"
      }
      requests = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }

    tolerations = [{
      key      = "system"
      operator = "Equal"
      value    = "true"
      effect   = "NoSchedule"
    }]

    affinity = {
      nodeAffinity = {
        requiredDuringSchedulingIgnoredDuringExecution = {
          nodeSelectorTerms = [{
            matchExpressions = [
              {
                key      = "eks.amazonaws.com/nodegroup"
                operator = "In"
                values   = [local.eks_cluster_system_node_group_name]
              },
              {
                key      = "kubernetes.io/os"
                operator = "In"
                values   = ["linux"]
              },
              {
                key      = "kubernetes.io/arch"
                operator = "In"
                values   = ["amd64", "arm64"]
              }
            ]
          }]
        }
      }
    }
  })]
}

#################################
# Pod Disruption Budget         #
#################################

resource "kubernetes_pod_disruption_budget_v1" "external-dns-controller" {
  metadata {
    name      = "external-dns-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = "external-dns-controller"
      "app.kubernetes.io/name"       = "external-dns-controller"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    max_unavailable = "1"
    selector {
      match_labels = {
        "app.kubernetes.io/instance" = "external-dns-controller"
        "app.kubernetes.io/name"     = "external-dns-controller"
      }
    }
  }
}

#################################
# IRSA                          #
#################################

data "aws_iam_policy_document" "external-dns-controller-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.iam_openid_connect_provider_url_stripped}:sub"
      values   = ["system:serviceaccount:kube-system:external-dns-controller-sa"]
    }

    principals {
      identifiers = [local.iam_openid_connect_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "external-dns-controller-assume-role" {
  assume_role_policy = data.aws_iam_policy_document.external-dns-controller-assume-role-policy.json
  name               = "${var.environment}-${var.module}-external-dns-controller-assume-role"
}

resource "aws_iam_role_policy_attachment" "external-dns-controller" {
  policy_arn = aws_iam_policy.external-dns-controller.arn
  role       = aws_iam_role.external-dns-controller-assume-role.name
}

resource "aws_iam_policy" "external-dns-controller" {
  name        = "${var.environment}-${var.module}-external-dns-controller"
  description = "EKS External DNS Controller for Cluster ${var.environment}-${var.module}"
  policy      = data.aws_iam_policy_document.external-dns-controller.json
}

data "aws_iam_policy_document" "external-dns-controller" {
  statement {
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets"
    ]
    resources = ["*"]
  }
}
