output "bucket_id" {
  value = aws_s3_bucket.portal.id
}

output "bucket_arn" {
  value = aws_s3_bucket.portal.arn
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.portal.bucket_regional_domain_name
}
