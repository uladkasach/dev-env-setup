#!/usr/bin/env bash
######################################################################
# .what = review the nvim error log, ranked by how often each error hit
#
# .why  = init.lua streams every error nvim throws into one durable log.
#         this reads it back the way a fix wants to be prioritized:
#         loudest first, with the file that threw it and when it last hit.
#         raw tail is for the freshest incident; the rank is for the
#         repeat flake worth a repair.
#
# usage:
#   nvim.errors.review.sh                    # top 15 by hit count
#   nvim.errors.review.sh --top 40           # widen the rank
#   nvim.errors.review.sh --since 7d         # only the last 7 days
#   nvim.errors.review.sh --tail 30          # raw last 30 lines, newest last
#   nvim.errors.review.sh --grep neominimap  # filter to one culprit
#   nvim.errors.review.sh --all              # include the rotated errors.log.1
#   nvim.errors.review.sh --help
#
# guarantee:
#   - read-only; never mutates the log
#   - exit 0 = read ok (even when clean), 2 = no log yet / bad input
######################################################################

set -euo pipefail

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
LOG_PATH="$LOG_DIR/errors.log"

TOP=15
TAIL=0
SINCE=""
GREP=""
INCLUDE_ROTATED=0

print_help() {
  # the header block: every comment line between the two ##### fences
  awk 'NR > 2 && /^#####/ { exit } NR > 2 { sub(/^# ?/, ""); print }' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --top)   TOP="${2:?--top needs a number}"; shift 2 ;;
    --tail)  TAIL="${2:?--tail needs a number}"; shift 2 ;;
    --since) SINCE="${2:?--since needs a duration, e.g. 7d}"; shift 2 ;;
    --grep)  GREP="${2:?--grep needs a pattern}"; shift 2 ;;
    --all)   INCLUDE_ROTATED=1; shift ;;
    --help|-h) print_help; exit 0 ;;
    --repo|--role|--skill) shift 2 ;;   # absorb rhachet injection
    *) echo "✋ unknown arg: $1 — see --help" >&2; exit 2 ;;
  esac
done

# an absent log is the healthy state — the scribe only creates it on the
# first error. it is NOT a constraint, so it must not read as blocked.
if [[ ! -f "$LOG_PATH" ]]; then
  echo "🐢 shell yeah — clean"
  echo ""
  echo "🔭 nvim.errors.review"
  echo "   ├─ log: $LOG_PATH"
  echo "   └─ absent — no error on record yet"
  echo "      (if that reads too good to be true, confirm the scribe is"
  echo "       live: rhx grove.provision --what 4.5.nvim --mode apply,"
  echo "       then reopen nvim)"
  exit 0
fi

# assemble the source lines (newest log last, so tail reads chronologically)
collect() {
  if [[ $INCLUDE_ROTATED -eq 1 && -f "$LOG_PATH.1" ]]; then
    cat "$LOG_PATH.1" "$LOG_PATH"
  else
    cat "$LOG_PATH"
  fi
}

# apply --since / --grep filters
filter() {
  local cutoff=""
  if [[ -n "$SINCE" ]]; then
    if [[ ! "$SINCE" =~ ^([0-9]+)([dhm])$ ]]; then
      echo "✋ --since wants <n>d|<n>h|<n>m, got: $SINCE" >&2
      exit 2
    fi
    cutoff=$(date -d "-${BASH_REMATCH[1]} $(case "${BASH_REMATCH[2]}" in
      d) echo days ;; h) echo hours ;; m) echo minutes ;; esac)" +%Y-%m-%dT%H:%M:%S)
  fi
  awk -v cutoff="$cutoff" -v pat="$GREP" '
    cutoff != "" && $1 < cutoff { next }
    pat != "" && index($0, pat) == 0 { next }
    { print }
  '
}

TOTAL=$(collect | filter | wc -l)

if [[ "$TAIL" -gt 0 ]]; then
  echo "🐢 heres the wave"
  echo ""
  echo "🔭 nvim.errors.review --tail $TAIL${SINCE:+ --since $SINCE}${GREP:+ --grep $GREP}"
  echo "   ├─ log: $LOG_PATH"
  echo "   ├─ lines: $TOTAL"
  echo "   └─ tail (newest last)"
  echo "      │"
  collect | filter | tail -n "$TAIL" | sed 's/^/      │  /'
  echo "      └─"
  exit 0
fi

if [[ "$TOTAL" -eq 0 ]]; then
  echo "🐢 shell yeah — clean"
  echo ""
  echo "🔭 nvim.errors.review${SINCE:+ --since $SINCE}${GREP:+ --grep $GREP}"
  echo "   ├─ log: $LOG_PATH"
  echo "   └─ 0 errors in scope"
  exit 0
fi

echo "🐢 heres the wave"
echo ""
echo "🔭 nvim.errors.review --top $TOP${SINCE:+ --since $SINCE}${GREP:+ --grep $GREP}"
echo "   ├─ log: $LOG_PATH"
echo "   ├─ lines: $TOTAL"
echo "   └─ ranked by hits"
echo "      │"

# each line is: <ts> pid=N src=S n=COUNT cwd=P | <msg>
# n= is a per-pid cumulative count, so the true total per signature is the
# sum of each pid's high-water mark — not a sum of every line's n=.
collect | filter | awk -F' \\| ' '
  {
    head = $1; msg = $2
    for (i = 3; i <= NF; i++) msg = msg " | " $i
    ts = head; sub(/ .*/, "", ts)
    pid = head; sub(/.*pid=/, "", pid); sub(/ .*/, "", pid)
    n = head;   sub(/.*n=/, "", n);     sub(/ .*/, "", n)

    sig = msg
    gsub(/[0-9]+/, "#", sig)
    gsub(/  +/, " ", sig)
    sig = substr(sig, 1, 240)

    key = pid SUBSEP sig
    if (n + 0 > peak[key]) peak[key] = n + 0
    if (!(key in known)) { known[key] = 1; sigs[sig] = 1 }
    if (ts > last[sig]) last[sig] = ts
    if (!(sig in sample) || length(msg) > length(sample[sig])) sample[sig] = msg
  }
  END {
    for (key in peak) {
      split(key, parts, SUBSEP)
      total[parts[2]] += peak[key]
      sessions[parts[2]] += 1
    }
    for (sig in sigs)
      printf "%d\t%d\t%s\t%s\n", total[sig], sessions[sig], last[sig], sample[sig]
  }
' | sort -rn | head -n "$TOP" | awk -F'\t' '
  {
    printf "      ├─ %-6s hits  %-3s sessions  last %s\n", $1, $2, $3
    msg = $4
    if (length(msg) > 150) msg = substr(msg, 1, 150) "…"
    printf "      │     %s\n", msg
    printf "      │\n"
  }
'
echo "      └─ tip: --grep <plugin> to isolate, --tail 30 for raw context"
