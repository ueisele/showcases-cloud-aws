#################################
# External DNS Controller       #
#################################
# https://github.com/kubernetes-sigs/external-dns/tree/master/charts/external-dns
# https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md

locals {
  external_dns_controller_name = "external-dns-controller"
}

resource "helm_release" "external_dns_controller" {
  name       = local.external_dns_controller_name
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  version    = "1.7.1"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = local.external_dns_controller_name
  }

  set {
    name  = "nameOverride"
    value = local.external_dns_controller_name
  }

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "priorityClassName"
    value = kubernetes_priority_class_v1.service_system_medium_priority.metadata.0.name
  }

  values = [yamlencode({
    serviceAccount = {
      create = true
      name   = "${local.external_dns_controller_name}-sa"
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns_controller_assume_role.arn
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

    affinity = {
      nodeAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [
          {
            weight = 100
            preference = {
              matchExpressions = [{
                key      = "kubernetes.io/arch"
                operator = "In"
                values   = ["arm64"]
              }]
            }
          }
        ],
        requiredDuringSchedulingIgnoredDuringExecution = {
          nodeSelectorTerms = [{
            matchExpressions = [
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

  depends_on = [aws_iam_role_policy_attachment.external_dns_controller]
}

#################################
# Pod Disruption Budget         #
#################################

resource "kubernetes_pod_disruption_budget_v1" "external_dns_controller" {
  metadata {
    name      = local.external_dns_controller_name
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = local.external_dns_controller_name
      "app.kubernetes.io/name"       = local.external_dns_controller_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    max_unavailable = "1"
    selector {
      match_labels = {
        "app.kubernetes.io/instance" = local.external_dns_controller_name
        "app.kubernetes.io/name"     = local.external_dns_controller_name
      }
    }
  }
}

#################################
# IRSA                          #
#################################

data "aws_iam_policy_document" "external_dns_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.iam_openid_connect_provider_url_stripped}:sub"
      values   = ["system:serviceaccount:kube-system:${local.external_dns_controller_name}-sa"]
    }

    principals {
      identifiers = [local.iam_openid_connect_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "external_dns_controller_assume_role" {
  assume_role_policy = data.aws_iam_policy_document.external_dns_controller_assume_role_policy.json
  name               = "${var.environment}-${local.external_dns_controller_name}-assume-role"
}

resource "aws_iam_role_policy_attachment" "external_dns_controller" {
  policy_arn = aws_iam_policy.external_dns_controller.arn
  role       = aws_iam_role.external_dns_controller_assume_role.name
}

resource "aws_iam_policy" "external_dns_controller" {
  name        = "${var.environment}-${local.external_dns_controller_name}"
  description = "External DNS Controller for EKS Cluster ${var.environment}"
  policy      = data.aws_iam_policy_document.external_dns_controller.json
}

data "aws_iam_policy_document" "external_dns_controller" {
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
