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
  tags                    = var.tags

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}
