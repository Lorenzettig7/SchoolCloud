output "portal_bucket_arn" {
  value = module.portal_bucket.bucket_arn
}

output "portal_bucket_domain" {
  value = module.portal_bucket.bucket_regional_domain_name
}
output "api_base_url" {
  description = "Base URL for the demo identity API Gateway"
  value       = module.demo_identity_api.api_base_url
}

output "users_table" {
  value = module.demo_identity_api.users_table
}

output "events_table" {
  value = module.demo_identity_api.events_table
}
