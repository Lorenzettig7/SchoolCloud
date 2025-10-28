resource "aws_iam_policy" "boundary" {
  name   = "SchoolCloudBoundary"
  policy = file("${path.module}/boundary.json")

  lifecycle {
    prevent_destroy = true
  }
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

resource "aws_lambda_function" "identity" {
  function_name    = "${var.project}-demo-identity"
  role             = aws_iam_role.identity.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = "${path.module}/../../apps/api/identity/identity.zip"
  source_code_hash = filebase64sha256("${path.module}/../../apps/api/identity/identity.zip")


  timeout = 30

  environment {
    variables = {
      LOG_LEVEL = "info"
      USERS_TABLE = "schoolcloud-demo-users"
    }
  }
}

resource "aws_lambda_function" "events" {
  function_name    = "${var.project}-demo-events"
  role             = aws_iam_role.events.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = "${path.module}/../../apps/api/events/events.zip"
  source_code_hash = filebase64sha256("${path.module}/../../apps/api/events/events.zip")


  timeout = 30

  environment {
    variables = {
      LOG_LEVEL = "info"
    }
  }
}
