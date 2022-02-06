#################################
# Route 53                      #
#################################
# https://aws.amazon.com/de/blogs/networking-and-content-delivery/integrating-your-directory-services-dns-resolution-with-amazon-route-53-resolvers/

# https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resolver-forwarding-outbound-queries.html#resolver-forwarding-outbound-queries-endpoint-values
resource "aws_security_group" "ldap_resolver_endpoint_outbound" {
  name        = "${replace(aws_directory_service_directory.main.name, ".", "-")}-ldap-resolver-outbound"
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
    Name        = "${replace(aws_directory_service_directory.main.name, ".", "-")}-ldap-resolver-outbound"
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_route53_resolver_endpoint" "ldap_resolver_endpoint_outbound" {
  name      = replace(aws_directory_service_directory.main.name, ".", "-")
  direction = "OUTBOUND"

  security_group_ids = [aws_security_group.ldap_resolver_endpoint_outbound.id]

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

resource "aws_route53_resolver_rule" "ldap_resolver_endpoint_outbound" {
  domain_name          = aws_directory_service_directory.main.name
  name                 = replace(aws_directory_service_directory.main.name, ".", "-")
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.ldap_resolver_endpoint_outbound.id

  dynamic "target_ip" {
    for_each = aws_directory_service_directory.main.dns_ip_addresses
    content {
      ip = target_ip.value
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_route53_resolver_rule_association" "ldap_resolver_endpoint_outbound" {
  resolver_rule_id = aws_route53_resolver_rule.ldap_resolver_endpoint_outbound.id
  vpc_id           = data.aws_vpc.main.id
}

## Reverse DNS

locals {
  ldap_dns_ip_addresses = tolist(aws_directory_service_directory.main.dns_ip_addresses)
}

resource "aws_route53_resolver_rule" "ldap_dns_resolver_reverse" {
  count = length(local.ldap_dns_ip_addresses)

  domain_name = (format("%s.%s.%s.%s.in-addr.arpa",
    element(split(".", element(
      local.ldap_dns_ip_addresses, count.index
    )), 3),
    element(split(".", element(
      local.ldap_dns_ip_addresses, count.index
    )), 2),
    element(split(".", element(
      local.ldap_dns_ip_addresses, count.index
    )), 1),
    element(split(".", element(
      local.ldap_dns_ip_addresses, count.index
    )), 0)
  ))
  name                 = "${replace(aws_directory_service_directory.main.name, ".", "-")}-reverse-${count.index}"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.ldap_resolver_endpoint_outbound.id

  dynamic "target_ip" {
    for_each = local.ldap_dns_ip_addresses
    content {
      ip = target_ip.value
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_route53_resolver_rule_association" "ldap_dns_resolver_reverse" {
  count = length(aws_route53_resolver_rule.ldap_dns_resolver_reverse)

  resolver_rule_id = element(aws_route53_resolver_rule.ldap_dns_resolver_reverse.*.id, count.index)
  vpc_id           = data.aws_vpc.main.id
}
