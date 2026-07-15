# warehouse-infra

Terraform IaC for the Smart Warehouse project — provisions the VPC, ECR repos, EKS cluster, S3 image bucket, Route53/ACM DNS, and (via Helm, invoked from Terraform) ArgoCD, nginx-ingress, metrics-server, Prometheus/Grafana, and fluent-bit — all on AWS `eu-west-1`.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.0`
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), configured with credentials that can create VPC/EKS/IAM/S3/Route53/ACM/Secrets Manager resources
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- An existing S3 bucket for Terraform state (`warehouse-terraform-state-ido273`, see `backend.tf`) and two AWS Secrets Manager secrets the `argocd` module reads at apply time: `warehouse/mysql` and `warehouse/grafana`

## Bring everything up

```bash
terraform init
terraform plan
terraform apply
```

Then point `kubectl` at the new cluster:
```bash
aws eks update-kubeconfig --name warehouse-cluster --region eu-west-1
kubectl get nodes
```

## Tear down

```bash
terraform destroy
```

> Doesn't remove the S3 state bucket or the CI/CD IAM user/group — those were created manually, outside Terraform.

## Module structure

Root `main.tf` wires these in order: `vpc` → `ecr` → `eks` → `s3` → (reads the nginx-ingress NLB hostname back out of the cluster) → `dns` → `argocd`.

| Module | What it creates |
|---|---|
| `modules/vpc` | VPC across 2 AZs, 2 public + 2 private subnets, 1 NAT Gateway (wraps `terraform-aws-modules/vpc/aws`) |
| `modules/ecr` | One ECR repository per service in `var.services`, mutable tags, scan-on-push, `force_delete = true` (so `terraform destroy` works even with images pushed) |
| `modules/eks` | EKS cluster (Kubernetes 1.31), one managed node group (`t3.medium`, 1-3 nodes), core add-ons (coredns/kube-proxy/vpc-cni/aws-ebs-csi-driver), IRSA enabled, plus IRSA roles for the EBS CSI driver, backend's S3 access, and ai-tagging's Bedrock access |
| `modules/s3` | The `warehouse-images` bucket (public-read bucket policy for images, `force_destroy = true`) |
| `modules/dns` | Route53 hosted zone for `var.domain_name`, ACM certificate (with wildcard SAN) validated via DNS, and an A-record alias pointing the domain at the ingress NLB |
| `modules/argocd` | ArgoCD itself, the App-of-Apps root Application (watches `warehouse-gitops/apps` with `recurse: true`), the `warehouse` namespace + its k8s Secrets (MySQL creds, JWT/Flask secrets from Secrets Manager and `random_password`), and the Helm releases below |

### Helm releases installed by `modules/argocd`

- **argocd** — the ArgoCD control plane, plus a `root-app` Application (App-of-Apps) pointed at `warehouse-gitops`'s `apps/` directory
- **metrics-server** — into `kube-system`
- **ingress-nginx** — configured for AWS NLB TLS termination (NLB terminates TLS via the ACM cert, forwards plain HTTP to nginx's HTTP port)
- **kube-prometheus-stack** (Prometheus + Grafana) — into `monitoring`, Grafana admin password pulled from the `warehouse/grafana` Secrets Manager secret, 7-day Prometheus retention
- **fluent-bit** — into `logging`, ships container logs to CloudWatch (`/warehouse/<cluster_name>`)

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

| Output | What it's for |
|---|---|
| `vpc_id` | The provisioned VPC's ID |
| `ecr_repository_urls` | Map of service name → ECR repository URL, used by CI to push images |
| `cluster_name` | EKS cluster name, for `aws eks update-kubeconfig` |
| `cluster_endpoint` | EKS API server endpoint |
| `name_servers` | Route53 hosted-zone nameservers — add these at your domain registrar (GoDaddy) to delegate DNS |
| `certificate_arn` | ACM certificate ARN, wired into the NLB/ingress for TLS |
| `ai_tagging_bedrock_role_arn` | IRSA role ARN for the `ai-tagging` service account — used by `warehouse-gitops` to set `eks.amazonaws.com/role-arn` |

## Known limitations

- **EKS API endpoint is open to `0.0.0.0/0`** (`cluster_endpoint_public_access_cidrs` defaults wide-open) — should be restricted to admin/CI IP ranges for a real production posture.
- **MySQL runs in-cluster**, not as a managed RDS instance — no automated backups, point-in-time recovery, or multi-AZ failover.
- **JWT revocation blocklist is in-memory** (in the `auth-service` process), not backed by Redis or similar — doesn't survive a pod restart and isn't shared across replicas.
- **AWS Bedrock requires manual account/model access approval** — the IRSA role and IAM policy are provisioned here, but the underlying account must already have Bedrock model access granted (this isn't something Terraform can request on your behalf).
- **The Terraform S3 backend region is hardcoded** (`backend.tf`) — this is a hard Terraform limitation, not a design choice: backend configuration blocks don't support variable interpolation, so the region can't be parameterized via `var.region` (only a literal, or `-backend-config` at `terraform init` time).

## IAM permissions

The `warehouse-ci-cd` IAM group uses least-privilege scoped policies instead of `*FullAccess`: AWS-managed policies plus two custom inline policies (`warehouse-terraform-minimal`, `warehouse-s3-ssm-minimal`) covering exactly the IAM/EC2/KMS/Logs/EKS/ECR actions Terraform needs. Policies attach to the group, not the user, so the CI user inherits everything via group membership.
