# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
provider "aws" {
  region  = var.region
  profile = var.profile
}
