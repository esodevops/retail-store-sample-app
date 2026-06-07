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

## Remote state bootstrap

The S3 backend bucket must exist before Terraform can run `init`, `plan`,
`apply`, or `destroy`. The bucket is bootstrap infrastructure and is created by
the helper script instead of being destroyed by the main Terraform stack.

```sh
../scripts/create-tfstate-bucket.sh
terraform init -reconfigure
```

GitHub Actions runs this bootstrap helper before `terraform init`.

## Deploy infrastructure

```sh
cd terraform
terraform init
terraform apply
```

## Destroy infrastructure

Use the destroy helper from the repository root. It recreates the backend bucket
first if it was deleted, then initializes Terraform and runs destroy.

```sh
scripts/terraform-destroy.sh
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
