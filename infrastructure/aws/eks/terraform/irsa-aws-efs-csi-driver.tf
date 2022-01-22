#################################
# IAM                           #
#################################

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
data "aws_iam_policy_document" "aws-efs-csi-driver-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks-cluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks-cluster.arn]
      type        = "Federated"
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "aws-efs-csi-driver-assume-role" {
  assume_role_policy = data.aws_iam_policy_document.aws-efs-csi-driver-assume-role-policy.json
  name               = "${var.environment}-${var.module}-aws-efs-csi-driver-assume-role"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "aws-efs-csi-driver" {
  policy_arn = aws_iam_policy.aws-efs-csi-driver.arn
  role       = aws_iam_role.aws-efs-csi-driver-assume-role.name
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "aws-efs-csi-driver" {
  name = "${var.environment}-${var.module}-aws-efs-csi-driver"
  description = "EKS External DNS Controller for Cluster ${var.environment}-${var.module}"
  policy      = data.aws_iam_policy_document.aws-efs-csi-driver.json
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
data "aws_iam_policy_document" "aws-efs-csi-driver" {
  statement {
    effect = "Allow"
    actions = [
      "elasticfilesystem:DescribeAccessPoints",
      "elasticfilesystem:DescribeFileSystems"
    ]
    resources = ["*"]
  }  

  statement {
    effect = "Allow"
    actions = ["elasticfilesystem:CreateAccessPoint"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = ["elasticfilesystem:DeleteAccessPoint"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }
}

output "aws-efs-csi-driver-role-arn" {
  value = aws_iam_role.aws-efs-csi-driver-assume-role.arn
}

#################################
# EFS                           #
#################################

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system
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
    Name = "${var.environment}-${var.module}-efs-pod-storage"
    Environment = var.environment
    Module = var.module
    Terraform = "true"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target
resource "aws_efs_mount_target" "efs-pod-storage" {
  count = length(data.aws_subnet_ids.private.ids)

  file_system_id  = aws_efs_file_system.efs-pod-storage.id
  subnet_id       = element(tolist(data.aws_subnet_ids.private.ids), count.index)
  security_groups = [aws_security_group.efs.id]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "efs" {
  name        = "${var.environment}-${var.module}-efs"
  description = "Security group for all nodes in the cluster"
  vpc_id      = data.aws_vpc.main.id
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [data.aws_vpc.main.ipv6_cidr_block]
  }
  tags = {
    Name = "${var.environment}-${var.module}-efs"
    Environment = var.environment
    Module = var.module
    Terraform = "true"
  }
}

output efs-pod-storage-fs-id {
  value = aws_efs_file_system.efs-pod-storage.id
}