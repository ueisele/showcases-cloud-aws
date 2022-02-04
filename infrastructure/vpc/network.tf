#################################
# VPC                           #
#################################

resource "aws_vpc" "main" {
  cidr_block                       = var.vpc_cidr
  assign_generated_ipv6_cidr_block = true

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = var.environment
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id            = aws_vpc.main.id
  availability_zone = element(var.azs, count.index % length(var.azs))
  cidr_block        = element(var.public_subnets, count.index)
  ipv6_cidr_block   = length(var.public_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, var.public_subnet_ipv6_prefixes[count.index]) : null

  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = length(var.public_subnet_ipv6_prefixes) > 0

  tags = {
    Name        = "${var.environment}-public-${count.index}"
    Environment = var.environment
    Tier        = "public"
    Terraform   = "true"
  }
}

resource "aws_route_table" "public" {
  count = length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-public"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public[0].id
}

resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.main.id
  availability_zone = element(var.azs, count.index % length(var.azs))
  cidr_block        = element(var.private_subnets, count.index)
  ipv6_cidr_block   = length(var.private_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, var.private_subnet_ipv6_prefixes[count.index]) : null

  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = length(var.private_subnet_ipv6_prefixes) > 0

  tags = {
    Name        = "${var.environment}-private-${count.index}"
    Environment = var.environment
    Tier        = "private"
    Terraform   = "true"
  }
}

resource "aws_route_table" "private" {
  count = length(var.private_subnets)

  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-private-${count.index}"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}
