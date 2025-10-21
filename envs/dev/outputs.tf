output "deploy_role_arn" {
  value = module.identity.deploy_role_arn
}

output "portal_bucket_id" {
  value = module.edge_portal.portal_bucket_id
}

output "portal_distribution_id" {
  value = module.edge_portal.portal_distribution_id
}

output "portal_domain_name" {
  value = module.edge_portal.portal_domain_name
}

output "portal_hosted_zone_id" {
  value = module.edge_portal.portal_hosted_zone_id
}
