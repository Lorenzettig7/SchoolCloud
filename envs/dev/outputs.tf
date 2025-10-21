output "deploy_role_arn" {
  value = module.identity.deploy_role_arn
}
output "portal_bucket" { value = module.edge_portal.portal_bucket }
output "portal_domain" { value = module.edge_portal.portal_domain }
output "cloudfront_distid" { value = module.edge_portal.distribution_id }
output "cf_hosted_zone_id" {
  value = module.edge_portal.cf_hosted_zone_id
}
