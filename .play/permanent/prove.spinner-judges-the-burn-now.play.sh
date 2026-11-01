#!/usr/bin/env bash
######################################################################
# .what = start one process that burns now and one that burned and went
#         quiet, then ask the SHIPPED spinner finder which it offers a kill
#
# .why  = the finder once judged on the lifetime ratio alone (cpu time /
#         elapsed), an average since birth. it cannot tell a process that
#         spins now from one that spun days ago and idles. measured
#         2026-10-21: the tmux server read `48% CPU over 14498m` while it drew
#         8% of a core, and the report offered it `kill -9`. the finder now
#         also samples /proc ticks over a live window; both clocks must clear
#
# .the arms — the old arm must go red, or this play is blind (term=bite)
#   control-burn       a busy loop, still on cpu   → 🦎, in the kill list
#   quiet-now          a 2s burst, then sleep      → 💤, NOT in the kill list
#   old-lifetime-only  the same quiet pid, judged by the finder at 9f9f2e0
#                      (before the window)         → in the kill list
#
# .it starts two scratch processes; a trap kills both
#
# usage:
#   rhx play.run --play prove.spinner-judges-the-burn-now
######################################################################
set -uo pipefail

REPO="${GROVE_SRC:-$PWD/src}"
FINDER="$REPO/machine/machine_resource_procs_find_spinner"
OLD_REV=9f9f2e0
FAILED=0
BURN=""
QUIET=""
OLD_FINDER="$(mktemp -t spinner-old.XXXXXX)"

cleanup() {
  [[ -n "$BURN" ]] && kill "$BURN" 2>/dev/null
  [[ -n "$QUIET" ]] && kill "$QUIET" 2>/dev/null
  rm -f "$OLD_FINDER"
  echo ""
  if { [[ -n "$BURN" ]] && kill -0 "$BURN" 2>/dev/null; } || { [[ -n "$QUIET" ]] && kill -0 "$QUIET" 2>/dev/null; }; then
    echo "   ✋ a scratch process SURVIVED"
  else
    echo "   🧹 restored: both scratch processes down"
  fi
}
trap cleanup EXIT

# refuse a subject we would have to invent
[[ -r "$FINDER" ]] || { echo "✋ no finder at $FINDER"; exit 1; }
git show "$OLD_REV:src/machine/machine_resource_procs_find_spinner" >"$OLD_FINDER" 2>/dev/null \
  || { echo "✋ cannot read the finder at $OLD_REV"; exit 1; }

# the two subjects
bash -c 'while :; do :; done' &
BURN=$!
bash -c 'end=$((SECONDS + 2)); while (( SECONDS < end )); do :; done; exec sleep 300' &
QUIET=$!

# let the burst end, so the quiet pid has a high lifetime ratio and no live burn
sleep 4

# one arm: run a finder, then read where a pid landed
#   verdict = kill (🦎 + kill list) | quiet (💤) | host | absent
verdict_of() {
  local out="$1" pid="$2"
  if printf '%s\n' "$out" | awk -v p="$pid" '/🪄 kill -9/ { for (i = 1; i <= NF; i++) if ($i == p) f = 1 } END { exit !f }'; then
    echo kill; return
  fi
  if printf '%s\n' "$out" | awk -v p="$pid" '$0 ~ "💤 " p " " { f = 1 } END { exit !f }'; then
    echo quiet; return
  fi
  echo absent
}

arm() {
  local name="$1" finder="$2" pid="$3" want="$4" out got
  out="$(bash "$finder" --min-minutes 0 --min-ratio 15 ${5:-} 2>&1)"
  got="$(verdict_of "$out" "$pid")"
  if [[ "$got" == "$want" ]]; then
    echo "   ├─ ✔ $name: pid $pid → $got"
  else
    echo "   ├─ ✋ $name: pid $pid → $got, expected $want"
    printf '%s\n' "$out" | awk '{ print "   │    " $0 }'
    FAILED=1
  fi
}

echo "🐢 does the spinner finder judge the burn now?"
echo ""
echo "🐚 prove.spinner-judges-the-burn-now"
arm control-burn      "$FINDER"     "$BURN"  kill  "--window 2"
arm quiet-now         "$FINDER"     "$QUIET" quiet "--window 2"
arm old-lifetime-only "$OLD_FINDER" "$QUIET" kill
if (( FAILED )); then
  echo "   └─ ✋ red"
  exit 1
fi
echo "   └─ ✔ green — a process quiet now is history, never a kill target"