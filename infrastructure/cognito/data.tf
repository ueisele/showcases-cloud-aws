data "aws_caller_identity" "current" {}

data "aws_vpc" "main" {
  tags = {
    Name = var.environment
  }
}

data "aws_route53_zone" "public" {
  name         = "${var.environment}.${var.route53_public_main_zone}"
  private_zone = false
}

data "aws_route53_zone" "private" {
  name         = "${var.environment}.${var.route53_public_main_zone}"
  private_zone = true
  vpc_id       = data.aws_vpc.main.id
}

data "aws_acm_certificate" "public" {
  domain      = "*.${data.aws_route53_zone.public.name}"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}
