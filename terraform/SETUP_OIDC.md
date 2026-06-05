# Setting up GitHub Actions OIDC Authentication with AWS

This guide explains how to resolve the "Not authorized to perform sts:AssumeRoleWithWebIdentity" error.

## The Problem

GitHub Actions uses OIDC (OpenID Connect) to authenticate with AWS without storing long-lived credentials. However, this requires an IAM role in AWS that trusts GitHub's OIDC provider. The role must exist **before** GitHub Actions can assume it.

## Solution Overview

1. **First-time setup**: Use temporary AWS credentials to create the OIDC provider and IAM role
2. **After setup**: GitHub Actions will use OIDC to assume the role automatically

## Step-by-Step Setup

### Step 1: Create Initial AWS Credentials

You need AWS credentials with permission to create IAM roles and OIDC providers. This could be:
- Your root account (not recommended for production)
- An admin user
- Temporary credentials from AWS SSO

### Step 2: Apply Terraform with Initial Credentials

```bash
# Set your initial AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"

# Navigate to terraform directory
cd terraform

# Initialize Terraform
terraform init -reconfigure

# Apply the configuration to create the OIDC provider and IAM role
terraform apply -target=aws_iam_openid_connect_provider.github_actions -target=aws_iam_role.github_actions_terraform -target=aws_iam_role_policy_attachment.github_actions_terraform

# Get the role ARN
terraform output -json | jq -r '.github_actions_terraform_role_arn.value'
```

### Step 3: Update GitHub Repository Secrets

Go to your GitHub repository settings → Secrets and variables → Actions, and add:

#### Required Secrets (for Terraform workflow)

| Secret | Value | Purpose |
|--------|-------|---------|
| `AWS_TERRAFORM_ROLE_ARN` | `arn:aws:iam::<YOUR_ACCOUNT_ID>:role/project-bedrock-github-actions-terraform` | Allows Terraform workflow to authenticate with AWS via OIDC |

#### Optional Secrets (only for container image publishing)

These secrets are only needed if you plan to build and publish Docker images to ECR:

| Secret | Value | Purpose |
|--------|-------|---------|
| `AWS_ROLE_ARN` | Same as above | Used by "Publish Build" workflow for ECR access |
| `AWS_ECR_REPOSITORY` | `public.ecr.xxx/your-repo` | ECR repository URI for container images |

> **Note**: If you only need Terraform to work (not container builds), you only need to set `AWS_TERRAFORM_ROLE_ARN`.

### Step 4: Verify the Setup

After setting up the secrets, trigger a workflow manually:
1. Go to Actions → Terraform → Run workflow
2. Select the main branch
3. Click "Run workflow"

The workflow should now successfully assume the IAM role.

## Troubleshooting

### Error: "No OpenIDConnect provider found in your account"

This error occurs when the OIDC provider has **never been created** in your AWS account. GitHub Actions cannot authenticate without it.

**Solution: Create the OIDC provider and IAM role first using AWS credentials**

You must use AWS credentials (admin access) to create these resources before GitHub Actions can work. Choose one of these options:

#### Option 1: Use the Setup Script (Easiest)

```bash
# Set your AWS credentials with admin access
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"

# Run the setup script to create OIDC provider and IAM role
bash scripts/setup-github-oidc.sh

# Copy the role ARN from the output and add it to GitHub secrets
```

#### Option 2: Use Terraform

```bash
# Set your AWS credentials with admin access
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"

cd terraform
terraform init -reconfigure

# Create only the OIDC provider and IAM role
terraform apply -target=aws_iam_openid_connect_provider.github_actions -target=aws_iam_role.github_actions_terraform -target=aws_iam_role_policy_attachment.github_actions_terraform

# Get the role ARN
terraform output -json | jq -r '.github_actions_terraform_role_arn.value'
```

#### Option 3: Create Manually with AWS CLI

See the "Manual Role Creation" section at the end of this document.

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

This means the IAM role doesn't exist or the trust policy doesn't match. Verify:

1. The role exists:
   ```bash
   aws iam get-role --role-name project-bedrock-github-actions-terraform
   ```

2. The trust policy allows your repository:
   ```bash
   aws iam get-role --role-name project-bedrock-github-actions-terraform --query 'Role.AssumeRolePolicyDocument' --output json
   ```

3. The GitHub secret contains the correct ARN

### Error: "OIDC provider already exists" or "ResourceAlreadyExistsException"

If you see errors about resources already existing (OIDC provider, CloudWatch Log Groups, etc.), it means your AWS account has infrastructure that was created previously but is not tracked by Terraform state. This is common when:
- Infrastructure was created manually or by a previous setup
- Terraform state was lost or you're running from a fresh clone
- Another team member set up the infrastructure

**Solution 1: Use the Automated Import Script (Recommended)**

We provide a script (`scripts/terraform-import-existing.sh`) that automatically discovers and imports all existing resources:

```bash
# Set your AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"

# Run the import script
bash scripts/terraform-import-existing.sh

# After import completes, apply the configuration
cd terraform
terraform apply
```

This script will:
- Import the existing OIDC provider for GitHub Actions
- Import the GitHub Actions IAM role
- Import the EKS cluster CloudWatch log groups
- Import EKS addons
- Import other existing AWS resources (S3, DynamoDB, IAM, Lambda, etc.)
- Skip resources already tracked in Terraform state

**Solution 2: Manual Import**

If you prefer to import resources manually:

```bash
cd terraform
terraform init -reconfigure

# 1. Import OIDC Provider
OIDC_ARN=$(aws iam list-open-id-connect-providers \
  --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' \
  --output text)
terraform import 'aws_iam_openid_connect_provider.github_actions[0]' "$OIDC_ARN"

# 2. Import CloudWatch Log Group
terraform import 'module.eks.module.eks.aws_cloudwatch_log_group.this[0]' "/aws/eks/project-bedrock-cluster/cluster"

# 3. Import EKS Addons (repeat for each addon)
terraform import 'module.eks.module.eks.aws_eks_addon.this["amazon-cloudwatch-observability"]' "project-bedrock-cluster/amazon-cloudwatch-observability"

# 4. Import IAM Role (if exists)
terraform import 'aws_iam_role.github_actions_terraform' "arn:aws:iam::YOUR_ACCOUNT_ID:role/project-bedrock-github-actions-terraform"

# 5. Apply
terraform apply
```

**Solution 3: Set variables to skip creating existing resources**

If you don't want to import resources, you can tell Terraform to skip creating them:

```bash
# Get the existing OIDC provider ARN
OIDC_ARN=$(aws iam list-open-id-connect-providers \
  --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' \
  --output text)

# Create terraform.tfvars
cat > terraform/terraform.tfvars <<EOF
github_actions_oidc_provider_arn = "$OIDC_ARN"
github_actions_repository        = "esodevops/retail-store-sample-app"
EOF

cd terraform
terraform init -reconfigure
terraform apply
```

**Important**: With Solution 3, Terraform won't manage those resources. This may cause issues if you need to update them later.

### Checking the OIDC Subject Claims

The trust policy allows these subject claims:
- `repo:esodevops/retail-store-sample-app:ref:refs/heads/main` (pushes to main)
- `repo:esodevops/retail-store-sample-app:pull_request` (PR events)

If you're running from a different branch or fork, you'll need to update the trust policy in `terraform/github-actions.tf`.

## Manual Role Creation (Alternative)

If you prefer to create the role manually without Terraform:

```bash
# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create the trust policy
cat > trust-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": [
                        "repo:esodevops/retail-store-sample-app:ref:refs/heads/main",
                        "repo:esodevops/retail-store-sample-app:pull_request"
                    ]
                }
            }
        }
    ]
}
EOF

# Create the OIDC provider (if it doesn't exist)
aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list $(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[0].ThumbprintList[0]' --output text)

# Create the role
aws iam create-role \
    --role-name project-bedrock-github-actions-terraform \
    --assume-role-policy-document file://trust-policy.json

# Attach AdministratorAccess policy
aws iam attach-role-policy \
    --role-name project-bedrock-github-actions-terraform \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Get the role ARN
aws iam get-role --role-name project-bedrock-github-actions-terraform --query 'Role.Arn' --output text
```

Then update your GitHub secrets with the role ARN.