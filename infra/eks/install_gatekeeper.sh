#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_CONFIG="${SCRIPT_DIR}/eksctl-config.yaml"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

require_binary() {
  local bin="$1"
  local url="$2"
  if ! command -v "${bin}" >/dev/null 2>&1; then
    echo "${bin} not found. Install from ${url} before continuing." >&2
    exit 1
  fi
}

require_binary eksctl "https://eksctl.io/"
require_binary helm "https://helm.sh/docs/intro/install/"
require_binary yq "https://github.com/mikefarah/yq"

CLUSTER_NAME="$(yq '.metadata.name' "${CLUSTER_CONFIG}")"
if ! eksctl get cluster --name "${CLUSTER_NAME}" >/dev/null 2>&1; then
  echo "[eks] Creating cluster ${CLUSTER_NAME} using ${CLUSTER_CONFIG}..."
  eksctl create cluster -f "${CLUSTER_CONFIG}"
else
  echo "[eks] Cluster ${CLUSTER_NAME} already exists. Skipping creation."
fi

echo "[eks] Installing Gatekeeper via Helm..."
"${ROOT_DIR}/infra/cluster/install_gatekeeper.sh"

echo "[eks] Applying policy bundle..."
"${ROOT_DIR}/scripts/apply_policies.sh"

echo "[eks] Setup complete."
