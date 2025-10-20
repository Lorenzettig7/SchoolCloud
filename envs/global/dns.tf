# Look up the public hosted zone for your domain
data "aws_route53_zone" "root" {
  name         = "secureschoolcloud.org."
  private_zone = false
}

# If you want the record to be portal.secureschoolcloud.org
resource "aws_route53_record" "portal_alias_a" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "portal" # or "portal.secureschoolcloud.org"
  type    = "A"

  alias {
    name                   = module.edge_portal.portal_domain # <-- was cf_domain_name
    zone_id                = module.edge_portal.cf_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "portal_alias_aaaa" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "portal" # keep same label as A
  type    = "AAAA"

  alias {
    name                   = module.edge_portal.portal_domain # <-- was cf_domain_name
    zone_id                = module.edge_portal.cf_hosted_zone_id
    evaluate_target_health = false
  }
}
