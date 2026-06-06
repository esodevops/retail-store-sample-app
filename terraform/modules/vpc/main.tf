# VPC with standardized bedrock naming conventions
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = var.vpc_name
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

  # Unique route table names (one public table per AZ)
  create_multiple_public_route_tables = true
  public_route_table_tags = {
    Name = "bedrock-public-rt"
  }
  private_route_table_tags = {
    Name = "bedrock-private-rt"
  }

  # Internet gateway, NAT gateway, and EIP naming
  igw_tags = {
    Name = "bedrock-igw"
  }
  nat_gateway_tags = {
    Name = "bedrock-nat-gw"
  }
  nat_eip_tags = {
    Name = "bedrock-nat-eip"
  }

  tags = merge(var.tags, {
    Name = var.vpc_name
  })

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}
