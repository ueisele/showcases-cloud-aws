#################################
# EBS CSI                       #
#################################
# https://github.com/kubernetes-sigs/aws-efs-csi-driver
# https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html
# https://aws.amazon.com/de/blogs/aws/new-aws-fargate-for-amazon-eks-now-supports-amazon-efs/

locals {
  efs_csi_driver_name     = "efs-csi-driver"
  efs_csi_controller_name = "efs-csi-controller"
}

resource "helm_release" "efs_csi_driver" {
  name       = local.efs_csi_driver_name
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver"
  chart      = "aws-efs-csi-driver"
  version    = "2.2.3"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = local.efs_csi_controller_name
  }

  set {
    name  = "nameOverride"
    value = local.efs_csi_controller_name
  }

  values = [yamlencode({
    replicaCount = 1

    controller = {
      resources = {
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      serviceAccount = {
        create = true
        name   = "${local.efs_csi_controller_name}-sa"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.efs_csi_controller_assume_role.arn
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
                    values   = [local.efs_csi_controller_name]
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
                    values   = [local.efs_csi_controller_name]
                  }]
                }
                topologyKey = "failure-domain.beta.kubernetes.io/zone"
              }
              weight = 25
            }
          ]
        }
      }
    }

    node = {
      tolerateAllTaints = true
    }
  })]

  depends_on = [aws_iam_role_policy_attachment.efs_csi_controller]
}

#################################
# Pod Disruption Budget         #
#################################

resource "kubernetes_pod_disruption_budget_v1" "efs_csi_driver" {
  metadata {
    name      = local.efs_csi_driver_name
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance"   = local.efs_csi_driver_name
      "app.kubernetes.io/name"       = local.efs_csi_controller_name
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  spec {
    max_unavailable = "1"
    selector {
      match_labels = {
        "app.kubernetes.io/instance" = local.efs_csi_driver_name
        "app.kubernetes.io/name"     = local.efs_csi_controller_name
      }
    }
  }
}

#################################
# ISRA                          #
#################################

data "aws_iam_policy_document" "efs_csi_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.iam_openid_connect_provider_url_stripped}:sub"
      values   = ["system:serviceaccount:kube-system:${local.efs_csi_controller_name}-sa"]
    }

    principals {
      identifiers = [local.iam_openid_connect_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "efs_csi_controller_assume_role" {
  assume_role_policy = data.aws_iam_policy_document.efs_csi_controller_assume_role_policy.json
  name               = "${var.environment}-${local.efs_csi_controller_name}-assume-role"
}

resource "aws_iam_role_policy_attachment" "efs_csi_controller" {
  policy_arn = aws_iam_policy.efs_csi_controller.arn
  role       = aws_iam_role.efs_csi_controller_assume_role.name
}

resource "aws_iam_policy" "efs_csi_controller" {
  name        = "${var.environment}-${local.efs_csi_controller_name}"
  description = "EFS CSI Driver Plugin Policy for EKS Cluster ${var.environment}"
  policy      = data.aws_iam_policy_document.efs_csi_controller.json
}

data "aws_iam_policy_document" "efs_csi_controller" {
  statement {
    effect = "Allow"
    actions = [
      "elasticfilesystem:DescribeAccessPoints",
      "elasticfilesystem:DescribeFileSystems"
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["elasticfilesystem:CreateAccessPoint"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["elasticfilesystem:DeleteAccessPoint"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }
}

#################################
# EFS                           #
#################################

resource "aws_kms_key" "efs_csi_driver" {
  description             = "This key is used to encrypt EFS volumes created by Kubernetes EFS CSI driver."
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7

  tags = {
    Name        = "${var.environment}-${local.efs_csi_driver_name}"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_efs_file_system" "efs_csi_driver" {
  creation_token = "${var.environment}-${local.efs_csi_driver_name}"

  performance_mode = "generalPurpose"

  encrypted = true
  kms_key_id = aws_kms_key.efs_csi_driver.arn

  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = {
    Name        = "${var.environment}-${local.efs_csi_driver_name}"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_efs_mount_target" "efs_csi_driver" {
  count = length(data.aws_subnet_ids.private.ids)

  file_system_id  = aws_efs_file_system.efs_csi_driver.id
  subnet_id       = element(tolist(data.aws_subnet_ids.private.ids), count.index)
  security_groups = [aws_security_group.efs_csi_driver.id]
}

resource "aws_security_group" "efs_csi_driver" {
  name        = "${var.environment}-${local.efs_csi_driver_name}"
  description = "Security group for all nodes in the cluster for EFS access"
  vpc_id      = data.aws_vpc.main.id
  ingress {
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = [data.aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [data.aws_vpc.main.ipv6_cidr_block]
  }
  tags = {
    Name        = "${var.environment}-${local.efs_csi_driver_name}"
    Environment = var.environment
    Terraform   = "true"
  }
}

#################################
# Storage Class                 #
#################################
# https://github.com/kubernetes-sigs/aws-efs-csi-driver#storage-class-parameters-for-dynamic-provisioning

resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = "efs"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  storage_provisioner = "efs.csi.aws.com"
  mount_options       = ["tls"]
  reclaim_policy      = "Delete"
  volume_binding_mode = "Immediate"
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.efs_csi_driver.id
    directoryPerms : "700"
  }

  depends_on = [
    helm_release.efs_csi_driver,
    aws_efs_mount_target.efs_csi_driver
  ]
}
