# EKS Platform Engineering Task

## Overview

This public-repository-ready assignment provisions a small AWS EKS platform, deploys a stateless NestJS API with Terraform-managed Helm, and supplies metrics, logs, dashboarding, alerting, external availability checks, and a k6 test.

## Architecture

```
Internet -> internet-facing ALB -> Service -> NestJS pods
                                      ^ AWS Load Balancer Controller (IRSA)
                                  EKS: exactly 2 private Spot managed nodes

Application -> Prometheus                 -> Grafana -> Slack
container logs -> Alloy -> Loki            -> Grafana
```

See [architecture notes](docs/architecture.md).

## Repository structure

- `app/`: TypeScript/NestJS service and production multi-stage Dockerfile.
- `terraform/`: thin composition layer for AWS infrastructure and Helm deployments; [`terraform/modules/`](terraform/modules/README.md) contains one module per platform service.
- `helm/app/`: local chart used by Terraform’s `helm_release`.
- `helm/*.yaml`: values for controller and observability charts.
- `dashboards/`: custom app dashboard JSON.
- `load-test/`: k6 script; `docs/`: operational guidance and decisions.

## Prerequisites

AWS CLI credentials with permissions for VPC/EKS/IAM/EC2/ELB, Terraform >=1.7, Docker, kubectl, Helm, Node 20, and k6. Configure a remote encrypted Terraform backend before using a shared or long-lived environment. This repo intentionally ships no backend block so it is runnable for an interview account.

## Configuration

Copy `terraform/terraform.tfvars.example` to ignored `terraform/terraform.tfvars`. `app_image_repository` must point to a published image. `aws_region`, `cluster_name`, version, image, tags, and optional external domain are variables. Do not place secrets in the example or commit local tfvars; prefer `TF_VAR_slack_webhook_url` and a required 16+ character `TF_VAR_grafana_admin_password`.

The ALB-generated DNS name is the default public endpoint. Optionally set `domain_name` to add an Ingress host rule when DNS is managed outside this Terraform repository; create the DNS record and any TLS configuration in that external DNS/certificate system. This repository does not create Route53, ACM, or Route53 health-check resources.

## Deployment

```sh
docker build -t <repository>:<tag> app
docker push <repository>:<tag>
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
terraform -chdir=terraform init
terraform -chdir=terraform fmt
terraform -chdir=terraform validate
terraform -chdir=terraform plan
terraform -chdir=terraform apply
make kubeconfig
make nodes && make pods && make ingress
```

Detailed operational instructions are in [deployment](docs/deployment.md).

## Application and EKS

The API exposes `/`, `/health`, `/api/items`, and Prometheus `/metrics`; it is stateless, logs JSON to stdout, and shuts down gracefully. The local chart uses two replicas, ClusterIP, health probes, resource limits, and ALB Ingress (`ip` targets). EKS uses exactly two `SPOT` managed workers with three compatible 2-vCPU/8-GiB instance alternatives. See [decisions](docs/decisions.md).

The app uses ESLint and Prettier. Run `npm --prefix app run lint`, `npm --prefix app run format:check`, or `npm --prefix app run format` before committing.

## Monitoring, logging, dashboard, and alerting

Terraform Helm releases install AWS Load Balancer Controller, kube-prometheus-stack, Loki, Alloy, and the application. Grafana is intentionally ClusterIP-only; run `make grafana` and authenticate with the configured admin password. The custom dashboard shows request/error rate, app CPU/memory, pod count/restarts, node CPU/memory, and app logs. Details: [monitoring](docs/monitoring.md), [alerting](docs/alerting.md).

Both Grafana alerts trigger above 80% of application CPU or memory limits for five minutes, and notify Slack when the sensitive webhook variable is set. Grafana provisioning files contain only `$SLACK_WEBHOOK_URL`; the value is injected via an in-cluster Secret.

## Health check and load test

Kubernetes probes test container health internally. For external checks, configure your existing monitoring provider against the ALB endpoint’s `/health` path. Run `BASE_URL=http://<alb-dns-name> k6 run load-test/test.js`; enter measured results in [load-testing](docs/load-testing.md). No results are claimed by this repository.

## Security, limitations, and improvements

Security controls are documented in [security](docs/security.md). This is intentionally a small environment: Spot interruption risk, a single NAT gateway, non-HA Loki/observability, short Prometheus retention, no autoscaling, backups, WAF, CI/CD, or remote-state implementation. Production next steps include On-Demand baseline capacity, HPA/Cluster Autoscaler/Karpenter, HA storage, encrypted remote state, secrets manager, WAF, network policies, and CI/CD.

## Cleanup

Run `terraform -chdir=terraform destroy`. Confirm any externally-created image registry/repository lifecycle separately; this repository does not manage one.
