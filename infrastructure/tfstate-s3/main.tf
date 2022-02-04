provider "aws" {
  region  = var.region
  profile = var.profile
}

resource "aws_kms_key" "terraform_state_key" {
  description             = "This key is used to encrypt terraform state bucket objects and tables"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7

  tags = {
    Name        = "${var.environment}-tfstate"
    Environment = var.environment
    Terraform   = "true"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.environment}-tfstate"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.terraform_state_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = {
    Name        = "${var.environment}-tfstate"
    Environment = var.environment
    Terraform   = "true"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_block_public" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "${var.environment}-tfstate"
  read_capacity  = 1
  write_capacity = 1

  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.terraform_state_key.arn
  }

  tags = {
    Name        = "${var.environment}-tfstate"
    Environment = var.environment
    Terraform   = "true"
  }

  lifecycle {
    prevent_destroy = true
  }
}
