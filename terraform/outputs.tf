output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_name" { value = module.eks.cluster_name }
output "region" { value = var.aws_region }
output "vpc_id" { value = module.vpc.vpc_id }
output "assets_bucket_name" { value = module.s3.bucket_name }
output "state_bucket_name" { value = module.state.bucket_name }

output "catalog_mysql_endpoint" { value = module.data.catalog_mysql_endpoint }
output "orders_postgres_endpoint" { value = module.data.orders_postgres_endpoint }
output "dynamodb_table_name" { value = module.data.dynamodb_table_name }
output "carts_irsa_role_arn" { value = module.data.carts_irsa_role_arn }
output "catalog_db_username" { value = module.data.catalog_db_username }
output "catalog_db_password" {
  value     = module.data.catalog_db_password
  sensitive = true
}
output "orders_db_username" { value = module.data.orders_db_username }
output "orders_db_password" {
  value     = module.data.orders_db_password
  sensitive = true
}

output "bedrock_dev_view_access_key_id" { value = module.iam.access_key_id }
output "bedrock_dev_view_secret_access_key" {
  value     = module.iam.secret_access_key
  sensitive = true
}
output "bedrock_dev_view_console_password" {
  value     = module.iam.console_password
  sensitive = true
}

output "github_actions_terraform_role_arn" {
  value = aws_iam_role.github_actions_terraform.arn
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_terraform.arn
}
