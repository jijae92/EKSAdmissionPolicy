#!/usr/bin/env bash
set -euo pipefail

echo "[cleanup] Deleting bad manifest resources..."
kubectl delete -f manifests/bad --ignore-not-found --wait=false || true

echo "[cleanup] Deleting good manifest resources..."
kubectl delete -f manifests/good --ignore-not-found --wait=false || true

WAIVER_NAMESPACE="${1:-waiver-demo}"
echo "[cleanup] Removing waiver demo namespace (${WAIVER_NAMESPACE}) if present..."
kubectl delete namespace "${WAIVER_NAMESPACE}" --ignore-not-found || true

if [ "${CLEAN_POLICIES:-false}" = "true" ]; then
  echo "[cleanup] Removing Gatekeeper constraints and templates (CLEAN_POLICIES=true)..."
  kubectl delete -f policies/constraints --ignore-not-found || true
  kubectl delete -f policies/templates --ignore-not-found || true
  if [ -f waivers/constraint-exemptions.yaml ]; then
    kubectl delete -f waivers/constraint-exemptions.yaml --ignore-not-found || true
  fi
fi
