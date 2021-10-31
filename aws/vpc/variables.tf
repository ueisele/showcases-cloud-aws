variable "region" {
  default = "eu-central-1"
}

variable "profile" {
  default = "default"
}

variable "environment" {
  default = "asyncapi"
}

variable "route53_public_main_zone" {
  default = "aws.uweeisele.dev"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "azs" {
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "public_subnets" {
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_ipv6_prefixes" {
  type        = list(number)
  default     = [0, 1, 2]
}

variable "private_subnets" {
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
}

variable "private_subnet_ipv6_prefixes" {
  type        = list(number)
  default     = [3, 4, 5]
}
