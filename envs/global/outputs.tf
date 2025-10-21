output "portal_bucket" {
  value = module.edge_portal.portal_bucket_id
}

output "portal_domain" {
  value = module.edge_portal.portal_domain_name
}

output "cloudfront_distid" {
  value = module.edge_portal.portal_distribution_id
}

output "cf_hosted_zone_id" {
  value = module.edge_portal.portal_hosted_zone_id
}
