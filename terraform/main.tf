provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

module "state" {
  source      = "./modules/state"
  bucket_name = var.state_bucket_name
  tags        = local.tags
}

module "vpc" {
  source                  = "./modules/vpc"
  vpc_name                = var.vpc_name
  vpc_cidr                = var.vpc_cidr
  vpc_azs                 = var.vpc_azs
  private_subnets         = var.private_subnets
  public_subnets          = var.public_subnets
  enable_nat_gateway      = var.enable_nat_gateway
  map_public_ip_on_launch = var.map_public_ip_on_launch
  tags                    = local.tags
}

module "iam" {
  source                       = "./modules/iam"
  user_name                    = var.iam_user_name
  policy_arn                   = var.iam_policy_arn
  s3_bucket_name               = var.s3_bucket_name
  create_console_login_profile = var.create_console_login_profile
  tags                         = local.tags
}

module "eks" {
  source                               = "./modules/eks"
  cluster_name                         = var.cluster_name
  cluster_version                      = var.cluster_version
  subnet_ids                           = concat(module.vpc.private_subnets, module.vpc.public_subnets)
  vpc_id                               = module.vpc.vpc_id
  enable_irsa                          = var.enable_irsa
  cluster_enabled_log_types            = var.cluster_enabled_log_types
  cluster_addons                       = var.cluster_addons
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  tags                                 = local.tags
  eks_managed_node_groups              = var.eks_managed_node_groups
}

resource "aws_eks_access_entry" "bedrock_dev_view" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.iam.user_arn
  type          = "STANDARD"
  user_name     = module.iam.user_name
}

resource "aws_eks_access_policy_association" "bedrock_dev_view_policy" {
  cluster_name  = module.eks.cluster_name
  principal_arn = module.iam.user_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type = "cluster"
  }
}

module "data" {
  source                     = "./modules/data"
  name_prefix                = var.name_prefix
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnets
  eks_node_security_group_id = module.eks.node_security_group_id
  oidc_provider_arn          = module.eks.oidc_provider_arn
  oidc_provider              = module.eks.oidc_provider
  app_namespace              = var.app_namespace
  dynamodb_table_name        = var.dynamodb_table_name
  db_instance_class          = var.db_instance_class
  tags                       = local.tags
}

module "s3" {
  source        = "./modules/s3"
  bucket_name   = var.s3_bucket_name
  force_destroy = var.s3_force_destroy
  tags          = local.tags
}

module "lambda" {
  source            = "./modules/lambda"
  function_name     = var.lambda_function_name
  role_name         = var.lambda_role_name
  handler           = var.lambda_handler
  runtime           = var.lambda_runtime
  filename          = var.lambda_filename
  lambda_policy_arn = var.lambda_policy_arn
  tags              = local.tags
}

locals {
  tags = {
    Project = var.project_tag
  }
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${module.s3.bucket_name}"
}

resource "aws_s3_bucket_notification" "assets_upload_event" {
  bucket = module.s3.bucket_name

  lambda_function {
    lambda_function_arn = module.lambda.function_arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}
