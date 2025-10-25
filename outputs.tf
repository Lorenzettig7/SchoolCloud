output "portal_domain" {
  description = "The CloudFront domain name for the SchoolCloud portal"
  value       = module.portal_edge.portal_domain_name
}
