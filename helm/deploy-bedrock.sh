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

if [[ -f ".env" ]]; then
  echo "Loading environment variables from .env..."
  set -a
  source .env
  set +a
fi

echo "Configuring AWS credentials for EKS access..."

if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  echo "Using AWS credentials from environment variables"
elif [[ -n "${AWS_PROFILE:-}" ]]; then
  echo "Using AWS profile: ${AWS_PROFILE}"
elif [[ -n "${AWS_WEB_IDENTITY_TOKEN_FILE:-}" ]] && [[ -n "${AWS_ROLE_ARN:-}" ]]; then
  echo "Using AWS web identity credentials"
else
  echo "WARNING: No deployer credentials found. Use an admin/deployer role, not bedrock-dev-view."
  exit 1
fi

echo "Updating kubeconfig for cluster ${CLUSTER_NAME} in region ${AWS_REGION}..."
if ! aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "ERROR: EKS cluster ${CLUSTER_NAME} does not exist. Run terraform apply successfully before deploying."
  exit 1
fi
aws eks wait cluster-active --name "${CLUSTER_NAME}" --region "${AWS_REGION}"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"

if ! kubectl cluster-info &>/dev/null; then
  echo "Warning: Cannot access cluster with current credentials."
  exit 1
fi

kubectl wait --for=condition=ready node --all --timeout=300s

if [[ "${SKIP_SECRET_SYNC:-false}" != "true" ]]; then
  NAMESPACE="${NAMESPACE}" TERRAFORM_DIR="terraform" ./scripts/sync-retail-secrets.sh
fi

if [[ ! -f "${GENERATED_VALUES}" ]]; then
  echo "Missing ${GENERATED_VALUES}. Run ./scripts/sync-retail-secrets.sh first."
  exit 1
fi

ALB_ROLE_ARN="$(terraform -chdir=terraform output -raw alb_controller_role_arn)"
VPC_ID="$(terraform -chdir=terraform output -raw vpc_id)"
CARTS_IRSA_ROLE_ARN="$(terraform -chdir=terraform output -raw carts_irsa_role_arn)"

if [[ "${NAMESPACE}" == "retail-app-dev" ]]; then
  NAMESPACE_MANIFEST="k8s/namespace-dev.yaml"
  INGRESS_MANIFEST="k8s/ingress-dev.yaml"
else
  NAMESPACE_MANIFEST="k8s/namespace.yaml"
  INGRESS_MANIFEST="k8s/ingress.yaml"
fi

kubectl apply -f "${NAMESPACE_MANIFEST}"
kubectl apply -f k8s/clusterrolebinding-dev-view.yaml
kubectl apply -f k8s/aws-load-balancer-controller.yaml

sed "s|REPLACE_WITH_ALB_CONTROLLER_ROLE_ARN|${ALB_ROLE_ARN}|g" \
  k8s/aws-load-balancer-controller-sa.yaml | kubectl apply -f -

helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${AWS_REGION}" \
  --set vpcId="${VPC_ID}" \
  --wait --timeout=600s

kubectl -n kube-system rollout status deployment/aws-load-balancer-controller --timeout=300s

helm dependency build src/app/chart
helm upgrade --install "${RELEASE_NAME}" src/app/chart \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  -f src/app/chart/values.yaml \
  -f "${VALUES_FILE}" \
  -f "${GENERATED_VALUES}" \
  --set cart.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${CARTS_IRSA_ROLE_ARN}" \
  --wait --timeout=600s

kubectl apply -f "${INGRESS_MANIFEST}"

echo "Helm deployment complete."
echo "Check pods: kubectl get pods -n ${NAMESPACE}"
echo "Check ingress: kubectl get ingress -n ${NAMESPACE}"
