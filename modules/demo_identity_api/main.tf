locals {
  name_prefix = "${var.project}-demo"
}

# ---------------------------------------------------------------------------
# API Gateway (DEMO)
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "demo" {
  name          = "${var.project}-demo-api"
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

  tags = {
    Project = var.project
  }
}

# Stage
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.demo.id
  name        = "prod"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 50
    throttling_rate_limit  = 25
  }
}

# ---------------------------------------------------------------------------
# Integrations (use Lambda ARNs passed in as variables)
# For HTTP APIs with AWS_PROXY, integration_uri is the Lambda function ARN.
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_integration" "auth" {
  api_id                 = aws_apigatewayv2_api.demo.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.auth_lambda_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

resource "aws_apigatewayv2_integration" "identity" {
  api_id                 = aws_apigatewayv2_api.demo.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.identity_lambda_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

resource "aws_apigatewayv2_integration" "events" {
  api_id                 = aws_apigatewayv2_api.demo.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.events_lambda_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_route" "auth_health" {
  api_id    = aws_apigatewayv2_api.demo.id
  route_key = "GET /auth/health"
  target    = "integrations/${aws_apigatewayv2_integration.auth.id}"
}

resource "aws_apigatewayv2_route" "auth_login" {
  api_id    = aws_apigatewayv2_api.demo.id
  route_key = "POST /auth/login"
  target    = "integrations/${aws_apigatewayv2_integration.auth.id}"
}

resource "aws_apigatewayv2_route" "auth_signup" {
  api_id    = aws_apigatewayv2_api.demo.id
  route_key = "POST /auth/signup"
  target    = "integrations/${aws_apigatewayv2_integration.auth.id}"
}

resource "aws_apigatewayv2_route" "post_group" {
  api_id    = aws_apigatewayv2_api.demo.id
  route_key = "POST /identity/group"
  target    = "integrations/${aws_apigatewayv2_integration.identity.id}"
}

resource "aws_apigatewayv2_route" "post_policy" {
  api_id    = aws_apigatewayv2_api.demo.id
  route_key = "POST /identity/policy"
  target    = "integrations/${aws_apigatewayv2_integration.identity.id}"
}

resource "aws_apigatewayv2_route" "get_events" {
  api_id    = aws_apigatewayv2_api.demo.id
  route_key = "GET /events"
  target    = "integrations/${aws_apigatewayv2_integration.events.id}"
}

# ---------------------------------------------------------------------------
# Lambda permissions (use the same Lambda ARNs you pass in)
# ---------------------------------------------------------------------------

resource "aws_lambda_permission" "auth" {
  statement_id  = "AllowAPIGWAuth"
  action        = "lambda:InvokeFunction"
  function_name = var.auth_lambda_arn          # ARN works here
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.demo.execution_arn}/*/*"
}

resource "aws_lambda_permission" "identity" {
  statement_id  = "AllowAPIGWIdentity"
  action        = "lambda:InvokeFunction"
  function_name = var.identity_lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.demo.execution_arn}/*/*"
}

resource "aws_lambda_permission" "events" {
  statement_id  = "AllowAPIGWEvents"
  action        = "lambda:InvokeFunction"
  function_name = var.events_lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.demo.execution_arn}/*/*"
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "demo_api_id" {
  value = aws_apigatewayv2_api.demo.id
}

output "demo_api_endpoint" {
  value = aws_apigatewayv2_api.demo.api_endpoint
}
