# warehouse-infra

Terraform IaC for the Smart Warehouse project — provisions the VPC, ECR repos, EKS cluster, S3 image bucket, Route53/ACM DNS, and (via Helm, invoked from Terraform) ArgoCD, nginx-ingress, metrics-server, Prometheus/Grafana, fluent-bit, and External Secrets Operator — all on AWS `eu-west-1`.

## Two-layer architecture

This repo is **two separate Terraform root modules with two separate states**, not one:

| Layer | Directory | State | What's in it | Lifecycle |
|---|---|---|---|---|
| **core** (permanent) | `core/` | `core/terraform.tfstate` | Route53 hosted zone + ACM certificate | Applied once, essentially never destroyed |
| **root** (ephemeral) | `.` (repo root) | `terraform.tfstate` | VPC, ECR, EKS, S3, ArgoCD/Helm stack, ESO | Freely destroyed and recreated |

**Why the split**: a Route53 hosted zone gets brand-new nameservers every time it's created. If it lived in the same state as the EKS cluster, every `terraform destroy` + `terraform apply` cycle (routine for a demo/dev cluster you don't want running 24/7) would force you to re-delegate the domain at the registrar (GoDaddy) again. `core/` holds only what genuinely needs to survive that cycle; everything else — including the ACM cert's *validation*, which depends on the zone but not vice versa — lives in root and gets recreated freely.

`modules/dns` (used by root) doesn't create the zone/cert anymore — it looks them up with `data "aws_route53_zone"` / `data "aws_acm_certificate"` by `domain_name`, and only creates the stack-specific piece: the A-record aliasing the domain to whatever ingress NLB exists in *this* apply of the cluster.

> **Migrating an existing zone/cert into `core/`**: if a zone+cert already exist in root's state from before this split, don't just apply both states as-is — that plans to create a *second* zone (new nameservers) or, worse, destroy the one root already tracks. Use `terraform import` to bring the existing zone/cert into `core/`'s state, then `terraform state rm` them from root's state, *before* applying either. Only then does root's data-source lookup resolve against the right, already-existing resources with no plan to create or destroy anything DNS-related.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.0`
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), configured with credentials that can create VPC/EKS/IAM/S3/Route53/ACM/Secrets Manager resources
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- An existing S3 bucket for Terraform state (`warehouse-terraform-state-ido273`, see `backend.tf` / `core/backend.tf` — same bucket, different state keys)
- Three AWS Secrets Manager secrets created **before** applying root: `warehouse/mysql`, `warehouse/grafana`, and `warehouse/app-secrets` (keys: `jwt-secret`, `flask-secret`, `database-url` — see External Secrets Operator section below). Root's `data "aws_secretsmanager_secret_version" "app_secrets"` will fail `plan`/`apply` fast if the last one is missing, rather than surfacing as a silent ESO sync failure later.

## How to bring everything up

Two steps now, not one:

```bash
# 1. First time only — permanent layer (Route53 zone + ACM cert)
cd core
terraform init
terraform apply

# 2. Every time — the actual cluster
cd ..
terraform init
terraform plan
terraform apply
```

Then point `kubectl` at the new cluster:
```bash
aws eks update-kubeconfig --name warehouse-cluster --region eu-west-1
kubectl get nodes
```

## How to tear down

```bash
terraform destroy
```

Run from the **repo root only**. This destroys the cluster/VPC/ECR/Helm stack but does **not** touch `core/` — the Route53 zone and ACM cert stay intact, so the domain keeps working (or rather, keeps its DNS delegation ready) for the next `terraform apply`. To actually tear down `core/` too (rarely what you want), you'd `cd core && terraform destroy` explicitly and separately.

> Neither state removes the S3 state bucket or the CI/CD IAM user/group — those were created manually, outside Terraform.

## Module structure

Root `main.tf` wires these in order: `vpc` → `ecr` → `eks` → `s3` → (reads the nginx-ingress NLB hostname back out of the cluster) → `dns` → `argocd`.

| Module | What it creates |
|---|---|
| `modules/vpc` | VPC across 2 AZs, 2 public + 2 private subnets, 1 NAT Gateway (wraps `terraform-aws-modules/vpc/aws`) |
| `modules/ecr` | One ECR repository per service in `var.services`, mutable tags, scan-on-push, `force_delete = true` (so `terraform destroy` works even with images pushed) |
| `modules/eks` | EKS cluster (Kubernetes 1.31), one managed node group (`t3.medium`, 1-4 nodes, desired 3), core add-ons (coredns/kube-proxy/vpc-cni/aws-ebs-csi-driver), IRSA enabled, plus IRSA roles for the EBS CSI driver, backend's S3 access, ai-tagging's Bedrock access, and External Secrets Operator's Secrets Manager access |
| `modules/s3` | The `warehouse-images` bucket (public-read bucket policy for images, `force_destroy = true`) |
| `modules/dns` | **Data-source lookups** (not resources) of the Route53 zone + ACM cert created in `core/`, plus the stack-specific A-record aliasing the domain to the ingress NLB |
| `modules/argocd` | ArgoCD itself, the App-of-Apps root Application (watches `warehouse-gitops/apps` with `recurse: true`), the `warehouse` namespace, External Secrets Operator, and the other Helm releases below |

### Helm releases installed by `modules/argocd`

- **argocd** — the ArgoCD control plane, plus a `root-app` Application (App-of-Apps) pointed at `warehouse-gitops`'s `apps/` directory
- **external-secrets** — into the `external-secrets` namespace; its ServiceAccount is annotated with the IRSA role ARN automatically (`serviceAccount.annotations.eks.amazonaws.com/role-arn`), no manual post-apply step needed
- **metrics-server** — into `kube-system`
- **ingress-nginx** — configured for AWS NLB TLS termination (NLB terminates TLS via the ACM cert, forwards plain HTTP to nginx's HTTP port)
- **kube-prometheus-stack** (Prometheus + Grafana) — into `monitoring`, Grafana admin password pulled from the `warehouse/grafana` Secrets Manager secret, 7-day Prometheus retention
- **fluent-bit** — into `logging`, ships container logs to CloudWatch (`/warehouse/<cluster_name>`)

## External Secrets Operator: how secrets actually flow

Terraform used to write `mysql-secret`/`app-secrets`/`frontend-secret` directly as `kubernetes_secret` resources. It doesn't anymore — those three now come from AWS Secrets Manager via ESO:

```
AWS Secrets Manager                    Kubernetes (namespace: warehouse)
┌──────────────────────┐               ┌─────────────────────────┐
│ warehouse/mysql       │──┐            │                         │
│ warehouse/app-secrets │  │  ClusterSecretStore   ExternalSecret  │  k8s Secret
│ (jwt-secret,          │  ├──────────► │  aws-secrets-manager ──►│  mysql-secret
│  flask-secret,        │  │  (IRSA auth,          app-secrets    │  app-secrets
│  database-url)        │  │  external-secrets     frontend-secret│  frontend-secret
└──────────────────────┘  │  ServiceAccount)                      │
                           │                                       │
   refreshInterval: 1h ────┘         (all defined in               │
                                      warehouse-gitops/apps/secrets/)
```

- **This repo (`modules/eks`)** provisions the IRSA role (`warehouse-cluster-external-secrets`, `secretsmanager:GetSecretValue` scoped to `warehouse/*`) and (`modules/argocd`) installs the `external-secrets` Helm release with that role wired onto its ServiceAccount.
- **`warehouse-gitops/apps/secrets/`** defines the actual sync: a `ClusterSecretStore` (cross-namespace, since the IRSA ServiceAccount lives in `external-secrets` but the target Secrets live in `warehouse`) and three `ExternalSecret` resources, one per k8s Secret, each polling its AWS Secrets Manager source every `refreshInterval: 1h`.
- `warehouse/mysql` and `warehouse/grafana` already existed (created manually, same as before). **`warehouse/app-secrets` is new** and must be created manually — see Prerequisites above — since `jwt-secret`/`flask-secret` used to come from `random_password` resources that regenerated on every apply (the actual bug this migration fixes: a destroy+apply would silently desync the k8s Secret from anything relying on the old value).

## Accessing ArgoCD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Then open `https://localhost:8080`. Username is `admin`; get the initial password with:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

## Accessing Grafana UI

```bash
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
```
Then open `http://localhost:3000`. Username is `admin`; password is whatever's stored in the `warehouse/grafana` AWS Secrets Manager secret (key `admin_password`), which Terraform injects into the Helm release at apply time.

## Outputs

Root (`terraform output`, after step 2 above):

| Output | What it's for |
|---|---|
| `vpc_id` | The provisioned VPC's ID |
| `ecr_repository_urls` | Map of service name → ECR repository URL, used by CI to push images |
| `cluster_name` | EKS cluster name, for `aws eks update-kubeconfig` |
| `cluster_endpoint` | EKS API server endpoint |
| `name_servers` | Route53 hosted-zone nameservers (proxied from `core/`) — add these at your domain registrar (GoDaddy) to delegate DNS |
| `certificate_arn` | ACM certificate ARN (proxied from `core/` via `modules/dns`'s data source), wired into the NLB/ingress for TLS |
| `ai_tagging_bedrock_role_arn` | IRSA role ARN for the `ai-tagging` service account — used by `warehouse-gitops` to set `eks.amazonaws.com/role-arn` |
| `external_secrets_role_arn` | IRSA role ARN for the External Secrets Operator service account (informational — the ServiceAccount annotation is now wired automatically, see above) |

`core/` (`cd core && terraform output`):

| Output | What it's for |
|---|---|
| `hosted_zone_id` | Route53 hosted zone ID |
| `name_servers` | Same nameservers as root's output above — this is the source of truth |
| `certificate_arn` | Same cert ARN as root's output above — this is the source of truth |

## Known limitations

- **EKS API endpoint is open to `0.0.0.0/0`** (`cluster_endpoint_public_access_cidrs` defaults wide-open) — should be restricted to admin/CI IP ranges for a real production posture.
- **MySQL runs in-cluster**, not as a managed RDS instance — no automated backups, point-in-time recovery, or multi-AZ failover.
- **JWT revocation blocklist is in-memory** (in the `auth-service` process), not backed by Redis or similar — doesn't survive a pod restart and isn't shared across replicas.
- **AWS Bedrock requires manual account/model access approval** — the IRSA role and IAM policy are provisioned here, but the underlying account must already have Bedrock model access granted (this isn't something Terraform can request on your behalf).
- **The Terraform S3 backend region is hardcoded** (`backend.tf` / `core/backend.tf`) — this is a hard Terraform limitation, not a design choice: backend configuration blocks don't support variable interpolation, so the region can't be parameterized via `var.region` (only a literal, or `-backend-config` at `terraform init` time).
- **The core/root state split hasn't been migrated on a live environment yet** — see the import/state-migration note above. Applying `core/` and root out of order, or without first importing an existing zone/cert, will produce an incorrect plan.
- **`warehouse/app-secrets` must be created and kept in sync manually** — ESO reads it, nothing writes it. If `jwt-secret`/`flask-secret` ever need to rotate, that's a manual `aws secretsmanager update-secret` plus whatever session/token invalidation that implies, not a `terraform apply`.

## IAM permissions

The `warehouse-ci-cd` IAM group uses least-privilege scoped policies instead of `*FullAccess`: AWS-managed policies plus two custom inline policies (`warehouse-terraform-minimal`, `warehouse-s3-ssm-minimal`) covering exactly the IAM/EC2/KMS/Logs/EKS/ECR actions Terraform needs. Policies attach to the group, not the user, so the CI user inherits everything via group membership.
