# Engineering decisions

1. EKS provides managed Kubernetes control-plane operations and a standard deployment target.
2. Managed node groups reduce lifecycle work; exactly two nodes meet the assignment’s availability constraint.
3. Spot capacity reduces cost. `m6a.large`, `m5a.large`, and `m5.large` provide 2 vCPU/8 GiB alternatives: materially more realistic than tiny nodes for Prometheus, Grafana, Loki, Alloy and system pods, while remaining cost-conscious. Spot interruption risk remains.
4. Prometheus/Grafana are well-maintained Kubernetes metrics tooling; Loki/Alloy provide lightweight label-based log search.
5. ALB supports Internet-facing traffic and IP targets. The controller gets its permissions through IRSA. DNS and TLS are deliberately external to this small platform module.
6. Terraform Helm releases keep application and observability deployments declarative; no `kubectl apply` workflow is required.
7. Single-NAT and single-binary Loki are cost trade-offs, not highly available production designs. Monitoring retention is short and no autoscaling, remote state, backup, WAF, DNS/certificate management, or CI/CD is included.
