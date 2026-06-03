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
# Architectural-layer ratchet gate.
#
# Runs go-arch-lint against .go-arch-lint.yml, counts the layer violations,
# and compares the count to .architecture-baseline.json:
#   - current > baseline  -> FAIL (a PR introduced new cross-layer imports)
#   - current < baseline  -> OK, and prints a reminder to ratchet the baseline down
#   - current = baseline  -> OK
# The baseline may only ever be lowered, never raised.

set -e

BACKEND_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$BACKEND_DIR"

BASELINE_FILE=".architecture-baseline.json"

if ! command -v go-arch-lint >/dev/null 2>&1; then
  echo "error: go-arch-lint not found on PATH (install: go install github.com/fe3dback/go-arch-lint@latest)" >&2
  exit 2
fi

# go-arch-lint exits non-zero when any violation exists; capture output regardless.
OUTPUT=$(go-arch-lint check 2>&1 || true)

# Strip ANSI colour codes, then read "total notices: N".
CURRENT=$(printf '%s\n' "$OUTPUT" | sed 's/\x1b\[[0-9;]*m//g' | grep -oE 'total notices: [0-9]+' | grep -oE '[0-9]+' | tail -1)
CURRENT=${CURRENT:-0}

BASELINE=$(grep -oE '"violations"[[:space:]]*:[[:space:]]*[0-9]+' "$BASELINE_FILE" | grep -oE '[0-9]+')
BASELINE=${BASELINE:-0}

echo "Architectural layer violations: current=$CURRENT baseline=$BASELINE"

if [ "$CURRENT" -gt "$BASELINE" ]; then
  echo ""
  echo "FAIL: layer violations increased ($BASELINE -> $CURRENT)."
  echo "A new cross-layer import was introduced. Fix it, or (if intentional)"
  echo "adjust .go-arch-lint.yml. The baseline may only be lowered, never raised."
  exit 1
fi

if [ "$CURRENT" -lt "$BASELINE" ]; then
  echo "Violations decreased — please ratchet down: set \"violations\": $CURRENT in $BASELINE_FILE."
fi

echo "OK: within the architectural baseline."
