#!/usr/bin/env bash
set -euo pipefail

# TODO(v0): invoke waveform-core deterministically and emit topology_report.v0 JSON.
# This scaffold intentionally stays non-authoritative and side-effect free.

if [[ $# -lt 2 ]]; then
  echo "usage: emit_topology_report.sh <subject_hash> <input_digest>" >&2
  exit 2
fi

subject_hash="$1"
input_digest="$2"

python3 "$(dirname "$0")/canonicalize_report.py" <<JSON
{
  "kind":"topology_report.v0",
  "subject":{"kind":"artifact","hash":"${subject_hash}"},
  "source":{"tool":"waveform-core","version":"TODO"},
  "input":{"mode":"samples","digest":"${input_digest}"},
  "embedding":{},
  "classification":{"periodic":false,"chaotic":false,"topology_changed":false,"confidence":0.0},
  "persistence":{},
  "labels":[],
  "summary":{"class":"unknown","note":"TODO: adapter scaffold"}
}
JSON
