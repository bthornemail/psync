#!/usr/bin/env python3
import json
import sys

# TODO(v0): enforce full topology_report.v0 contract + must-reject vectors.

def fail(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(2)

raw = sys.stdin.read()
if not raw.strip():
    fail('empty input')

obj = json.loads(raw)
if not isinstance(obj, dict):
    fail('report must be a JSON object')
if obj.get('kind') != 'topology_report.v0':
    fail('kind must be topology_report.v0')

# Deterministic canonical output.
out = json.dumps(obj, sort_keys=True, separators=(',', ':'))
sys.stdout.write(out + '\n')
