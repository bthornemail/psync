#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash scripts/wave31-device-parity-golden.sh
bash scripts/wave31-device-parity-must-reject.sh

echo "ok wave31 device parity contract"
