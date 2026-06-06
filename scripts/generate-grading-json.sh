#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TERRAFORM_DIR="${TERRAFORM_DIR:-${ROOT_DIR}/terraform}"
OUTPUT_FILE="${OUTPUT_FILE:-${ROOT_DIR}/grading.json}"
TMP_OUTPUT="$(mktemp)"
TMP_SAFE_OUTPUT="$(mktemp)"
INCLUDE_SENSITIVE_OUTPUTS="${INCLUDE_SENSITIVE_OUTPUTS:-false}"

terraform -chdir="${TERRAFORM_DIR}" output -json > "${TMP_OUTPUT}"

if [[ ! -s "${TMP_OUTPUT}" ]]; then
  echo "Terraform output was empty; not updating ${OUTPUT_FILE}" >&2
  rm -f "${TMP_OUTPUT}"
  exit 1
fi

if ! ruby -rjson -e 'JSON.parse(File.read(ARGV.fetch(0)))' "${TMP_OUTPUT}"; then
  echo "Terraform output was not valid JSON; not updating ${OUTPUT_FILE}" >&2
  rm -f "${TMP_OUTPUT}" "${TMP_SAFE_OUTPUT}"
  exit 1
fi

if [[ "${INCLUDE_SENSITIVE_OUTPUTS}" == "true" ]]; then
  if [[ "${CI:-false}" == "true" ]]; then
    echo "Refusing to write sensitive Terraform outputs in CI" >&2
    rm -f "${TMP_OUTPUT}" "${TMP_SAFE_OUTPUT}"
    exit 1
  fi

  ruby -rjson -e '
    outputs = JSON.parse(File.read(ARGV.fetch(0)))
    File.write(ARGV.fetch(1), JSON.pretty_generate(outputs) + "\n")
  ' "${TMP_OUTPUT}" "${TMP_SAFE_OUTPUT}"
else
  ruby -rjson -e '
    outputs = JSON.parse(File.read(ARGV.fetch(0)))
    secret_name = /(access[_-]?key|secret|password|credential|token)/i

    outputs.each do |name, output|
      next unless output.is_a?(Hash)
      next unless output["sensitive"] || name.match?(secret_name)

      output["value"] = "REDACTED"
      output["sensitive"] = true
    end

    File.write(ARGV.fetch(1), JSON.pretty_generate(outputs) + "\n")
  ' "${TMP_OUTPUT}" "${TMP_SAFE_OUTPUT}"
fi

mv "${TMP_SAFE_OUTPUT}" "${OUTPUT_FILE}"
rm -f "${TMP_OUTPUT}"
echo "Wrote ${OUTPUT_FILE}"
