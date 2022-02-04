#################################
# Cluster Autoscaler            #
#################################
# https://docs.aws.amazon.com/de_de/eks/latest/userguide/cluster-autoscaler.html
# https://github.com/kubernetes/autoscaler/tree/master/charts/cluster-autoscaler
# https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md

locals {
  cluster_autoscaler_name = "cluster-autoscaler"
}

resource "helm_release" "cluster_autoscaler" {
  name       = local.cluster_autoscaler_name
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.13.0"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = local.cluster_autoscaler_name
  }

  set {
    name  = "nameOverride"
    value = local.cluster_autoscaler_name
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
    value = kubernetes_priority_class_v1.service_system_medium_priority.metadata.0.name
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
        name   = "${local.cluster_autoscaler_name}-sa"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler_assume_role.arn
        }
      }
    }

    # https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#what-are-the-parameters-to-ca
    extraArgs = {
      logtostderr                   = true
      stderrthreshold               = "info"
      v                             = 4
      skip-nodes-with-system-pods   = false
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
      podAntiAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [
          {
            podAffinityTerm = {
              labelSelector = {
                matchExpressions = [{
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = [local.cluster_autoscaler_name]
                }]
              }
              topologyKey = "kubernetes.io/hostname"
            }
            weight = 50
          },
          {
            podAffinityTerm = {
              labelSelector = {
                matchExpressions = [{
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = [local.cluster_autoscaler_name]
                }]
              }
              topologyKey = "failure-domain.beta.kubernetes.io/zone"
            }
            weight = 25
          }
        ]
      }
    }
  })]

  depends_on = [aws_iam_role_policy_attachment.cluster_autoscaler]
}

#################################
# IRSA                          #
#################################

data "aws_iam_policy_document" "cluster_autoscaler_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.iam_openid_connect_provider_url_stripped}:sub"
      values   = ["system:serviceaccount:kube-system:${local.cluster_autoscaler_name}-sa"]
    }

    principals {
      identifiers = [local.iam_openid_connect_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "cluster_autoscaler_assume_role" {
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume_role_policy.json
  name               = "${var.environment}-${local.cluster_autoscaler_name}-assume-role"
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.cluster_autoscaler_assume_role.name
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.environment}-${local.cluster_autoscaler_name}"
  description = "Cluster Autoscaler for EKS Cluster ${var.environment}"
  policy      = data.aws_iam_policy_document.cluster_autoscaler.json
}

data "aws_iam_policy_document" "cluster_autoscaler" {
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
