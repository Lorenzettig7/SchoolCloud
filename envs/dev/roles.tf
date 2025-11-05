data "aws_caller_identity" "current" {}

resource "aws_iam_role" "identity" {
  name                 = "${var.project}-demo-identity-role"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role.json
  permissions_boundary = "arn:aws:iam::713881788173:policy/SchoolCloudBoundary"
  tags                 = { Project = var.project }
}

resource "aws_iam_role" "events" {
  name                 = "${var.project}-demo-events-role"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role.json
  permissions_boundary = "arn:aws:iam::713881788173:policy/SchoolCloudBoundary"
  tags                 = { Project = var.project }
}

# Managed policy attachments (replaces managed_policy_arns)
resource "aws_iam_role_policy_attachment" "identity_logs" {
  role       = aws_iam_role.identity.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "events_logs" {
  role       = aws_iam_role.events.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Inline DDB + SSM access policies
resource "aws_iam_role_policy" "identity_ddb_ssm" {
  name = "${var.project}-identity-ddb-ssm"
  role = aws_iam_role.identity.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "DdbRW",
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ],
        Resource = [
          "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/${var.project}-demo-users",
          "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/${var.project}-demo-users/index/*",
          "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/${var.project}-demo-events",
          "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/${var.project}-demo-events/index/*"
        ]
      },
      {
        Sid    = "SsmRead",
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParameterHistory"
        ],
        Resource = "arn:aws:ssm:us-east-1:${data.aws_caller_identity.current.account_id}:parameter/${var.project}-demo/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "events_ddb_ssm" {
  name   = "${var.project}-events-ddb-ssm"
  role   = aws_iam_role.events.id
  policy = aws_iam_role_policy.identity_ddb_ssm.policy
}
