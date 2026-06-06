#!/bin/bash
# Script to clean up orphaned EKS Access Entry
# This resolves the "ResourceInUseException" error when the access entry already exists
# but the associated IAM role no longer exists

set -e

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-project-bedrock-cluster}"
REGION="${AWS_REGION:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== EKS Access Entry Cleanup Script ===${NC}"

# List all access entries for the cluster
echo -e "${YELLOW}Listing all access entries for cluster: $CLUSTER_NAME${NC}"
ACCESS_ENTRIES=$(aws eks list-access-entries --cluster-name "$CLUSTER_NAME" --region "$REGION" --query 'accessEntries[*].principalArn' --output text 2>/dev/null || echo "")

if [ -z "$ACCESS_ENTRIES" ]; then
    echo -e "${GREEN}No access entries found in the cluster.${NC}"
    exit 0
fi

echo "Found access entries:"
echo "$ACCESS_ENTRIES"

# Look for the GitHub Actions access entry
GITHUB_ACTIONS_ENTRY=$(echo "$ACCESS_ENTRIES" | tr ' ' '\n' | grep -E "github-actions|terraform" || echo "")

if [ -z "$GITHUB_ACTIONS_ENTRY" ]; then
    echo -e "${GREEN}No GitHub Actions access entry found. No cleanup needed.${NC}"
    exit 0
fi

echo -e "${YELLOW}Found GitHub Actions access entry: $GITHUB_ACTIONS_ENTRY${NC}"

# Check if the IAM role exists
ROLE_ARN="$GITHUB_ACTIONS_ENTRY"
ROLE_NAME=$(echo "$ROLE_ARN" | sed 's/.*role\///')

echo -e "${YELLOW}Checking if IAM role exists: $ROLE_NAME${NC}"
ROLE_EXISTS=$(aws iam get-role --role-name "$ROLE_NAME" --region "$REGION" --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_EXISTS" ] || [[ "$ROLE_EXISTS" == "None" ]]; then
    echo -e "${YELLOW}IAM role does not exist. The access entry is orphaned.${NC}"
else
    echo -e "${GREEN}IAM role exists: $ROLE_EXISTS${NC}"
    echo "The access entry is valid. No cleanup needed."
    exit 0
fi

# Delete the orphaned access entry
echo -e "${YELLOW}Deleting orphaned EKS Access Entry...${NC}"
aws eks delete-access-entry \
    --cluster-name "$CLUSTER_NAME" \
    --principal-arn "$ROLE_ARN" \
    --region "$REGION"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully deleted orphaned EKS Access Entry!${NC}"
else
    echo -e "${RED}Failed to delete EKS Access Entry${NC}"
    exit 1
fi

# Also clean up any orphaned access policy associations
echo -e "${YELLOW}Checking for orphaned access policy associations...${NC}"
ASSOCIATIONS=$(aws eks list-access-policy-associations \
    --cluster-name "$CLUSTER_NAME" \
    --principal-arn "$ROLE_ARN" \
    --region "$REGION" \
    --query 'accessPolicyAssociations[*].associationId' \
    --output text 2>/dev/null || echo "")

if [ -n "$ASSOCIATIONS" ] && [[ "$ASSOCIATIONS" != "None" ]]; then
    for ASSOC_ID in $ASSOCIATIONS; do
        echo -e "${YELLOW}Deleting access policy association: $ASSOC_ID${NC}"
        aws eks delete-access-policy-association \
            --cluster-name "$CLUSTER_NAME" \
            --principal-arn "$ROLE_ARN" \
            --association-id "$ASSOC_ID" \
            --region "$REGION"
    done
    echo -e "${GREEN}Cleaned up orphaned access policy associations${NC}"
fi

echo -e "${GREEN}=== Cleanup complete ===${NC}"
echo ""
echo "You can now run 'terraform apply' to create fresh resources."