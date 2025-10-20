data "aws_route53_zone" "root" {
  name         = "secureschoolcloud.org"
  private_zone = false
}

resource "aws_route53_record" "portal_alias_a" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "portal.secureschoolcloud.org"
  type    = "A"
  alias {
    name                   = module.edge_portal.cf_domain_name
    zone_id                = module.edge_portal.cf_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "portal_alias_aaaa" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "portal.secureschoolcloud.org"
  type    = "AAAA"
  alias {
    name                   = module.edge_portal.cf_domain_name
    zone_id                = module.edge_portal.cf_hosted_zone_id
    evaluate_target_health = false
  }
}
