#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-retail-app}"
RELEASE_NAME="${RELEASE_NAME:-retail}"
CLUSTER_NAME="${CLUSTER_NAME:-project-bedrock-cluster}"
AWS_REGION="${AWS_REGION:-us-east-1}"
VALUES_FILE="${VALUES_FILE:-helm/values-bedrock.yaml}"
GENERATED_VALUES="${GENERATED_VALUES:-helm/values-bedrock.generated.yaml}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ ! -f "${GENERATED_VALUES}" ]]; then
  echo "Missing ${GENERATED_VALUES}. Run ./scripts/sync-retail-secrets.sh first."
  exit 1
fi

# Configure AWS credentials for EKS access
# The bedrock-dev-view user has cluster access configured by Terraform
echo "Configuring AWS credentials for EKS access..."

# Try to get bedrock-dev-view credentials from Terraform state using jq
BEDROCK_ACCESS_KEY=""
BEDROCK_SECRET_KEY=""

if command -v jq &> /dev/null; then
  # Use jq to properly parse the state file
  TERRAFORM_STATE=$(terraform -chdir=terraform state show -json module.iam.aws_iam_access_key.dev_view 2>/dev/null || echo "")
  if [[ -n "${TERRAFORM_STATE:-}" ]]; then
    BEDROCK_ACCESS_KEY=$(echo "${TERRAFORM_STATE}" | jq -r '.values.access_key // empty' | tr -d '\n')
    BEDROCK_SECRET_KEY=$(echo "${TERRAFORM_STATE}" | jq -r '.values.secret // empty' | tr -d '\n')
  fi
fi

# Fallback: try grep if jq didn't work
if [[ -z "${BEDROCK_ACCESS_KEY:-}" ]]; then
  BEDROCK_ACCESS_KEY=$(terraform -chdir=terraform state show module.iam.aws_iam_access_key.dev_view 2>/dev/null | grep -E '^\s*access_key\s*=' | sed 's/.*=\s*"//' | sed 's/"$//' | tr -d '\n' || echo "")
  BEDROCK_SECRET_KEY=$(terraform -chdir=terraform state show module.iam.aws_iam_access_key.dev_view 2>/dev/null | grep -E '^\s*secret\s*=' | sed 's/.*=\s*"//' | sed 's/"$//' | tr -d '\n' || echo "")
fi

if [[ -n "${BEDROCK_ACCESS_KEY:-}" ]] && [[ -n "${BEDROCK_SECRET_KEY:-}" ]]; then
  echo "Using bedrock-dev-view credentials from Terraform state"
  export AWS_ACCESS_KEY_ID="${BEDROCK_ACCESS_KEY}"
  export AWS_SECRET_ACCESS_KEY="${BEDROCK_SECRET_KEY}"
elif [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  echo "Using AWS credentials from environment variables"
else
  echo "WARNING: No credentials found. Using current AWS profile."
  echo "If authentication fails, you may need to:"
  echo "  1. Set AWS_PROFILE to a profile with EKS cluster access, or"
  echo "  2. Create a new access key: aws iam create-access-key --user-name bedrock-dev-view"
fi

# Update kubeconfig
echo "Updating kubeconfig for cluster ${CLUSTER_NAME} in region ${AWS_REGION}..."
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"

CARTS_IRSA_ROLE_ARN="$(terraform -chdir=terraform output -raw carts_irsa_role_arn)"

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/clusterrolebinding-dev-view.yaml
kubectl apply -f k8s/aws-load-balancer-controller.yaml

helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=true \
  --set region="${AWS_REGION}"

kubectl -n kube-system rollout status deployment/aws-load-balancer-controller --timeout=180s

helm dependency build src/app/chart
helm upgrade --install "${RELEASE_NAME}" src/app/chart \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  -f src/app/chart/values.yaml \
  -f "${VALUES_FILE}" \
  -f "${GENERATED_VALUES}" \
  --set cart.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${CARTS_IRSA_ROLE_ARN}"

kubectl apply -f k8s/ingress.yaml

echo "Helm deployment complete."
echo "Check pods: kubectl get pods -n ${NAMESPACE}"
echo "Check ingress: kubectl get ingress -n ${NAMESPACE}"
