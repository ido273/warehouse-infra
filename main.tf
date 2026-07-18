module "vpc" {
  source = "./modules/vpc"

  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
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
  s3_bucket_name     = module.s3.bucket_name
}

module "s3" {
  source      = "./modules/s3"
  environment = var.environment
}

module "iam" {
  source = "./modules/iam"
}
data "kubernetes_service" "nginx_ingress" {
  metadata {
    name      = "nginx-ingress-ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [module.argocd]
}

module "dns" {
  source       = "./modules/dns"
  environment  = var.environment
  domain_name  = var.domain_name
  nlb_hostname = data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname
}


module "argocd" {
  source                    = "./modules/argocd"
  certificate_arn           = module.dns.certificate_arn
  region                    = var.region
  cluster_name              = var.cluster_name
  external_secrets_role_arn = module.eks.external_secrets_role_arn
  depends_on                = [module.eks]
}
