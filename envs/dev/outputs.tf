output "deploy_role_arn" {
  value = module.identity.deploy_role_arn
}
output "portal_bucket"     { value = module.edge_portal.portal_bucket }
output "portal_domain"     { value = module.edge_portal.portal_domain }
output "cloudfront_distid" { value = module.edge_portal.distribution_id }
