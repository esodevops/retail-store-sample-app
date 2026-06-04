output "catalog_mysql_endpoint" {
  value = "${aws_db_instance.catalog_mysql.address}:${aws_db_instance.catalog_mysql.port}"
}

output "orders_postgres_endpoint" {
  value = "${aws_db_instance.orders_postgres.address}:${aws_db_instance.orders_postgres.port}"
}

output "catalog_db_username" { value = aws_db_instance.catalog_mysql.username }
output "catalog_db_password" {
  value     = random_password.catalog_db.result
  sensitive = true
}

output "orders_db_username" { value = aws_db_instance.orders_postgres.username }
output "orders_db_password" {
  value     = random_password.orders_db.result
  sensitive = true
}

output "dynamodb_table_name" { value = aws_dynamodb_table.carts.name }
output "catalog_db_secret_arn" { value = aws_secretsmanager_secret.catalog_db.arn }
output "orders_db_secret_arn" { value = aws_secretsmanager_secret.orders_db.arn }
output "carts_irsa_role_arn" { value = aws_iam_role.carts_irsa.arn }
