#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-waiver-demo}"
MANIFEST="manifests/bad/pod-privileged.yaml"
WAIVER_LABEL="guardrails.gatekeeper.dev/waive=true"
WAIVE_REASON="${WAIVE_REASON:-Temporary privileged access for investigation}"
FUTURE_DATE="$(date -u -d '+7 days' '+%Y-%m-%d')"
PAST_DATE="$(date -u -d 'yesterday' '+%Y-%m-%d')"

echo "[waiver] Ensuring namespace ${NAMESPACE} exists and is labeled for waivers..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "${NAMESPACE}" "${WAIVER_LABEL}" --overwrite

echo "[waiver] Attempting to apply violating manifest without waiver (should be denied)..."
if kubectl apply -n "${NAMESPACE}" -f "${MANIFEST}" >/tmp/waiver-deny.out 2>/tmp/waiver-deny.err; then
  echo "Unexpected success when waiver annotations were absent."
  cat /tmp/waiver-deny.out
  exit 1
else
  echo "Denial summary:"
  grep -iE 'violation|deny|error' /tmp/waiver-deny.err | sed 's/^/  /'
fi

echo "[waiver] Applying manifest with waiver annotations (expected to succeed)..."
TEMP_FILE="$(mktemp)"
trap 'rm -f "${TEMP_FILE}" /tmp/waiver-deny.out /tmp/waiver-deny.err /tmp/waiver-expire.err 2>/dev/null || true' EXIT

kubectl apply --dry-run=client -n "${NAMESPACE}" -f "${MANIFEST}" -o yaml \
  | kubectl annotate --local -f - \
      guardrails.gatekeeper.dev/waive-until="${FUTURE_DATE}" \
      guardrails.gatekeeper.dev/waive-reason="${WAIVE_REASON}" \
      --overwrite -o yaml \
  > "${TEMP_FILE}"

kubectl apply -f "${TEMP_FILE}"
kubectl get pod -n "${NAMESPACE}" bad-privileged

echo "[waiver] Forcing waiver expiry (annotation ${PAST_DATE}) to trigger denial..."
if kubectl annotate -n "${NAMESPACE}" pod bad-privileged guardrails.gatekeeper.dev/waive-until="${PAST_DATE}" --overwrite >/tmp/waiver-expire.out 2>/tmp/waiver-expire.err; then
  echo "Unexpected success when setting expired waiver."
else
  echo "Expired waiver denial summary:"
  grep -iE 'violation|deny|error' /tmp/waiver-expire.err | sed 's/^/  /'
fi

echo "[waiver] Cleaning waived pod so future runs start fresh..."
kubectl delete pod -n "${NAMESPACE}" bad-privileged --ignore-not-found --wait=false
