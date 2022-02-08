#################################
# Route 53                      #
#################################
# https://aws.amazon.com/de/blogs/networking-and-content-delivery/integrating-your-directory-services-dns-resolution-with-amazon-route-53-resolvers/

# https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-forwarding-outbound-queries.html#resolver-forwarding-outbound-queries-endpoint-values
resource "aws_security_group" "ldap_dns_resolver_outbound" {
  name        = "${var.environment}-ldap-dns-resolver-outbound"
  description = "Allow DNS from and to LDAP Route 53 resolver endpoint"
  vpc_id      = data.aws_vpc.main.id

  ingress = [
    {
      protocol         = "udp"
      cidr_blocks      = [data.aws_vpc.main.cidr_block]
      ipv6_cidr_blocks = [data.aws_vpc.main.ipv6_cidr_block]
      from_port        = 53
      to_port          = 53
      description      = "DNS from Amazon Provided DNS"
      prefix_list_ids  = null
      security_groups  = null
      self             = false
    },
    {
      protocol         = "tcp"
      cidr_blocks      = [data.aws_vpc.main.cidr_block]
      ipv6_cidr_blocks = [data.aws_vpc.main.ipv6_cidr_block]
      from_port        = 53
      to_port          = 53
      description      = "DNS from Amazon Provided DNS"
      prefix_list_ids  = null
      security_groups  = null
      self             = false
    }
  ]

  egress = [
    {
      protocol         = "udp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      from_port        = 53
      to_port          = 53
      description      = "DNS queries"
      prefix_list_ids  = null
      security_groups  = null
      self             = false
    },
    {
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      from_port        = 53
      to_port          = 53
      description      = "DNS queries"
      prefix_list_ids  = null
      security_groups  = null
      self             = false
    }
  ]

  tags = {
    Name        = "${var.environment}-ldap-dns-resolver-outbound"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_route53_resolver_endpoint" "ldap_dns_resolver_outbound" {
  name      = "${var.environment}-ldap-dns-resolver-outbound"
  direction = "OUTBOUND"

  security_group_ids = [aws_security_group.ldap_dns_resolver_outbound.id]

  dynamic "ip_address" {
    for_each = local.ldap_subnet_ids
    content {
      subnet_id = ip_address.value
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

#################################
# Resolver Rules (Local)        #
#################################

resource "aws_route53_resolver_rule" "local_ldap" {
  domain_name          = aws_directory_service_directory.local.name
  name                 = replace(aws_directory_service_directory.local.name, ".", "-")
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.ldap_dns_resolver_outbound.id

  dynamic "target_ip" {
    for_each = aws_directory_service_directory.local.dns_ip_addresses
    content {
      ip = target_ip.value
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_route53_resolver_rule_association" "local_ldap" {
  resolver_rule_id = aws_route53_resolver_rule.local_ldap.id
  vpc_id           = data.aws_vpc.main.id
}

## Reverse DNS

locals {
  local_ldap_dns_ip_addresses = tolist(aws_directory_service_directory.local.dns_ip_addresses)
}

resource "aws_route53_resolver_rule" "local_ldap_reverse" {
  count = 2

  domain_name = (format("%s.%s.%s.%s.in-addr.arpa",
    element(split(".", element(
      local.local_ldap_dns_ip_addresses, count.index
    )), 3),
    element(split(".", element(
      local.local_ldap_dns_ip_addresses, count.index
    )), 2),
    element(split(".", element(
      local.local_ldap_dns_ip_addresses, count.index
    )), 1),
    element(split(".", element(
      local.local_ldap_dns_ip_addresses, count.index
    )), 0)
  ))
  name                 = "${replace(aws_directory_service_directory.local.name, ".", "-")}-reverse-${count.index}"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.ldap_dns_resolver_outbound.id

  dynamic "target_ip" {
    for_each = local.local_ldap_dns_ip_addresses
    content {
      ip = target_ip.value
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_route53_resolver_rule_association" "local_ldap_reverse" {
  count = length(aws_route53_resolver_rule.local_ldap_reverse)

  resolver_rule_id = element(aws_route53_resolver_rule.local_ldap_reverse.*.id, count.index)
  vpc_id           = data.aws_vpc.main.id
}

#################################
# Resolver Rules (Remote)       #
#################################

resource "aws_route53_resolver_rule" "remote_ldap" {
  domain_name          = aws_directory_service_directory.remote.name
  name                 = replace(aws_directory_service_directory.remote.name, ".", "-")
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.ldap_dns_resolver_outbound.id

  dynamic "target_ip" {
    for_each = aws_directory_service_directory.remote.dns_ip_addresses
    content {
      ip = target_ip.value
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_route53_resolver_rule_association" "remote_ldap" {
  resolver_rule_id = aws_route53_resolver_rule.remote_ldap.id
  vpc_id           = data.aws_vpc.main.id
}

## Reverse DNS

locals {
  remote_ldap_dns_ip_addresses = tolist(aws_directory_service_directory.remote.dns_ip_addresses)
}

resource "aws_route53_resolver_rule" "remote_ldap_reverse" {
  count = 2

  domain_name = (format("%s.%s.%s.%s.in-addr.arpa",
    element(split(".", element(
      local.remote_ldap_dns_ip_addresses, count.index
    )), 3),
    element(split(".", element(
      local.remote_ldap_dns_ip_addresses, count.index
    )), 2),
    element(split(".", element(
      local.remote_ldap_dns_ip_addresses, count.index
    )), 1),
    element(split(".", element(
      local.remote_ldap_dns_ip_addresses, count.index
    )), 0)
  ))
  name                 = "${replace(aws_directory_service_directory.remote.name, ".", "-")}-reverse-${count.index}"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.ldap_dns_resolver_outbound.id

  dynamic "target_ip" {
    for_each = local.remote_ldap_dns_ip_addresses
    content {
      ip = target_ip.value
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_route53_resolver_rule_association" "remote_ldap_reverse" {
  count = length(aws_route53_resolver_rule.remote_ldap_reverse)

  resolver_rule_id = element(aws_route53_resolver_rule.remote_ldap_reverse.*.id, count.index)
  vpc_id           = data.aws_vpc.main.id
}
