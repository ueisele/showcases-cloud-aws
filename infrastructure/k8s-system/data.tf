
data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_vpc" "main" {
  tags = {
    Name = var.environment
  }
}

data "aws_subnet_ids" "public" {
  vpc_id = data.aws_vpc.main.id
  tags = {
    Tier = "public"
  }
}

data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.main.id
  tags = {
    Tier = "private"
  }
}

data "aws_acm_certificate" "public" {
  domain      = "*.${local.env_domain}"
  statuses    = ["ISSUED"]
  most_recent = true
}

data "aws_eks_cluster" "main" {
  name = var.environment
}

data "aws_eks_cluster_auth" "main" {
  name = var.environment
}

data "aws_iam_role" "eks_node_group" {
  name = "${var.environment}-eks-node-group"
}

data "aws_iam_role" "eks_fargate_profile" {
  name = "${var.environment}-eks-fargate-profile"
}

data "aws_iam_role" "k8sadmin" {
  name = "${var.environment}-k8sadmin"
}

locals {
  partition                                = data.aws_partition.current.id
  account_id                               = data.aws_caller_identity.current.account_id
  env_domain                               = "${var.environment}.${var.route53_public_main_zone}"
  iam_openid_connect_provider_url_stripped = replace(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
  iam_openid_connect_provider_arn          = "arn:${local.partition}:iam::${local.account_id}:oidc-provider/${local.iam_openid_connect_provider_url_stripped}"
}
