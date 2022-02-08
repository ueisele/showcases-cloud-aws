data "aws_caller_identity" "current" {}

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

data "aws_directory_service_directory" "local" {
  directory_id = var.local_ldap_id
}

data "aws_directory_service_directory" "remote" {
  directory_id = var.remote_ldap_id
}
