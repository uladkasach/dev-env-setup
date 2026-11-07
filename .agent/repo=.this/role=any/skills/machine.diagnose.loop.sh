#!/usr/bin/env bash
######################################################################
# .what = name a spawn loop — the fleet of parents that share one shape
#
# .why  = `machine.diagnose.churn` says HOW FAST the box forks; this says WHICH
#         LOOP does it, in one line: "145 zsh parents · each spawns {sleep,ssh}",
#         with one parent's full argv and the process that launched it
#
# usage:
#   rhx machine.diagnose.loop                # 5s live sample
#   rhx machine.diagnose.loop --secs 10      # a longer sample
#   rhx machine.diagnose.loop --gate         # as the watchdog asks: only if
#                                            #   churn held ≥100/sec for 3 minutes
#
# guarantee:
#   - runs THIS checkout's src/machine/machine_resource_procs_find_loop, so a
#     change is testable before `1.6.1.finders` installs it
#   - read-only; it names a loop and kills none
######################################################################
set -euo pipefail

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
exec "$ROOT/src/machine/machine_resource_procs_find_loop" "$@"
