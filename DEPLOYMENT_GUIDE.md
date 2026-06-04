# Project Bedrock Deployment Guide

## 1. Prerequisites

- AWS CLI, Terraform >= 1.3, kubectl, Helm >= 3
- AWS account permissions for VPC, EKS, RDS, DynamoDB, IAM, S3, Lambda
- GitHub secret `AWS_TERRAFORM_ROLE_ARN` for CI/CD OIDC

If GitHub Actions fails with `Not authorized to perform sts:AssumeRoleWithWebIdentity`, the secret is usually pointing at a role that does not trust GitHub's OIDC provider. This stack now creates a dedicated role output for the Terraform workflow:

```sh
terraform -chdir=terraform output -raw github_actions_terraform_role_arn
```

Set that value as the repository secret `AWS_TERRAFORM_ROLE_ARN`. You can also reuse the same role for `AWS_ROLE_ARN` if you want the artifact publishing workflow to assume the same IAM role. If your AWS account already has the GitHub OIDC provider, set `github_actions_oidc_provider_arn` before apply so Terraform reuses it instead of creating a duplicate provider.

## 2. Provision Infrastructure (first time)

The remote state bucket is managed by `module.state` in the main Terraform stack (same pattern as `modules/s3`, `modules/vpc`, etc.). Because Terraform cannot store state in S3 until that bucket exists, run this once:

```sh
cd terraform
terraform init -backend=false
terraform apply -target=module.state
terraform init -migrate-state
terraform apply
```

## 3. Provision Infrastructure (subsequent runs)

```sh
cd terraform
terraform init
terraform apply
```

Generates grading outputs and managed data layer endpoints.

## 4. Configure kubectl

```sh
aws eks update-kubeconfig --region us-east-1 --name project-bedrock-cluster
```

## 5. Deploy Retail Store (Helm)

```sh
./scripts/sync-retail-secrets.sh
./helm/deploy-bedrock.sh
kubectl apply -f k8s/clusterrolebinding-dev-view.yaml
```

`./helm/deploy-bedrock.sh` applies `k8s/ingress.yaml` (HTTP) by default.

To enable HTTPS, update `k8s/ingress-tls.yaml` and replace:

- `REPLACE_WITH_ACM_CERT_ARN` with your ACM certificate ARN
- `retail.example.com` with your real domain (or nip.io hostname)

Then apply the TLS ingress:

```sh
kubectl apply -f k8s/ingress-tls.yaml
```

## 6. Verify Application

```sh
kubectl get pods -n retail-app
kubectl get ingress -n retail-app
```

Open the ALB hostname from the ingress status. All pods should be `Running` and the UI should load.

## 7. CI/CD Pipeline

- Open a PR touching `terraform/**` -> GitHub Actions runs `terraform plan` and comments output
- Merge to `main` -> workflow runs `terraform apply`

## 8. Grading Artifacts

```sh
./scripts/generate-grading-json.sh
```

Commit `grading.json` after apply.

### Developer credentials (`bedrock-dev-view`)

```sh
terraform -chdir=terraform output bedrock_dev_view_access_key_id
terraform -chdir=terraform output -raw bedrock_dev_view_secret_access_key
terraform -chdir=terraform output -raw bedrock_dev_view_console_password
```

Console sign-in URL: `https://<account-id>.signin.aws.amazon.com/console`

## 9. Architecture Diagram

See [docs/PROJECT_BEDROCK_ARCHITECTURE.md](docs/PROJECT_BEDROCK_ARCHITECTURE.md).
