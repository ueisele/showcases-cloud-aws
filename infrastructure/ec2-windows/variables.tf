variable "region" {
  default = "eu-central-1"
}

variable "profile" {
  default = "default"
}

variable "environment" {
  default = "ada"
}

variable "local_ldap_id" {
  type = string
}

variable "remote_ldap_id" {
  type = string
}
