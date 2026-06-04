resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds"
  description = "Allow database access from EKS worker nodes"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "mysql_from_eks" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = var.eks_node_security_group_id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_eks" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = var.eks_node_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "random_password" "catalog_db" {
  length  = 16
  special = false
}

resource "random_password" "orders_db" {
  length  = 16
  special = false
}

resource "aws_db_instance" "catalog_mysql" {
  identifier             = "${var.name_prefix}-catalog-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  db_name                = "catalog"
  username               = "catalog"
  password               = random_password.catalog_db.result
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  tags                   = var.tags
}

resource "aws_db_instance" "orders_postgres" {
  identifier             = "${var.name_prefix}-orders-postgres"
  engine                 = "postgres"
  engine_version         = "16.4"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  db_name                = "orders"
  username               = "orders"
  password               = random_password.orders_db.result
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  tags                   = var.tags
}

resource "aws_dynamodb_table" "carts" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "customerId"
    type = "S"
  }

  global_secondary_index {
    name            = "idx_global_customerId"
    hash_key        = "customerId"
    projection_type = "ALL"
  }

  tags = var.tags
}

resource "aws_secretsmanager_secret" "catalog_db" {
  name = "${var.name_prefix}/catalog-db"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "catalog_db" {
  secret_id = aws_secretsmanager_secret.catalog_db.id
  secret_string = jsonencode({
    username = aws_db_instance.catalog_mysql.username
    password = random_password.catalog_db.result
    host     = aws_db_instance.catalog_mysql.address
    port     = aws_db_instance.catalog_mysql.port
    database = aws_db_instance.catalog_mysql.db_name
  })
}

resource "aws_secretsmanager_secret" "orders_db" {
  name = "${var.name_prefix}/orders-db"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "orders_db" {
  secret_id = aws_secretsmanager_secret.orders_db.id
  secret_string = jsonencode({
    username = aws_db_instance.orders_postgres.username
    password = random_password.orders_db.result
    host     = aws_db_instance.orders_postgres.address
    port     = aws_db_instance.orders_postgres.port
    database = aws_db_instance.orders_postgres.db_name
  })
}

resource "aws_iam_policy" "carts_dynamodb" {
  name = "${var.name_prefix}-carts-dynamodb"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.carts.arn,
          "${aws_dynamodb_table.carts.arn}/index/*"
        ]
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_role" "carts_irsa" {
  name = "${var.name_prefix}-carts-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider}:sub" = "system:serviceaccount:${var.app_namespace}:carts"
            "${var.oidc_provider}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "carts_dynamodb" {
  role       = aws_iam_role.carts_irsa.name
  policy_arn = aws_iam_policy.carts_dynamodb.arn
}
