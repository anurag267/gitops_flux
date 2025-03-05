data "terraform_remote_state" "network_details" {
  backend = "s3"
  config = {
    bucket = var.networking_tf_state_bucket
    key    = var.networking_tf_state_key
    region = var.aws_region
  }
}

locals {
  network_details = {
    vpc_id             = data.terraform_remote_state.network_details.outputs.vpc_id
    availability_zones = data.terraform_remote_state.network_details.outputs.availability_zones
    private_subnet_ids = data.terraform_remote_state.network_details.outputs.private_subnet_ids
    nat_gw_ids         = data.terraform_remote_state.network_details.outputs.nat_gw_ids
    vpc_primary_cidr   = data.terraform_remote_state.network_details.outputs.vpc_cidr
    vpc_endpoint_sg_id = data.terraform_remote_state.network_details.outputs.vpc_endpoint_sg_id
  }
}

locals {
  new_bits      = ceil(log(length(local.network_details.availability_zones), 2))
  subnet_cidrs  = [for i in range(length(local.network_details.availability_zones)) : cidrsubnet(var.vpc_cidr_block, local.new_bits, i)]
}

locals {
  eks_cluster_name = format("%s", var.eks_name)
  git_url = format("%s/%s/%s/%s", var.ado_repo_baseurl, var.ado_organization, var.ado_project, var.ado_hub_repository)
}

# Fetch the secret metadata by name
data "aws_secretsmanager_secret" "ado_ssh_key" {
  name = var.secrets_path_ado_ssh_key
}

# Retrieve the latest version of the secret's value
data "aws_secretsmanager_secret_version" "ado_ssh_key" {
  secret_id = data.aws_secretsmanager_secret.ado_ssh_key.id
}

