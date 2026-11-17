#!/usr/bin/env bash
######################################################################
# .what = count the top-level dirs in /tmp, grouped by name shape
#
# .why  = a /tmp with tens of thousands of dirs taxes every path lookup
#         and holds kernel dir cache that no process is charged for.
#         tmp.fixture.prune only clears KNOWN fixture shapes; this names
#         the unknown ones, so a new leaker is found by its shape and
#         its age, then either taught to clean up or added to the prune
#
# usage:
#   rhx tmp.dirs.census              # top 15 shapes
#   rhx tmp.dirs.census --top 30
#
# guarantee:
#   - read-only: lists and counts, never removes
#   - a shape = the dir name with every digit run and every 6+ char
#     hex/alnum random run folded to '#', so one harness = one row
#   - each row: count, the newest age, the oldest age, one example
#   - exit 0 = answered · 2 = bad input
######################################################################
set -uo pipefail

top=15
while [[ $# -gt 0 ]]; do
  case "$1" in
    --top) top="${2:-}"; shift 2 ;;
    # absorb harness-injected args; `rhx <skill>` prepends --repo/--role/--skill
    --repo|--role|--skill) shift 2 ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg '$1'" >&2; exit 2 ;;
  esac
done
[[ "$top" =~ ^[0-9]+$ ]] || { echo "✋ ConstraintError: --top is a number" >&2; exit 2; }

now="$(date +%s)"

# one find pass: mtime + name of each top-level dir; one awk pass folds and tallies
rows="$(find /tmp -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' 2>/dev/null | awk -v now="$now" '
  {
    t = int($1); name = substr($0, index($0, " ") + 1)
    shape = name
    gsub(/[0-9a-fA-F]{6,}/, "#", shape)       # hex / hash runs
    gsub(/[A-Za-z0-9]{6}$/, "#", shape)       # mkdtemp XXXXXX tails
    gsub(/[0-9]+/, "#", shape)                # any digit run
    gsub(/#([-_.T:Z]*#)+/, "#", shape)        # collapse adjacent folds
    n[shape]++
    if (!(shape in newest) || t > newest[shape]) newest[shape] = t
    if (!(shape in oldest) || t < oldest[shape]) oldest[shape] = t
    if (!(shape in ex)) ex[shape] = name
    total++
  }
  function age(s) {
    s = now - s
    if (s < 3600) return int(s / 60) "m"
    if (s < 86400) return int(s / 3600) "h"
    return int(s / 86400) "d"
  }
  END {
    printf "TOTAL\t%d\n", total
    for (s in n) printf "%d\t%s\t%s\t%s\t%s\n", n[s], age(newest[s]), age(oldest[s]), s, ex[s]
  }')"

total="$(printf '%s\n' "$rows" | awk -F'\t' '$1 == "TOTAL" { print $2 }')"

echo "🐢 lets see who fills /tmp..."
echo ""
echo "🐚 tmp.dirs.census --top $top"
echo "   ├─ top-level dirs: ${total:-0}"
echo "   └─ shapes, by count  (newest / oldest age · one example)"
echo "      ├─"
echo "      │"
printf '%s\n' "$rows" | awk -F'\t' '$1 != "TOTAL"' | sort -t$'\t' -k1,1nr | head -n "$top" \
  | while IFS=$'\t' read -r count newest oldest shape example; do
      printf '      │  %7s  %5s / %-5s  %s\n' "$count" "$newest" "$oldest" "$shape"
      printf '      │  %7s  %13s  e.g. %s\n' "" "" "$example"
    done
echo "      │"
echo "      └─"
echo ""
echo "🥥 a shape whose NEWEST age is minutes still leaks now; its name says who"
