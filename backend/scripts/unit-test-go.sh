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

set -e

ROOT_DIR=$(dirname $(dirname "$0"))

# Merged coverage profile for all tested packages. Override the path with
# COVER_PROFILE if needed (e.g. in CI). Each per-package profile is appended
# (minus its leading "mode:" line) so a single file covers the whole run.
COVER_PROFILE="${COVER_PROFILE:-coverage.out}"
echo "mode: atomic" > "$COVER_PROFILE"

for m in $(go list $ROOT_DIR/... | egrep -v 'test|models|e2e'); do
  echo start unit testing on $m
  go test -timeout 60s -covermode=atomic -coverprofile=profile.tmp -v $m
  if [ -f profile.tmp ]; then
    tail -n +2 profile.tmp >> "$COVER_PROFILE"
    rm -f profile.tmp
  fi
done

echo "==== total coverage ===="
go tool cover -func="$COVER_PROFILE" | tail -n 1
