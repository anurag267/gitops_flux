module "eks" {
  depends_on = [aws_route_table_association.private_secondary_route_tables_association]

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31.6"

  cluster_name    = local.eks_cluster_name
  cluster_version = var.cluster_version
  vpc_id          = local.network_details.vpc_id

  subnet_ids               = aws_subnet.private_secondary_subnets[*].id
  control_plane_subnet_ids = local.network_details.private_subnet_ids

  cluster_endpoint_private_access = var.cluster_endpoint_private_access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  create_cloudwatch_log_group     = var.create_cloudwatch_log_group

  cluster_enabled_log_types = var.cluster_enabled_log_types
}
cluster_enabled_log_types        = var.cluster_enabled_log_types
cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days

enable_irsa                      = true
create_iam_role                  = false
iam_role_arn                     = module.eks_cluster_role.iam_role_arn
create_node_iam_role             = true
node_iam_role_name               = format("%s-%s-%s", local.eks_cluster_name, var.aws_region, "eksautomode-Role")

cluster_compute_config = {
  enabled = true
  node_pools = ["system"]
}

create_node_security_group       = false
create_cluster_security_group    = false

authentication_mode                      = var.authentication_mode
enable_cluster_creator_admin_permissions = false
access_entries = {
  cluster_admin_access_entry = {
    kubernetes_groups = []
    principal_arn     = var.cluster_admin_role

    policy_associations = {
      cluster_admin_access_policy = {
        policy_arn = var.cluster_admin_access_policy
        access_scope = {
          type = "cluster"
        }
      }
    }
  }
}
attach_cluster_encryption_policy = false
cluster_encryption_config        = {}
create_kms_key                   = false
tags                             = merge(var.tag_defaults)
