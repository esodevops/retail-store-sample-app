# VPC with standardized naming conventions
module "vpc" {
  source                  = "terraform-aws-modules/vpc/aws"
  version                 = "5.21.0"
  name                    = var.vpc_name
  cidr                    = var.vpc_cidr
  azs                     = var.vpc_azs
  private_subnets         = var.private_subnets
  public_subnets          = var.public_subnets
  enable_nat_gateway      = var.enable_nat_gateway
  map_public_ip_on_launch = var.map_public_ip_on_launch

  # Standardized naming for subnets
  public_subnet_names  = ["project-bedrock-public-1", "project-bedrock-public-2"]
  private_subnet_names = ["project-bedrock-private-1", "project-bedrock-private-2"]

  # Standardized naming for NAT Gateway (one per AZ for HA)
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  tags = merge(var.tags, {
    Name = var.vpc_name
  })

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    Name                     = "project-bedrock-public-subnet"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    Name                              = "project-bedrock-private-subnet"
  }
}
