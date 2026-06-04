resource "aws_iam_user" "dev_view" {
  name = var.user_name
  tags = var.tags
}

resource "aws_iam_user_policy_attachment" "readonly" {
  user       = aws_iam_user.dev_view.name
  policy_arn = var.policy_arn
}

resource "aws_iam_user_policy" "s3_put_object" {
  name = "${var.user_name}-s3-put-object"
  user = aws_iam_user.dev_view.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowPutObjectToAssetsBucket"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/*"
      }
    ]
  })
}

resource "aws_iam_access_key" "dev_view" {
  user = aws_iam_user.dev_view.name
}

resource "aws_iam_user_login_profile" "dev_view" {
  count                   = var.create_console_login_profile ? 1 : 0
  user                    = aws_iam_user.dev_view.name
  password_length         = 20
  password_reset_required = true
}
