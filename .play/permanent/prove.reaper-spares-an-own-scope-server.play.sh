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
#   1 = an arm failed, or the checkout holds no executable reaper
#   2 = no checkout, no user manager, or a bait that never started — no claim was graded
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
ROOT="$(_root_of)" || { echo "   ✋ ConstraintError: no checkout found" >&2; exit 2; }
REAPER="$ROOT/src/machine/machine_resource_procs_reap_abandoned"
TMPDIR_BAIT=""
BAIT_PIDS=()
UNIT="prove-crew-server-$$"
FAILED=0

# every call to the user manager is bounded and fed no stdin: a wedged manager is
# a state this play may meet, and it must report rather than hang
# (rule.require.bounded-probes-in-verifies)
cleanup() {
  local pid
  for pid in "${BAIT_PIDS[@]}"; do kill "$pid" 2>/dev/null; done
  timeout -k 2 10 systemctl --user stop "$UNIT.scope" </dev/null >/dev/null 2>&1
  [[ -n "$TMPDIR_BAIT" ]] && rm -rf "$TMPDIR_BAIT"
  echo "   🧹 bait killed, scope stopped, temp dir removed"
}
trap cleanup EXIT

# .what = wait for a bait's pid file, then for the pid to live — up to 5s, never one fixed sleep
# stdout: the live pid, or empty if none appeared in time
_await_bait() {
  local file="$1" pid="" tick
  for tick in $(seq 1 20); do
    pid="$(cat "$file" 2>/dev/null)"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && { printf '%s' "$pid"; return 0; }
    sleep 0.25
  done
  return 1
}

# the reaper is a CHECKOUT file, so its absence is a defect in the tree under proof, never an
#   absent subject on this seat — it fails, where a seat with no user manager declines
[[ -x "$REAPER" ]] || { echo "   💥 MalfunctionError: the checkout holds no executable reaper at $REAPER" >&2; exit 1; }
timeout -k 2 10 systemctl --user show-environment </dev/null >/dev/null 2>&1 \
  || { echo "   ✋ ConstraintError: no user manager on this seat — no scope can be planted" >&2; exit 2; }

TMPDIR_BAIT="$(mktemp -d "${TMPDIR:-/tmp}/prove.reaper-scope.XXXXXX")"
cp "$(command -v sleep)" "$TMPDIR_BAIT/tmux"

# own-scope: a fresh user scope whose launcher exits, so the bait is the scope's oldest
timeout -k 2 20 systemd-run --user --scope --quiet --unit "$UNIT" \
  bash -c "setsid '$TMPDIR_BAIT/tmux' 600 </dev/null &>/dev/null & echo \$! > '$TMPDIR_BAIT/own.pid'" \
  </dev/null || { echo "   ✋ ConstraintError: systemd-run --user --scope failed — no scope planted" >&2; exit 2; }
OWN="$(_await_bait "$TMPDIR_BAIT/own.pid")"
[[ -n "$OWN" ]] && BAIT_PIDS+=("$OWN")

# in-pane: the same bait, reparented, but inside THIS play's cgroup
( setsid "$TMPDIR_BAIT/tmux" 600 </dev/null &>/dev/null & echo "$!" > "$TMPDIR_BAIT/pane.pid" )
PANE="$(_await_bait "$TMPDIR_BAIT/pane.pid")"
[[ -n "$PANE" ]] && BAIT_PIDS+=("$PANE")

[[ -n "$OWN" && -n "$PANE" ]] \
  || { echo "   ✋ ConstraintError: a bait did not start within 5s — this play measured no world" >&2; exit 2; }

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
  [[ "$RC" -eq 0 ]] || { echo "   │  💥 MalfunctionError: reaper exit $RC — no verdict" >&2; return 1; }
  found "$OWN" && { echo "   │  💥 MalfunctionError: named for the kill — a per-crew server in its own scope would die" >&2; return 1; }
  echo "   │  ✔ spared — its scope's oldest"
}

# .what = the in-pane arm: the reaper must NAME it, or the own-scope green proves naught
_arm_pane() {
  reap --mode plan --min-age 0 --pid "$PANE"
  echo "   └─ arm 'in-pane'"
  [[ "$RC" -eq 0 ]] || { echo "      💥 MalfunctionError: reaper exit $RC — no verdict" >&2; return 1; }
  found "$PANE" || { echo "      💥 MalfunctionError: NOT named — the own-scope arm's green proves naught" >&2; return 1; }
  echo "      ✔ named — a server born in a peer's pane would be reaped"
  PANE_LINE="$(printf '%s\n' "$OUT" | grep "🪲 $PANE ")"
}
PANE_LINE=""

_arm_own  || FAILED=1
_arm_pane || FAILED=1

[[ "$FAILED" -eq 0 ]] || exit "$FAILED"

# the snap keeps the reaper's own words for the in-pane bait — its glyph, its name, its
#   shape — and masks what any run varies by: the pid, the bait dir, its age, rss, and cgroup
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"
PANE_SHAPE="${PANE_LINE//$PANE/<pid>}"
PANE_SHAPE="$(printf '%s\n' "$PANE_SHAPE" | sed -E 's/^ *├─//; s/age [0-9.]+h/age <age>h/; s/rss [0-9.]+M/rss <rss>M/; s# — /.*# — <the pane cgroup, which varies by seat and session>#')"
play_snap_assert arm=R rendered="$(printf '%s\n' \
  "   • own-scope bait spared — the reaper named no 🪲 line for it ✔" \
  "   • in-pane bait named — $PANE_SHAPE ✔")" mask="$TMPDIR_BAIT" || exit 1

echo ""
echo "🌲 a crew server born in its own scope is spared; one born in a pane is not"
exit 0
