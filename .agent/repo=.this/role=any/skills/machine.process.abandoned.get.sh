#!/usr/bin/env bash
######################################################################
# .what = list every process the abandoned-reaper WOULD kill — read-only
#
# .why  = `1.6.6.abandoned` arms an hourly timer that kills by four rules
#         (ours · reparented · not its cgroup's oldest · past --min-age).
#         those rules can match a long-lived host reparented to pid 1 (a
#         tmux server, a watch daemon). this is the look before the arm:
#         the reaper's own plan mode, so the verdict and the kill share one
#         implementation and can never disagree
#
# usage:
#   rhx machine.process.abandoned.get                  # the timer's own gate: 24h
#   rhx machine.process.abandoned.get --min-age 3600   # a wider net, 1h
#   rhx machine.process.abandoned.get --pid 123        # judge one pid
#
# guarantee:
#   - read-only: always runs the reaper in plan mode; signals no process
#   - refuses --mode, so this skill can never become the kill
#   - exit 0 = reported · 2 = bad input
######################################################################

set -euo pipefail

# rhx may prepend `--repo`/`--role`/`--skill`; the reaper reads strict args,
# so drop them here.
# .why --mode is refused, not passed: a get that can apply is a set in disguise
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo|--role|--skill) shift 2 ;;
    --mode)
      echo "✋ ConstraintError: machine.process.abandoned.get is read-only; --mode is not accepted" >&2
      echo "   └─ to reap, arm the timer: rhx grove.provision --what 1.6.6.abandoned --mode apply" >&2
      exit 2 ;;
    *) args+=("$1"); shift ;;
  esac
done

# `src/` sits beside `.agent/`, four levels up — a relative derivation, so it
# holds on every worktree (same shim shape as machine.usage.diagnose)
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/src/machine/machine_resource_procs_reap_abandoned" --mode plan "${args[@]}"
