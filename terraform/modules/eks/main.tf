module "eks" {
  source                               = "terraform-aws-modules/eks/aws"
  version                              = "20.36.0"
  cluster_name                         = var.cluster_name
  cluster_version                      = var.cluster_version
  subnet_ids                           = var.subnet_ids
  vpc_id                               = var.vpc_id
  enable_irsa                          = var.enable_irsa
  cluster_enabled_log_types            = var.cluster_enabled_log_types
  cluster_addons                       = var.cluster_addons
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  tags                                 = var.tags
  eks_managed_node_groups              = var.eks_managed_node_groups

  enable_cluster_creator_admin_permissions = true
}
