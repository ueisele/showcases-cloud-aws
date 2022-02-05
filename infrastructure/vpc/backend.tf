# https://www.terraform.io/docs/language/settings/backends/s3.html
terraform {
  backend "s3" {
    region         = "eu-central-1"
    key            = "vpc"
    bucket         = "tfstate-ada"
    dynamodb_table = "tfstate-ada"
  }
}
