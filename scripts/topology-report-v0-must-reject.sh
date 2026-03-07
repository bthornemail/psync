#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

expect_fail() {
  local label="$1"
  local needle="$2"
  shift 2
  set +e
  local out
  out="$("$@" 2>&1)"
  local code=$?
  set -e
  if [[ $code -eq 0 ]]; then
    echo "ERROR: expected failure for $label" >&2
    exit 2
  fi
  grep -Fq "$needle" <<<"$out" || {
    echo "ERROR: missing reject marker for $label: $needle" >&2
    echo "$out" >&2
    exit 2
  }
}

# TODO(v0): expand to full contract vectors from docs/topology-report-v0.md.
expect_fail "empty report" "empty input" python3 adapters/topology-report-v0/canonicalize_report.py < /dev/null
expect_fail "wrong kind" "kind must be topology_report.v0" python3 -c "import subprocess; subprocess.run(['python3','adapters/topology-report-v0/canonicalize_report.py'], input='{\"kind\":\"wrong\"}\\n', text=True, check=True)"

echo "ok topology-report-v0 must-reject (scaffold)"
