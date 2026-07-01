terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "~> 7.0"
}

resource "kubectl_manifest" "root_app" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: root-app
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com/ido273/warehouse-gitops.git
        targetRevision: master
        path: apps
        directory:
          recurse: true
      destination:
        server: https://kubernetes.default.svc
        namespace: argocd
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  YAML

  depends_on = [helm_release.argocd]
}

data "aws_secretsmanager_secret_version" "mysql" {
  secret_id = "warehouse/mysql"
}

resource "kubernetes_namespace" "warehouse" {
  metadata {
    name = "warehouse"
  }
  depends_on = [helm_release.argocd]
}

resource "kubernetes_secret" "mysql" {
  metadata {
    name      = "mysql-secret"
    namespace = kubernetes_namespace.warehouse.metadata[0].name
  }

  data = {
    "root-password" = jsondecode(data.aws_secretsmanager_secret_version.mysql.secret_string)["root_password"]
    "password"      = jsondecode(data.aws_secretsmanager_secret_version.mysql.secret_string)["password"]
  }

  type       = "Opaque"
  depends_on = [kubernetes_namespace.warehouse]
}