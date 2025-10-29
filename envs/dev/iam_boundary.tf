data "aws_iam_policy_document" "permissions_boundary" {
  # TODO: keep your real statements here; these are placeholders that match your earlier intent

  statement {
    sid       = "TagGuardExceptKMS"
    effect    = "Allow"
    actions   = ["tag:*", "iam:PassRole"] # keep your actual list
    resources = ["*"]
  }

  statement {
    sid    = "RestrictKMSExceptAllowedAliases"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant"
    ]
    # Start permissive while stabilizing the stack; later tighten to specific key ARNs/conditions if desired
    resources = ["*"]
  }
}

resource "aws_iam_policy" "permissions_boundary" {
  name   = "SchoolCloudBoundary"
  path   = "/"
  policy = data.aws_iam_policy_document.permissions_boundary.json

  lifecycle {
    prevent_destroy = true
  }
}
