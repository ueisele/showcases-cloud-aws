variable "region" {
  default = "eu-central-1"
}

variable "profile" {
  default = "default"
}

variable "environment" {
  default = "showcase"
}

variable "module" {
  default = "eks"
}

variable "route53_public_main_zone" {
  default = "aws.uweeisele.dev"
}

variable "eks_cluster_dns_ip" {
  default = "172.20.0.10"
  description = "'cluster-dns-ip' setting of instance template user data"
}