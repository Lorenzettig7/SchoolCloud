# modules/edge_portal/main.tf

locals {
  bucket_name = "${var.project}-portal-${var.region}"
  waf_name    = "${var.project}-waf"
}

# -----------------------------
# S3: Private bucket for portal
# -----------------------------
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

# ----------------------------------------------------------------
# CloudFront: OAC (SigV4) so CF can read from private S3 origin
# ----------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "portal" {
  provider = aws.edge

  name                              = "${var.project}-oac"
  description                       = "OAC for ${var.project} portal"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ----------------------------------------------------
# WAF (global/CLOUDFRONT) – pin to aws.edge (us-east-1)
# ----------------------------------------------------
resource "aws_wafv2_web_acl" "portal" {
  provider    = aws.edge
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
    metric_name                = local.waf_name
    sampled_requests_enabled   = true
  }
}

# -------------------------------------------------
# CloudFront distribution (global) – pin aws.edge
# -------------------------------------------------
resource "aws_cloudfront_distribution" "portal" {
  provider            = aws.edge
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  web_acl_id          = aws_wafv2_web_acl.portal.arn
  aliases             = [var.portal_fqdn]

  origin {
    domain_name              = aws_s3_bucket.portal.bucket_regional_domain_name
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

# ---------------------------------------------------------
# S3 bucket policy: allow CloudFront (OAC) to GetObject
# ---------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "portal_bucket_policy" {
  statement {
    sid     = "AllowCloudFrontServicePrincipalRead"
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.portal.arn}/*"
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    # Restrict reads to *this* distribution (supported by AWS now)
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.portal.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "portal" {
  bucket = aws_s3_bucket.portal.id
  policy = data.aws_iam_policy_document.portal_bucket_policy.json
}

# ----------------
# Module outputs
# ----------------
output "portal_bucket_id" {
  value = aws_s3_bucket.portal.id
}

output "portal_distribution_id" {
  value = aws_cloudfront_distribution.portal.id
}

output "portal_domain_name" {
  value = aws_cloudfront_distribution.portal.domain_name
}

output "portal_hosted_zone_id" {
  value = aws_cloudfront_distribution.portal.hosted_zone_id
}

