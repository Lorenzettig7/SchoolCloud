resource "aws_iam_policy" "boundary" {
  count  = var.create_boundary ? 1 : 0
  name   = "SchoolCloudBoundary"
  path   = "/"
  policy = data.aws_iam_policy_document.permissions_boundary.json
}
  # Build the boundary policy document in HCL (was raw JSON before)
data "aws_iam_policy_document" "permissions_boundary" {
  # Deny common IAM privilege-escalation paths
  statement {
    sid     = "NoPrivilegeEscalation"
    effect  = "Deny"
    actions = [
      "iam:CreatePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:PutRolePolicy",
    ]
    resources = ["*"]
  }

  # Your "TagGuardExceptKMS" JSON (use not_actions + condition in HCL)
  statement {
    sid         = "TagGuardExceptKMS"
    effect      = "Deny"
    not_actions = ["kms:*"]
    resources   = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:ResourceTag/Project"
      values   = ["schoolcloud"]
    }
  }

  # Your "RestrictKMSExceptAllowedAliases" JSON
  statement {
    sid      = "RestrictKMSExceptAllowedAliases"
    effect   = "Deny"
    actions  = ["kms:*"]
    resources = ["*"]

    # HCL for: "ForAnyValue:StringNotLike": { "kms:ResourceAliases": ["alias/schoolcloud/*","alias/aws/lambda"] }
    condition {
      test     = "ForAnyValue:StringNotLike"
      variable = "kms:ResourceAliases"
      values   = ["alias/schoolcloud/*", "alias/aws/lambda"]
    }
  }

  # Optional: read SSM params
  statement {
    sid      = "AllowSSMParameterRead"
    effect   = "Allow"
    actions  = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParameterHistory"]
    resources = ["*"]
  }
}
# --- Trust policy for Lambda execution role
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# --- Identity role
resource "aws_iam_role" "identity" {
  name               = "${var.project}-demo-identity-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Basic logging for Identity
resource "aws_iam_role_policy_attachment" "identity_logs" {
  role       = aws_iam_role.identity.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- Events role
resource "aws_iam_role" "events" {
  name               = "${var.project}-demo-events-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  permissions_boundary = var.permissions_boundary_arn
}

# Basic logging for Events
resource "aws_iam_role_policy_attachment" "events_logs" {
  role       = aws_iam_role.events.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
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
      BUILD_ID     = var.build_id
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
    REGION       = var.region
    BUILD_ID     = var.build_id 
  }
}
} 
# --- Allow SSM Parameter Store reads for JWT secret ---
resource "aws_iam_policy" "ssm_read" {
  name   = "${var.project}-ssm-read"
  path   = "/"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid      = "SSMRead",
      Effect   = "Allow",
      Action   = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParameterHistory"
      ],
      Resource = "*"
    }]
  })
}

# Attach to both Lambda roles (identity + events)
resource "aws_iam_role_policy_attachment" "identity_ssm_read" {
  role       = aws_iam_role.identity.name
  policy_arn = aws_iam_policy.ssm_read.arn
}

resource "aws_iam_role_policy_attachment" "events_ssm_read" {
  role       = aws_iam_role.events.name
  policy_arn = aws_iam_policy.ssm_read.arn
}
data "aws_caller_identity" "this" {}
data "aws_partition" "this" {}
# … if not already present

resource "aws_iam_policy" "identity_events_ddb_ssm" {
  name = "${var.project}-identity-events-ddb-ssm"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["dynamodb:GetItem","dynamodb:PutItem","dynamodb:UpdateItem","dynamodb:Query","dynamodb:Scan"],
        Resource = [
          "arn:${data.aws_partition.this.partition}:dynamodb:${var.region}:${data.aws_caller_identity.this.account_id}:table/schoolcloud-demo-users",
          "arn:${data.aws_partition.this.partition}:dynamodb:${var.region}:${data.aws_caller_identity.this.account_id}:table/schoolcloud-demo-users/index/*",
          "arn:${data.aws_partition.this.partition}:dynamodb:${var.region}:${data.aws_caller_identity.this.account_id}:table/schoolcloud-demo-events",
          "arn:${data.aws_partition.this.partition}:dynamodb:${var.region}:${data.aws_caller_identity.this.account_id}:table/schoolcloud-demo-events/index/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["ssm:GetParameter","ssm:GetParameters","ssm:GetParameterHistory"],
        Resource = "arn:${data.aws_partition.this.partition}:ssm:${var.region}:${data.aws_caller_identity.this.account_id}:parameter/schoolcloud-demo/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "identity_ddb_ssm" {
  role       = aws_iam_role.identity.name
  policy_arn = aws_iam_policy.identity_events_ddb_ssm.arn
}

resource "aws_iam_role_policy_attachment" "events_ddb_ssm" {
  role       = aws_iam_role.events.name
  policy_arn = aws_iam_policy.identity_events_ddb_ssm.arn
}
