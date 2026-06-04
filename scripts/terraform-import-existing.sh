#!/usr/bin/env bash
# terraform-import-existing.sh
# Idempotently imports pre-existing AWS resources into Terraform state.
# Safe to run on every apply — skips any resource already tracked in state.

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
NAME_PREFIX="${NAME_PREFIX:-project-bedrock}"
TFDIR="${TFDIR:-terraform}"

tf_import() {
  local addr="$1"
  local id="$2"
  if terraform -chdir="$TFDIR" state show "$addr" >/dev/null 2>&1; then
    echo "[SKIP]   $addr already in state"
  else
    echo "[IMPORT] $addr  <-  $id"
    terraform -chdir="$TFDIR" import "$addr" "$id"
  fi
}

echo "=== Restoring secrets scheduled for deletion ==="
for secret in "${NAME_PREFIX}/catalog-db" "${NAME_PREFIX}/orders-db"; do
  if aws secretsmanager describe-secret --secret-id "$secret" --region "$REGION" \
       --query 'DeletedDate' --output text 2>/dev/null | grep -q .; then
    aws secretsmanager restore-secret --secret-id "$secret" --region "$REGION" \
      >/dev/null 2>&1 && echo "Restored: $secret" || true
  fi
done

echo "=== Importing existing AWS resources into Terraform state ==="

# ---------- S3 state bucket ----------
if aws s3api head-bucket --bucket "${NAME_PREFIX}-tfstate-3765" 2>/dev/null; then
  tf_import "module.state.aws_s3_bucket.tfstate" "${NAME_PREFIX}-tfstate-3765"
fi

# ---------- DynamoDB ----------
if aws dynamodb describe-table --table-name "retail-carts" --region "$REGION" >/dev/null 2>&1; then
  tf_import "module.data.aws_dynamodb_table.carts" "retail-carts"
fi

# ---------- RDS subnet group ----------
if aws rds describe-db-subnet-groups --db-subnet-group-name "${NAME_PREFIX}-db-subnet-group" \
     --region "$REGION" >/dev/null 2>&1; then
  DB_SUBNET_GROUP_VPC=$(aws rds describe-db-subnet-groups \
    --db-subnet-group-name "${NAME_PREFIX}-db-subnet-group" \
    --region "$REGION" \
    --query 'DBSubnetGroups[0].VpcId' \
    --output text 2>/dev/null || true)

  PROJECT_VPC_ID=$(aws ec2 describe-vpcs \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=${NAME_PREFIX}-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || true)

  if [[ -n "${PROJECT_VPC_ID:-}" ]] && [[ "${DB_SUBNET_GROUP_VPC:-}" != "${PROJECT_VPC_ID:-}" ]]; then
    echo "Detected stale DB subnet group in VPC ${DB_SUBNET_GROUP_VPC}; expected ${PROJECT_VPC_ID}."
    DB_GROUP_IN_USE=$(aws rds describe-db-instances \
      --region "$REGION" \
      --query "DBInstances[?DBSubnetGroup.DBSubnetGroupName=='${NAME_PREFIX}-db-subnet-group'].DBInstanceIdentifier" \
      --output text 2>/dev/null || true)

    if [[ -z "${DB_GROUP_IN_USE:-}" ]]; then
      echo "Deleting stale DB subnet group ${NAME_PREFIX}-db-subnet-group so Terraform can recreate it in the correct VPC."
      aws rds delete-db-subnet-group \
        --db-subnet-group-name "${NAME_PREFIX}-db-subnet-group" \
        --region "$REGION" >/dev/null 2>&1 || true
    else
      echo "[WARN] DB subnet group is attached to instances (${DB_GROUP_IN_USE}). Importing as-is."
      tf_import "module.data.aws_db_subnet_group.this" "${NAME_PREFIX}-db-subnet-group"
    fi
  else
    tf_import "module.data.aws_db_subnet_group.this" "${NAME_PREFIX}-db-subnet-group"
  fi
fi

# ---------- Secrets Manager ----------
CATALOG_ARN=$(aws secretsmanager describe-secret \
  --secret-id "${NAME_PREFIX}/catalog-db" --region "$REGION" \
  --query 'ARN' --output text 2>/dev/null || true)
[[ -n "${CATALOG_ARN:-}" ]] && tf_import "module.data.aws_secretsmanager_secret.catalog_db" "$CATALOG_ARN"

ORDERS_ARN=$(aws secretsmanager describe-secret \
  --secret-id "${NAME_PREFIX}/orders-db" --region "$REGION" \
  --query 'ARN' --output text 2>/dev/null || true)
[[ -n "${ORDERS_ARN:-}" ]] && tf_import "module.data.aws_secretsmanager_secret.orders_db" "$ORDERS_ARN"

# ---------- IAM User ----------
if aws iam get-user --user-name "bedrock-dev-view" >/dev/null 2>&1; then
  tf_import "module.iam.aws_iam_user.dev_view" "bedrock-dev-view"

  if aws iam get-login-profile --user-name "bedrock-dev-view" >/dev/null 2>&1; then
    tf_import "module.iam.aws_iam_user_login_profile.dev_view[0]" "bedrock-dev-view"
  fi

  if aws iam get-user-policy --user-name "bedrock-dev-view" \
       --policy-name "bedrock-dev-view-s3-put-object" >/dev/null 2>&1; then
    tf_import "module.iam.aws_iam_user_policy.s3_put_object" \
      "bedrock-dev-view:bedrock-dev-view-s3-put-object"
  fi

  READONLY_POLICY_ARN="arn:aws:iam::aws:policy/ReadOnlyAccess"
  if aws iam list-attached-user-policies --user-name "bedrock-dev-view" \
       --query "AttachedPolicies[?PolicyArn=='${READONLY_POLICY_ARN}'].PolicyArn" \
       --output text | grep -q "$READONLY_POLICY_ARN"; then
    tf_import "module.iam.aws_iam_user_policy_attachment.readonly" \
      "bedrock-dev-view/${READONLY_POLICY_ARN}"
  fi

  ACCESS_KEY_ID=$(aws iam list-access-keys --user-name "bedrock-dev-view" \
    --query 'AccessKeyMetadata[0].AccessKeyId' \
    --output text 2>/dev/null || true)
  if [[ -n "${ACCESS_KEY_ID:-}" ]] && [[ "${ACCESS_KEY_ID}" != "None" ]]; then
    tf_import "module.iam.aws_iam_access_key.dev_view" "$ACCESS_KEY_ID"
  fi
fi

# ---------- IAM Policy ----------
IAM_POLICY_ARN=$(aws iam list-policies --scope Local \
  --query "Policies[?PolicyName=='${NAME_PREFIX}-carts-dynamodb'].Arn | [0]" \
  --output text 2>/dev/null || true)
if [[ -n "${IAM_POLICY_ARN:-}" ]] && [[ "${IAM_POLICY_ARN}" != "None" ]]; then
  tf_import "module.data.aws_iam_policy.carts_dynamodb" "$IAM_POLICY_ARN"
fi

# ---------- IAM Roles ----------
if aws iam get-role --role-name "${NAME_PREFIX}-carts-irsa" >/dev/null 2>&1; then
  tf_import "module.data.aws_iam_role.carts_irsa" "${NAME_PREFIX}-carts-irsa"
fi

if aws iam get-role --role-name "lambda_exec_role" >/dev/null 2>&1; then
  tf_import "module.lambda.aws_iam_role.lambda_exec" "lambda_exec_role"
fi

# ---------- Lambda ----------
if aws lambda get-function --function-name "bedrock-asset-processor" --region "$REGION" >/dev/null 2>&1; then
  tf_import "module.lambda.aws_lambda_function.asset_processor" "bedrock-asset-processor"

  if aws lambda get-policy --function-name "bedrock-asset-processor" --region "$REGION" \
       --query 'Policy' --output text 2>/dev/null | grep -q 'AllowExecutionFromS3Bucket'; then
    tf_import "aws_lambda_permission.allow_s3_invoke" \
      "bedrock-asset-processor/AllowExecutionFromS3Bucket"
  fi
fi

# ---------- KMS alias ----------
KMS_ALIAS_EXISTS=$(aws kms list-aliases --region "$REGION" \
  --query "Aliases[?AliasName=='alias/eks/${NAME_PREFIX}-cluster'].AliasName" \
  --output text 2>/dev/null || true)
if [[ -n "${KMS_ALIAS_EXISTS:-}" ]]; then
  tf_import "module.eks.module.eks.module.kms.aws_kms_alias.this[\"cluster\"]" \
    "alias/eks/${NAME_PREFIX}-cluster"
fi

# ---------- GitHub Actions OIDC Provider ----------
OIDC_ARN=$(aws iam list-open-id-connect-providers \
  --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' \
  --output text 2>/dev/null || true)
if [[ -n "${OIDC_ARN:-}" ]] && [[ "${OIDC_ARN}" != "None" ]]; then
  tf_import "aws_iam_openid_connect_provider.github_actions[0]" "$OIDC_ARN"
fi

# ---------- GitHub Actions IAM Role ----------
if aws iam get-role --role-name "project-bedrock-github-actions-terraform" >/dev/null 2>&1; then
  tf_import "aws_iam_role.github_actions_terraform" \
    "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/project-bedrock-github-actions-terraform"
fi

# ---------- CloudWatch Log Group for EKS Cluster ----------
LOG_GROUP_NAME="/aws/eks/${NAME_PREFIX}-cluster/cluster"
if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP_NAME" \
     --region "$REGION" \
     --query "logGroups[0].logGroupName" \
     --output text 2>/dev/null | grep -q "$LOG_GROUP_NAME"; then
  tf_import "module.eks.module.eks.aws_cloudwatch_log_group.this[0]" "$LOG_GROUP_NAME"
fi

# ---------- EKS Addons ----------
for addon in $(aws eks list-addons --cluster-name "${NAME_PREFIX}-cluster" --region "$REGION" \
     --query 'addons[*]' --output text 2>/dev/null || true); do
  if [[ -n "${addon:-}" ]]; then
    tf_import "module.eks.module.eks.aws_eks_addon.this[\"${addon}\"]" \
      "${NAME_PREFIX}-cluster/${addon}"
  fi
done

echo "=== Import step complete ==="
