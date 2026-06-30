resource "aws_ecr_repository" "services" {
  for_each = toset([
    "warehouse-backend",
    "warehouse-frontend",
    "warehouse-auth-service",
    "warehouse-ai-tagging"
  ])

  name                 = each.value
  image_tag_mutability = "MUTABLE"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}