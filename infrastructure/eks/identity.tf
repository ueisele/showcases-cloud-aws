#####################################
# Kubernetes Access with IAM Groups #
#####################################
# https://www.eksworkshop.com/beginner/091_iam-groups/

resource "aws_iam_role" "k8sadmin" {
  name = "${var.environment}-k8sadmin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
    }]
  })

  tags = {
    Name        = "${var.environment}-k8sadmin"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_policy" "eks_describe_cluster" {
  name = "${var.environment}-eks-describe-cluster"
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

resource "aws_iam_role_policy_attachment" "k8sadmin_eks_describe_cluster" {
  policy_arn = aws_iam_policy.eks_describe_cluster.arn
  role       = aws_iam_role.k8sadmin.name
}

resource "aws_iam_policy" "k8sadmin_assume_role" {
  name = "${var.environment}-k8sadmin-assume-role"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowAssumeOrganizationAccountRole",
        "Effect" : "Allow",
        "Action" : "sts:AssumeRole",
        "Resource" : aws_iam_role.k8sadmin.arn
      }
    ]
  })
}

resource "aws_iam_group" "k8sadmin" {
  name = "${var.environment}-k8sadmin"
}

resource "aws_iam_group_policy_attachment" "k8sadmin_assume_role" {
  group      = aws_iam_group.k8sadmin.name
  policy_arn = aws_iam_policy.k8sadmin_assume_role.arn
}

output "ks8admin_role_arn" {
  value = aws_iam_role.k8sadmin.arn
}

output "ks8admin_assumerole_policy_arn" {
  value = aws_iam_policy.k8sadmin_assume_role.arn
}

output "ks8admin_group_arn" {
  value = aws_iam_group.k8sadmin.arn
}
