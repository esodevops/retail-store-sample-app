output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_name" { value = module.eks.cluster_name }
output "cluster_security_group_id" { value = module.eks.cluster_security_group_id }
output "node_security_group_id" { value = module.eks.node_security_group_id }
output "oidc_provider_arn" { value = module.eks.oidc_provider_arn }
output "oidc_provider" { value = module.eks.oidc_provider }
output "alb_controller_role_arn" { value = module.alb_controller_irsa.iam_role_arn }
