# Architecture

Two private EKS managed Spot nodes run the application and small observability stack. Public ALBs are created from Ingress objects by AWS Load Balancer Controller. The generated ALB DNS name is the public endpoint; DNS and TLS may be managed externally.

Terraform is composed from service modules (`vpc`, `eks`, `eks-addons`, `alb-controller`, `application`, and `observability`); the root module only supplies shared inputs and explicit deployment ordering.

```
Internet -> ALB -> Ingress -> ClusterIP service -> two NestJS pods
                                      \-> EKS private Spot nodes
Pods -> Prometheus metrics -> Grafana <- Loki <- Alloy container logs
Grafana alerts -> Slack
```
