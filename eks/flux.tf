// Create the flux-system namespace.
resource "kubernetes_namespace" "flux_system" {
  depends_on = [
    module.eks,
    aws_vpc_security_group_ingress_rule.allow_vpc_primary_cidr_api_traffic,
    aws_vpc_security_group_ingress_rule.allow_vpc_secondary_cidr_api_traffic,
    aws_vpc_security_group_ingress_rule.allow_vdi_cidr_api_traffic,
    kubernetes_namespace.flux_system
  ]

  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}

// Create a Kubernetes secret with the Git credentials
resource "kubernetes_secret" "git_auth" {
  depends_on = [
    module.eks,
    aws_vpc_security_group_ingress_rule.allow_vpc_primary_cidr_api_traffic,
    aws_vpc_security_group_ingress_rule.allow_vpc_secondary_cidr_api_traffic,
    aws_vpc_security_group_ingress_rule.allow_vdi_cidr_api_traffic,
    kubernetes_namespace.flux_system
  ]

  metadata {
    name = "git-auth"
  }

  data {
    username = var.git_username
    password = var.git_password
  }
metadata {
  name = "flux-system"
  namespace = "flux-system"
}
type = "Opaque"
data = {
  "identity" = data.aws_secretsmanager_secret_version.ado_ssh_key.secret_string
  "known_hosts" = "ssh.dev.azure.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7Hr1oTwqNq0lZGJOFGJ4NakvyIZfIrXYd4d7wo6j8lklvCA"
}
}


// Install the Flux Operator.
resource "helm_release" "flux_operator" {
  depends_on = [kubernetes_namespace.flux_system]

  name = "flux-operator"
  namespace = "flux-system"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart = "flux-operator"
  wait = true
  timeout = 600
  values = [
    <<-EOT
    {
        "affinity": {
            "nodeAffinity": {
            "requiredDuringSchedulingIgnoredDuringExecution": {
                "nodeSelectorTerms": [
                {
                    "matchExpressions": [
                    {
                        "key": "kubernetes.io/os",
                        "operator": "In",
                        "values": ["linux"]
                    }
                    ]
                }
                ]
            }
            }
        }
    }
    EOT
  ]
}

set {
  name  = "tolerations[0].key"
  value = "CriticalAddonsOnly"
}

set {
  name  = "tolerations[0].operator"
  value = "Equal"
}

set {
  name  = "tolerations[0].effect"
  value = "NoSchedule"
}

// Configure the Flux instance.
resource "helm_release" "flux_instance" {
  depends_on = [helm_release.flux_operator]

  name       = "flux"
  namespace  = "flux-system"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-instance"
  timeout    = 600

  // Configure the Flux components and kustomize patches.
  values = [
    <<-EOT
    instance:
      cluster:
        type: kubernetes
    EOT
  ]
}
cluster:
  type: kubernetes
  multitenant: true
  networkPolicy: true
  domain: "cluster.local"
components:
  - source-controller
  - kustomize-controller
  - helm-controller
  - notification-controller
  - image-reflector-controller
  - image-automation-controller
kustomize:
  patches:
    - target:
        kind: Deployment
        name: "(kustomize-controller|helm-controller)"
      patch: |
        - op: add
          path: /spec/template/spec/containers/0/args/-
          value: --concurrent=100
        - op: add
          path: /spec/template/spec/containers/0/args/-
          value: --requeue-dependency=10s
        - op: add
          path: /spec/template/spec/containers/0/args/-
          value: --insecure-kubeconfig-exec=true
    - patch: |
        apiVersion: apps/v1
        kind: Deployment
 path: /spec/template/spec/containers/0/args/-
 value: --insecure-kubeconfig-exec=true
 - patch: |
 apiVersion: apps/v1
 kind: Deployment
 metadata:
   name: all
 spec:
   template:
     spec:
       affinity:
         nodeAffinity:
           requiredDuringSchedulingIgnoredDuringExecution:
             nodeSelectorTerms:
             - matchExpressions:
               - key: karpenter.sh/nodepool
                 operator: In

set {
  name  = "instance.sync.pullSecret"
  value = "flux-system"
}

set {
  name = "instance.distribution.version"
  value = var.flux_version
}

set {
  name = "instance.distribution.registry"
  value = var.flux_registry
}

// Configure Flux Git sync.
set {
  name = "instance.sync.kind"
  value = "GitRepository"
}

set {
  name = "instance.sync.url"
  value = local.git_url
}

set {
  name = "instance.sync.path"
  value = "clusters/${var.aws_account_id}/${local.eks_cluster_name}"
}

set {
  name = "instance.sync.ref"
  value = var.flux_gitops_hub_branch
}

set {
  name = "instance.sync.pullSecret"
  value = "flux-system"
}
# Create a ConfigMap with key/values that are used by Flux during post-build variable
resource "kubernetes_config_map" "cluster-info" {
  depends_on = [
    helm_release.flux_instance,
    aws_vpc_security_group_ingress_rule.allow_vpc_primary_cidr_api_traffic,
    aws_vpc_security_group_ingress_rule.allow_vpc_secondary_cidr_api_traffic,
    aws_vpc_security_group_ingress_rule.allow_vdi_cidr_api_traffic
  ]
  metadata {
    name      = "cluster-info"
    namespace = "flux-system"
  }
  data = {
    aws_partition          = "aws"
    vpc_id                 = local.network_details.vpc_id
    account_id             = var.aws_account_id
    aws_region             = var.aws_region
    cluster_name           = module.eks.cluster_name
    cluster_arn            = module.eks.cluster_arn
    cluster_security_group = module.eks.cluster_primary_security_group_id
    oidc_provider          = module.eks.oidc_provider
    private_subnets        = join(",", local.network_details.private_subnet_ids)
    availability_zones     = join(",", local.network_details.availability_zones)
    acm_cert_arn           = data.aws_acm_certificate.acm_certificate.arn
    acm_cert_id            = data.aws_acm_certificate.acm_certificate.id
    automode_iam_role_name = module.eks.node_iam_role_name
  }
}

