#!/usr/bin/env bash
######################################################################
# prove.earlyoom-spares-the-session — under memory pressure, earlyoom must
# pick a leaked runtime, never the session's own daemons
#
# .what = runs the REAL earlyoom binary in --dryrun against two bait processes,
#         with its thresholds pinned so it decides at once, and reads which
#         process it WOULD kill:
#           bait "systemd" — oom_score_adj 900, the shape that won on 2026-10-07
#           bait "node"    — oom_score_adj 700, a stand-in for a leaked runtime
#         the 200 gap is the real one (session daemon 200, orphan 0); see below
#
# .why  = on 2026-10-07 earlyoom, at its package default, SIGTERMed the session
#         bus and then systemd --user itself, because systemd raises the score
#         of every small session daemon (gotcha.earlyoom-kills-the-session-not-the-hog).
#         the repair is the --avoid/--prefer policy in
#         `src/grove.provision/1.system/1.6.procs/1.6.3.earlyoom/earlyoom.default`
#
# .the arms
#   control      the declared policy, split the way systemd splits it
#                → the victim matches --prefer, and is never "systemd"
#   old-default  `-r 3600`, the package default
#                → the victim IS the "systemd" bait. if it is not, this play
#                  cannot see the defect, and control's green proves naught
#
# .the write — `rule.forbid.repair-plays` exception 2. the break is two bait
#   processes in a temp dir; a trap kills them and removes the dir. --dryrun
#   means earlyoom sends no signal to any process
#
# ⚠️ .what it does NOT prove
#   - that the LIVE daemon runs this policy — `1.6.3.earlyoom.configure.verify`
#     reads the daemon's own argv for that
#   - kills of root-owned processes: an unprivileged earlyoom may see them and
#     cannot signal them; --dryrun signals none either way
#
# usage:
#   rhx play.run --play prove.earlyoom-spares-the-session
######################################################################
set -uo pipefail

REPO="${GROVE_SRC:-$PWD/src}"
POLICY="$REPO/grove.provision/1.system/1.6.procs/1.6.3.earlyoom/earlyoom.default"
TMPDIR_BAIT=""
BAIT_PIDS=()
FAILED=0

cleanup() {
  local pid
  for pid in "${BAIT_PIDS[@]}"; do kill "$pid" 2>/dev/null; done
  [[ -n "$TMPDIR_BAIT" ]] && rm -rf "$TMPDIR_BAIT"
  echo ""
  local alive=0
  for pid in "${BAIT_PIDS[@]}"; do kill -0 "$pid" 2>/dev/null && alive=1; done
  if (( alive )) || [[ -n "$TMPDIR_BAIT" && -e "$TMPDIR_BAIT" ]]; then
    echo "   ✋ residue SURVIVED — bait pids ${BAIT_PIDS[*]}, dir $TMPDIR_BAIT"
  else
    echo "   🧹 restored: bait gone, no residue"
  fi
}
trap cleanup EXIT

# refuse a subject we would have to invent
command -v earlyoom >/dev/null || { echo "✋ no earlyoom on PATH — this play measures the real binary"; exit 1; }
[[ -r "$POLICY" ]] || { echo "✋ no declared policy at $POLICY"; exit 1; }
EARLYOOM_BIN="$(command -v earlyoom)"

# the bait: copies of sleep, so each process's comm IS its file name
TMPDIR_BAIT="$(mktemp -d "${TMPDIR:-/tmp}/prove.earlyoom.XXXXXX")"
cp "$(command -v sleep)" "$TMPDIR_BAIT/systemd"
cp "$(command -v sleep)" "$TMPDIR_BAIT/node"
"$TMPDIR_BAIT/systemd" 600 & BAIT_PIDS+=("$!")
"$TMPDIR_BAIT/node" 600 &    BAIT_PIDS+=("$!")
sleep 0.2
# the GAP between the two baits mirrors the real one: systemd's user manager
# gives its daemons oom_score_adj 200, and a leaked node runtime carries 0. both
# are lifted by 700 so the pair outranks every real process on the box, and
# earlyoom's single pick is always one of the two.
#
# ⚠️ .why not adj 1000 on the systemd bait
#   --avoid / --prefer are WEIGHTS of ±300 on the score, never exclusions. a
#   bait at the max score outranks any weight, so it measures a world no real
#   session daemon lives in (measured: control picked it at 1333 vs 966)
#
# an unprivileged process may RAISE its own score, never lower it
echo 900 > "/proc/${BAIT_PIDS[0]}/oom_score_adj" || { echo "✋ could not raise the systemd bait's oom_score_adj"; exit 1; }
echo 700 > "/proc/${BAIT_PIDS[1]}/oom_score_adj" || { echo "✋ could not raise the node bait's oom_score_adj"; exit 1; }

# the fixture must take, all of it (gotcha.a-check-that-cries-wolf-gets-silenced, q5)
for pid in "${BAIT_PIDS[@]}"; do
  kill -0 "$pid" 2>/dev/null || { echo "💥 a bait process did not start — this play measured no world"; exit 1; }
done
echo "🔭 does earlyoom pick a leaked runtime over the session's own daemons?"
echo "   ├─ bait systemd pid ${BAIT_PIDS[0]}, oom_score $(cat "/proc/${BAIT_PIDS[0]}/oom_score")"
echo "   ├─ bait node    pid ${BAIT_PIDS[1]}, oom_score $(cat "/proc/${BAIT_PIDS[1]}/oom_score")"

# .what = run earlyoom --dryrun with the given args; print the comm it would kill
# .why  = -m/-s at 99 (earlyoom's cap: "value 100 exceeds limit 99") put it
#         below threshold on its first poll, so it decides
#         at once; a timeout bounds the call (hazard.a-clamp-for-a-hang-needs-a-timeout)
LAST_RAW=""
victim_of() {
  # ⚠️ stdbuf: off a tty earlyoom buffers its output, and the timeout's kill
  #    discards the buffer — so an unbuffered run is what makes any line arrive
  LAST_RAW="$(timeout 8 stdbuf -oL -eL "$EARLYOOM_BIN" --dryrun -m 99,99 -s 99,99 "$@" 2>&1)"
  LAST_RC=$?
  VICTIM="$(printf '%s\n' "$LAST_RAW" | grep -oP 'process [0-9]+ uid [0-9]+ "\K[^"]+' | head -1)"
}
# ⚠️ results ride in globals, never `$(victim_of …)` — a command substitution is
#    a subshell, and the raw output it records would never reach quote_raw
LAST_RC=""
VICTIM=""

# .what = quote what earlyoom said, when an arm reads no victim
# .why  = an empty read has two causes — it said none, or it said it in a shape
#         this parse misses — and only its own words part the two (q14)
quote_raw() {
  echo "   │     │ exit=$LAST_RC bin=$EARLYOOM_BIN version=$("$EARLYOOM_BIN" -v 2>&1 | head -1)"
  printf '%s\n' "$LAST_RAW" | head -12 | sed 's/^/   │     │ /'
}

# control: the declared policy, split exactly as systemd splits $EARLYOOM_ARGS
# shellcheck disable=SC1090
EARLYOOM_ARGS=""; source "$POLICY"
# shellcheck disable=SC2086
read -r -a POLICY_ARGV <<< "$EARLYOOM_ARGS"
victim_of "${POLICY_ARGV[@]}"; saw="$VICTIM"
echo "   ├─ arm 'control'"
if [[ -z "$saw" ]]; then
  echo "   │  💥 earlyoom named no victim — this arm rendered NO verdict"; quote_raw; FAILED=1
elif [[ "$saw" == "systemd" ]]; then
  echo "   │  ✋ victim=$saw — the declared policy still kills the session manager"; FAILED=1
elif [[ "$saw" =~ ^(node|claude|claude.exe|bun|jest)$ ]]; then
  echo "   │  ✔ victim=$saw — a --prefer name, and the systemd bait was spared"
else
  echo "   │  ✋ victim=$saw — neither the bait nor a --prefer name; --prefer did not steer"; FAILED=1
fi

# old-default: the package args, which must reproduce the 2026-10-07 defect
victim_of -r 3600; saw="$VICTIM"
echo "   └─ arm 'old-default'"
if [[ "$saw" == "systemd" ]]; then
  echo "      ✔ victim=$saw — the old args kill the session manager, so this play bites"
else
  echo "      ✋ victim=${saw:-none} — the old args did not pick the bait, so control's green proves naught"; quote_raw; FAILED=1
fi

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 earlyoom spares the session, and the clamp is seen to bite"
else
  echo "✋ the contract did NOT hold — read the arms above"
fi
exit "$FAILED"
