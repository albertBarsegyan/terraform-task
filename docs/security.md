# Security

Git ignores Terraform state, tfvars, kubeconfig, `.env` files, credentials, and secrets. No AWS credentials, domain, password, or Slack webhook is committed. EKS workers are private, ALB Controller uses IRSA rather than static credentials, and the container is non-root with a restricted security context. Resource requests/limits reduce noisy-neighbour risk. Use a remote encrypted Terraform backend and secret manager in a real environment.
