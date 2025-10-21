#!/usr/bin/env bash
set -euo pipefail

MANIFEST_DIR="${1:-manifests/bad}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "[violations] Testing manifests in ${MANIFEST_DIR}"

denied=0
unexpected_success=0
for manifest in "${MANIFEST_DIR}"/*.yaml; do
  name=$(basename "${manifest}")
  echo "---- ${name} ----"

  # Ensure any previous object is removed to avoid false positives.
  kubectl delete -f "${manifest}" --ignore-not-found >/dev/null 2>&1 || true

  stdout_file="${TMP_DIR}/${name}.out"
  stderr_file="${TMP_DIR}/${name}.err"

  if kubectl apply -f "${manifest}" 1>"${stdout_file}" 2>"${stderr_file}"; then
    echo "Expected violation but apply succeeded for ${name}"
    cat "${stdout_file}"
    kubectl delete -f "${manifest}" --ignore-not-found >/dev/null 2>&1 || true
    unexpected_success=1
  else
    denied=1
    echo "Violation summary:"
    if grep -iE 'violation|deny|error' "${stderr_file}" >/dev/null; then
      grep -iE 'violation|deny|error' "${stderr_file}" | sed 's/^/  /'
    else
      tail -n 10 "${stderr_file}" | sed 's/^/  /'
    fi
  fi
done

if [[ "${unexpected_success}" -eq 1 ]]; then
  echo "[violations] One or more manifests were not denied as expected."
  exit 1
fi

if [[ "${denied}" -eq 1 ]]; then
  echo "[violations] Violations detected as expected."
  exit 2
fi

echo "[violations] No manifests tested."
exit 0
