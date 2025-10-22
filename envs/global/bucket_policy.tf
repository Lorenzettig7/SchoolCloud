# envs/global/bucket_policy.tf

data "aws_caller_identity" "current" {}

locals {
  portal_bucket_name = replace(data.terraform_remote_state.dev.outputs.portal_bucket_arn, "arn:aws:s3:::", "")
  cloudfront_dist_arn = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${module.portal_edge.portal_distribution_id}"
}

data "aws_iam_policy_document" "portal_bucket_policy" {
  statement {
    sid     = "AllowCloudFrontReadViaOAC"
    actions = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::${local.portal_bucket_name}/*"
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [local.cloudfront_dist_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "portal" {
  bucket = local.portal_bucket_name
  policy = data.aws_iam_policy_document.portal_bucket_policy.json
}
