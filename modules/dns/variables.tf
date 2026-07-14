variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "nlb_hostname" {
  description = "NLB hostname from Nginx Ingress"
  type        = string
}