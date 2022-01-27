#################################
# EBS CSI                       #
#################################
# https://github.com/kubernetes-sigs/aws-efs-csi-driver
# https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html
# https://aws.amazon.com/de/blogs/aws/new-aws-fargate-for-amazon-eks-now-supports-amazon-efs/

resource "helm_release" "efs-csi-driver" {
  name       = "efs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver"
  chart      = "aws-efs-csi-driver"
  version    = "2.2.3"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = "efs-csi-controller"
  }

  set {
    name  = "nameOverride"
    value = "efs-csi-controller"
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
        name   = "efs-csi-controller-sa"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.efs-csi-driver-assume-role.arn
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
                    values   = ["efs-csi-controller"]
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
                    values   = ["efs-csi-controller"]
                  }]
                }
                topologyKey = "failure-domain.beta.kubernetes.io/zone"
              }
              weight = 100
            }
          ]
        }
      }
    }

    node = {
      tolerateAllTaints = true
    }
  })]
}

#################################
# ISRA                          #
#################################

data "aws_iam_policy_document" "efs-csi-driver-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.iam_openid_connect_provider_url_stripped}:sub"
      values   = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]
    }

    principals {
      identifiers = [local.iam_openid_connect_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "efs-csi-driver-assume-role" {
  assume_role_policy = data.aws_iam_policy_document.efs-csi-driver-assume-role-policy.json
  name               = "${var.environment}-${var.module}-efs-csi-driver-assume-role"
}

resource "aws_iam_role_policy_attachment" "efs-csi-driver" {
  policy_arn = aws_iam_policy.efs-csi-driver.arn
  role       = aws_iam_role.efs-csi-driver-assume-role.name
}

resource "aws_iam_policy" "efs-csi-driver" {
  name        = "${var.environment}-${var.module}-efs-csi-driver"
  description = "EKS External DNS Controller for Cluster ${var.environment}-${var.module}"
  policy      = data.aws_iam_policy_document.efs-csi-driver.json
}

data "aws_iam_policy_document" "efs-csi-driver" {
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

resource "aws_efs_file_system" "efs-pod-storage" {
  creation_token = "${var.environment}-${var.module}-efs-pod-storage"

  performance_mode = "generalPurpose"

  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = {
    Name        = "${var.environment}-${var.module}-efs-pod-storage"
    Environment = var.environment
    Module      = var.module
    Terraform   = "true"
  }
}

resource "aws_efs_mount_target" "efs-pod-storage" {
  count = length(data.aws_subnet_ids.private.ids)

  file_system_id  = aws_efs_file_system.efs-pod-storage.id
  subnet_id       = element(tolist(data.aws_subnet_ids.private.ids), count.index)
  security_groups = [aws_security_group.efs.id]
}

resource "aws_security_group" "efs" {
  name        = "${var.environment}-${var.module}-efs"
  description = "Security group for all nodes in the cluster"
  vpc_id      = data.aws_vpc.main.id
  ingress {
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = [data.aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [data.aws_vpc.main.ipv6_cidr_block]
  }
  tags = {
    Name        = "${var.environment}-${var.module}-efs"
    Environment = var.environment
    Module      = var.module
    Terraform   = "true"
  }
}

#################################
# Storage Class                 #
#################################

resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = "efs"
  }
  storage_provisioner = "efs.csi.aws.com"
  mount_options       = ["tls"]
  reclaim_policy      = "Delete"
  volume_binding_mode = "Immediate"
  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.efs-pod-storage.id
    directoryPerms : "700"
  }
}
