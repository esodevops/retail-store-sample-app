# VPC with standardized bedrock naming conventions
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = var.name_prefix
  cidr = var.vpc_cidr
  azs  = var.vpc_azs

  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway      = var.enable_nat_gateway
  map_public_ip_on_launch = var.map_public_ip_on_launch

  # One NAT gateway per AZ for HA
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # Unique subnet names
  public_subnet_names  = var.public_subnet_names
  private_subnet_names = var.private_subnet_names

  public_subnet_suffix  = "public-rt"
  private_subnet_suffix = "private-rt"

  # A single public route table is shared by both public subnets.
  create_multiple_public_route_tables = false

  # Internet gateway naming
  igw_tags = {
    Name = "${var.name_prefix}-IGW"
  }

  tags = var.tags

  vpc_tags = {
    Name = var.vpc_name
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}
