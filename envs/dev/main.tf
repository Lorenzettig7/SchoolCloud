###############################################################################
# SchoolCloud Dev - API Gateway, Authorizer, Integrations, Routes, Stage, Logs
###############################################################################

#############################
# HTTP API
#############################
resource "aws_apigatewayv2_api" "demo" {
  name          = "${var.project}-demo-api"
  protocol_type = "HTTP"

  # Keep CORS permissive for dev; lock this down later
  cors_configuration {
    allow_headers = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_origins = ["*"]
  }

  tags = {
    Project = var.project
  }
}

#############################
# Cognito JWT Authorizer
#############################
# Replace these with your actual pool/clients if different
locals {
  cognito_issuer   = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_7soL15d0V"
  cognito_audience = "4vljm45is9ejulo4fhoo5a1bp" # portal app client ID
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id          = aws_apigatewayv2_api.demo.id
  name            = "cognito"
  authorizer_type = "JWT"

  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = local.cognito_issuer
    audience = [local.cognito_audience]
  }
}

#############################
# Integrations (Lambda proxy)
#############################
resource "aws_apigatewayv2_integration" "auth" {
  api_id                 = aws_apigatewayv2_api.demo.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.auth.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "identity" {
  api_id                 = aws_apigatewayv2_api.demo.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.identity.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "events" {
  api_id                 = aws_apigatewayv2_api.demo.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.events.invoke_arn
  payload_format_version = "2.0"
}

#############################
# Routes
#############################
# Public routes (no auth)
resource "aws_apigatewayv2_route" "auth_login" {
  api_id             = aws_apigatewayv2_api.demo.id
  route_key          = "POST /auth/login"
  target             = "integrations/${aws_apigatewayv2_integration.auth.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "auth_signup" {
  api_id             = aws_apigatewayv2_api.demo.id
  route_key          = "POST /auth/signup"
  target             = "integrations/${aws_apigatewayv2_integration.auth.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "auth_health" {
  api_id             = aws_apigatewayv2_api.demo.id
  route_key          = "GET /auth/health"
  target             = "integrations/${aws_apigatewayv2_integration.auth.id}"
  authorization_type = "NONE"
}

# Protected routes (JWT)
resource "aws_apigatewayv2_route" "get_events" {
  api_id    = aws_apigatewayv2_api.demo.id
  route_key = "GET /events"
  target    = "integrations/${aws_apigatewayv2_integration.events.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "post_identity" {
  api_id    = aws_apigatewayv2_api.demo.id
  route_key = "POST /identity"
  target    = "integrations/${aws_apigatewayv2_integration.identity.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

#############################
# Stage (auto deploy)
#############################
resource "aws_apigatewayv2_stage" "demo" {
  api_id      = aws_apigatewayv2_api.demo.id
  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      integrationError = "$context.integrationErrorMessage"
    })
  }
}

#############################
# Lambda invoke permissions
#############################
resource "aws_lambda_permission" "auth_invoke" {
  statement_id  = "AllowAPIGatewayInvokeAuth"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.demo.execution_arn}/*/*"
}

resource "aws_lambda_permission" "identity_invoke" {
  statement_id  = "AllowAPIGatewayInvokeIdentity"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.identity.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.demo.execution_arn}/*/*"
}

resource "aws_lambda_permission" "events_invoke" {
  statement_id  = "AllowAPIGatewayInvokeEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.events.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.demo.execution_arn}/*/*"
}

#############################
# Logs
#############################
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.project}-demo-api"
  retention_in_days = 14
}

#############################
# Outputs
#############################
output "api_endpoint" {
  value = aws_apigatewayv2_stage.demo.invoke_url
}
