# WAFv2 (global)
resource "aws_wafv2_web_acl" "portal" {
  provider    = aws.edge
  name        = "${var.project}-waf"
  description = "Basic WAF for ${var.project} portal"
  scope       = "CLOUDFRONT"

  default_action { allow {} }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action { none {} }
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

# OAC for S3 origin
resource "aws_cloudfront_origin_access_control" "portal" {
  provider                           = aws.edge
  name                               = "portal-oac"
  origin_access_control_origin_type  = "s3"
  signing_behavior                   = "always"
  signing_protocol                   = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "portal" {
  provider            = aws.edge
  enabled             = true
  default_root_object = "index.html"

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
      cookies { forward = "none" }
    }
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  aliases = [var.portal_fqdn]

  viewer_certificate {
    acm_certificate_arn      = var.portal_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  web_acl_id = aws_wafv2_web_acl.portal.arn
}

# S3 bucket policy that limits access to this specific CF distribution
data "aws_iam_policy_document" "s3_cf" {
  statement {
    sid     = "AllowCloudFrontPrivateContent"
    actions = ["s3:GetObject"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    resources = ["${var.s3_bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.portal.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "portal" {
  bucket = trimprefix(var.s3_bucket_arn, "arn:aws:s3:::")
  policy = data.aws_iam_policy_document.s3_cf.json
}

# Route53 A/AAAA alias records
resource "aws_route53_record" "portal_alias_a" {
  zone_id = var.root_zone_id
  name    = replace(var.portal_fqdn, "/\\.$/", "") # ensure no trailing dot
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.portal.domain_name
    zone_id                = aws_cloudfront_distribution.portal.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "portal_alias_aaaa" {
  zone_id = var.root_zone_id
  name    = replace(var.portal_fqdn, "/\\.$/", "")
  type    = "AAAA"
  alias {
    name                   = aws_cloudfront_distribution.portal.domain_name
    zone_id                = aws_cloudfront_distribution.portal.hosted_zone_id
    evaluate_target_health = false
  }
}
