variable "aws_region" {
  type    = string
  default = "eu-central-1"
}
variable "aws_access_key" {
  type        = string
  default     = null
  sensitive   = true
  description = "Optional AWS access key ID for local development. Prefer the standard AWS credential provider chain or an assumed role."
}
variable "aws_secret_key" {
  type        = string
  default     = null
  sensitive   = true
  description = "Optional AWS secret access key for local development. Prefer the standard AWS credential provider chain or an assumed role."
}
variable "cluster_name" {
  type    = string
  default = "eks-platform-task"
}
variable "kubernetes_version" {
  type    = string
  default = "1.30"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "domain_name" {
  type    = string
  default = ""
}
variable "app_image_repository" {
  type        = string
  description = "Published container image repository"
}
variable "app_image_tag" {
  type    = string
  default = "latest"
}
variable "slack_webhook_url" {
  type      = string
  default   = ""
  sensitive = true
}
variable "grafana_admin_password" {
  type      = string
  default   = ""
  sensitive = true
  validation {
    condition     = length(var.grafana_admin_password) >= 16
    error_message = "Set a Grafana admin password of at least 16 characters via TF_VAR_grafana_admin_password or ignored tfvars."
  }
}
variable "tags" {
  type    = map(string)
  default = {}
}
