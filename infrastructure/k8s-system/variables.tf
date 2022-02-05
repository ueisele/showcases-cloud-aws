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

variable "eks_cluster_dns_ip" {
  default     = "172.20.0.10"
  description = "'cluster-dns-ip' setting of instance template user data"
}

variable "k8s_admin_users" {
  type    = list(string)
  default = ["ueisele"]
}

variable "traefik_dashboard_expose" {
  type    = bool
  default = true
}
