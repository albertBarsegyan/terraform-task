output "cluster_name" { value = module.eks.cluster_name }
output "aws_region" { value = var.aws_region }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "application_domain" {
  value = var.domain_name
  description = "Optional externally managed hostname configured in the Ingress rule."
}
output "grafana_port_forward" { value = "kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80" }
