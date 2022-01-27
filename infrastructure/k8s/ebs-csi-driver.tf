#################################
# EBS CSI                       #
#################################
# https://github.com/kubernetes-sigs/aws-ebs-csi-driver
# https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-volume-types.html

resource "helm_release" "ebs-csi-driver" {
  name       = "ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = "2.6.2"

  namespace = "kube-system"

  set {
    name  = "fullnameOverride"
    value = "ebs-csi-controller"
  }

  set {
    name  = "nameOverride"
    value = "ebs-csi-controller"
  }

  values = [yamlencode({
    controller = {
      replicaCount = 1

      priorityClassName = kubernetes_priority_class_v1.medium-priority-system-service.metadata.0.name

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
        name   = "ebs-csi-controller-sa"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.ebs-csi-assume-role.arn
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
                    values   = ["ebs-csi-controller"]
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
                    values   = ["ebs-csi-controller"]
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
# IRSA                          #
#################################

data "aws_iam_policy_document" "ebs-csi-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.iam_openid_connect_provider_url_stripped}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    principals {
      identifiers = [local.iam_openid_connect_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "ebs-csi-assume-role" {
  assume_role_policy = data.aws_iam_policy_document.ebs-csi-assume-role-policy.json
  name               = "${var.environment}-${var.module}-ebs-csi-assume-role"
}

resource "aws_iam_role_policy_attachment" "ebs-csi-driver-policy-attachment" {
  policy_arn = aws_iam_policy.ebs-csi-driver-policy.arn
  role       = aws_iam_role.ebs-csi-assume-role.name
}

resource "aws_iam_policy" "ebs-csi-driver-policy" {
  name        = "${var.environment}-${var.module}-ebs-csi-driver-policy"
  description = "EBS CSI Driver Plugin Policy for Cluster ${var.environment}-${var.module}"
  policy      = data.aws_iam_policy_document.ebs-csi-driver-policy-document.json
}

data "aws_iam_policy_document" "ebs-csi-driver-policy-document" {
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
}

#################################
# Storage Classes               #
#################################

## Update existing gp2 storage class

resource "kubectl_manifest" "gp2" {
  yaml_body = <<-EOF
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: gp2
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

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
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
    #iops = "3000"
    #throughput = "125"
  }
}

resource "kubernetes_storage_class_v1" "st1" {
  metadata {
    name = "st1"
  }
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  parameters = {
    type                        = "st1"
    "csi.storage.k8s.io/fstype" = "ext4"
  }
}

resource "kubernetes_storage_class_v1" "sc1" {
  metadata {
    name = "sc1"
  }
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  parameters = {
    type                        = "sc1"
    "csi.storage.k8s.io/fstype" = "ext4"
  }
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
