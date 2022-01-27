#####################################
# Kubernetes Access with IAM Groups #
#####################################
# https://www.eksworkshop.com/beginner/091_iam-groups/

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "k8sadmin" {
  name = "${var.environment}-${var.module}-k8sadmin"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
    }]
  })

  tags = {
    Name = "${var.environment}-${var.module}-k8sadmin"
    Environment = var.environment
    Module = var.module
    Terraform = "true"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "eks-describe-cluster" {
  name        = "${var.environment}-${var.module}-eks-describe-cluster"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:DescribeCluster",
        ]
        Effect   = "Allow"
        Resource = aws_eks_cluster.main.arn
      },
    ]
  })
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "k8sadmin-eks-describe-cluster" {
  policy_arn = aws_iam_policy.eks-describe-cluster.arn
  role       = aws_iam_role.k8sadmin.name
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
resource "aws_iam_policy" "k8sadmin-assumerole" {
  name        = "${var.environment}-${var.module}-k8sadmin-assumerole"
  policy      = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowAssumeOrganizationAccountRole",
        "Effect": "Allow",
        "Action": "sts:AssumeRole",
        "Resource": aws_iam_role.k8sadmin.arn
      }
    ]
  })
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group
resource "aws_iam_group" "k8sadmin" {
  name = "${var.environment}-${var.module}-k8sadmin"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group_policy_attachment
resource "aws_iam_group_policy_attachment" "k8sadmin-assumerole" {
  group      = aws_iam_group.k8sadmin.name
  policy_arn = aws_iam_policy.k8sadmin-assumerole.arn
}

output "ks8admin-role-arn" {
  value = aws_iam_role.k8sadmin.arn
}

output "ks8admin-assumerole-policy-arn" {
  value = aws_iam_policy.k8sadmin-assumerole.arn
}

output "ks8admin-group-arn" {
  value = aws_iam_group.k8sadmin.arn
}