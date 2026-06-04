variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_tag" {
  type    = string
  default = "karatu-2025-capstone"
}

# VPC
variable "vpc_name" {
  type    = string
  default = "project-bedrock-vpc"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "vpc_azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "map_public_ip_on_launch" {
  type    = bool
  default = true
}

variable "cluster_name" {
  type    = string
  default = "project-bedrock-cluster"
}

variable "cluster_version" {
  type    = string
  default = "1.34"
}

variable "enable_irsa" {
  type    = bool
  default = true
}

variable "cluster_enabled_log_types" {
  type    = list(string)
  default = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_endpoint_public_access" {
  type    = bool
  default = true
}

variable "cluster_endpoint_private_access" {
  type    = bool
  default = true
}

variable "cluster_endpoint_public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "cluster_addons" {
  type = any
  default = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
    amazon-cloudwatch-observability = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
    }
  }
}

variable "eks_managed_node_groups" {
  type = any
  default = {
    default = {
      desired_size   = 2
      max_size       = 3
      min_size       = 1
      instance_types = ["t3.medium"]
      tags = {
        Project = "karatu-2025-capstone"
      }
    }
  }
}

# IAM
variable "iam_user_name" {
  type    = string
  default = "bedrock-dev-view"
}

variable "iam_policy_arn" {
  type    = string
  default = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# S3
variable "s3_bucket_name" {
  type    = string
  default = "bedrock-assets-3765"
}

variable "s3_force_destroy" {
  type    = bool
  default = true
}

# Lambda
variable "lambda_function_name" {
  type    = string
  default = "bedrock-asset-processor"
}

variable "lambda_role_name" {
  type    = string
  default = "lambda_exec_role"
}

variable "lambda_handler" {
  type    = string
  default = "lambda_function.lambda_handler"
}

variable "lambda_runtime" {
  type    = string
  default = "python3.12"
}

variable "lambda_filename" {
  type    = string
  default = "../lambda/lambda_function.py"
}

variable "lambda_policy_arn" {
  type    = string
  default = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

variable "state_bucket_name" {
  type    = string
  default = "project-bedrock-tfstate-3765"
}

variable "create_console_login_profile" {
  type    = bool
  default = true
}

variable "name_prefix" {
  type    = string
  default = "project-bedrock"
}

variable "app_namespace" {
  type    = string
  default = "retail-app"
}

variable "dynamodb_table_name" {
  type    = string
  default = "retail-carts"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "github_actions_repository" {
  type    = string
  default = "esodevops/retail-store-sample-app"
}

variable "github_actions_role_name" {
  type    = string
  default = "project-bedrock-github-actions-terraform"
}

variable "github_actions_role_policy_arn" {
  type    = string
  default = "arn:aws:iam::aws:policy/AdministratorAccess"
}

variable "github_actions_oidc_provider_arn" {
  type    = string
  default = ""
}
