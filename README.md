# warehouse-infra

Terraform IaC for the Smart Warehouse project — provisions VPC, ECR, and EKS on AWS (`eu-west-1`).

## Modules

| Module | Purpose |
|---|---|
| `modules/vpc` | VPC, public/private subnets (2 AZs), 1 NAT Gateway |
| `modules/ecr` | 4 ECR repos, one per microservice |
| `modules/eks` | EKS cluster (Kubernetes 1.31), managed node group, core add-ons |

## Usage

```bash
terraform init
terraform plan
terraform apply
```

```bash
aws eks update-kubeconfig --name warehouse-cluster --region eu-west-1
kubectl get nodes
```

Tear down when not in use (this stack is billable — EKS control plane, 2x t3.medium, NAT Gateway):

```bash
terraform destroy
```

> Doesn't remove the S3 state bucket or IAM user/group — those were created manually, outside Terraform.

## IAM permissions

`warehouse-ci-cd` group uses least-privilege policies instead of `*FullAccess` (same principle as the MySQL DB user grants): scoped AWS-managed policies plus two custom inline policies (`warehouse-terraform-minimal`, `warehouse-s3-ssm-minimal`) covering exactly the IAM/EC2/KMS/Logs/EKS/ECR actions Terraform needs. All policies attach to the group, not the user, so the user inherits everything via membership.
