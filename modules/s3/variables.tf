variable "environment" {
  description = "Environment name"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket for warehouse images"
  type        = string
  default     = "warehouse-images-ido273"
}
