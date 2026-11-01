#!/usr/bin/env bash
######################################################################
# .what = a THIN SHIM onto `src/machine/machine_power_profile_sync` — hold the
#         power profile to the charger: plugged in past the threshold →
#         performance; unplugged → battery
#
# .why  = the implementation is a declared asset of `src/`, installed to
#         `~/.local/bin` by `1.2.power`; this shim lets `rhx` reach it from a
#         checkout before any install (same split as `machine.usage.history`)
#
# usage:
#   rhx machine.power.profile.sync                 # plan: what the box reads, what would change
#   rhx machine.power.profile.sync --mode apply    # act once on an edge
######################################################################
set -euo pipefail
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/src/machine/machine_power_profile_sync" "$@"
