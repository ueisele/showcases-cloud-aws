
data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "main" {
  name = "${var.environment}-${var.module}"
}

data "aws_eks_cluster_auth" "main" {
  name = "${var.environment}-${var.module}"
}

locals {
  partition    = data.aws_partition.current.id
  account_id   = data.aws_caller_identity.current.account_id
  iam_openid_connect_provider_url_stripped = replace(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
  iam_openid_connect_provider_arn          = "arn:${local.partition}:iam::${local.account_id}:oidc-provider/${local.iam_openid_connect_provider_url_stripped}"
}