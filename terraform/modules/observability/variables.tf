variable "grafana_admin_password" {
  type      = string
  sensitive = true
}
variable "slack_webhook_url" {
  type      = string
  sensitive = true
}
variable "prometheus_values_file" { type = string }
variable "loki_values_file" { type = string }
variable "alloy_values_file" { type = string }
variable "dashboard_file" { type = string }
variable "alerting_directory" { type = string }
