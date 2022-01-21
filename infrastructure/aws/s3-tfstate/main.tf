provider "aws" {
  region  = var.region
  profile = var.profile
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-aws-uweeisele-dev"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "terraform-aws-uweeisele-dev"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}