# Alerting

Grafana provisioning defines High CPU and High Memory alerts, each sustained for five minutes and calculated against the application container limit. Set `slack_webhook_url` through a secret variable (prefer `TF_VAR_slack_webhook_url`) before apply. Terraform creates a Kubernetes Secret and Grafana receives it as `SLACK_WEBHOOK_URL`; it is never stored in tracked files. Empty webhook values should be used only when alert delivery is intentionally not configured.
