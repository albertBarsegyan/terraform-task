resource "kubernetes_namespace_v1" "this" {
  metadata { name = "monitoring" }
}

# Secrets are supplied through sensitive root inputs; their values never appear in source.
resource "kubernetes_secret_v1" "grafana_slack" {
  metadata { name = "grafana-slack" namespace = kubernetes_namespace_v1.this.metadata[0].name }
  data = { SLACK_WEBHOOK_URL = var.slack_webhook_url }
  type = "Opaque"
}
resource "kubernetes_config_map_v1" "grafana_alerting" {
  metadata { name = "grafana-alerting" namespace = kubernetes_namespace_v1.this.metadata[0].name }
  data = {
    "contactpoints.yaml" = file("${var.alerting_directory}/contactpoints.yaml")
    "policies.yaml" = file("${var.alerting_directory}/policies.yaml")
    "rules.yaml" = file("${var.alerting_directory}/rules.yaml")
  }
}
resource "helm_release" "prometheus" {
  name = "kube-prometheus-stack"
  namespace = kubernetes_namespace_v1.this.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart = "kube-prometheus-stack"
  version = "62.7.0"
  values = [templatefile(var.prometheus_values_file, { grafana_admin_password = var.grafana_admin_password })]
  depends_on = [kubernetes_secret_v1.grafana_slack, kubernetes_config_map_v1.grafana_alerting]
}
resource "helm_release" "loki" {
  name = "loki"
  namespace = kubernetes_namespace_v1.this.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart = "loki"
  version = "6.16.0"
  values = [file(var.loki_values_file)]
}
resource "helm_release" "alloy" {
  name = "alloy"
  namespace = kubernetes_namespace_v1.this.metadata[0].name
  repository = "https://grafana.github.io/helm-charts"
  chart = "alloy"
  version = "0.12.1"
  values = [file(var.alloy_values_file)]
  depends_on = [helm_release.loki]
}
resource "kubernetes_config_map_v1" "dashboard" {
  metadata { name = "application-dashboard" namespace = kubernetes_namespace_v1.this.metadata[0].name labels = { grafana_dashboard = "1" } }
  data = { "application-dashboard.json" = file(var.dashboard_file) }
  depends_on = [helm_release.prometheus]
}
resource "kubernetes_config_map_v1" "loki_datasource" {
  metadata { name = "grafana-loki-datasource" namespace = kubernetes_namespace_v1.this.metadata[0].name labels = { grafana_datasource = "1" } }
  data = { "loki.yaml" = <<-YAML
    apiVersion: 1
    datasources:
      - name: Loki
        uid: loki
        type: loki
        access: proxy
        url: http://loki-gateway.monitoring.svc.cluster.local
        editable: false
    YAML
  }
  depends_on = [helm_release.prometheus, helm_release.loki]
}
