#!/usr/bin/env bash
######################################################################
# .what = a THIN SHIM onto `src/machine/machine_usage_history` — rank what
#         consumed this box's cpu and memory over a window
#
# .why  = the implementation is a declared asset of `src/`, installed to
#         `~/.local/bin` by `1.7.usage`; this shim lets `rhx` reach it from a
#         checkout before any install (same split as `machine.usage.diagnose`)
#
# usage:
#   rhx machine.usage.history                 # the last hour
#   rhx machine.usage.history --since 6h      # 30m, 6h, 2d …
#   rhx machine.usage.history --by where      # group by worktree alone
#   rhx machine.usage.history --top 15
######################################################################
set -euo pipefail
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/src/machine/machine_usage_history" "$@"
