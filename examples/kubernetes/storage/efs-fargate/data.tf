data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "main" {
  name = "${var.environment}-${var.module}"
}

data "aws_eks_cluster_auth" "main" {
  name = "${var.environment}-${var.module}"
}