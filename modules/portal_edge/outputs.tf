output "waf_arn" { value = aws_wafv2_web_acl.portal.arn }
output "distribution_id" { value = aws_cloudfront_distribution.portal.id }
output "distribution_domain" { value = aws_cloudfront_distribution.portal.domain_name }
output "distribution_zone_id" { value = aws_cloudfront_distribution.portal.hosted_zone_id }
