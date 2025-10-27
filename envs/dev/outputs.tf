output "portal_bucket_arn" {
  value = module.portal_bucket.bucket_arn
}

output "portal_bucket_domain" {
  value = module.portal_bucket.bucket_regional_domain_name
}

# Your API base URL already exported from the module we fixed
output "api_base_url" {
  value       = "${module.demo_identity_api.demo_api_endpoint}/prod"
  description = "Fully qualified base URL for the demo API including stage"
}

# Look up existing DynamoDB tables by name (they already exist in AWS)
data "aws_dynamodb_table" "users"  { name = "schoolcloud-demo-users" }
data "aws_dynamodb_table" "events" { name = "schoolcloud-demo-events" }

output "users_table"  { value = data.aws_dynamodb_table.users.name }
output "events_table" { value = data.aws_dynamodb_table.events.name }

