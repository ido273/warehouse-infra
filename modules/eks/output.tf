output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate"
  value       = module.eks.cluster_certificate_authority_data
}

output "ai_tagging_bedrock_role_arn" {
  description = "IRSA role ARN for the ai-tagging service account"
  value       = module.ai_tagging_bedrock_irsa.iam_role_arn
}

output "external_secrets_role_arn" {
  description = "IRSA role ARN for the External Secrets Operator service account"
  value       = module.external_secrets_irsa.iam_role_arn
}