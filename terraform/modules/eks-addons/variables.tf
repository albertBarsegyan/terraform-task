variable "cluster_name" { type = string }

variable "ebs_csi_role_arn" {
  type        = string
  description = "IAM role ARN for the EBS CSI controller service account (IRSA)."
}
