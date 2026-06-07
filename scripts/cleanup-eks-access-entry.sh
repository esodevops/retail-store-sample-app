#!/bin/bash
# Script to clean up orphaned EKS Access Entry
# This resolves the "ResourceInUseException" error when the access entry already exists
# but the associated IAM role no longer exists

set -e

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-project-bedrock-cluster}"
REGION="${AWS_REGION:-us-east-1}"
FORCE_DELETE="${FORCE_DELETE:-false}"
PRINCIPAL_ARN="${PRINCIPAL_ARN:-${AWS_TERRAFORM_ROLE_ARN:-}}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== EKS Access Entry Cleanup Script ===${NC}"

if ! aws eks describe-cluster --cluster-name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo -e "${YELLOW}Cluster $CLUSTER_NAME does not exist yet. Skipping access entry cleanup.${NC}"
    exit 0
fi

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
if [[ -n "$PRINCIPAL_ARN" ]]; then
    GITHUB_ACTIONS_ENTRY=$(echo "$ACCESS_ENTRIES" | tr ' ' '\n' | grep -F "$PRINCIPAL_ARN" || echo "")
else
    GITHUB_ACTIONS_ENTRY=$(echo "$ACCESS_ENTRIES" | tr ' ' '\n' | grep -E "github-actions|terraform" || echo "")
fi

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

if [[ "$FORCE_DELETE" == "true" ]]; then
    echo -e "${YELLOW}FORCE_DELETE=true. Removing access entry even though the IAM role may exist.${NC}"
elif [ -z "$ROLE_EXISTS" ] || [[ "$ROLE_EXISTS" == "None" ]]; then
    echo -e "${YELLOW}IAM role does not exist. The access entry is orphaned.${NC}"
else
    echo -e "${GREEN}IAM role exists: $ROLE_EXISTS${NC}"
    echo "The access entry is valid. No cleanup needed."
    exit 0
fi

# Delete access policy associations first
echo -e "${YELLOW}Checking access policy associations...${NC}"
POLICY_ARNS=$(aws eks list-associated-access-policies \
    --cluster-name "$CLUSTER_NAME" \
    --principal-arn "$ROLE_ARN" \
    --region "$REGION" \
    --query 'associatedAccessPolicies[*].policyArn' \
    --output text 2>/dev/null || echo "")

if [ -n "$POLICY_ARNS" ] && [[ "$POLICY_ARNS" != "None" ]]; then
    for POLICY_ARN in $POLICY_ARNS; do
        echo -e "${YELLOW}Disassociating access policy: $POLICY_ARN${NC}"
        aws eks disassociate-access-policy \
            --cluster-name "$CLUSTER_NAME" \
            --principal-arn "$ROLE_ARN" \
            --policy-arn "$POLICY_ARN" \
            --region "$REGION" >/dev/null 2>&1 || true
    done
fi

# Delete the access entry
echo -e "${YELLOW}Deleting EKS Access Entry...${NC}"
aws eks delete-access-entry \
    --cluster-name "$CLUSTER_NAME" \
    --principal-arn "$ROLE_ARN" \
    --region "$REGION" >/dev/null 2>&1 || true

echo -e "${GREEN}EKS Access Entry cleanup attempted for $ROLE_ARN${NC}"

echo -e "${GREEN}=== Cleanup complete ===${NC}"
echo ""
echo "You can now run 'terraform apply' to create fresh resources."
