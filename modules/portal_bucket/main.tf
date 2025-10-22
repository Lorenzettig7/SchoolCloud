locals {
  bucket_name = "${var.project}-portal-${var.region}"
}

resource "aws_s3_bucket" "portal" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "portal" {
  bucket                  = aws_s3_bucket.portal.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "portal" {
  bucket = aws_s3_bucket.portal.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "portal" {
  bucket = aws_s3_bucket.portal.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
