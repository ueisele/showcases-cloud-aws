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

#################################
# Trust Relationship            #
#################################
# local -- one-way: outgoing --> remote
# remote <-- one-way: incoming -- local

# Unfortunately, the creation of trust relationship is not supported by Terraform until now:
#   https://github.com/hashicorp/terraform-provider-aws/issues/11901

# In this section the required security groups are created:
#   https://docs.aws.amazon.com/directoryservice/latest/admin-guide/ms_ad_tutorial_setup_trust_prepare_mad_between_2_managed_ad_domains.html

# Local LDAP Egress

resource "aws_security_group_rule" "local_egress_to_remote" {
  description              = "Allow any traffic to remote LDAP"
  security_group_id        = aws_directory_service_directory.local.security_group_id
  type                     = "egress"
  source_security_group_id = aws_directory_service_directory.remote.security_group_id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}

# Remote LDAP Ingress

resource "aws_security_group_rule" "remote_ingress_from_local" {
  description              = "Allow any traffic from local LDAP"
  security_group_id        = aws_directory_service_directory.remote.security_group_id
  type                     = "ingress"
  source_security_group_id = aws_directory_service_directory.local.security_group_id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}

# Remote LDAP Egress

resource "aws_security_group_rule" "remote_egress_to_local" {
  description              = "Allow any traffic to local LDAP"
  security_group_id        = aws_directory_service_directory.remote.security_group_id
  type                     = "egress"
  source_security_group_id = aws_directory_service_directory.local.security_group_id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}

# Local LDAP Ingress

resource "aws_security_group_rule" "local_ingress_from_remote" {
  description              = "Allow any traffic from remote LDAP"
  security_group_id        = aws_directory_service_directory.local.security_group_id
  type                     = "ingress"
  source_security_group_id = aws_directory_service_directory.remote.security_group_id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
}
