#################################
# EBS CSI                       #
#################################
# https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
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

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "ebs-csi-assume-role" {
  assume_role_policy = data.aws_iam_policy_document.ebs-csi-assume-role-policy.json
  name               = "${var.environment}-${var.module}-ebs-csi-assume-role"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "ebs-csi-driver-policy-attachment" {
  policy_arn = aws_iam_policy.ebs-csi-driver-policy.arn
  role       = aws_iam_role.ebs-csi-assume-role.name
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "ebs-csi-driver-policy" {
  name = "${var.environment}-${var.module}-ebs-csi-driver-policy"
  description = "EBS CSI Driver Plugin Policy for ${var.environment}-${var.module}"
  policy      = data.aws_iam_policy_document.ebs-csi-driver-policy-document.json
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
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
    effect = "Allow"
    actions = ["ec2:CreateTags"]
    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = [
        "CreateVolume",
        "CreateSnapshot"
      ]
    }
  }

  statement {
    effect = "Allow"
    actions = ["ec2:DeleteTags"]
    resources = [
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:snapshot/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = ["ec2:CreateVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = ["ec2:CreateVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    effect = "Allow"
    actions = ["ec2:CreateVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/kubernetes.io/cluster/*"
      values   = ["owned"]
    }
  }

  statement {
    effect = "Allow"
    actions = ["ec2:DeleteVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = ["ec2:DeleteVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/CSIVolumeName"
      values   = ["*"]
    }
  }

  statement {
    effect = "Allow"
    actions = ["ec2:DeleteVolume"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/kubernetes.io/cluster/*"
      values   = ["owned"]
    }
  }

  statement {
    effect = "Allow"
    actions = ["ec2:DeleteSnapshot"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/CSIVolumeSnapshotName"
      values   = ["*"]
    }
  }

  statement {
    effect = "Allow"
    actions = ["ec2:DeleteSnapshot"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ec2:ResourceTag/ebs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }
}

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