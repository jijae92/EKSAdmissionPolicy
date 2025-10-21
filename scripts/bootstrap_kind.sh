#!/usr/bin/env bash
set -euo pipefail

kind create cluster --config infra/cluster/kind-config.yaml
./infra/cluster/install_gatekeeper.sh
./scripts/apply_policies.sh
