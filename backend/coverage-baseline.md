<!--
Licensed to the Apache Software Foundation (ASF) under one or more
contributor license agreements.  See the NOTICE file distributed with
this work for additional information regarding copyright ownership.
The ASF licenses this file to You under the Apache License, Version 2.0
(the "License"); you may not use this file except in compliance with
the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# Go Unit-Test Coverage Baseline

Baseline line-coverage for the modules targeted by the test-coverage initiative
(REQ-009 / WO-002). These numbers are the **starting point** that subsequent
coverage work orders (e.g. WO-011 threshold enforcement, WO-039 coverage
increase to >80%) measure progress against.

How to reproduce:

```sh
cd backend
make unit-test-go      # writes a merged coverage.out
go tool cover -func=coverage.out          # per-function + total
go tool cover -func=coverage.out | tail   # total line
```

`make unit-test-go` now emits a merged `coverage.out` profile, and the
`unit-test` CI job uploads it as the `go-coverage` workflow artifact and prints
per-package `coverage: N%` lines in the logs.

## Baseline (measured on Go 1.26.4)

| Target package | Line coverage |
|----------------|---------------|
| `backend/core/runner` | **0.9%** |
| `backend/server/api/auth` | **51.7%** |
| `backend/helpers/pluginhelper` | **70.2%** |
| `backend/plugins/gitextractor` | **~0%** |

### Sub-package detail

**`helpers/pluginhelper`**
| Package | Coverage |
|---------|----------|
| `helpers/pluginhelper` | 70.2% |
| `helpers/pluginhelper/api` | 21.9% |
| `helpers/pluginhelper/services` | 0.0% |
| `helpers/pluginhelper/subtaskmeta/sorter` | 93.3% |
| `helpers/pluginhelper/api/apihelperabstract` | no test files |
| `helpers/pluginhelper/api/models` | no test files |

**`plugins/gitextractor`** (requires libgit2/CGO — measured in the build image)
| Package | Coverage |
|---------|----------|
| `plugins/gitextractor` | 0.0% |
| `plugins/gitextractor/store` | 16.0% |
| `plugins/gitextractor/impl` | 0.0% |
| `plugins/gitextractor/models` | 0.0% |
| `plugins/gitextractor/parser` | 0.0% |
| `plugins/gitextractor/tasks` | 0.0% |
| `plugins/gitextractor/api` | no test files |

## Notes

- Scope mirrors `scripts/unit-test-go.sh` (`go list ./...` minus `test|models|e2e`).
- `gitextractor` numbers were captured inside the `mericodev/lake-builder` image
  (with a Go 1.26 toolchain) because the package links libgit2 via CGO.
- Out of scope for this WO: writing new tests to raise these numbers — that is
  handled by the dedicated coverage work orders.
