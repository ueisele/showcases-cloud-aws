#################################
# Internet                      #
#################################

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = var.environment
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_route" "public_internet_gateway" {
  count = length(var.public_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route" "public_internet_gateway_ipv6" {
  count = length(var.public_subnet_ipv6_prefixes) > 0 ? 1 : 0

  route_table_id              = aws_route_table.public[0].id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.gw.id
}

resource "aws_eip" "nat" {
  count = length(var.private_subnets) > 0 ? min(var.nat_gateway_count, length(var.private_subnets)) : 0

  vpc = true

  tags = {
    Name        = "${var.environment}-nat-${count.index}"
    Environment = var.environment
    Terraform   = "true"
  }
}

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

resource "aws_route" "private_nat_gateway" {
  count = length(var.public_subnets) > 0 ? length(var.private_subnets) : 0

  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.nat.*.id, count.index % length(aws_nat_gateway.nat.*))
}

resource "aws_egress_only_internet_gateway" "gw" {
  count = length(var.private_subnet_ipv6_prefixes) > 0 ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = {
    Name        = var.environment
    Environment = var.environment
    Terraform   = "true"
  }

}

resource "aws_route" "private_ipv6_egress" {
  count = length(var.private_subnet_ipv6_prefixes)

  route_table_id              = element(aws_route_table.private.*.id, count.index)
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = element(aws_egress_only_internet_gateway.gw.*.id, 0)
}
