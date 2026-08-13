locals {
  name       = var.cluster_name
  azs        = slice(data.aws_availability_zones.available.names, 0, 2)
  common_tags = merge({ Project = "eks-platform-task", ManagedBy = "Terraform" }, var.tags)
}

data "aws_availability_zones" "available" { state = "available" }
data "aws_caller_identity" "current" {}
