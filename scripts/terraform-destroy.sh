#!/usr/bin/env bash
# Safely run Terraform destroy by ensuring the remote backend exists first.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"

bash "${ROOT_DIR}/scripts/create-tfstate-bucket.sh"

terraform -chdir="${TF_DIR}" init -reconfigure
bash "${ROOT_DIR}/scripts/terraform-import-existing.sh"
terraform -chdir="${TF_DIR}" destroy -auto-approve
