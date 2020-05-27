################################################################################
# IAM

resource aws_iam_role lambda {
  name = "lambda-billing-daily-notification"
  path = "/service-role/"

  assume_role_policy = <<-POLICY
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "lambda.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
  POLICY
}

resource aws_iam_policy lambda {
  policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [
      {
        "Effect" = "Allow"
        "Action" = [
          "ce:GetCostAndUsage",
          //"logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        "Resource" = "*"
      }
    ]
  })
}

resource aws_iam_role_policy_attachment lambda {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}

################################################################################
# lambda

variable SLACK_WEBHOOK_URL {}
variable SLACK_CHANNEL {}
variable SLACK_USERNAME {}

locals {
  lambda_file = {
    filename         = ".build/package.zip"
    source_code_hash = filebase64sha256(".build/package.zip")
  }
}

resource aws_lambda_function lambda {
  function_name = "billing-daily-notification"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs12.x"
  timeout       = 60

  filename         = local.lambda_file.filename
  source_code_hash = local.lambda_file.source_code_hash

  environment {
    variables = {
      TZ                = "Asia/Tokyo"
      SLACK_WEBHOOK_URL = var.SLACK_WEBHOOK_URL
      SLACK_CHANNEL     = var.SLACK_CHANNEL
      SLACK_USERNAME    = var.SLACK_USERNAME
    }
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }
}

################################################################################
# cloudwatch_event

resource aws_cloudwatch_event_rule lambda {
  name                = "lambda-billing-daily-notification"
  is_enabled          = true
  schedule_expression = "cron(0 22 * * ? *)" # 07:00 JST

  depends_on = [aws_cloudwatch_log_group.lambda]
}

resource aws_cloudwatch_event_target lambda {
  rule = aws_cloudwatch_event_rule.lambda.name
  arn  = aws_lambda_function.lambda.arn
}

resource aws_lambda_permission lambda {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda.arn
}

################################################################################
# log_group

resource aws_cloudwatch_log_group lambda {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 1
}
