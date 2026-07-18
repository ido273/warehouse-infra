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

output "github_oidc_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC federation (warehouse-app CI/CD)"
  value       = module.iam.github_oidc_role_arn
}
