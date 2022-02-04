data "aws_eks_cluster" "main" {
  name = var.environment
}

data "aws_eks_cluster_auth" "main" {
  name = var.environment
}

locals {
  env_domain = "${var.environment}.${var.route53_public_main_zone}"
}
