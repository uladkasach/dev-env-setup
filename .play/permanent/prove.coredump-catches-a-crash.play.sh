#!/usr/bin/env bash
######################################################################
# prove.coredump-catches-a-crash — a real segfault on this box leaves a core
# that `coredumpctl` can show
#
# .why this play exists
#   - `1.6.8.coredump`'s verify reads `core_pattern`, which proves where the
#     kernel SENDS a core, never that one lands. a verify stays read-only, so
#     the crash itself lives here (vision row 21)
#   - a grove's tmux segfaulted ~110 times and left no core; this is the probe
#     that would have caught that box
#
# .the arm
#   - a copy of `sleep`, named for this play, gets SIGSEGV; within 30s a
#     coredumpctl entry must name its pid
#
# .the write — `rule.forbid.repair-plays` exception 2: one bait process and a
#   temp dir. the core it leaves is a sleep's, a few kilobytes, and systemd
#   ages it out by its own policy
#
# usage:
#   rhx play.run --play prove.coredump-catches-a-crash
#
# exit:
#   0 = a core landed for the bait
#   1 = no core landed
#   2 = no coredumpctl on this box, or the bait never ran, so no claim was graded
######################################################################
set -uo pipefail

TMPDIR_BAIT=""
cleanup() { [[ -n "$TMPDIR_BAIT" ]] && rm -rf "$TMPDIR_BAIT"; }
trap cleanup EXIT

command -v coredumpctl >/dev/null 2>&1 || {
  echo "✋ ConstraintError: no coredumpctl — systemd-coredump is absent" >&2
  echo "   fix: sudo -v && rhx grove.provision --what 1.6.8.coredump --mode apply" >&2
  exit 2
}

TMPDIR_BAIT="$(mktemp -d "${TMPDIR:-/tmp}/prove.coredump.XXXXXX")"
BAIT="$TMPDIR_BAIT/prove-coredump-bait"
cp "$(command -v sleep)" "$BAIT"

# the limit is lifted for the bait alone, so the collector stores the core
( ulimit -c unlimited; exec "$BAIT" 600 ) &
PID="$!"
# the signal must meet the BAIT, not the subshell before its exec — polled, never one fixed sleep
for _ in $(seq 1 20); do
  [[ "$(readlink "/proc/$PID/exe" 2>/dev/null)" == "$BAIT" ]] && break
  sleep 0.25
done
[[ "$(readlink "/proc/$PID/exe" 2>/dev/null)" == "$BAIT" ]] \
  || { echo "✋ ConstraintError: the bait did not exec within 5s — this play measured no world" >&2; exit 2; }

echo "🔭 does a segfault on this box leave a core?"
echo "   ├─ bait pid $PID"
kill -SEGV "$PID"
wait "$PID" 2>/dev/null

hit=""
# the collector writes after the kernel hands it the core; on a loaded box that
# can trail the signal, so the window is generous and ends at the first hit
for _ in $(seq 1 30); do
  hit="$(timeout -k 2 5 coredumpctl list --no-pager --no-legend "COREDUMP_PID=$PID" </dev/null 2>/dev/null)"
  [[ -n "$hit" ]] && break
  sleep 1
done

if [[ -n "$hit" ]]; then
  echo "   └─ ✔ coredumpctl holds it: $(printf '%s' "$hit" | head -1 | tr -s ' ' | cut -c1-120)"
  exit 0
fi
echo "   └─ 💥 MalfunctionError: no core landed for pid $PID within 30s" >&2
echo "      read why: cat /proc/sys/kernel/core_pattern ; journalctl -u systemd-coredump -n 20" >&2
exit 1
