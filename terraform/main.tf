# The root module wires independently deployable platform services together.
module "vpc" {
  source = "./modules/vpc"
  name   = local.name
  cidr   = var.vpc_cidr
  azs    = local.azs
  tags   = local.common_tags
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = local.name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  tags               = local.common_tags
}

module "eks_addons" {
  source = "./modules/eks-addons"

  cluster_name     = module.eks.cluster_name
  ebs_csi_role_arn = module.ebs_csi_irsa_role.iam_role_arn

  depends_on = [module.eks, module.ebs_csi_irsa_role]
}

module "alb_controller" {
  source            = "./modules/alb-controller"
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  aws_region        = var.aws_region
  vpc_id            = module.vpc.vpc_id
  values_file       = "${path.module}/../helm/aws-load-balancer-values.yaml"
  tags              = local.common_tags
  depends_on        = [module.eks_addons]
}

module "application" {
  source           = "./modules/application"
  image_repository = var.app_image_repository
  image_tag        = var.app_image_tag
  domain_name      = var.domain_name
  chart_path       = "${path.module}/../helm/app"
  values_file      = "${path.module}/../helm/app-values.yaml"
  depends_on       = [module.alb_controller]
}

module "observability" {
  source                 = "./modules/observability"
  grafana_admin_password = var.grafana_admin_password
  slack_webhook_url      = var.slack_webhook_url
  prometheus_values_file = "${path.module}/../helm/prometheus-values.yaml"
  loki_values_file       = "${path.module}/../helm/loki-values.yaml"
  alloy_values_file      = "${path.module}/../helm/alloy-values.yaml"
  dashboard_file         = "${path.module}/../dashboards/application-dashboard.json"
  alerting_directory     = "${path.module}/templates/grafana-alerting"
  depends_on             = [module.eks_addons]
}
