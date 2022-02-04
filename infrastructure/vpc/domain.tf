#################################
# Route53                       #
#################################
# https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zone-private-considerations.html

data "aws_route53_zone" "main" {
  name = "${var.route53_public_main_zone}."
}

resource "aws_route53_zone" "public" {
  name = "${var.environment}.${var.route53_public_main_zone}"

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_route53_record" "public_ns" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = aws_route53_zone.public.name
  type    = "NS"
  ttl     = "30"
  records = aws_route53_zone.public.name_servers
}

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

#################################
# ACM Certificates              #
#################################

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

resource "aws_route53_record" "public_validation" {
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

resource "aws_acm_certificate_validation" "public" {
  certificate_arn         = aws_acm_certificate.public.arn
  validation_record_fqdns = [for record in aws_route53_record.public_validation : record.fqdn]
}

output "public_certificate_arn" {
  value = aws_acm_certificate.public.arn
}

#################################
# DHCP                          #
#################################

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

resource "aws_vpc_dhcp_options_association" "main" {
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.main.id
}
