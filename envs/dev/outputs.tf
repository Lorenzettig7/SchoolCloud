# ===== API base URL from the stage you defined in main.tf
output "api_base_url" {
  # If your stage name is "prod" in aws_apigatewayv2_stage.demo, this is the full invoke URL
  value       = aws_apigatewayv2_stage.demo.invoke_url
  description = "HTTP API invoke URL"
}

# ===== Portal bucket info (lookup by name instead of module reference)
# Adjust the bucket name if yours differs
data "aws_s3_bucket" "portal" {
  bucket = "${var.project}-portal-us-east-1"
}

output "portal_bucket_arn" {
  value       = data.aws_s3_bucket.portal.arn
  description = "Portal bucket ARN"
}

output "portal_bucket_domain" {
  value       = data.aws_s3_bucket.portal.bucket_regional_domain_name
  description = "Portal bucket regional domain"
}

# ===== DynamoDB tables (lookup by name instead of undeclared resources)
# Adjust names if your tables differ

