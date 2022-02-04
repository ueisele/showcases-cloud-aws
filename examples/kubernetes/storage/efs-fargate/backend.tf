# https://www.terraform.io/docs/language/settings/backends/s3.html
terraform {
  backend "s3" {
    region         = "eu-central-1"
    key            = "examples-k8s-storage-efs-fargate"
    bucket         = "showcase-tfstate"
    dynamodb_table = "showcase-tfstate"
  }
}
