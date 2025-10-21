#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="gatekeeper-system"

helm uninstall gatekeeper --namespace "${NAMESPACE}" || true
kubectl delete namespace "${NAMESPACE}" --ignore-not-found

# TODO: Evaluate removing Gatekeeper CRDs when appropriate.
