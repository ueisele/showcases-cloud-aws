data "aws_caller_identity" "current" {}

data "aws_vpc" "main" {
  tags = {
    Name = var.environment
  }
}

data "aws_subnet_ids" "private_az_1" {
  vpc_id = data.aws_vpc.main.id
  tags = {
    Tier = "private"
  }
  filter {
    name   = "availability-zone"
    values = [var.ldap_az_1]
  }
}

data "aws_subnet_ids" "private_az_2" {
  vpc_id = data.aws_vpc.main.id
  tags = {
    Tier = "private"
  }
  filter {
    name   = "availability-zone"
    values = [var.ldap_az_2]
  }
}

locals {
  ldap_subnet_ids = [
    tolist(data.aws_subnet_ids.private_az_1.ids)[0],
    tolist(data.aws_subnet_ids.private_az_2.ids)[0]
  ]
}
