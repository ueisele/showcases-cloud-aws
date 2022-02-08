#################################
# AWS Directory (Local)         #
#################################

resource "random_password" "local_ldap_password" {
  length           = 16
  special          = true
  override_special = "%=?@+#"
}

resource "aws_directory_service_directory" "local" {
  name     = "${var.environment}.${var.local_ldap_base_domain}"
  password = random_password.local_ldap_password.result
  edition  = "Standard"
  type     = "MicrosoftAD"

  vpc_settings {
    vpc_id     = data.aws_vpc.main.id
    subnet_ids = local.ldap_subnet_ids
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

output "local_ldap_id" {
  value = aws_directory_service_directory.local.id
}

output "local_ldap_name" {
  value = aws_directory_service_directory.local.name
}

output "local_ldap_dns_ip_addresses" {
  value = aws_directory_service_directory.local.dns_ip_addresses
}

output "local_ldap_username" {
  value = "Admin@${aws_directory_service_directory.local.name}"
}

output "local_ldap_password" {
  value     = random_password.local_ldap_password.result
  sensitive = true
}

#################################
# AWS Directory (Remote)        #
#################################

resource "random_password" "remote_ldap_password" {
  length           = 16
  special          = true
  override_special = "%=?@+#"
}

resource "aws_directory_service_directory" "remote" {
  name     = var.remote_ldap_domain
  password = random_password.remote_ldap_password.result
  edition  = "Standard"
  type     = "MicrosoftAD"

  vpc_settings {
    vpc_id     = data.aws_vpc.main.id
    subnet_ids = local.ldap_subnet_ids
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

output "remote_ldap_id" {
  value = aws_directory_service_directory.remote.id
}

output "remote_ldap_name" {
  value = aws_directory_service_directory.remote.name
}

output "remote_ldap_dns_ip_addresses" {
  value = aws_directory_service_directory.local.dns_ip_addresses
}

output "remote_ldap_username" {
  value = "Admin@${aws_directory_service_directory.remote.name}"
}

output "remote_ldap_password" {
  value     = random_password.remote_ldap_password.result
  sensitive = true
}
