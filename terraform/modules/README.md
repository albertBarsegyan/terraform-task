# Terraform service modules

The root configuration is deliberately a thin composition layer. Each directory owns one platform service and exposes only the values needed by its dependants.

- `vpc`: network, public/private subnets, and NAT.
- `eks`: managed EKS control plane and exactly two Spot workers.
- `eks-addons`: EKS managed add-ons.
- `alb-controller`: IRSA role and AWS Load Balancer Controller Helm release.
- `application`: local Helm chart deployment.
- `observability`: Prometheus/Grafana, Loki, Alloy, dashboard, datasource, and alert provisioning.

Provider configuration remains at the root, so Helm and Kubernetes providers use the EKS connection once and are inherited by Kubernetes-facing modules.
