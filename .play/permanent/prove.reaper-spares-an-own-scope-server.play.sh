#!/usr/bin/env bash
######################################################################
# prove.reaper-spares-an-own-scope-server — the reaper spares a process that is
# its own scope's oldest, and names the same process born inside a peer's cgroup
#
# .why this play exists
#   - one tmux server per crew is built in nheuron (uladkasach/nheuron#44); each
#     server outlives the pane that started it, so its spawner is dead and it
#     ages past 24h — two of the reaper's three marks
#   - the third mark, "not its cgroup's oldest", is the only one that spares
#     it, and only if the server is born in its OWN scope (vision case 9)
#   - `prove.abandoned-procs-are-reaped` states it cannot prove that rule: bait
#     spawned from a play lands in the play's cgroup. `systemd-run --user --scope`
#     plants an owner in a cgroup of its own, which is what a crew server gets
#
# .the arms — both read in PLAN mode, so no arm kills
#   - own-scope  bait alone in a fresh user scope, spawner exited → NOT named
#   - in-pane    bait reparented inside THIS play's cgroup         → named
#     (if in-pane were spared too, own-scope's green would prove naught)
#
# .the write — `rule.forbid.repair-plays` exception 2: bait processes, a temp
#   dir, and one transient user scope; a trap kills the bait and stops the scope
#
# usage:
#   rhx play.run --play prove.reaper-spares-an-own-scope-server
#
# exit:
#   0 = both arms hold
#   1 = an arm failed
#   2 = no user manager, so no scope could be planted
######################################################################
set -uo pipefail

# .what = the checkout under proof — `PROVE_ROOT` (the red half), this play's own, or the cwd
_root_of() {
  [[ -n "${PROVE_ROOT:-}" ]] && { printf '%s' "$PROVE_ROOT"; return 0; }
  local self; self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
  [[ -n "$self" && -f "$self/src/grove.provision._.sh" ]] && { printf '%s' "$self"; return 0; }
  [[ -f "$PWD/src/grove.provision._.sh" ]] && { printf '%s' "$PWD"; return 0; }
  return 1
}
ROOT="$(_root_of)" || { echo "✋ no checkout found"; exit 2; }
REAPER="$ROOT/src/machine/machine_resource_procs_reap_abandoned"
TMPDIR_BAIT=""
BAIT_PIDS=()
UNIT="prove-crew-server-$$"
FAILED=0

cleanup() {
  local pid
  for pid in "${BAIT_PIDS[@]}"; do kill "$pid" 2>/dev/null; done
  systemctl --user stop "$UNIT.scope" >/dev/null 2>&1
  [[ -n "$TMPDIR_BAIT" ]] && rm -rf "$TMPDIR_BAIT"
  echo "   🧹 bait killed, scope stopped, temp dir removed"
}
trap cleanup EXIT

[[ -x "$REAPER" ]] || { echo "✋ no reaper at $REAPER — this play measures the real executable"; exit 1; }
systemctl --user show-environment >/dev/null 2>&1 \
  || { echo "✋ no user manager on this seat — no scope can be planted"; exit 2; }

TMPDIR_BAIT="$(mktemp -d "${TMPDIR:-/tmp}/prove.reaper-scope.XXXXXX")"
cp "$(command -v sleep)" "$TMPDIR_BAIT/tmux"

# own-scope: a fresh user scope whose launcher exits, so the bait is the scope's oldest
if ! systemd-run --user --scope --quiet --unit "$UNIT" \
     bash -c "setsid '$TMPDIR_BAIT/tmux' 600 </dev/null &>/dev/null & echo \$! > '$TMPDIR_BAIT/own.pid'"; then
  echo "✋ systemd-run --user --scope failed — no scope planted"; exit 2
fi
sleep 0.3
OWN="$(cat "$TMPDIR_BAIT/own.pid" 2>/dev/null)"
[[ -n "$OWN" ]] && BAIT_PIDS+=("$OWN")

# in-pane: the same bait, reparented, but inside THIS play's cgroup
( setsid "$TMPDIR_BAIT/tmux" 600 </dev/null &>/dev/null & echo "$!" > "$TMPDIR_BAIT/pane.pid" )
PANE="$(cat "$TMPDIR_BAIT/pane.pid")"
BAIT_PIDS+=("$PANE")
sleep 0.3

for pid in "$OWN" "$PANE"; do
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null || { echo "💥 a bait did not start — this play measured no world"; exit 1; }
done

echo "🔭 does the reaper spare a crew server born in its own scope?"
echo "   ├─ own-scope pid $OWN, cgroup $(cut -d: -f3 "/proc/$OWN/cgroup")"
echo "   ├─ in-pane   pid $PANE, cgroup $(cut -d: -f3 "/proc/$PANE/cgroup")"

OUT=""; RC=""
reap() { OUT="$("$REAPER" --report "$TMPDIR_BAIT/reaped.log" "$@" 2>&1)"; RC=$?; }
found() { printf '%s\n' "$OUT" | grep -q "🪲 $1 "; }

# .what = the own-scope arm: the reaper must SPARE its scope's oldest
_arm_own() {
  reap --mode plan --min-age 0 --pid "$OWN"
  echo "   ├─ arm 'own-scope'"
  [[ "$RC" -eq 0 ]] || { echo "   │  💥 reaper exit $RC — no verdict"; return 1; }
  found "$OWN" && { echo "   │  ✋ named for the kill — a per-crew server in its own scope would die"; return 1; }
  echo "   │  ✔ spared — its scope's oldest"
}

# .what = the in-pane arm: the reaper must NAME it, or the own-scope green proves naught
_arm_pane() {
  reap --mode plan --min-age 0 --pid "$PANE"
  echo "   └─ arm 'in-pane'"
  [[ "$RC" -eq 0 ]] || { echo "      💥 reaper exit $RC — no verdict"; return 1; }
  found "$PANE" || { echo "      ✋ NOT named — the own-scope arm's green proves naught"; return 1; }
  echo "      ✔ named — a server born in a peer's pane would be reaped"
}

_arm_own  || FAILED=1
_arm_pane || FAILED=1

echo ""
[[ "$FAILED" -eq 0 ]] && echo "🌲 a crew server born in its own scope is spared; one born in a pane is not"
exit "$FAILED"
