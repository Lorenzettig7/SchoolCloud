##############################
# modules/portal_edge/main.tf
##############################

# This module assumes an existing private S3 bucket is passed in.
# Inputs (see modules/portal_edge/variables.tf):
# - project (string)
# - portal_fqdn (string)
# - portal_cert_arn (string)  # ACM cert in us-east-1
# - s3_bucket_arn (string)    # existing bucket ARN
# - s3_bucket_domain (string) # existing bucket regional domain (e.g., bucket.s3.us-east-1.amazonaws.com)
# - root_zone_id (string)     # hosted zone for "portal" record

##############################
# CloudFront OAC (global)
##############################
resource "aws_cloudfront_origin_access_control" "portal" {
  provider = aws.edge

  name                              = "${var.project}-oac"
  description                       = "Origin Access Control for ${var.project} portal"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

##############################
# WAF (global/CLOUDFRONT)
##############################
resource "aws_wafv2_web_acl" "portal" {
  provider    = aws.edge
  name        = "${var.project}-waf"
  description = "Basic WAF for ${var.project} portal"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-waf"
    sampled_requests_enabled   = true
  }
}

##############################
# CloudFront Distribution
##############################
resource "aws_cloudfront_distribution" "portal" {
  provider            = aws.edge
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  web_acl_id          = aws_wafv2_web_acl.portal.arn
  aliases             = [var.portal_fqdn]

  origin {
    domain_name              = var.s3_bucket_domain
    origin_id                = "portalS3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.portal.id
  }

  default_cache_behavior {
    target_origin_id       = "portalS3Origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.portal_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

##############################
# Outputs
##############################
output "portal_distribution_id" {
  value = aws_cloudfront_distribution.portal.id
}

output "portal_domain_name" {
  value = aws_cloudfront_distribution.portal.domain_name
}

output "portal_hosted_zone_id" {
  value = aws_cloudfront_distribution.portal.hosted_zone_id
}
