#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TERRAFORM_DIR="${TERRAFORM_DIR:-${ROOT_DIR}/terraform}"
OUTPUT_FILE="${OUTPUT_FILE:-${ROOT_DIR}/grading.json}"

terraform -chdir="${TERRAFORM_DIR}" output -json > "${OUTPUT_FILE}"
echo "Wrote ${OUTPUT_FILE}"
