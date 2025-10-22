output "portal_bucket_arn" {
  value = module.portal_bucket.bucket_arn
}

output "portal_bucket_domain" {
  value = module.portal_bucket.bucket_regional_domain_name
}
