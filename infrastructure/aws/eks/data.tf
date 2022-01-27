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

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet_ids
data "aws_subnet_ids" "public" {
  vpc_id = data.aws_vpc.main.id
  tags = {
    Tier = "public"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet_ids
data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.main.id
  tags = {
    Tier = "private"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_groups
data "aws_security_groups" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "group-name"
    values = ["${var.environment}-public"]
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_groups
data "aws_security_groups" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "group-name"
    values = ["${var.environment}-private"]
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_groups
data "aws_security_groups" "web" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "group-name"
    values = ["${var.environment}-web"]
  }
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
