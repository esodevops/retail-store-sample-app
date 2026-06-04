variable "function_name" { type = string }
variable "role_name" { type = string }
variable "handler" { type = string }
variable "runtime" { type = string }
variable "filename" { type = string }
variable "lambda_policy_arn" { type = string }
variable "tags" { type = map(string) }
