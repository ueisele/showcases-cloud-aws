data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "main" {
  name = var.environment
}

data "aws_eks_cluster_auth" "main" {
  name = var.environment
}

data "aws_efs_file_system" "eks_pod_storage" {
  tags = {
    Name = "${var.environment}-eks-pod-storage"
  }
}