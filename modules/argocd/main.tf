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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
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

resource "kubernetes_namespace" "warehouse" {
  metadata {
    name = "warehouse"
  }
  depends_on = [helm_release.argocd]
}

data "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = "warehouse/app-secrets"
}

resource "null_resource" "cleanup_external_secrets_crds" {
  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      kubectl delete externalsecret --all --all-namespaces --ignore-not-found=true 2>/dev/null || true
      kubectl delete clustersecretstore --all --ignore-not-found=true 2>/dev/null || true
      kubectl delete secretstore --all --all-namespaces --ignore-not-found=true 2>/dev/null || true
    EOT
  }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  timeout          = 600

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.external_secrets_role_arn
  }

  depends_on = [helm_release.argocd]
}

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  namespace        = "kube-system"
  create_namespace = false
  depends_on       = [helm_release.argocd]
}

resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"
    value = var.certificate_arn
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-ports"
    value = "https"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-backend-protocol"
    value = "http"
  }

  set {
    name  = "controller.service.targetPorts.https"
    value = "http"
  }

  depends_on = [helm_release.argocd]
}

data "aws_secretsmanager_secret_version" "grafana" {
  secret_id = "warehouse/grafana"
}

resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "~> 65.0"

  values = [
    yamlencode({
      grafana = {
        adminPassword = jsondecode(data.aws_secretsmanager_secret_version.grafana.secret_string)["admin_password"]
        service = {
          type = "ClusterIP"
        }
      }
      prometheus = {
        prometheusSpec = {
          retention = "7d"
        }
      }
    })
  ]

  depends_on = [helm_release.argocd]
}

resource "helm_release" "fluent_bit" {
  name             = "fluent-bit"
  repository       = "https://fluent.github.io/helm-charts"
  chart            = "fluent-bit"
  namespace        = "logging"
  create_namespace = true

  values = [
    yamlencode({
      cloudWatch = {
        enabled      = true
        region       = var.region
        logGroupName = "/warehouse/${var.cluster_name}"
      }
    })
  ]

  depends_on = [helm_release.argocd]
}