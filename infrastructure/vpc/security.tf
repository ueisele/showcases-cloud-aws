#################################
# Security (ACL)                #
#################################

### Default ACL

resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.main.default_network_acl_id

  tags = {
    Name        = "${var.environment}-default"
    Environment = var.environment
    Terraform   = "true"
  }
}

### Public ACL

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

resource "aws_network_acl_rule" "public_ingress_ipv4_rdp" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id = aws_network_acl.public[0].id
  egress         = false
  rule_number    = 140
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 3389
  to_port        = 3389
}

resource "aws_network_acl_rule" "public_ingress_ipv6_rdp" {
  count = length(aws_network_acl.public.*) > 0 ? 1 : 0

  network_acl_id  = aws_network_acl.public[0].id
  egress          = false
  rule_number     = 150
  protocol        = "tcp"
  rule_action     = "allow"
  ipv6_cidr_block = "::/0"
  from_port       = 3389
  to_port         = 3389
}

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
    },
    {
      protocol         = "udp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      from_port        = 53
      to_port          = 53
      description      = "DNS"
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
      description      = "DNS"
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
