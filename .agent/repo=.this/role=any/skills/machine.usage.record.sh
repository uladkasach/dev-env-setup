#!/usr/bin/env bash
######################################################################
# .what = a THIN SHIM onto `src/machine/machine_usage_record` — take one
#         sample of where this box's cpu and memory went, by hand
#
# .why  = the timer `1.7.usage` arms runs it once a minute; this is for a
#         checkout with no install yet, or a sample on demand
#
# usage:
#   rhx machine.usage.record
######################################################################
set -euo pipefail
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/src/machine/machine_usage_record" "$@"
