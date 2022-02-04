# https://www.terraform.io/docs/language/settings/backends/s3.html
terraform {
  backend "s3" {
    region         = "eu-central-1"
    key            = "showcase-k8s-system"
    bucket         = "showcase-tfstate"
    dynamodb_table = "showcase-tfstate"
  }
}
