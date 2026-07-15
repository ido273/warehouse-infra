variable "certificate_arn" {
  description = "ACM certificate ARN for TLS"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "external_secrets_role_arn" {
  description = "IRSA role ARN for the External Secrets Operator service account"
  type        = string
}