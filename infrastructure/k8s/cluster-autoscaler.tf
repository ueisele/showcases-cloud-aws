#################################
# Cluster Autoscaler            #
#################################
# https://docs.aws.amazon.com/de_de/eks/latest/userguide/cluster-autoscaler.html
# https://github.com/kubernetes/autoscaler/tree/master/charts/cluster-autoscaler
# https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md

resource "helm_release" "cluster-autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.11.0"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = "cluster-autoscaler"
  }

  set {
    name  = "nameOverride"
    value = "cluster-autoscaler"
  }

  set {
    name  = "image.tag"
    value = "v1.23.0"
  }

  set {
    name  = "replicaCount"
    value = 1
  }

  set {
    name  = "priorityClassName"
    value = kubernetes_priority_class_v1.medium-priority-system-service.metadata.0.name
  }

  set {
    name  = "autoDiscovery.clusterName"
    value = data.aws_eks_cluster.main.name
  }

  set {
    name  = "cloudProvider"
    value = "aws"
  }

  set {
    name  = "awsRegion"
    value = data.aws_region.current.name
  }

  values = [yamlencode({
    rbac = {
      create = true
      serviceAccount = {
        create = true
        name   = "cluster-autoscaler-sa"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.cluster-autoscaler-assume-role.arn
        }
      }
    }

    # https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#what-are-the-parameters-to-ca
    extraArgs = {
      logtostderr = true
      stderrthreshold = "info"
      v = 4
      skip-nodes-with-system-pods = false
      skip-nodes-with-local-storage = false
      # scan-interval = "10s"
      # max-node-provision-time = "15m0s"
      # scale-down-enabled = true
      # scale-down-delay-after-add = "10m"
      # scale-down-delay-after-delete = "0s"
      # scale-down-delay-after-failure = "3m"
      # scale-down-unneeded-time = "10m"
      # scale-down-unready-time = "20m"
      # scale-down-utilization-threshold = 0.5
      # scale-down-non-empty-candidates-count = 30
      # balance-similar-node-groups = true
      # write-status-configmap = true
      # status-config-map-name = "cluster-autoscaler-status"
      # leader-elect = true
      # leader-elect-resource-lock = "endpoints"
      # balancing-ignore-label_1 = "first-label-to-ignore"
      # balancing-ignore-label_2 = "second-label-to-ignore"
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
      podAntiAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [
          {
            podAffinityTerm = {
              labelSelector = {
                matchExpressions = [{
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = ["cluster-autoscaler"]
                }]
              }
              topologyKey = "kubernetes.io/hostname"
            }
            weight = 100
          },
          {
            podAffinityTerm = {
              labelSelector = {
                matchExpressions = [{
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = ["cluster-autoscaler"]
                }]
              }
              topologyKey = "failure-domain.beta.kubernetes.io/zone"
            }
            weight = 100
          }
        ]
      }
    }
  })]
}

#################################
# IRSA                          #
#################################

data "aws_iam_policy_document" "cluster-autoscaler-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.iam_openid_connect_provider_url_stripped}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler-sa"]
    }

    principals {
      identifiers = [local.iam_openid_connect_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "cluster-autoscaler-assume-role" {
  assume_role_policy = data.aws_iam_policy_document.cluster-autoscaler-assume-role-policy.json
  name               = "${var.environment}-${var.module}-cluster-autoscaler-assume-role"
}

resource "aws_iam_role_policy_attachment" "cluster-autoscaler" {
  policy_arn = aws_iam_policy.cluster-autoscaler.arn
  role       = aws_iam_role.cluster-autoscaler-assume-role.name
}

resource "aws_iam_policy" "cluster-autoscaler" {
  name        = "${var.environment}-${var.module}-cluster-autoscaler"
  description = "EKS Cluster Autoscaler for Cluster ${var.environment}-${var.module}"
  policy      = data.aws_iam_policy_document.cluster-autoscaler.json
}

data "aws_iam_policy_document" "cluster-autoscaler" {
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions"
    ]
    resources = ["*"]
  }
}
