#!/bin/bash
# Script to create the S3 bucket for Terraform remote state
# Usage: ./scripts/create-tfstate-bucket.sh

set -e

BUCKET_NAME="project-bedrock-tfstate-3765"
REGION="us-east-1"

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
  echo "Enabling versioning on $BUCKET_NAME..."
  aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
  echo "S3 bucket $BUCKET_NAME created and versioning enabled."
fi
