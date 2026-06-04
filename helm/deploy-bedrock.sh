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
