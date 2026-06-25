variable "region" {
  description = "AWS region"
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  default     = "warehouse-cluster"
}

variable "environment" {
  description = "Environment name"
  default     = "production"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}