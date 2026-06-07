#!/usr/bin/env bash
# Script to create the S3 bucket for Terraform remote state
# Usage: ./scripts/create-tfstate-bucket.sh

set -euo pipefail

BUCKET_NAME="${TFSTATE_BUCKET:-project-bedrock-tfstate-3765}"
REGION="${AWS_REGION:-us-east-1}"
PROJECT_TAG="${PROJECT_TAG:-karatu-2025-capstone}"

if ! aws sts get-caller-identity --region "$REGION" >/dev/null 2>&1; then
  echo "ERROR: AWS credentials are not available or are expired. Authenticate first, then rerun this script." >&2
  exit 1
fi

# Check if bucket exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "S3 bucket $BUCKET_NAME already exists."
else
  echo "Creating S3 bucket $BUCKET_NAME in $REGION..."
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
  else
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION"
  fi
  echo "S3 bucket $BUCKET_NAME created."
fi

echo "Applying Terraform state bucket safeguards..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-tagging \
  --bucket "$BUCKET_NAME" \
  --tagging "TagSet=[{Key=Project,Value=${PROJECT_TAG}}]"

echo "Terraform state bucket $BUCKET_NAME is ready in $REGION."
