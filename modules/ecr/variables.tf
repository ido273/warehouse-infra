variable "environment" {
  description = "Environment name"
  type        = string
}

variable "services" {
  description = "List of service names to create ECR repositories for"
  type        = list(string)
  default     = ["warehouse-backend", "warehouse-frontend", "warehouse-auth-service", "warehouse-ai-tagging"]
}
