# EKS Platform — interview walkthrough

## 30-second summary

This repository provisions a small, declarative AWS platform for a stateless
NestJS API. Terraform creates the network and EKS cluster, then uses Helm
releases to install the AWS Load Balancer Controller, the application, and the
observability stack. Public traffic enters through an internet-facing ALB,
reaches a Kubernetes ClusterIP Service, and is served by two application pods.
Prometheus collects metrics, Alloy ships logs to Loki, and Grafana provides
dashboards and Slack alerts.

The implementation intentionally optimizes for a cost-conscious demo rather
than production-grade high availability. I would call out both the controls it
has and the gaps I would close next.

## Architecture at a glance

```text
                        AWS account / eu-central-1 by default

Internet
   |
   v
Internet-facing Application Load Balancer
   |  created from Kubernetes Ingress by AWS Load Balancer Controller
   v
EKS cluster in a two-AZ VPC
   |-- public subnets: ALB
   |-- private subnets: EKS managed node group (exactly 2 Spot nodes)
          |
          +--> demo namespace
          |      Ingress -> ClusterIP Service -> 2 NestJS pods (:3000)
          |
          +--> monitoring namespace
                 Prometheus <--- /metrics from application pods
                 Grafana  <--- Prometheus and Loki
                 Alloy DaemonSet ---> Loki <--- container stdout logs
                 Grafana alerts ---> Slack webhook (optional)
```

## How I would explain the codebase

### Application: `app/`

The application is intentionally small so the focus is platform engineering.
It is a TypeScript/NestJS HTTP API with four endpoints:

| Endpoint | Purpose |
| --- | --- |
| `/` | Simple service response |
| `/health` | Kubernetes liveness/readiness and external health-check target |
| `/api/items` | Example API endpoint |
| `/metrics` | Prometheus metrics endpoint |

`health.controller.ts` emits structured JSON request logs to stdout and
instruments each handled request with `prom-client` counters and latency
histograms. Default process metrics are collected as well. This makes metrics
scrapeable by Prometheus and logs collectable without adding an application
logging agent.

`main.ts` listens on `0.0.0.0:3000` and enables Nest shutdown hooks, allowing
the process to respond correctly when Kubernetes terminates a pod. The service
is stateless: no database, local persistence, sessions, or in-memory shared
state are required, so replicas can be replaced safely.

The Dockerfile is a multi-stage Node 20 build. The build stage compiles
TypeScript and prunes development dependencies; the runtime stage copies only
the compiled output and production dependencies. It creates an unprivileged
`app` user and runs as that user.

### Application deployment: `helm/app/`

The local Helm chart describes the workload rather than relying on manual
`kubectl apply` commands:

- A Deployment runs two replicas.
- Each pod exposes port 3000 and has a `/health` readiness probe (after 5s,
  every 10s) and liveness probe (after 15s, every 20s).
- Requests are `100m` CPU / `128Mi` memory; limits are `500m` / `256Mi`.
- The Service is `ClusterIP`, so pods are not directly public.
- An ALB Ingress forwards `/` traffic to the Service using IP targets and uses
  `/health` as its ALB target health check.
- Pod annotations enable Prometheus scraping of port 3000 at `/metrics`.
- Pod and container security settings require non-root execution, RuntimeDefault
  seccomp, no privilege escalation, and all Linux capabilities dropped.

Terraform supplies the image repository, image tag, and optional hostname to
the chart. The public default is the ALB-generated DNS name. DNS records and
TLS certificates are deliberately outside this repository; the values template
can support HTTPS when a certificate ARN is supplied, although the current
application module passes HTTP-only values.

### Infrastructure as code: `terraform/`

The Terraform root module is a thin composition layer. It passes shared names,
tags, and outputs between focused modules and makes the intended order explicit:

1. `vpc` creates a `10.0.0.0/16` VPC across two Availability Zones, with two
   public and two private `/24` subnets. It enables one NAT gateway as a cost
   trade-off. Subnet tags allow Kubernetes to discover external and internal
   load-balancer placement.
2. `eks` creates a Kubernetes 1.30 EKS cluster (default) with IRSA enabled.
   Worker nodes are in private subnets. The managed node group is fixed at two
   `SPOT` nodes, with `m6a.large`, `m5a.large`, and `m5.large` alternatives
   (each roughly 2 vCPU/8 GiB) to improve Spot capacity availability.
3. `eks-addons` installs the standard networking and storage add-ons: VPC CNI,
   CoreDNS, kube-proxy, and the EBS CSI driver.
4. `alb-controller` creates an IAM role scoped to the controller service account
   through IRSA, then installs the AWS Load Balancer Controller with Helm. The
   controller observes the app Ingress and creates/configures the ALB.
5. `application` deploys the local app chart into the `demo` namespace once the
   controller is ready.
6. `observability` creates the `monitoring` namespace, secret/config maps, and
   Helm releases for Prometheus/Grafana, Loki, and Alloy.

This structure keeps concerns independently readable and deployable while the
root preserves a single `terraform apply` experience. Provider and chart/module
versions are pinned, making infrastructure changes more repeatable.

## Request, health, and deployment flow

When asked to walk through one request, I would say:

1. A client resolves the ALB DNS name (or an externally managed domain) and
   sends an HTTP request.
2. The ALB, created by the AWS Load Balancer Controller from the Ingress,
   forwards to healthy pod IPs in the private subnets.
3. Kubernetes routes through the ClusterIP Service to one of two ready NestJS
   pods. A pod receives traffic only after its readiness probe succeeds.
4. The controller returns JSON, writes a structured log line to stdout, and
   increments request and latency metrics.
5. In parallel, Alloy tails Kubernetes container logs and writes them to Loki;
   Prometheus scrapes the pod metrics endpoint. Grafana queries both stores.

For failure handling: a failed liveness probe causes Kubernetes to restart the
container; a failed readiness probe removes it from Service endpoints; ALB
health checks also stop routing to unhealthy targets. Two replicas reduce the
impact of a single pod failure, but not a node/AZ or Spot interruption failure.

## Observability and operations

`kube-prometheus-stack` supplies Prometheus, Grafana, kube-state-metrics, and
node-exporter. Prometheus retains data for three days and also uses an
additional Kubernetes pod-discovery scrape config constrained to the `demo`
namespace and `prometheus.io/scrape=true` annotation.

Loki runs as one single-binary instance with filesystem storage. Alloy runs as
a DaemonSet so every node can collect container logs. It labels logs with
namespace, pod, container, and application name; a useful app query is:

```logql
{namespace="demo", app="demo-app"}
```

Grafana is intentionally `ClusterIP` only. Operators use `make grafana` to
port-forward it rather than exposing dashboards through the public ALB. A
dashboard ConfigMap is automatically discovered by the Grafana sidecar, and a
Loki datasource ConfigMap adds logs beside Prometheus metrics.

Two Grafana alerts calculate aggregate application CPU and memory usage as a
percentage of the configured container limits. Each fires only above 80% for
five minutes. The Slack URL is injected into a Kubernetes Secret through the
sensitive `slack_webhook_url` Terraform variable and exposed to Grafana as an
environment variable; it is not committed to source files.

The included k6 script exercises `/health`, ramps through 10, 25, 50, and 100
virtual users, and expects less than 1% failed requests and p95 latency under
one second. I would report measured results only after running it against a
deployed environment and correlate k6 output with Grafana.

## Security posture

The main controls are private worker nodes, IRSA for the ALB controller rather
than long-lived AWS credentials in pods, a non-root restricted container,
resource requests/limits, and ignored local secrets/state files. Sensitive
Grafana and Slack values are Terraform-sensitive inputs; normal usage is via
`TF_VAR_*` environment variables rather than committed tfvars.

One nuance worth stating accurately: EKS API endpoint public access is enabled
in the module. That is convenient for an interview/demo account, but I would
normally restrict endpoint CIDRs or use private-only access and a controlled
administration path.

## Deliberate limitations and production next steps

| Current decision | Why it is acceptable here | Production improvement |
| --- | --- | --- |
| Exactly two Spot nodes | Meets the assignment constraint and reduces cost | Keep an On-Demand baseline; add Cluster Autoscaler or Karpenter and interruption handling |
| One NAT gateway | Lower demo cost | One NAT gateway per AZ or alternative egress design |
| Single Loki + filesystem storage | Simple, small footprint | HA Loki with durable object storage and backup/retention policy |
| 3-day Prometheus retention | Suitable for a demo | Remote-write/long-term metrics storage and HA Prometheus design |
| Fixed two app replicas | Demonstrates service availability | HPA driven by CPU, memory, or request metrics; pod disruption budget and topology spread rules |
| Public ALB over HTTP by default | Keeps external dependencies out of the task | ACM certificate, HTTPS redirect, managed DNS, WAF, rate limiting, and security headers |
| No remote Terraform backend in repo | Easy to run in an interview account | Encrypted remote state with locking, restricted state access, and CI plan/apply workflow |
| No CI/CD | Scope is infrastructure design | Build/scan/sign/push image, run lint/tests/IaC policy checks, then GitOps or controlled Terraform deployment |
| No network policies or secret manager | Keeps the sample focused | Default-deny policies, workload-specific egress, AWS Secrets Manager/External Secrets |

## A strong interview answer

> I designed this as a small, declarative EKS platform rather than just a
> container deployment. Terraform creates the VPC, private EKS worker capacity,
> standard add-ons, and the IAM integration for the load balancer controller.
> It then installs the application and observability components as Helm
> releases, so the whole environment is reproducible from one plan and apply.
>
> The app itself is stateless NestJS. It exposes health and Prometheus endpoints,
> emits structured stdout logs, and runs as two restricted, non-root pods behind
> a ClusterIP service. An ALB Ingress is the only public entry point; the ALB
> health checks and Kubernetes probes both use `/health`.
>
> Operationally, Prometheus collects app and Kubernetes metrics, Alloy sends
> pod logs to Loki, and Grafana combines them in a dashboard and alerts to Slack
> when app CPU or memory stays above 80% of its limit for five minutes. Grafana
> remains private and is accessed through port-forwarding.
>
> The important trade-off is that this is cost-conscious demo infrastructure:
> it has two Spot nodes, a single NAT gateway, single-instance Loki, short
> metrics retention, and no autoscaling or CI/CD. For production I would first
> add resilient capacity and autoscaling, HTTPS/WAF and managed DNS, encrypted
> remote Terraform state, durable HA observability storage, stronger network and
> secrets controls, and a CI/CD or GitOps delivery path.

## Commands worth knowing

```sh
# Validate and deploy
terraform -chdir=terraform init
terraform -chdir=terraform validate
terraform -chdir=terraform plan
terraform -chdir=terraform apply

# Connect and inspect
make kubeconfig
make nodes
make pods
make ingress

# View Grafana privately
make grafana

# Run the load test after obtaining the ALB endpoint
BASE_URL=http://<alb-dns-name> k6 run load-test/test.js
```

The image must be built and pushed to a registry before applying Terraform.
Credentials, Grafana password, and optional Slack webhook are supplied outside
tracked source. Destroying the platform is `terraform -chdir=terraform destroy`;
an externally created image registry is intentionally outside Terraform scope.
