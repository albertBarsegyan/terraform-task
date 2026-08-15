module "this" {
  source                                   = "terraform-aws-modules/eks/aws"
  version                                  = "20.31.6"
  cluster_name                             = var.cluster_name
  cluster_version                          = var.kubernetes_version
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = true
  vpc_id                                   = var.vpc_id
  subnet_ids                               = var.private_subnet_ids

  eks_managed_node_groups = {
    spot = {
      name          = "spot"
      capacity_type = "SPOT"
      # EKS stopped publishing AL2-optimized AMIs in November 2025. Select the
      # supported AL2023 image explicitly so managed node creation succeeds.
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.small"]
      min_size       = 2
      max_size       = 2
      desired_size   = 2
      labels         = { workload = "platform" }
      update_config  = { max_unavailable = 1 }
    }
  }
  tags = var.tags
}
