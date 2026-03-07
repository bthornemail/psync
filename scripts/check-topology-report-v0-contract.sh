#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash scripts/topology-report-v0-golden.sh
bash scripts/topology-report-v0-must-reject.sh

echo "ok topology-report-v0 contract (scaffold)"
