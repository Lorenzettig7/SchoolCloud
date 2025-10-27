
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

  # Use a literal JSON policy so there is zero ambiguity
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_openid_connect_provider.github.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:Lorenzettig7/SchoolCloud:*"
        }
      }
    }
  ]
}
EOF
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
resource "aws_iam_role" "identity" {
  name = "${var.project}-demo-identity-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_lambda_function" "identity" {
  function_name = "${var.project}-demo-identity"
  role          = aws_iam_role.identity.arn
  # Add your actual lambda config here
}
resource "aws_iam_role" "events" {
  name = "${var.project}-demo-events-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_lambda_function" "events" {
  function_name = "${var.project}-demo-events"
  role          = aws_iam_role.events.arn
  # Add your actual lambda config here
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy_dev.arn
}

