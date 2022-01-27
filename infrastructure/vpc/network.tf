#################################
# VPC                           #
#################################

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
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

output "vpc-id" {
  value = aws_vpc.main.id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
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

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "public" {
  count = length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-public"
    Environment = var.environment
    Terraform   = "true"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public[0].id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
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

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "private" {
  count = length(var.private_subnets)

  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-private-${count.index}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

#################################
# Internet                      #
#################################

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = var.environment
    Environment = var.environment
    Terraform   = "true"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route
resource "aws_route" "public_internet_gateway" {
  count = length(var.public_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route
resource "aws_route" "public_internet_gateway_ipv6" {
  count = length(var.public_subnet_ipv6_prefixes) > 0 ? 1 : 0

  route_table_id              = aws_route_table.public[0].id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.gw.id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
resource "aws_eip" "nat" {
  count = length(var.private_subnets) > 0 ? min(var.nat_gateway_count, length(var.private_subnets)) : 0

  vpc = true

  tags = {
    Name        = "${var.environment}-nat-${count.index}"
    Environment = var.environment
    Terraform   = "true"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway
resource "aws_nat_gateway" "nat" {
  count = length(var.private_subnets) > 0 ? min(var.nat_gateway_count, length(var.private_subnets)) : 0

  allocation_id = element(aws_eip.nat.*.id, count.index)
  subnet_id     = element(aws_subnet.public.*.id, count.index % length(aws_subnet.public.*))

  tags = {
    Name        = "${var.environment}-${count.index}"
    Environment = var.environment
    Terraform   = "true"
  }

  depends_on = [aws_internet_gateway.gw]
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route
resource "aws_route" "private_nat_gateway" {
  count = length(var.public_subnets) > 0 ? length(var.private_subnets) : 0

  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.nat.*.id, count.index % length(aws_nat_gateway.nat.*))
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/egress_only_internet_gateway
resource "aws_egress_only_internet_gateway" "gw" {
  count = length(var.private_subnet_ipv6_prefixes) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = {
    Name        = var.environment
    Environment = var.environment
    Terraform   = "true"
  }

}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route
resource "aws_route" "private_ipv6_egress" {
  count = length(var.private_subnet_ipv6_prefixes)

  route_table_id              = element(aws_route_table.private.*.id, count.index)
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = element(aws_egress_only_internet_gateway.gw.*.id, 0)
}

#################################
# Route53                       #
#################################

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone
data "aws_route53_zone" "main" {
  name = "${var.route53_public_main_zone}."
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone
resource "aws_route53_zone" "public" {
  name = "${var.environment}.${var.route53_public_main_zone}"

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

output "public-hosted-zone-id" {
  value = aws_route53_zone.public.id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
resource "aws_route53_record" "public-ns" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = aws_route53_zone.public.name
  type    = "NS"
  ttl     = "30"
  records = aws_route53_zone.public.name_servers
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone
# https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zone-private-considerations.html
resource "aws_route53_zone" "private" {
  name = "${var.environment}.${var.route53_public_main_zone}"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

output "private-hosted-zone-id" {
  value = aws_route53_zone.public.id
}

#################################
# ACM Certificates              #
#################################

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate
resource "aws_acm_certificate" "public" {
  domain_name       = "*.${aws_route53_zone.public.name}"
  validation_method = "DNS"

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
resource "aws_route53_record" "public-validation" {
  for_each = {
    for dvo in aws_acm_certificate.public.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.public.zone_id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation
resource "aws_acm_certificate_validation" "public" {
  certificate_arn         = aws_acm_certificate.public.arn
  validation_record_fqdns = [for record in aws_route53_record.public-validation : record.fqdn]
}

output "public-certificate-arn" {
  value = aws_acm_certificate.public.arn
}

#################################
# DHCP                          #
#################################

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_dhcp_options
resource "aws_vpc_dhcp_options" "main" {
  domain_name         = aws_route53_zone.private.name
  domain_name_servers = ["AmazonProvidedDNS"]
  ntp_servers         = ["169.254.169.123"]

  tags = {
    Name        = var.environment
    Environment = var.environment
    Terraform   = "true"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_dhcp_options_association
resource "aws_vpc_dhcp_options_association" "this" {
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.main.id
}

#################################
# Security (ACL)                #
#################################

### Default ACL

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_network_acl
resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.main.default_network_acl_id

  tags = {
    Name        = "${var.environment}-default"
    Environment = var.environment
    Terraform   = "true"
  }
}

### Public ACL

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl
resource "aws_network_acl" "public" {
  count = length(var.public_subnets) > 0 ? 1 : 0

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public.*.id

  tags = {
    Name        = "${var.environment}-public"
    Environment = var.environment
    Terraform   = "true"
  }
}

## Public ACL Ingress Rules

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_ingress_ipv4_http" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  egress         = false
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_ingress_ipv6_http" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.public[0].id
  egress          = false
  rule_number     = 110
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 80
  to_port         = 80
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_ingress_ipv4_https" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  egress         = false
  rule_number    = 120
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_ingress_ipv6_https" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.public[0].id
  egress          = false
  rule_number     = 130
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 443
  to_port         = 443
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_ingress_ipv4_ephemeral" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  egress         = false
  rule_number    = 200
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1025
  to_port        = 65535
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_ingress_ipv6_ephemeral" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.public[0].id
  egress          = false
  rule_number     = 210
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 1025
  to_port         = 65535
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_ingress_ipv4_vpc" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  egress         = false
  rule_number    = 300
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 0
  to_port        = 0
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_ingress_ipv6_vpc" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.public[0].id
  egress          = false
  rule_number     = 310
  protocol        = -1
  rule_action     = "allow"
  ipv6_cidr_block = aws_vpc.main.ipv6_cidr_block
  from_port       = 0
  to_port         = 0
}

## Public ACL Egress Rules

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_egress_ipv4_ephemeral" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  egress         = true
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1025
  to_port        = 65535
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_egress_ipv6_ephemeral" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.public[0].id
  egress          = true
  rule_number     = 110
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 1025
  to_port         = 65535
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_egress_ipv4_http" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  egress         = true
  rule_number    = 200
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_egress_ipv6_http" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.public[0].id
  egress          = true
  rule_number     = 210
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 80
  to_port         = 80
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_egress_ipv4_https" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  egress         = true
  rule_number    = 220
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_egress_ipv6_https" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.public[0].id
  egress          = true
  rule_number     = 230
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 443
  to_port         = 443
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_egress_ipv4_kafka" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  egress         = true
  rule_number    = 240
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 9092
  to_port        = 9092
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_egress_ipv6_kafka" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.public[0].id
  egress          = true
  rule_number     = 250
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 9092
  to_port         = 9092
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_egress_ipv4_vpc" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  egress         = true
  rule_number    = 300
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 0
  to_port        = 0
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "public_egress_ipv6_vpc" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.public[0].id
  egress          = true
  rule_number     = 310
  protocol        = -1
  rule_action     = "allow"
  ipv6_cidr_block = aws_vpc.main.ipv6_cidr_block
  from_port       = 0
  to_port         = 0
}

### Private ACL

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl
resource "aws_network_acl" "private" {
  count = length(var.private_subnets) > 0 ? 1 : 0

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private.*.id

  tags = {
    Name        = "${var.environment}-private"
    Environment = var.environment
    Terraform   = "true"
  }
}

## Private ACL Ingress Rules

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "private_ingress_ipv4_ephemeral" {
  count = length(aws_network_acl.private.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.private[0].id
  egress         = false
  rule_number    = 200
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1025
  to_port        = 65535
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "private_ingress_ipv6_ephemeral" {
  count = length(aws_network_acl.private.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.private[0].id
  egress          = false
  rule_number     = 210
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 1025
  to_port         = 65535
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "private_ingress_ipv4_vpc" {
  count = length(aws_network_acl.private.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.private[0].id
  egress         = false
  rule_number    = 300
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 0
  to_port        = 0
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "private_ingress_ipv6_vpc" {
  count = length(aws_network_acl.private.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.private[0].id
  egress          = false
  rule_number     = 310
  protocol        = -1
  rule_action     = "allow"
  ipv6_cidr_block = aws_vpc.main.ipv6_cidr_block
  from_port       = 0
  to_port         = 0
}

## Private ACL Egress Rules

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "private_egress_ipv4_http" {
  count = length(aws_network_acl.private.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.private[0].id
  egress         = true
  rule_number    = 200
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "private_egress_ipv6_http" {
  count = length(aws_network_acl.private.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.private[0].id
  egress          = true
  rule_number     = 210
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 80
  to_port         = 80
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "private_egress_ipv4_https" {
  count = length(aws_network_acl.private.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.private[0].id
  egress         = true
  rule_number    = 220
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "private_egress_ipv6_https" {
  count = length(aws_network_acl.private.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.private[0].id
  egress          = true
  rule_number     = 230
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 443
  to_port         = 443
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "private_egress_ipv4_kafka" {
  count = length(aws_network_acl.private.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.private[0].id
  egress         = true
  rule_number    = 240
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 9092
  to_port        = 9092
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "private_egress_ipv6_kafka" {
  count = length(aws_network_acl.private.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.private[0].id
  egress          = true
  rule_number     = 250
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 9092
  to_port         = 9092
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "private_egress_ipv4_vpc" {
  count = length(aws_network_acl.private.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.private[0].id
  egress         = true
  rule_number    = 300
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = 0
  to_port        = 0
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl_rule
resource "aws_network_acl_rule" "private_egress_ipv6_vpc" {
  count = length(aws_network_acl.private.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.private[0].id
  egress          = true
  rule_number     = 310
  protocol        = -1
  rule_action     = "allow"
  ipv6_cidr_block = aws_vpc.main.ipv6_cidr_block
  from_port       = 0
  to_port         = 0
}

#################################
# Security (SG)                 #
#################################

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  egress = [
    {
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      from_port        = 80
      to_port          = 80
      description      = "HTTP"
      prefix_list_ids  = null
      security_groups  = null
      self             = false
    },
    {
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      from_port        = 443
      to_port          = 443
      description      = "HTTPS"
      prefix_list_ids  = null
      security_groups  = null
      self             = false
    }
  ]

  tags = {
    Name        = "${var.environment}-default"
    Environment = var.environment
    Tier        = "default"
    Terraform   = "true"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "public" {
  name = "${var.environment}-public"

  vpc_id = aws_vpc.main.id

  ingress = [
    {
      protocol         = -1
      cidr_blocks      = [aws_vpc.main.cidr_block]
      ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
      from_port        = 0
      to_port          = 0
      description      = null
      prefix_list_ids  = null
      security_groups  = null
      self             = false
    }
  ]

  egress = [
    {
      protocol         = -1
      cidr_blocks      = [aws_vpc.main.cidr_block]
      ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
      from_port        = 0
      to_port          = 0
      description      = null
      prefix_list_ids  = null
      security_groups  = null
      self             = false
    }
  ]

  tags = {
    Name        = "${var.environment}-public"
    Environment = var.environment
    Tier        = "public"
    Terraform   = "true"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "private" {
  name = "${var.environment}-private"

  vpc_id = aws_vpc.main.id

  ingress = [
    {
      protocol         = -1
      cidr_blocks      = [aws_vpc.main.cidr_block]
      ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
      from_port        = 0
      to_port          = 0
      description      = null
      prefix_list_ids  = null
      security_groups  = null
      self             = false
    }
  ]

  egress = [
    {
      protocol         = -1
      cidr_blocks      = aws_subnet.private.*.cidr_block
      ipv6_cidr_blocks = aws_subnet.private.*.ipv6_cidr_block
      from_port        = 0
      to_port          = 0
      description      = null
      prefix_list_ids  = null
      security_groups  = null
      self             = false
    }
  ]

  tags = {
    Name        = "${var.environment}-private"
    Environment = var.environment
    Tier        = "private"
    Terraform   = "true"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "web" {
  name = "${var.environment}-web"

  vpc_id = aws_vpc.main.id

  ingress = [
    {
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      from_port        = 80
      to_port          = 80
      description      = "HTTP"
      prefix_list_ids  = null
      security_groups  = null
      self             = false
    },
    {
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      from_port        = 443
      to_port          = 443
      description      = "HTTPS"
      prefix_list_ids  = null
      security_groups  = null
      self             = false
    }
  ]

  tags = {
    Name        = "${var.environment}-web"
    Environment = var.environment
    Tier        = "web"
    Terraform   = "true"
  }
}
