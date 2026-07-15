output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "name_servers" {
  description = "Add these nameservers to GoDaddy"
  value       = module.dns.name_servers
}

output "certificate_arn" {
  value = module.dns.certificate_arn
}

output "ai_tagging_bedrock_role_arn" {
  description = "IRSA role ARN for the ai-tagging service account"
  value       = module.eks.ai_tagging_bedrock_role_arn
}

output "external_secrets_role_arn" {
  description = "IRSA role ARN for the External Secrets Operator service account"
  value       = module.eks.external_secrets_role_arn
}

output "jwt_secret" {
  description = "Generated JWT secret — seed into AWS Secrets Manager \"warehouse/app-secrets\" as \"jwt-secret\""
  value       = module.argocd.jwt_secret
  sensitive   = true
}

output "flask_secret" {
  description = "Generated Flask secret — seed into AWS Secrets Manager \"warehouse/app-secrets\" as \"flask-secret\""
  value       = module.argocd.flask_secret
  sensitive   = true
}
