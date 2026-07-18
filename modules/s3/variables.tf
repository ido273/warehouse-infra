variable "environment" {
  description = "Environment name"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket for warehouse images"
  type        = string
  default     = "warehouse-images-ido273"
}

variable "backend_role_arn" {
  description = "IAM role ARN for backend IRSA to allow KMS encryption/decryption"
  type        = string
}
