data "archive_file" "reaper" {
  type        = "zip"
  source_file = "${path.module}/lambda/reaper.py"
  output_path = "${path.module}/lambda/reaper.zip"
}

resource "aws_iam_role" "reaper" {
  name = "hyperforge-ttl-reaper"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "reaper" {
  name = "hyperforge-ttl-reaper"
  role = aws_iam_role.reaper.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        # Terminate is tag-scoped: the reaper can only kill ephemeral-test instances.
        Effect   = "Allow"
        Action   = ["ec2:TerminateInstances"]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:ResourceTag/ephemeral-test" = "true" }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "reaper" {
  function_name    = "hyperforge-ttl-reaper"
  role             = aws_iam_role.reaper.arn
  runtime          = "python3.12"
  handler          = "reaper.handler"
  filename         = data.archive_file.reaper.output_path
  source_code_hash = data.archive_file.reaper.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      DRY_RUN = var.dry_run ? "true" : "false"
    }
  }
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "hyperforge-ttl-reaper"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "reaper" {
  rule = aws_cloudwatch_event_rule.schedule.name
  arn  = aws_lambda_function.reaper.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reaper.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

variable "schedule_expression" {
  type    = string
  default = "rate(15 minutes)"
}

variable "dry_run" {
  description = "Log what would be reaped without terminating; flip off once trusted."
  type        = bool
  default     = true
}
