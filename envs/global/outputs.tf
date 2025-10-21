output "portal_cert_arn" {
  value = aws_acm_certificate_validation.portal.certificate_arn
}

output "root_zone_id" {
  value = data.aws_route53_zone.root.zone_id
}
