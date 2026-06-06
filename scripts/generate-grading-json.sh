#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TERRAFORM_DIR="${TERRAFORM_DIR:-${ROOT_DIR}/terraform}"
OUTPUT_FILE="${OUTPUT_FILE:-${ROOT_DIR}/grading.json}"
TMP_OUTPUT="$(mktemp)"

terraform -chdir="${TERRAFORM_DIR}" output -json > "${TMP_OUTPUT}"

if [[ ! -s "${TMP_OUTPUT}" ]]; then
  echo "Terraform output was empty; not updating ${OUTPUT_FILE}" >&2
  rm -f "${TMP_OUTPUT}"
  exit 1
fi

if ! ruby -rjson -e 'JSON.parse(File.read(ARGV.fetch(0)))' "${TMP_OUTPUT}"; then
  echo "Terraform output was not valid JSON; not updating ${OUTPUT_FILE}" >&2
  rm -f "${TMP_OUTPUT}"
  exit 1
fi

mv "${TMP_OUTPUT}" "${OUTPUT_FILE}"
echo "Wrote ${OUTPUT_FILE}"
