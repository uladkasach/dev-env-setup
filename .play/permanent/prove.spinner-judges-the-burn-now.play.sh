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
#   old-lifetime-only  the quiet pid, judged by the finder at f10eb78
#                      (before the window)         → in the kill list
#   control-burn       a busy loop, still on cpu   → 🦎, in the kill list
#   quiet-now          a 4s cpu burst, then sleep  → 💤, NOT in the kill list
#
# .it starts two scratch processes; a trap kills both
#
# usage:
#   rhx play.run --play prove.spinner-judges-the-burn-now
######################################################################
set -uo pipefail

REPO="${GROVE_SRC:-$PWD/src}"
FINDER="$REPO/machine/machine_resource_procs_find_spinner"
# the last finder on main that judged by the lifetime ratio alone (#166); #168 added the window
# ⚠️ a pin must name a commit ON MAIN. the first pin, 9f9f2e0, was a branch commit that the
#    squash merge of #168 erased, so the old arm could not run on any clone
OLD_REV=f10eb782d5003bf88c98e3943cd9545d4cac483c
FAILED=0
BURN=""
QUIET=""
OLD_FINDER="$(mktemp -t spinner-old.XXXXXX)"

cleanup() {
  [[ -n "$BURN" ]] && kill "$BURN" 2>/dev/null
  [[ -n "$QUIET" ]] && kill "$QUIET" 2>/dev/null
  # a signal is async: reap both before the check, or a pid mid-exit reads as a survivor
  #   (📜 2026-11-17: "a scratch process SURVIVED" printed once on a loaded box)
  [[ -n "$BURN" ]] && wait "$BURN" 2>/dev/null
  [[ -n "$QUIET" ]] && wait "$QUIET" 2>/dev/null
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
# the burst burns a fixed CPU budget (4s of its own utime+stime), never a wall span
#   ⚠️ the lifetime ratio is cpu / elapsed, and the finder reads cpu in WHOLE seconds.
#     a wall-clock burst on a loaded box (a full play.run, plus BURN on a peer core)
#     got 1–2s of cpu, so by the third arm the ratio read under the 15% gate and the
#     quiet pid went absent — a clock race, not a finder verdict. 📜 measured
#     2026-11-17: green alone, red twice inside `play.run --all`
bash -c 'hz=$(getconf CLK_TCK); while :; do for _ in {1..20000}; do :; done; read -r -a s < /proc/$$/stat; (( s[13] + s[14] >= 4 * hz )) && break; done; exec sleep 300' &
QUIET=$!

# wait for the burst to END, by state: the exec makes the pid's comm `sleep`
#   bounded at 60s, so a starved box fails loud rather than hang
for _ in $(seq 1 600); do
  [[ "$(cat "/proc/$QUIET/comm" 2>/dev/null)" == sleep ]] && break
  sleep 0.1
done
[[ "$(cat "/proc/$QUIET/comm" 2>/dev/null)" == sleep ]] \
  || { echo "💥 the quiet pid never finished its 4s cpu burst within 60s — this play measured no world"; exit 1; }

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
  # --min-ratio 5: the gate is this play's input, not its subject. at 5% the 4s
  #   burn stays a candidate for 80s of elapsed, a margin no loaded box spends
  out="$(bash "$finder" --min-minutes 0 --min-ratio 5 ${5:-} 2>&1)"
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
arm old-lifetime-only "$OLD_FINDER" "$QUIET" kill
arm control-burn      "$FINDER"     "$BURN"  kill  "--window 2"
arm quiet-now         "$FINDER"     "$QUIET" quiet "--window 2"
if (( FAILED )); then
  echo "   └─ ✋ red"
  exit 1
fi
echo "   └─ ✔ green — a process quiet now is history, never a kill target"