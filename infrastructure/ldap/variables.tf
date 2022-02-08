variable "region" {
  default = "eu-central-1"
}

variable "profile" {
  default = "default"
}

variable "environment" {
  default = "ada"
}

variable "local_ldap_base_domain" {
  default = "letuscode.xyz"
}

variable "remote_ldap_domain" {
  default = "com.codelabs.dev"
}

variable "ldap_az_1" {
  default = "eu-central-1a"
}

variable "ldap_az_2" {
  default = "eu-central-1b"
}
