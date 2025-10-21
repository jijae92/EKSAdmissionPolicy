#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="${SCRIPT_DIR}/../helm/values-gatekeeper.yaml"
NAMESPACE="gatekeeper-system"

helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts >/dev/null
helm repo update >/dev/null

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace "${NAMESPACE}" \
  -f "${VALUES_FILE}"

kubectl wait --namespace "${NAMESPACE}" \
  --for=condition=Available deployment/gatekeeper-controller-manager \
  --timeout=180s
