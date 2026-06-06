#!/bin/bash
# Script to import existing EKS Access Entry into Terraform state
# This resolves the "ResourceInUseException" error when the access entry already exists

set -e

# Configuration - these should match your terraform/github-actions.tf
CLUSTER_NAME="${CLUSTER_NAME:-project-bedrock-cluster}"
REGION="${AWS_REGION:-us-east-1}"
ROLE_NAME="${GITHUB_ACTIONS_ROLE_NAME:-project-bedrock-github-actions-terraform}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== EKS Access Entry Import Script ===${NC}"

# Get the IAM role ARN for GitHub Actions
echo -e "${YELLOW}Looking up GitHub Actions IAM role...${NC}"
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --region "$REGION" --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ] || [[ "$ROLE_ARN" == "None" ]]; then
    echo -e "${RED}Error: Could not find IAM role '$ROLE_NAME'${NC}"
    echo "Make sure you have configured the GitHub Actions OIDC role correctly."
    exit 1
fi

echo -e "${GREEN}Found role ARN: $ROLE_ARN${NC}"

# Check if EKS Access Entry already exists
echo -e "${YELLOW}Checking if EKS Access Entry exists...${NC}"
EXISTING_ENTRY=$(aws eks describe-access-entry \
    --cluster-name "$CLUSTER_NAME" \
    --principal-arn "$ROLE_ARN" \
    --region "$REGION" \
    --query 'principalArn' \
    --output text 2>/dev/null || echo "")

if [ -z "$EXISTING_ENTRY" ] || [[ "$EXISTING_ENTRY" == "None" ]]; then
    echo -e "${GREEN}EKS Access Entry does not exist. No import needed.${NC}"
    echo "Terraform will create it normally."
    exit 0
fi

echo -e "${GREEN}EKS Access Entry already exists: $EXISTING_ENTRY${NC}"

# Change to terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

cd "$TERRAFORM_DIR"

# Initialize Terraform if needed
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init -backend-config="bucket=project-bedrock-tfstate-3765" \
    -backend-config="key=state/terraform.tfstate" \
    -backend-config="region=$REGION" \
    -reconfigure

# Check if resource is already in state
echo -e "${YELLOW}Checking Terraform state...${NC}"
RESOURCE_IN_STATE=$(terraform state list 2>/dev/null | grep -E "^aws_eks_access_entry\.github_actions\[" || echo "")

if [ -n "$RESOURCE_IN_STATE" ]; then
    echo -e "${GREEN}Resource is already in Terraform state: $RESOURCE_IN_STATE${NC}"
    echo "No import needed."
    exit 0
fi

# Import the resource
echo -e "${YELLOW}Importing EKS Access Entry into Terraform state...${NC}"
IMPORT_ID="${CLUSTER_NAME}:${ROLE_ARN}"
echo "Import ID: $IMPORT_ID"

terraform import 'aws_eks_access_entry.github_actions[0]' "$IMPORT_ID"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully imported EKS Access Entry!${NC}"
    echo ""
    echo "You can now run 'terraform apply' without errors."
else
    echo -e "${RED}Failed to import EKS Access Entry${NC}"
    exit 1
fi

# Also check and import the access policy association if it exists
echo -e "${YELLOW}Checking EKS Access Policy Association...${NC}"
POLICY_ARN="arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

POLICY_IN_STATE=$(terraform state list 2>/dev/null | grep -E "^aws_eks_access_policy_association\.github_actions_admin\[" || echo "")

if [ -z "$POLICY_IN_STATE" ]; then
    # Check if the policy association exists
    EXISTING_ASSOCIATION=$(aws eks list-access-policy-associations \
        --cluster-name "$CLUSTER_NAME" \
        --principal-arn "$ROLE_ARN" \
        --region "$REGION" \
        --query "accessPolicyAssociations[?policyArn=='$POLICY_ARN'].associationId" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_ASSOCIATION" ] && [[ "$EXISTING_ASSOCIATION" != "None" ]]; then
        echo -e "${YELLOW}Importing EKS Access Policy Association...${NC}"
        IMPORT_ID="${CLUSTER_NAME}/${ROLE_ARN}_${EXISTING_ASSOCIATION}"
        terraform import 'aws_eks_access_policy_association.github_actions_admin[0]' "$IMPORT_ID"
        echo -e "${GREEN}Successfully imported EKS Access Policy Association!${NC}"
    fi
fi

echo -e "${GREEN}=== Import complete ===${NC}"