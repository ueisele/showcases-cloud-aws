data "aws_caller_identity" "current" {}

output "account-id" {
  value = data.aws_caller_identity.current.account_id
}

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

data "aws_route53_zone" "public" {
  name         = "${var.environment}.${var.route53_public_main_zone}"
  private_zone = false
}

data "aws_route53_zone" "private" {
  name         = "${var.environment}.${var.route53_public_main_zone}"
  private_zone = true
  vpc_id       = data.aws_vpc.main.id
}
