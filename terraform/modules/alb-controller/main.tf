module "irsa" {
  source                                 = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version                                = "5.47.1"
  role_name                              = "${var.cluster_name}-aws-load-balancer-controller"
  # Customer-managed policy create/read requires iam:TagPolicy/GetPolicy which
  # this IAM user lacks. Attach an inline policy instead.
  attach_load_balancer_controller_policy = false
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
  tags = {}
}

resource "aws_iam_role_policy" "load_balancer_controller" {
  name   = "aws-load-balancer-controller"
  role   = module.irsa.iam_role_name
  policy = file("${path.module}/iam-policy.json")
}

resource "helm_release" "this" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.2"
  values = [templatefile(var.values_file, {
    cluster_name = var.cluster_name
    region       = var.aws_region
    vpc_id       = var.vpc_id
    role_arn     = module.irsa.iam_role_arn
  })]

  depends_on = [aws_iam_role_policy.load_balancer_controller]
}
