#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-retail-app}"
TERRAFORM_DIR="${TERRAFORM_DIR:-terraform}"

cd "$(dirname "$0")/.."

CATALOG_ENDPOINT="$(terraform -chdir="${TERRAFORM_DIR}" output -raw catalog_mysql_endpoint)"
ORDERS_ENDPOINT="$(terraform -chdir="${TERRAFORM_DIR}" output -raw orders_postgres_endpoint)"
CATALOG_USER="$(terraform -chdir="${TERRAFORM_DIR}" output -raw catalog_db_username)"
ORDERS_USER="$(terraform -chdir="${TERRAFORM_DIR}" output -raw orders_db_username)"
CATALOG_PASS="$(terraform -chdir="${TERRAFORM_DIR}" output -raw catalog_db_password)"
ORDERS_PASS="$(terraform -chdir="${TERRAFORM_DIR}" output -raw orders_db_password)"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "${NAMESPACE}" create secret generic catalog-db \
  --from-literal=RETAIL_CATALOG_PERSISTENCE_USER="${CATALOG_USER}" \
  --from-literal=RETAIL_CATALOG_PERSISTENCE_PASSWORD="${CATALOG_PASS}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "${NAMESPACE}" create secret generic orders-db \
  --from-literal=RETAIL_ORDERS_PERSISTENCE_USERNAME="${ORDERS_USER}" \
  --from-literal=RETAIL_ORDERS_PERSISTENCE_PASSWORD="${ORDERS_PASS}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "${NAMESPACE}" create secret generic orders-rabbitmq \
  --from-literal=RETAIL_ORDERS_MESSAGING_RABBITMQ_USERNAME="guest" \
  --from-literal=RETAIL_ORDERS_MESSAGING_RABBITMQ_PASSWORD="guest" \
  --dry-run=client -o yaml | kubectl apply -f -

cat > helm/values-bedrock.generated.yaml <<EOF
catalog:
  app:
    persistence:
      endpoint: "${CATALOG_ENDPOINT}"

orders:
  app:
    persistence:
      endpoint: "${ORDERS_ENDPOINT}"
EOF

echo "Synced Kubernetes secrets and generated helm/values-bedrock.generated.yaml"
