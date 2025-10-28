# envs/dev/auth.tf  (no variable blocks here)

data "aws_caller_identity" "this" {}
data "aws_partition" "this" {}

# -----------------------------
# IAM role for the Lambda
# -----------------------------
resource "aws_iam_role" "auth" {
  name               = "${var.project}-demo-auth-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  # <-- this must point to the ARN of SchoolCloudBoundary
  permissions_boundary = var.permissions_boundary_arn
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

  # Force AWS-managed key for env encryption
  kms_key_arn = "arn:aws:kms:us-east-1:${data.aws_caller_identity.this.account_id}:alias/aws/lambda"

  timeout = 30

  environment {
    variables = {
      REGION       = "us-east-1"
      USERS_TABLE  = "schoolcloud-demo-users"
      EVENTS_TABLE = "schoolcloud-demo-events"
      JWT_PARAM    = "/schoolcloud-demo/jwt_secret"
      JWT_SECRET   = "dev-demo-secret"
      BUILD_TS     = timestamp()   # forces config refresh & re-encryption
    }
  }
}

# Allow API Gateway v2 (HTTP API) to invoke the Auth Lambda
resource "aws_lambda_permission" "apigw_auth" {
  statement_id  = "AllowAPIGatewayInvokeAuth"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.demo_identity_api.execution_arn}/*/*"
}


# Optional outputs for other files to reference
output "auth_lambda_name" { value = aws_lambda_function.auth.function_name }
output "auth_lambda_arn" { value = aws_lambda_function.auth.arn }
