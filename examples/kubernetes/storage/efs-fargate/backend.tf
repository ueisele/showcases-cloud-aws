# https://www.terraform.io/docs/language/settings/backends/s3.html
terraform {
  backend "s3" {
    region         = "eu-central-1"
    bucket         = "tfstate-aws-uweeisele-dev"
    key            = "examples-k8s-storage-efs-fargate"
    dynamodb_table = "tfstate-aws-uweeisele-dev"
  }
}
