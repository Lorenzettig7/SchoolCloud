# envs/dev/auth.tf  (no variable blocks here)

data "aws_caller_identity" "this" {}
data "aws_partition" "this" {}
# Trust policy for the Lambda execution role
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# -----------------------------
# IAM role for the Lambda
# -----------------------------

resource "aws_iam_role" "auth" {
  name               = "${var.project}-demo-auth-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  # Use the boundary this module manages:
  permissions_boundary = aws_iam_policy.permissions_boundary.arn
}


# Basic logging
resource "aws_iam_role_policy_attachment" "auth_logs" {
  role       = aws_iam_role.auth.name
  policy_arn = "arn:${data.aws_partition.this.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDB + SSM access for the auth Lambda
resource "aws_iam_role_policy" "auth_ddb_ssm" {
  name = "${var.project}-auth-ddb-ssm"
  role = aws_iam_role.auth.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect : "Allow",
        Action : [
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:Query", "dynamodb:Scan"
        ],
        Resource : [
          "arn:${data.aws_partition.this.partition}:dynamodb:${var.region}:${data.aws_caller_identity.this.account_id}:table/schoolcloud-demo-users",
          "arn:${data.aws_partition.this.partition}:dynamodb:${var.region}:${data.aws_caller_identity.this.account_id}:table/schoolcloud-demo-users/index/*",
          "arn:${data.aws_partition.this.partition}:dynamodb:${var.region}:${data.aws_caller_identity.this.account_id}:table/schoolcloud-demo-events",
          "arn:${data.aws_partition.this.partition}:dynamodb:${var.region}:${data.aws_caller_identity.this.account_id}:table/schoolcloud-demo-events/index/*"
        ]
      },
      {
        Effect : "Allow",
        Action : ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParameterHistory"],
        Resource : "arn:${data.aws_partition.this.partition}:ssm:${var.region}:${data.aws_caller_identity.this.account_id}:parameter/schoolcloud-demo/*"
      }
    ]
  })
}

# -----------------------------
# Lambda function: AUTH
# -----------------------------
resource "aws_lambda_function" "auth" {
  function_name = "${var.project}-demo-auth"
  role          = aws_iam_role.auth.arn
  runtime       = "python3.12"
  handler       = "auth/handler.handler"

  filename         = "${path.module}/../../apps/auth.zip"
  source_code_hash = filebase64sha256("${path.module}/../../apps/auth.zip")


  timeout = 30

  environment {
    variables = {
      REGION       = "us-east-1"
      USERS_TABLE  = "schoolcloud-demo-users"
      EVENTS_TABLE = "schoolcloud-demo-events"
      JWT_PARAM    = "/schoolcloud-demo/jwt_secret"
      BUILD_TS     = timestamp() # forces config refresh & re-encryption
    }
  }
}


# Optional outputs for other files to reference
output "auth_lambda_name" { value = aws_lambda_function.auth.function_name }
output "auth_lambda_arn" { value = aws_lambda_function.auth.arn }
