module "vpc" {
  source = "./modules/vpc"

  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
  region       = var.region
  environment  = var.environment
}

module "ecr" {
  source = "./modules/ecr"

  environment = var.environment
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "argocd" {
  source = "./modules/argocd"

  depends_on = [module.eks]
}

module "s3" {
  source      = "./modules/s3"
  environment = var.environment
}