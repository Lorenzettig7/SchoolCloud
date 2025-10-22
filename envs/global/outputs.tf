output "portal_domain" {
  value = module.portal_edge.portal_domain_name
}

output "cloudfront_distid" {
  value = module.portal_edge.portal_distribution_id
}

output "cf_hosted_zone_id" {
  value = module.portal_edge.portal_hosted_zone_id
}

# If you want to expose the bucket here too (sourced from dev state):
output "portal_bucket_arn" {
  value = data.terraform_remote_state.dev.outputs.portal_bucket_arn
}

output "portal_bucket_domain" {
  value = data.terraform_remote_state.dev.outputs.portal_bucket_domain
}