# Project Bedrock Terraform Infrastructure

Provisions all core grading infrastructure in `us-east-1`:

- Remote state bucket `project-bedrock-tfstate-3765` (`modules/state`)
- VPC `project-bedrock-vpc` (public + private subnets, 2 AZs)
- EKS `project-bedrock-cluster` with control plane logs + CloudWatch Observability add-on
- Managed data layer: RDS MySQL, RDS PostgreSQL, DynamoDB (private subnets + Secrets Manager)
- IAM user `bedrock-dev-view` (ReadOnly + S3 PutObject on assets bucket)
- EKS access entry mapping IAM user to Kubernetes username for RBAC
- Private S3 bucket `bedrock-assets-3765` + Lambda `bedrock-asset-processor` trigger
- Tag `Project=karatu-2025-capstone` on all resources

## First-time setup (remote state)

The state bucket is defined in the main stack (`module.state`), but the S3 backend cannot exist before the bucket is created. Use a one-time two-step init:

```sh
cd terraform
terraform init -backend=false
terraform apply -target=module.state
terraform init -migrate-state
terraform apply
```

After that, use normal `terraform init` / `terraform apply`.

## Deploy infrastructure (subsequent runs)

```sh
cd terraform
terraform init
terraform apply
```

## Required outputs

- `cluster_endpoint`
- `cluster_name`
- `region`
- `vpc_id`
- `assets_bucket_name`

Generate grading file:

```sh
./scripts/generate-grading-json.sh
```
