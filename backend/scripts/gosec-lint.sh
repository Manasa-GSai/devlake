#!/bin/sh
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# gosec HIGH-severity ratchet gate.
#
# Runs gosec over the module (HIGH severity only), counts the findings, and
# compares to .gosec-baseline.json:
#   - current > baseline  -> FAIL (a PR introduced a new high-severity issue)
#   - current < baseline  -> OK, with a reminder to ratchet the baseline down
#   - current = baseline  -> OK
#
# Exclusions (see also .gosec-baseline.json):
#   - G115  integer-overflow conversion — a noisy false-positive rule
#   - generated mocks and *_test.go files
# The JSON report ($GOSEC_OUT, default gosec.json) is left for upload as a
# CI artifact.

set -e

BACKEND_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$BACKEND_DIR"

BASELINE_FILE=".gosec-baseline.json"
OUT="${GOSEC_OUT:-gosec.json}"

if ! command -v gosec >/dev/null 2>&1; then
  echo "error: gosec not found on PATH (install: go install github.com/securego/gosec/v2/cmd/gosec@v2.27.1)" >&2
  exit 2
fi

# -no-fail: never fail on gosec's own exit code; the ratchet below is the gate.
gosec -severity high -exclude=G115 -exclude-dir=mocks -tests=false \
  -fmt json -out "$OUT" -no-fail -quiet ./... || true

CURRENT=$(grep -o '"rule_id"' "$OUT" 2>/dev/null | wc -l | tr -d ' ')
CURRENT=${CURRENT:-0}
BASELINE=$(grep -oE '"high_findings"[[:space:]]*:[[:space:]]*[0-9]+' "$BASELINE_FILE" | grep -oE '[0-9]+')
BASELINE=${BASELINE:-0}

echo "gosec HIGH findings (G115 excluded): current=$CURRENT baseline=$BASELINE"

if [ "$CURRENT" -gt "$BASELINE" ]; then
  echo ""
  echo "FAIL: high-severity gosec findings increased ($BASELINE -> $CURRENT)."
  echo "A new high-severity issue was introduced — fix it (or, if a genuine"
  echo "false positive, annotate with #nosec). The baseline may only be lowered."
  exit 1
fi

if [ "$CURRENT" -lt "$BASELINE" ]; then
  echo "Findings decreased — please ratchet down: set \"high_findings\": $CURRENT in $BASELINE_FILE."
fi

echo "OK: within the gosec baseline."
