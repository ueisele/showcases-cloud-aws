variable "region" {
  default = "eu-central-1"
}

variable "profile" {
  default = "default"
}

variable "environment" {
  default = "ada"
}

variable "route53_public_main_zone" {
  default = "letuscode.dev"
}

variable "kubernetes_dashboard_expose" {
  type    = bool
  default = true
}
