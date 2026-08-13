# Deployment

1. Build and publish the app image to a registry you control: `docker build -t <repo>:<tag> app` then push it. Optional local settings are in `app/.env.example`; do not commit an `.env` file.
2. Copy `terraform/terraform.tfvars.example` to the ignored `terraform/terraform.tfvars` and set the image values. For protected values, use environment variables such as `TF_VAR_slack_webhook_url` and `TF_VAR_grafana_admin_password`.
3. From the repository root run `terraform -chdir=terraform init`, `terraform -chdir=terraform fmt`, `terraform -chdir=terraform validate`, `terraform -chdir=terraform plan`, and then `terraform -chdir=terraform apply`.
4. Configure kubectl: `make kubeconfig`; verify `make nodes`, `make pods`, `make ingress`.

The first apply can take several minutes. The ALB hostname is visible in `kubectl -n demo get ingress demo-app`; use it over HTTP. If you set `domain_name`, manage the matching DNS record and TLS certificate outside this repository.

Destroy with `terraform -chdir=terraform destroy`. Empty the ECR repository first only if you created it outside this configuration; it is intentionally not managed here.
