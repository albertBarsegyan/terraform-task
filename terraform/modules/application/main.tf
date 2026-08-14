resource "helm_release" "this" {
  name             = "demo-app"
  namespace        = "demo"
  create_namespace = true
  chart            = var.chart_path
  values = [templatefile(var.values_file, {
    image_repository = var.image_repository
    image_tag        = var.image_tag
    host             = var.domain_name
    certificate_arn  = ""
    enable_https     = false
  })]
}
