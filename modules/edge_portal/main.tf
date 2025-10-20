variable "project" { type = string }
variable "region"  { type = string }

locals {
  bucket_name = "${var.project}-portal-${var.region}"
  waf_name    = "${var.project}-waf"
}

# ----- S3 bucket for static site -----
resource "aws_s3_bucket" "portal" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "portal" {
  bucket                  = aws_s3_bucket.portal.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "portal" {
  bucket = aws_s3_bucket.portal.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "portal" {
  bucket = aws_s3_bucket.portal.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ----- WAF (managed rules) -----
resource "aws_wafv2_web_acl" "portal" {
  name        = local.waf_name
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

# ----- CloudFront (OAC to private S3) -----
resource "aws_cloudfront_distribution" "portal" {
  enabled             = true
  comment             = "${var.project} portal"
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.portal.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.portal.bucket}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${aws_s3_bucket.portal.bucket}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  price_class = "PriceClass_100"

  # ➜ Add your custom hostname here
  aliases = [var.portal_fqdn]

  # ➜ Use your ACM cert (in us-east-1)
  viewer_certificate {
    acm_certificate_arn      = var.portal_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  web_acl_id = aws_wafv2_web_acl.portal.arn
}


# ----- Outputs -----
output "portal_bucket"      { value = aws_s3_bucket.portal.id }
output "distribution_id"    { value = aws_cloudfront_distribution.portal.id }
output "portal_domain"      { value = aws_cloudfront_distribution.portal.domain_name }
output "cf_domain_name" {
  value = aws_cloudfront_distribution.portal.domain_name
}

output "cf_hosted_zone_id" {
  value = aws_cloudfront_distribution.portal.hosted_zone_id
}
