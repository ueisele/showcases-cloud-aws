#################################
# EBS CSI                       #
#################################
# https://github.com/kubernetes-sigs/aws-ebs-csi-driver
# https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html

locals {
  ebs_csi_driver_name     = "ebs-csi-driver"
  ebs_csi_controller_name = "ebs-csi-controller"
}

resource "helm_release" "ebs_csi_driver" {
  name       = local.ebs_csi_driver_name
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.6.2"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = local.ebs_csi_controller_name
  }

  set {
    name  = "nameOverride"
    value = local.ebs_csi_controller_name
  }

  values = [yamlencode({
    controller = {
      replicaCount = 1

      priorityClassName = kubernetes_priority_class_v1.service_system_medium_priority.metadata.0.name

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
        name   = "${local.ebs_csi_controller_name}-sa"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.ebs_csi_controller_assume_role.arn
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
                    values   = [local.ebs_csi_controller_name]
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
                    values   = [local.ebs_csi_controller_name]
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

  depends_on = [aws_iam_role_policy_attachment.ebs_csi_controller]
}

#################################
# IRSA                          #
#################################

data "aws_iam_policy_document" "ebs_csi_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.iam_openid_connect_provider_url_stripped}:sub"
      values   = ["system:serviceaccount:kube-system:${local.ebs_csi_controller_name}-sa"]
    }

    principals {
      identifiers = [local.iam_openid_connect_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "ebs_csi_controller_assume_role" {
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_controller_assume_role_policy.json
  name               = "${var.environment}-${local.ebs_csi_controller_name}-assume-role"
}

resource "aws_iam_role_policy_attachment" "ebs_csi_controller" {
  policy_arn = aws_iam_policy.ebs_csi_controller.arn
  role       = aws_iam_role.ebs_csi_controller_assume_role.name
}

resource "aws_iam_policy" "ebs_csi_controller" {
  name        = "${var.environment}-${local.ebs_csi_controller_name}"
  description = "EBS CSI Driver Plugin Policy for EKS Cluster ${var.environment}"
  policy      = data.aws_iam_policy_document.ebs_csi_controller.json
}

data "aws_iam_policy_document" "ebs_csi_controller" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateSnapshot",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:ModifyVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications"
    ]
    resources = ["*"]
  }

  statement {
    effect  = "Allow"
    actions = ["ec2:CreateTags"]
    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values = [
        "CreateVolume",
        "CreateSnapshot"
      ]
    }
  }

  statement {
    effect  = "Allow"
    actions = ["ec2:DeleteTags"]
    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*"
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/kubernetes.io/cluster/*"
      values   = ["owned"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:DeleteVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:DeleteVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:DeleteVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/kubernetes.io/cluster/*"
      values   = ["owned"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:DeleteSnapshot"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/CSIVolumeSnapshotName"
      values   = ["*"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:DeleteSnapshot"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]
    resources = [aws_kms_key.ebs_csi_driver.arn]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.ebs_csi_driver.arn]
  }
}

#################################
# Storage Classes               #
#################################

## KMS Key for storage encryption

resource "aws_kms_key" "ebs_csi_driver" {
  description             = "This key is used to encrypt EBS volumes created by Kubernetes EBS CSI driver."
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7

  tags = {
    Name        = "${var.environment}-${local.ebs_csi_driver_name}"
    Environment = var.environment
    Terraform   = "true"
  }
}

## Update existing gp2 storage class

resource "kubectl_manifest" "gp2" {
  yaml_body = <<-EOF
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: gp2
      labels:
        app.kubernetes.io/managed-by: Terraform
    parameters:
      fsType: ext4
      type: gp2
    provisioner: kubernetes.io/aws-ebs
    reclaimPolicy: Delete
    volumeBindingMode: WaitForFirstConsumer
    allowVolumeExpansion: true
    EOF
}

## New Storage Classes
# https://github.com/kubernetes-sigs/aws-ebs-csi-driver#createvolume-parameters

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = true
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  parameters = {
    type                        = "gp3"
    "csi.storage.k8s.io/fstype" = "ext4"
    encrypted = true
    kmsKeyId = aws_kms_key.ebs_csi_driver.arn
    #iops = "3000"
    #throughput = "125"
  }

  depends_on = [helm_release.ebs_csi_driver]
}

resource "kubernetes_storage_class_v1" "st1" {
  metadata {
    name = "st1"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  parameters = {
    type                        = "st1"
    "csi.storage.k8s.io/fstype" = "ext4"
    encrypted = true
    kmsKeyId = aws_kms_key.ebs_csi_driver.arn
  }

  depends_on = [helm_release.ebs_csi_driver]
}

resource "kubernetes_storage_class_v1" "sc1" {
  metadata {
    name = "sc1"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  parameters = {
    type                        = "sc1"
    "csi.storage.k8s.io/fstype" = "ext4"
    encrypted = true
    kmsKeyId = aws_kms_key.ebs_csi_driver.arn
  }

  depends_on = [helm_release.ebs_csi_driver]
}

#################################
# EBS CSI EKS Addon             #
#################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon
# Cannot be used, because EKS add-ons do not support tolerations
/*
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon
resource "aws_eks_addon" "ebs-csi" {
  cluster_name      = data.aws_eks_cluster.main.name
  addon_name        = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs-csi-assume-role.arn
  resolve_conflicts = "OVERWRITE"
  tags = {
    eks_addon = "aws-ebs-csi-driver"
    Environment = var.environment
    Module = var.module
    Terraform = "true"
  }
}
*/
