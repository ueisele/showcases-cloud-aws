# https://www.terraform.io/docs/language/settings/backends/s3.html
terraform {
  backend "s3" {
    region         = "eu-central-1"
    bucket         = "showcase-tfstate"
    key            = "showcase-ec2"
    dynamodb_table = "showcase-tfstate"
  }
}
