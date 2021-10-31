# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
data "aws_caller_identity" "current" {}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster
data "aws_eks_cluster" "main" {
  name = "${var.environment}-${var.module}"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth
data "aws_eks_cluster_auth" "main" {
  name = data.aws_eks_cluster.main.name
}

data "aws_eks_node_group" "main" {
  cluster_name    = data.aws_eks_cluster.main.name
  node_group_name = "${var.environment}-${var.module}-main"
}