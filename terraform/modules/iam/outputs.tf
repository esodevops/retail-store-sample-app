output "user_name" { value = aws_iam_user.dev_view.name }
output "user_arn" { value = aws_iam_user.dev_view.arn }
output "access_key_id" { value = aws_iam_access_key.dev_view.id }
output "secret_access_key" {
  value     = aws_iam_access_key.dev_view.secret
  sensitive = true
}
output "console_password" {
  value     = try(aws_iam_user_login_profile.dev_view[0].password, null)
  sensitive = true
}
