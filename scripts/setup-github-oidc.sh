#!/bin/bash
# Setup GitHub Actions OIDC Authentication with AWS
# This script creates the IAM role and OIDC provider needed for GitHub Actions to authenticate with AWS

set -e

# Configuration
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-esodevops/retail-store-sample-app}"
ROLE_NAME="${ROLE_NAME:-project-bedrock-github-actions-terraform}"
POLICY_ARN="${POLICY_ARN:-arn:aws:iam::aws:policy/AdministratorAccess}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}GitHub Actions OIDC Setup Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials are not configured${NC}"
    echo -e "${YELLOW}Please configure AWS credentials first:${NC}"
    echo "  export AWS_ACCESS_KEY_ID='your-access-key'"
    echo "  export AWS_SECRET_ACCESS_KEY='your-secret-key'"
    echo "  export AWS_REGION='us-east-1'"
    exit 1
fi

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}AWS Account ID: ${ACCOUNT_ID}${NC}"

# Check if OIDC provider already exists
OIDC_PROVIDER_ARN=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn' --output text 2>/dev/null || echo "")

if [ -z "$OIDC_PROVIDER_ARN" ]; then
    echo -e "${YELLOW}Creating OIDC provider...${NC}"
    
    # Get the thumbprint for GitHub's OIDC provider
    THUMBPRINT=$(echo | openssl s_client -servername token.actions.githubusercontent.com -connect token.actions.githubusercontent.com:443 2>/dev/null | openssl x509 -fingerprint -sha1 -noout | sed 's/SHA1 Fingerprint=//; s/://g' | tr '[:upper:]' '[:lower:]')
    
    # Create the OIDC provider
    OIDC_PROVIDER_ARN=$(aws iam create-open-id-connect-provider \
        --url https://token.actions.githubusercontent.com \
        --client-id-list sts.amazonaws.com \
        --thumbprint-list "$THUMBPRINT" \
        --query 'Arn' \
        --output text)
    
    echo -e "${GREEN}OIDC Provider created: ${OIDC_PROVIDER_ARN}${NC}"
else
    echo -e "${GREEN}OIDC Provider already exists: ${OIDC_PROVIDER_ARN}${NC}"
fi

# Check if role already exists
if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
    echo -e "${YELLOW}Role '${ROLE_NAME}' already exists. Updating trust policy...${NC}"
    
    # Update the assume role policy
    aws iam update-assume-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-document "{
            \"Version\": \"2012-10-17\",
            \"Statement\": [
                {
                    \"Effect\": \"Allow\",
                    \"Principal\": {
                        \"Federated\": \"${OIDC_PROVIDER_ARN}\"
                    },
                    \"Action\": \"sts:AssumeRoleWithWebIdentity\",
                    \"Condition\": {
                        \"StringEquals\": {
                            \"token.actions.githubusercontent.com:aud\": \"sts.amazonaws.com\"
                        },
                        \"StringLike\": {
                            \"token.actions.githubusercontent.com:sub\": [
                                \"repo:${GITHUB_REPOSITORY}:ref:refs/heads/main\",
                                \"repo:${GITHUB_REPOSITORY}:pull_request\"
                            ]
                        }
                    }
                }
            ]
        }"
    
    echo -e "${GREEN}Trust policy updated${NC}"
else
    echo -e "${YELLOW}Creating IAM role...${NC}"
    
    # Create the role
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "{
            \"Version\": \"2012-10-17\",
            \"Statement\": [
                {
                    \"Effect\": \"Allow\",
                    \"Principal\": {
                        \"Federated\": \"${OIDC_PROVIDER_ARN}\"
                    },
                    \"Action\": \"sts:AssumeRoleWithWebIdentity\",
                    \"Condition\": {
                        \"StringEquals\": {
                            \"token.actions.githubusercontent.com:aud\": \"sts.amazonaws.com\"
                        },
                        \"StringLike\": {
                            \"token.actions.githubusercontent.com:sub\": [
                                \"repo:${GITHUB_REPOSITORY}:ref:refs/heads/main\",
                                \"repo:${GITHUB_REPOSITORY}:pull_request\"
                            ]
                        }
                    }
                }
            ]
        }"
    
    echo -e "${GREEN}IAM role created: ${ROLE_NAME}${NC}"
fi

# Attach policy to role
echo -e "${YELLOW}Attaching policy to role...${NC}"
aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "$POLICY_ARN"

echo -e "${GREEN}Policy attached: ${POLICY_ARN}${NC}"

# Get role ARN
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Add the following secrets to your GitHub repository:"
echo ""
echo "   ${GREEN}AWS_TERRAFORM_ROLE_ARN${NC}:"
echo "   ${ROLE_ARN}"
echo ""
echo "   ${GREEN}AWS_ROLE_ARN${NC}:"
echo "   ${ROLE_ARN}"
echo ""
echo "2. (Optional) Add AWS_ECR_REPOSITORY for container image publishing"
echo ""
echo "3. Trigger a workflow to verify the setup"
echo ""
echo -e "${YELLOW}To verify, run:${NC}"
echo "   aws iam get-role --role-name ${ROLE_NAME}"