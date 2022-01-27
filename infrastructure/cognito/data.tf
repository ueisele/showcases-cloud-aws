# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
data "aws_caller_identity" "current" {}

output "account-id" {
  value = data.aws_caller_identity.current.account_id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc
data "aws_vpc" "main" {
  tags = {
    Name = var.environment
  }
}

output "vpc-id" {
  value = data.aws_vpc.main.id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone
data "aws_route53_zone" "public" {
  name         = "${var.environment}.${var.route53_public_main_zone}"
  private_zone = false
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone
data "aws_route53_zone" "private" {
  name         = "${var.environment}.${var.route53_public_main_zone}"
  private_zone = true
  vpc_id       = data.aws_vpc.main.id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/acm_certificate
data "aws_acm_certificate" "public" {
  domain      = "*.${data.aws_route53_zone.public.name}"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}
