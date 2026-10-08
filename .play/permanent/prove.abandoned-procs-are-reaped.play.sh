#!/usr/bin/env bash
######################################################################
# prove.abandoned-procs-are-reaped — the reaper kills and logs an abandoned
# process, and spares a young one and a parented one
#
# .what = drives the REAL `src/machine/machine_resource_procs_reap_abandoned`
#         against bait processes, scoped by --pid so no real process is touched:
#           bait orphan   — a copy of sleep named `node`, whose spawner exited,
#                           so it is reparented (to systemd --user, or pid 1)
#           bait parented — a child of this play, whose spawner is alive
#
# .the arms
#   young      orphan, --min-age far above its age, plan → NOT found
#   parented   parented bait, --min-age 0, plan       → NOT found
#   control    orphan, --min-age 0, apply             → killed, and ONE log line
#              names its pid. if young or parented also matched, control's
#              green would prove the reaper kills any process, not abandonment
#
# .the write — `rule.forbid.repair-plays` exception 2. the break is bait
#   processes and a temp dir; a trap kills the bait and removes the dir.
#   the reaper's report is aimed into the temp dir, never the real log
#
# ⚠️ .what it does NOT prove
#   - rule 3 (the cgroup's oldest process is spared): bait spawned from here
#     lands in this play's cgroup, whose oldest process is never the bait, so
#     no arm can plant a reparented OWNER without the user manager's help
#   - the hourly timer fires — `1.6.6.abandoned`'s verify reads that
#
# usage:
#   rhx play.run --play prove.abandoned-procs-are-reaped
######################################################################
set -uo pipefail

REPO="${GROVE_SRC:-$PWD/src}"
REAPER="$REPO/machine/machine_resource_procs_reap_abandoned"
TMPDIR_BAIT=""
BAIT_PIDS=()
FAILED=0

cleanup() {
  local pid alive=0
  for pid in "${BAIT_PIDS[@]}"; do kill "$pid" 2>/dev/null; done
  sleep 0.2
  for pid in "${BAIT_PIDS[@]}"; do kill -0 "$pid" 2>/dev/null && alive=1; done
  [[ -n "$TMPDIR_BAIT" ]] && rm -rf "$TMPDIR_BAIT"
  echo ""
  if (( alive )) || [[ -n "$TMPDIR_BAIT" && -e "$TMPDIR_BAIT" ]]; then
    echo "   ✋ residue SURVIVED — bait pids ${BAIT_PIDS[*]}, dir $TMPDIR_BAIT"
  else
    echo "   🧹 restored: bait gone, no residue"
  fi
}
trap cleanup EXIT

[[ -x "$REAPER" ]] || { echo "✋ no reaper at $REAPER — this play measures the real executable"; exit 1; }

TMPDIR_BAIT="$(mktemp -d "${TMPDIR:-/tmp}/prove.reaper.XXXXXX")"
cp "$(command -v sleep)" "$TMPDIR_BAIT/node"
REPORT="$TMPDIR_BAIT/reaped.log"

# the orphan: its spawner (the subshell) exits at once, so the kernel reparents it
( setsid "$TMPDIR_BAIT/node" 600 </dev/null &>/dev/null & echo "$!" > "$TMPDIR_BAIT/orphan.pid" )
ORPHAN="$(cat "$TMPDIR_BAIT/orphan.pid")"
BAIT_PIDS+=("$ORPHAN")

# the parented bait: a child of THIS shell, which stays alive
"$TMPDIR_BAIT/node" 600 & PARENTED="$!"
BAIT_PIDS+=("$PARENTED")
sleep 0.3

# the fixture must take, all of it (gotcha.a-check-that-cries-wolf-gets-silenced, q5)
for pid in "$ORPHAN" "$PARENTED"; do
  kill -0 "$pid" 2>/dev/null || { echo "💥 a bait did not start — this play measured no world"; exit 1; }
done
ORPHAN_PPID="$(awk '{print $4}' "/proc/$ORPHAN/stat")"
echo "🔭 does the reaper kill the abandoned, and only the abandoned?"
echo "   ├─ bait orphan   pid $ORPHAN, ppid $ORPHAN_PPID (reparented)"
echo "   ├─ bait parented pid $PARENTED, ppid $$ (this play)"

# .what = run the reaper; keep its output and exit code in globals (no subshell loss)
OUT=""; RC=""
reap() { OUT="$("$REAPER" --report "$REPORT" "$@" 2>&1)"; RC=$?; }
quote() { echo "   │     │ exit=$RC"; printf '%s\n' "$OUT" | head -10 | sed 's/^/   │     │ /'; }
found() { printf '%s\n' "$OUT" | grep -q "🪲 $1 "; }

# young: far above its age → spared
reap --mode plan --min-age 999999 --pid "$ORPHAN"
echo "   ├─ arm 'young'"
if [[ "$RC" -ne 0 ]]; then echo "   │  💥 reaper exit $RC — no verdict"; quote; FAILED=1
elif found "$ORPHAN"; then echo "   │  ✋ a young orphan was named for the kill"; quote; FAILED=1
else echo "   │  ✔ spared — under --min-age"; fi

# parented: spawner alive → spared
reap --mode plan --min-age 0 --pid "$PARENTED"
echo "   ├─ arm 'parented'"
if [[ "$RC" -ne 0 ]]; then echo "   │  💥 reaper exit $RC — no verdict"; quote; FAILED=1
elif found "$PARENTED"; then echo "   │  ✋ a process with a live parent was named for the kill"; quote; FAILED=1
else echo "   │  ✔ spared — its spawner lives"; fi

# control: abandoned + old enough → killed and logged
reap --mode apply --min-age 0 --pid "$ORPHAN"
sleep 0.3
echo "   └─ arm 'control'"
if ! found "$ORPHAN"; then
  echo "      ✋ the orphan was NOT named — the reaper cannot see abandonment"; quote; FAILED=1
elif kill -0 "$ORPHAN" 2>/dev/null; then
  echo "      ✋ the orphan was named and still lives"; quote; FAILED=1
elif ! grep -q "pid=$ORPHAN " "$REPORT" 2>/dev/null; then
  echo "      ✋ killed, and NO report line names it — a kill no reader can audit"; FAILED=1
else
  echo "      ✔ killed, and logged: $(grep "pid=$ORPHAN " "$REPORT" | cut -c1-120)"
fi

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 the reaper kills and logs the abandoned, and spares the young and the parented"
else
  echo "✋ the contract did NOT hold — read the arms above"
fi
exit "$FAILED"
