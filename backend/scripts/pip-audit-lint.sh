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
# pip-audit ratchet gate for the pydevlake Python SDK.
#
# Installs pydevlake into a throwaway venv, audits its resolved dependency
# tree (excluding the venv bootstrap: pip/setuptools/wheel), and compares the
# number of vulnerable findings to .pip-audit-baseline.json:
#   - current > baseline -> FAIL (a PR introduced a new vulnerable dependency)
#   - current < baseline -> OK, with a reminder to ratchet the baseline down
#   - current = baseline -> OK
#
# Requires python3 (3.12) and the build toolchain for pydevlake's native deps
# (gcc, default-libmysqlclient-dev, libpq-dev) — provided by the CI job.
# The JSON report ($PIP_AUDIT_OUT, default pip-audit.json) is left for upload.

set -e

BACKEND_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$BACKEND_DIR"

BASELINE_FILE=".pip-audit-baseline.json"
OUT="${PIP_AUDIT_OUT:-pip-audit.json}"

VENV=$(mktemp -d)/venv
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip >/dev/null 2>&1
echo "Installing pydevlake into an audit venv..."
"$VENV/bin/pip" install -q ./python/pydevlake
# Audit pydevlake's dependency tree only — drop the venv bootstrap packages.
"$VENV/bin/pip" freeze | grep -viE '^(pip|setuptools|wheel|pkg[-_]resources)==' > "$VENV/reqs.txt"
"$VENV/bin/pip" install -q pip-audit

# -r audits exactly pydevlake's resolved deps; never let pip-audit's own exit
# code gate the build — the ratchet below decides.
"$VENV/bin/pip-audit" -r "$VENV/reqs.txt" --format json -o "$OUT" || true

CURRENT=$(python3 - "$OUT" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
deps = d["dependencies"] if isinstance(d, dict) else d
print(len({(x["name"], v["id"]) for x in deps for v in x.get("vulns", [])}))
PY
)
CURRENT=${CURRENT:-0}
BASELINE=$(grep -oE '"findings"[[:space:]]*:[[:space:]]*[0-9]+' "$BASELINE_FILE" | grep -oE '[0-9]+')
BASELINE=${BASELINE:-0}

echo "pip-audit findings (pydevlake deps): current=$CURRENT baseline=$BASELINE"

if [ "$CURRENT" -gt "$BASELINE" ]; then
  echo ""
  echo "FAIL: vulnerable Python dependencies increased ($BASELINE -> $CURRENT)."
  echo "A new advisory affects pydevlake's dependency tree — upgrade the affected"
  echo "package(s). The baseline may only be lowered, never raised."
  exit 1
fi

if [ "$CURRENT" -lt "$BASELINE" ]; then
  echo "Findings decreased — please ratchet down: set \"findings\": $CURRENT in $BASELINE_FILE."
fi

echo "OK: within the pip-audit baseline."
