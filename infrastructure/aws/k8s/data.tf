
data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_vpc" "main" {
  tags = {
    Name = var.environment
  }
}

data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.main.id
  tags = {
    Tier = "private"
  }
}

data "aws_eks_cluster" "main" {
  name = "${var.environment}-${var.module}"
}

data "aws_eks_cluster_auth" "main" {
  name = "${var.environment}-${var.module}"
}

data "aws_iam_role" "eks-node-group" {
  name = "${var.environment}-${var.module}-node-group"
}

data "aws_iam_role" "eks-fargate-profile" {
  name = "${var.environment}-${var.module}-fargate-profile"
}

data "aws_iam_role" "k8sadmin" {
  name = "${var.environment}-${var.module}-k8sadmin"
}

locals {
  partition                                 = data.aws_partition.current.id
  account_id                                = data.aws_caller_identity.current.account_id
  iam_openid_connect_provider_url_stripped  = replace(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
  iam_openid_connect_provider_arn           = "arn:${local.partition}:iam::${local.account_id}:oidc-provider/${local.iam_openid_connect_provider_url_stripped}"
  eks_cluster_system_node_group_name        = "${data.aws_eks_cluster.main.name}-system"
}