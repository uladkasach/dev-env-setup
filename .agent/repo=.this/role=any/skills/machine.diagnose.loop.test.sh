#!/usr/bin/env bash
######################################################################
# .what = prove machine_resource_procs_find_loop alarms on a loop fleet, and
#         stays quiet on a calm desktop, a burst, and a stale or absent log
#
# .why  = an alarm that cries wolf gets muted, and one that sleeps through a
#         storm is worse than none. each case below is one of those two ways
#         to fail. the loop case replays the 2026-11-06 storm: 599 forks/sec
#         for three minutes, 145 identical `while true; ssh; sleep 5` parents
#
# usage:
#   rhx machine.diagnose.loop.test
#
# guarantee:
#   - hermetic: fixtures in a fresh mktemp dir; /proc is never read
#   - exit 0 = every case held · 1 = a case failed (each named)
######################################################################
set -u

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo|--role|--skill) shift 2 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
FIND="$ROOT/src/machine/machine_resource_procs_find_loop"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
NOW=2000000000
failed=0

# .what = write N minute rows to a usage log at a given forks/sec
__log_rows() {
  local file="$1" rate="$2" count="$3" newest="$4" i
  for ((i = count - 1; i >= 0; i--)); do
    printf 'B\t%d\t60\t4.0\t8000\t0\t%d\t9000\t30.0\t1.00\t0.00\n' "$((newest - i * 60))" "$((rate * 60))" >> "$file"
  done
}

# .what = assert the output holds (or lacks) a fragment
__expect() {
  local case_name="$1" out="$2" want="$3" mode="${4:-has}"
  if [[ "$mode" == has && "$out" != *"$want"* ]] || [[ "$mode" == lacks && "$out" == *"$want"* ]]; then
    echo "   ✋ $case_name — expected output to $mode: $want"
    printf '%s\n' "$out" | sed 's/^/      │ /'
    failed=1
    return
  fi
  echo "   ✔ $case_name — $mode: $want"
}

######################################################################
# the 2026-11-06 fleet: 145 kitty tabs, each a zsh loop that spawns ssh, then sleep
######################################################################
LOOP_ARGS='zsh -c while true; do if ssh -t grove-x "tmux attach-session -t crew/role"; then exit 0; fi; printf "duct lost"; sleep 5; done'
{
  for ((p = 0; p < 145; p++)); do
    printf '1\t%d\t%d\tkitty --class crew.%d\n' "$((9000 + p))" 2000 "$p"
    printf '1\t%d\t%d\t%s\n' "$((10000 + p))" "$((9000 + p))" "$LOOP_ARGS"
  done
  for ((s = 2; s <= 4; s++)); do
    for ((p = 0; p < 145; p++)); do
      printf '%d\t%d\t%d\tkitty --class crew.%d\n' "$s" "$((9000 + p))" 2000 "$p"
      printf '%d\t%d\t%d\t%s\n' "$s" "$((10000 + p))" "$((9000 + p))" "$LOOP_ARGS"
      printf '%d\t%d\t%d\tssh -t grove-x tmux attach-session -t crew/role\n' "$s" "$((20000 + s * 1000 + p))" "$((10000 + p))"
      printf '%d\t%d\t%d\t/usr/bin/sleep 5\n' "$s" "$((40000 + s * 1000 + p))" "$((10000 + p))"
    done
  done
} > "$WORK/sweeps.fleet"

# a calm desktop: one shell that spawned one git, once
{
  printf '1\t500\t400\tzsh\n'
  printf '2\t500\t400\tzsh\n'
  printf '2\t501\t500\tgit status\n'
} > "$WORK/sweeps.calm"

echo "🐈 heres the loop alarm, case by case..."

# case 1 — the storm: three minutes at 599/sec, the fleet in the sweeps
__log_rows "$WORK/log.storm" 599 5 "$NOW"
out="$("$FIND" --gate --log "$WORK/log.storm" --now "$NOW" --sweeps-from "$WORK/sweeps.fleet" --rate 599)"
__expect "storm alarms" "$out" "🌀 loop — 599 forks/sec now, and ≥599/sec for 3 straight minutes"
__expect "storm names the fleet" "$out" "145 zsh parents · each spawns {sleep,ssh}"
__expect "storm says fleet" "$out" "145 parents run ONE shape"
__expect "storm shows the loop argv" "$out" "e.g.  zsh -c while true; do if ssh"
__expect "storm shows who launched it" "$out" "under kitty --class crew."
__expect "storm never kills" "$out" "named, never killed"

# case 2 — a quiet desktop: 10/sec for an hour
__log_rows "$WORK/log.quiet" 10 60 "$NOW"
out="$("$FIND" --gate --log "$WORK/log.quiet" --now "$NOW" --sweeps-from "$WORK/sweeps.calm" --rate 10)"
__expect "quiet desktop stays quiet" "$out" "🌴 quiet — the slowest of the last 3 minutes ran 10 forks/sec"
__expect "quiet desktop does not alarm" "$out" "🌀" lacks

# case 3 — a burst: an npm install at 400/sec for two minutes, then calm
__log_rows "$WORK/log.burst" 10 10 "$((NOW - 180))"
__log_rows "$WORK/log.burst" 400 2 "$((NOW - 60))"
__log_rows "$WORK/log.burst" 12 1 "$NOW"
out="$("$FIND" --gate --log "$WORK/log.burst" --now "$NOW" --sweeps-from "$WORK/sweeps.fleet" --rate 400)"
__expect "a two-minute burst stays quiet" "$out" "🌴 quiet"

# case 4 — a past storm: the log stops 20 minutes ago at 599/sec
__log_rows "$WORK/log.stale" 599 5 "$((NOW - 1200))"
out="$("$FIND" --gate --log "$WORK/log.stale" --now "$NOW" --sweeps-from "$WORK/sweeps.fleet")"
__expect "a stale storm stays quiet" "$out" "🌴 quiet — the newest usage row is 1200s old"

# case 5 — no log at all: the record timer does not run here
out="$("$FIND" --gate --log "$WORK/absent.tsv" --now "$NOW" --sweeps-from "$WORK/sweeps.fleet")"
__expect "an absent log stays quiet" "$out" "🌴 quiet — the usage log holds under 3 minute rows"

# case 6 — one recursive run: a bash walk whose `$(…)` subshells nest 30 deep,
#          and each one forks a `timeout`. it is ONE parent, never a fleet of 30
{
  printf '1\t700\t600\tzsh\n'
  printf '1\t701\t700\tbash walk.sh --tree x\n'
  for ((s = 2; s <= 3; s++)); do
    printf '%d\t700\t600\tzsh\n' "$s"
    printf '%d\t701\t700\tbash walk.sh --tree x\n' "$s"
    for ((d = 1; d <= 30; d++)); do
      up=$((800 + d - 1)); [[ $d -eq 1 ]] && up=701
      printf '%d\t%d\t%d\tbash walk.sh --tree x\n' "$s" "$((800 + d))" "$up"
      printf '%d\t%d\t%d\ttimeout 5 git ls-tree\n' "$s" "$((3000 + s * 100 + d))" "$((800 + d))"
    done
  done
} > "$WORK/sweeps.recurse"
out="$("$FIND" --sweeps-from "$WORK/sweeps.recurse" --rate 300)"
__expect "a recursive run folds into one parent" "$out" "60 births · 1 bash parent · each spawns {timeout}"
__expect "a recursive run is not called a fleet" "$out" "ONE shape" lacks

# case 7 — no gate, calm sweeps: the fingerprint still reads, verdict quiet
out="$("$FIND" --sweeps-from "$WORK/sweeps.calm" --rate 8)"
__expect "an ungated calm sample reads quiet" "$out" "🌴 quiet — 8 forks/sec"
__expect "an ungated calm sample names its one shape" "$out" "1 births · 1 zsh parent · each spawns {git}"

echo ""
if [[ $failed -ne 0 ]]; then
  echo "🐈 bummer — a case failed above"
  exit 1
fi
echo "🐈 every case held"
