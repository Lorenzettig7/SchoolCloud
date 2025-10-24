##########################
# VARIABLES
##########################
variable "project" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "permissions_boundary_arn" {
  type    = string
  default = null
}
variable "github_repo_sub" {
  type        = string
  description = "Subject claim for GitHub OIDC (e.g., repo:owner/repo:ref)"
}


locals {
  name_prefix = "${var.project}-demo"
  apps_root   = "${path.module}/../../apps/api"
}

##########################
# DYNAMODB TABLES
##########################
resource "aws_dynamodb_table" "users" {
  name         = "${local.name_prefix}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "events" {
  name         = "${local.name_prefix}-events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}

##########################
# IAM ROLE & POLICIES
##########################
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api" {
  name                 = "${local.name_prefix}-api-role"
  assume_role_policy   = data.aws_iam_policy_document.assume_lambda.json
  permissions_boundary = var.permissions_boundary_arn
}

resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "ddb_access" {
  statement {
    sid    = "UsersTableAccess"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query"
    ]
    resources = [
      aws_dynamodb_table.users.arn,
      "${aws_dynamodb_table.users.arn}/index/*"
    ]
  }

  statement {
    sid    = "EventsTableAccess"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:Query"
    ]
    resources = [
      aws_dynamodb_table.events.arn,
      "${aws_dynamodb_table.events.arn}/index/*"
    ]
  }

  # Optional: read demo secret from SSM if you later store it
  statement {
    sid    = "ReadDemoSecret"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameterHistory",
      "ssm:GetParameters"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:*:parameter/${local.name_prefix}/jwt_secret"
    ]
  }
}

resource "aws_iam_policy" "ddb_access" {
  name   = "${local.name_prefix}-ddb-access"
  policy = data.aws_iam_policy_document.ddb_access.json
}

resource "aws_iam_role_policy_attachment" "ddb_access_attach" {
  role       = aws_iam_role.api.name
  policy_arn = aws_iam_policy.ddb_access.arn
}

##########################
# LAMBDAS (use your zipped handlers)
##########################
resource "aws_lambda_function" "auth" {
  function_name = "${local.name_prefix}-auth"
  role          = aws_iam_role.api.arn
  handler       = "handler.handler"
  runtime       = "python3.11"
  filename      = "${local.apps_root}/auth/package.zip"
  timeout       = 10

  environment {
    variables = {
      USERS_TABLE  = aws_dynamodb_table.users.name
      EVENTS_TABLE = aws_dynamodb_table.events.name
      JWT_PARAM    = "/${local.name_prefix}/jwt_secret"
      REGION       = var.region
    }
  }
}

resource "aws_lambda_function" "identity" {
  function_name = "${local.name_prefix}-identity"
  role          = aws_iam_role.api.arn
  handler       = "handler.handler"
  runtime       = "python3.11"
  filename      = "${local.apps_root}/identity/package.zip"
  timeout       = 10

  environment {
    variables = {
      USERS_TABLE  = aws_dynamodb_table.users.name
      EVENTS_TABLE = aws_dynamodb_table.events.name
      REGION       = var.region
    }
  }
}

resource "aws_lambda_function" "events" {
  function_name = "${local.name_prefix}-events"
  role          = aws_iam_role.api.arn
  handler       = "handler.handler"
  runtime       = "python3.11"
  filename      = "${local.apps_root}/events/package.zip"
  timeout       = 10

  environment {
    variables = {
      EVENTS_TABLE = aws_dynamodb_table.events.name
      REGION       = var.region
    }
  }
}

##########################
# HTTP API + STAGE + ROUTES
##########################
resource "aws_apigatewayv2_api" "http" {
  name          = "${local.name_prefix}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = [
      "https://portal.secureschoolcloud.org",
      "http://localhost:5173",
      "http://localhost:4173",
      "http://127.0.0.1:4173",
    ]
    allow_methods     = ["GET", "POST", "OPTIONS"]
    allow_headers     = ["authorization", "content-type"]
    allow_credentials = false
    max_age           = 86400
  }
}

resource "aws_apigatewayv2_stage" "nonprod" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "nonprod"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 50
    throttling_rate_limit  = 25
  }
}


resource "aws_apigatewayv2_integration" "auth" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.auth.invoke_arn
  payload_format_version = "2.0"   # <-- change from "1.0"
  timeout_milliseconds   = 29000
}

resource "aws_apigatewayv2_integration" "identity" {
  api_id           = aws_apigatewayv2_api.http.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.identity.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000 
}

resource "aws_apigatewayv2_integration" "events" {
  api_id           = aws_apigatewayv2_api.http.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.events.invoke_arn
  payload_format_version = "2.0" 
  timeout_milliseconds   = 29000
}

resource "aws_apigatewayv2_route" "post_signup" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /auth/signup"
  target    = "integrations/${aws_apigatewayv2_integration.auth.id}"
}

resource "aws_apigatewayv2_route" "post_login" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /auth/login"
  target    = "integrations/${aws_apigatewayv2_integration.auth.id}"
}

resource "aws_apigatewayv2_route" "post_group" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /identity/group"
  target    = "integrations/${aws_apigatewayv2_integration.identity.id}"
}

resource "aws_apigatewayv2_route" "post_policy" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /identity/policy"
  target    = "integrations/${aws_apigatewayv2_integration.identity.id}"
}

resource "aws_apigatewayv2_route" "get_events" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /events"
  target    = "integrations/${aws_apigatewayv2_integration.events.id}"
}

resource "aws_lambda_permission" "auth" {
  statement_id  = "AllowAPIGWAuth"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "identity" {
  statement_id  = "AllowAPIGWIdentity"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.identity.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "events" {
  statement_id  = "AllowAPIGWEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.events.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

##########################
# OUTPUTS
##########################
output "api_base_url" {
  value = "${aws_apigatewayv2_api.http.api_endpoint}/${aws_apigatewayv2_stage.nonprod.name}"
}

output "users_table" {
  value = aws_dynamodb_table.users.name
}

output "events_table" {
  value = aws_dynamodb_table.events.name
}
