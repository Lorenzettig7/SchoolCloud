
variable "project" { type = string }
variable "repo_sub" { type = string } # repo:Owner/Repo:ref:refs/heads/main

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_policy" "boundary" {
  name   = "SchoolCloudBoundary"
  policy = file("${path.module}/boundary.json")
}

resource "aws_iam_role" "deploy_dev" {
  name = "DeployRole-Dev"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" },
        StringLike   = { "token.actions.githubusercontent.com:sub" = var.repo_sub }
      }
    }]
  })
  permissions_boundary = aws_iam_policy.boundary.arn
}
resource "aws_iam_role_policy_attachment" "deploy_dev_poweruser" {
  role       = aws_iam_role.deploy_dev.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}
resource "aws_iam_role_policy_attachments_exclusive" "deploy_dev_exclusive" {
  role_name   = aws_iam_role.deploy_dev.name
  policy_arns = [aws_iam_role_policy_attachment.deploy_dev_poweruser.policy_arn]
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy_dev.arn
}

