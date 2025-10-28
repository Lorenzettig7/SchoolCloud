resource "aws_iam_policy" "boundary" {
  name        = "SchoolCloudBoundary"
  description = "Permissions boundary for SchoolCloud roles"
  policy      = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "NoPrivilegeEscalation",
        "Effect": "Deny",
        "Action": [
          "iam:CreatePolicyVersion",
          "iam:SetDefaultPolicyVersion",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:PutRolePolicy"
        ],
        "Resource": "*"
      },
      {
        "Sid": "TagGuardExceptKMS",
        "Effect": "Deny",
        "NotAction": [
          "kms:*"
        ],
        "Resource": "*",
        "Condition": {
          "StringNotEquals": {
            "aws:ResourceTag/Project": "schoolcloud"
          }
        }
      },
      {
        "Sid": "RestrictKMSExceptAllowedAliases",
        "Effect": "Deny",
        "Action": "kms:*",
        "Resource": "*",
        "Condition": {
          "ForAnyValue:StringNotLike": {
            "kms:ResourceAliases": [
              "alias/schoolcloud/*",
              "alias/aws/lambda"
            ]
          }
        }
      },
      {
        "Sid": "AllowSSMParameterRead",
        "Effect": "Allow",
        "Action": [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParameterHistory"
        ],
        "Resource": "*"
      }
    ]
  })
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

# --- Identity Lambda ---
resource "aws_lambda_function" "identity" {
  function_name    = "${var.project}-demo-identity"
  role             = aws_iam_role.identity.arn
  runtime          = "python3.12"
  handler          = "identity/handler.handler"
  filename         = "${path.module}/../../apps/identity.zip"
  source_code_hash = filebase64sha256("${path.module}/../../apps/identity.zip")
  timeout          = 30

  environment {
    variables = {
      USERS_TABLE  = "schoolcloud-demo-users"
      EVENTS_TABLE = "schoolcloud-demo-events"
      JWT_PARAM    = "/schoolcloud-demo/jwt_secret"
      REGION       = var.region
      JWT_SECRET   = "dev-demo-secret"
    }
  }
} 

# --- Events Lambda ---
resource "aws_lambda_function" "events" {
  function_name    = "${var.project}-demo-events"
  role             = aws_iam_role.events.arn
  runtime          = "python3.12"
  handler          = "events/handler.handler"
  filename         = "${path.module}/../../apps/events.zip"
  source_code_hash = filebase64sha256("${path.module}/../../apps/events.zip")
  timeout          = 30

  environment {
    variables = {
      USERS_TABLE  = "schoolcloud-demo-users"
      EVENTS_TABLE = "schoolcloud-demo-events"
      JWT_PARAM    = "/schoolcloud-demo/jwt_secret"
      JWT_SECRET   = "dev-demo-secret"
      REGION       = var.region
    }
  }
} 
