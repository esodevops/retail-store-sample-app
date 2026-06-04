data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = var.filename
  output_path = "${path.module}/lambda_function_payload.zip"
}

locals {
  # If caller passed an ARN, extract the role name portion after 'role/'
  lambda_role_name = contains(var.role_name, "arn:aws:iam::") ? regexreplace(var.role_name, "^arn:aws:iam::[0-9]+:role/", "") : var.role_name
}

resource "aws_lambda_function" "asset_processor" {
  function_name    = var.function_name
  role             = aws_iam_role.lambda_exec.arn
  handler          = var.handler
  runtime          = var.runtime
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  tags             = var.tags
}

resource "aws_iam_role" "lambda_exec" {
  name = local.lambda_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = var.lambda_policy_arn
}
