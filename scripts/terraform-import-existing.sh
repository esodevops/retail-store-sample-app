#!/usr/bin/env bash
# terraform-import-existing.sh
# Idempotently imports pre-existing AWS resources into Terraform state.
# Safe to run on every apply — skips any resource already tracked in state.

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
NAME_PREFIX="${NAME_PREFIX:-project-bedrock}"
CLUSTER_NAME="${CLUSTER_NAME:-${NAME_PREFIX}-cluster}"
TFDIR="${TFDIR:-terraform}"

tf_import() {
  local addr="$1"
  local id="$2"
  if terraform -chdir="$TFDIR" state show "$addr" >/dev/null 2>&1; then
    echo "[SKIP]   $addr already in state"
    return 0
  fi

  echo "[IMPORT] $addr  <-  $id"
  # Continue even if import fails (resource might have dependencies not yet imported)
  if terraform -chdir="$TFDIR" import "$addr" "$id"; then
    return 0
  fi
  echo "[WARN]    Failed to import $addr (may need manual intervention)"
  return 0
}

tf_import_failed() {
  local addr="$1"
  ! terraform -chdir="$TFDIR" state show "$addr" >/dev/null 2>&1
}

# Import resources that must exist in state when already present in AWS.
tf_import_required() {
  local addr="$1"
  local id="$2"
  tf_import "$addr" "$id"
  if tf_import_failed "$addr"; then
    echo "[ERROR]  Required import failed for $addr"
    echo "         Run manually: terraform -chdir=$TFDIR import '$addr' '$id'"
    exit 1
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
if aws iam get-role --role-name "${CLUSTER_NAME}-alb-controller" >/dev/null 2>&1; then
  tf_import "module.eks.module.alb_controller_irsa.aws_iam_role.this[0]" "${CLUSTER_NAME}-alb-controller"
fi

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

# ---------- EKS Cluster and dependencies ----------
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo "=== Importing existing EKS cluster: $CLUSTER_NAME ==="

  # KMS key (must be imported before cluster when encryption is enabled)
  KMS_KEY_ID=$(aws kms describe-key \
    --key-id "alias/eks/${CLUSTER_NAME}" \
    --region "$REGION" \
    --query 'KeyMetadata.KeyId' \
    --output text 2>/dev/null || true)
  if [[ -n "${KMS_KEY_ID:-}" ]] && [[ "${KMS_KEY_ID}" != "None" ]]; then
    tf_import "module.eks.module.eks.module.kms.aws_kms_key.this[0]" "$KMS_KEY_ID"
    tf_import "module.eks.module.eks.module.kms.aws_kms_alias.this[\"cluster\"]" \
      "alias/eks/${CLUSTER_NAME}"
  fi

  # Cluster IAM role
  CLUSTER_ROLE_NAME=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
    --query 'cluster.roleArn' --output text 2>/dev/null | awk -F'/' '{print $NF}' || true)
  if [[ -n "${CLUSTER_ROLE_NAME:-}" ]] && [[ "${CLUSTER_ROLE_NAME}" != "None" ]]; then
    tf_import "module.eks.module.eks.aws_iam_role.this[0]" "$CLUSTER_ROLE_NAME"
  fi

  # Cluster and node security groups
  CLUSTER_SG_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
    --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text 2>/dev/null || true)
  if [[ -n "${CLUSTER_SG_ID:-}" ]] && [[ "${CLUSTER_SG_ID}" != "None" ]]; then
    tf_import "module.eks.module.eks.aws_security_group.cluster[0]" "$CLUSTER_SG_ID"
  fi

  CLUSTER_VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
    --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null || true)
  NODE_SG_ID=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=${CLUSTER_NAME}-node" "Name=vpc-id,Values=${CLUSTER_VPC_ID}" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)
  if [[ -n "${NODE_SG_ID:-}" ]] && [[ "${NODE_SG_ID}" != "None" ]]; then
    tf_import "module.eks.module.eks.aws_security_group.node[0]" "$NODE_SG_ID"
  fi

  # CloudWatch log group should exist before cluster import
  LOG_GROUP_NAME="/aws/eks/${CLUSTER_NAME}/cluster"
  if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP_NAME" \
       --region "$REGION" \
       --query "logGroups[0].logGroupName" \
       --output text 2>/dev/null | grep -q "$LOG_GROUP_NAME"; then
    tf_import "module.eks.module.eks.aws_cloudwatch_log_group.this[0]" "$LOG_GROUP_NAME"
  fi

  # Cluster itself — fail the workflow if this cannot be imported
  tf_import_required "module.eks.module.eks.aws_eks_cluster.this[0]" "$CLUSTER_NAME"

  # EKS OIDC provider
  OIDC_URL=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
    --query 'cluster.identity.oidc.issuer' --output text 2>/dev/null || true)
  if [[ -n "${OIDC_URL:-}" ]] && [[ "${OIDC_URL}" != "None" ]]; then
    OIDC_PROVIDER_NAME=$(echo "$OIDC_URL" | sed 's|https://||' | sed 's|/$||')
    tf_import "module.eks.module.eks.aws_iam_openid_connect_provider.oidc_provider[0]" "$OIDC_PROVIDER_NAME"
  fi
fi

# ---------- GitHub Actions OIDC Provider ----------
OIDC_ARN=$(aws iam list-open-id-connect-providers \
  --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' \
  --output text 2>/dev/null || true)
if [[ -n "${OIDC_ARN:-}" ]] && [[ "${OIDC_ARN}" != "None" ]]; then
  tf_import "aws_iam_openid_connect_provider.github_actions[0]" "$OIDC_ARN"
fi

# ---------- GitHub Actions IAM Role ----------
GITHUB_ACTIONS_ROLE_NAME="project-bedrock-github-actions-terraform"
if aws iam get-role --role-name "$GITHUB_ACTIONS_ROLE_NAME" >/dev/null 2>&1; then
  tf_import "aws_iam_role.github_actions_terraform" "$GITHUB_ACTIONS_ROLE_NAME"

  # Import EKS Access Entry for GitHub Actions role
  ROLE_ARN=$(aws iam get-role --role-name "$GITHUB_ACTIONS_ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null || true)
  if [[ -n "${ROLE_ARN:-}" ]] && [[ "${ROLE_ARN}" != "None" ]]; then
    CLUSTER_NAME="${NAME_PREFIX}-cluster"
    # Check if access entry exists in AWS
    if aws eks describe-access-entry --cluster-name "$CLUSTER_NAME" --principal-arn "$ROLE_ARN" --region "$REGION" >/dev/null 2>&1; then
      tf_import "aws_eks_access_entry.github_actions[0]" "${CLUSTER_NAME}:${ROLE_ARN}"
      
      # Import EKS Access Policy Association for GitHub Actions role (cluster-admin)
      ADMIN_POLICY_ARN="arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      # List access policy associations for this principal
      ASSOC_IDS=$(aws eks list-access-policy-associations \
        --cluster-name "$CLUSTER_NAME" \
        --principal-arn "$ROLE_ARN" \
        --region "$REGION" \
        --query "accessPolicyAssociations[?policyArn=='${ADMIN_POLICY_ARN}'].associationId" \
        --output text 2>/dev/null || true)
      if [[ -n "${ASSOC_IDS:-}" ]] && [[ "${ASSOC_IDS}" != "None" ]]; then
        for ASSOC_ID in $ASSOC_IDS; do
          tf_import "aws_eks_access_policy_association.github_actions_admin[0]" "${CLUSTER_NAME}/${ROLE_ARN}_${ASSOC_ID}"
        done
      fi
    fi
  fi
fi

# ---------- EKS Addons ----------
for addon in $(aws eks list-addons --cluster-name "$CLUSTER_NAME" --region "$REGION" \
     --query 'addons[*]' --output text 2>/dev/null || true); do
  if [[ -n "${addon:-}" ]]; then
    tf_import "module.eks.module.eks.aws_eks_addon.this[\"${addon}\"]" \
      "${CLUSTER_NAME}/${addon}"
  fi
done

# ---------- EKS Managed Node Groups (terraform-aws-modules/eks v20+) ----------
# Map AWS node group name prefixes to Terraform module keys in variables.tf
declare -A NG_KEY_BY_PREFIX=(
  ["bedrock-server-1"]="server-1"
  ["bedrock-server-2"]="server-2"
  ["${NAME_PREFIX}-server-1"]="server-1"
  ["${NAME_PREFIX}-server-2"]="server-2"
)

for ng in $(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$REGION" \
     --query 'nodegroups[*]' --output text 2>/dev/null || true); do
  if [[ -z "${ng:-}" ]]; then
    continue
  fi

  ng_key=""
  for prefix in "${!NG_KEY_BY_PREFIX[@]}"; do
    if [[ "$ng" == "${prefix}"* ]]; then
      ng_key="${NG_KEY_BY_PREFIX[$prefix]}"
      break
    fi
  done

  if [[ -n "$ng_key" ]]; then
    tf_import "module.eks.module.eks.module.eks_managed_node_group[\"${ng_key}\"].aws_eks_node_group.this[0]" \
      "${CLUSTER_NAME}/${ng}"
  else
    echo "[WARN]    Could not map node group '$ng' to a Terraform module key; skipping import"
  fi
done

echo "=== Import step complete ==="
