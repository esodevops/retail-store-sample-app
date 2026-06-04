variable "user_name" { type = string }
variable "policy_arn" { type = string }
variable "s3_bucket_name" { type = string }
variable "tags" { type = map(string) }
variable "create_console_login_profile" { type = bool }
