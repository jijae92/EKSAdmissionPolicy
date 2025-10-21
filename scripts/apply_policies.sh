#!/usr/bin/env bash
set -euo pipefail

echo "[apply] Applying Gatekeeper ConstraintTemplates..."
kubectl apply -f policies/templates/

echo "[apply] Applying Gatekeeper Constraints..."
kubectl apply -f policies/constraints/

if [ -f waivers/constraint-exemptions.yaml ]; then
  echo "[apply] Applying waiver helper ConfigMap..."
  kubectl apply -f waivers/constraint-exemptions.yaml
fi

echo "[apply] Waiting for gatekeeper-system pods to become Ready (Ctrl+C to stop watching)..."
kubectl -n gatekeeper-system get pods -w
