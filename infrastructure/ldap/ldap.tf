#################################
# AWS Directory                 #
#################################

resource "random_password" "main_ldap_password" {
  length           = 16
  special          = true
  override_special = "%=?@+#"
}

resource "aws_directory_service_directory" "main" {
  name     = "${var.environment}.${var.ldap_main_zone}"
  password = random_password.main_ldap_password.result
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

output "ldap_domain" {
  value = aws_directory_service_directory.main.name
}

output "ldap_access_url" {
  value = aws_directory_service_directory.main.access_url
}

output "ldap_username" {
  value     = "Admin@${aws_directory_service_directory.main.name}"
}

output "ldap_password" {
  value     = random_password.main_ldap_password.result
  sensitive = true
}
