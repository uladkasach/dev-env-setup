#!/usr/bin/env bash
######################################################################
# .what = report the comment burden of every bundle file, and refuse the
#         ones that carry more prose than a reader will ever spend
#
# 🛑 .why a MEASURE and not an adjective
#   - "be terse" is not actionable, and four agents proved it
#   - 📜 measured 2026-09-03: a densify pass over 67 files returned
#     1342 insertions against 1441 deletions — a 0.93 ratio
#   - every deleted paragraph came back as a shorter paragraph
#   - the reader's cost fell ~7% and the diff cost was 100%
#   - an actor told to hit a NUMBER cuts; an actor told to be terse rewrites
#
# 📜 the baseline this gate was calibrated against, 2026-09-03:
#   - 24908 lines across the bundle tree
#   - 14735 of them comment — 59%
#   - the four worst files: 970, 809, 549, 486 lines
#
# .why the bar is BOTH a ratio and a line cap, never one alone
#   - a ratio alone lets a 900-line file pass by growth of its code
#   - a cap alone lets a 40-line file be 90% comment
#   - a header earns its keep by what it explains, so both bound it
#
# guarantee:
#   - READ-ONLY. it counts lines; it writes no file
######################################################################

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$HERE" || exit 1

####################################################################
# .the bar — TWO bars, because a dispatcher and a phase differ in kind
#
# 🛑 a ratio bar applied to an `_.sh` is NOISE, and noise gets silenced
#   - an `_.sh` is ~5 lines of `bundle.upgrade` by design
#   - so ANY header at all puts it over 55%, on every box, forever
#   - a check that reddens on correct code trains a reader to skim it
#   - (gotcha.a-check-that-cries-wolf-gets-silenced)
#
# ⇒ so a dispatcher is bounded by its header's ABSOLUTE size, which is
#   the fact that actually matters there: 40 lines to say what a bundle
#   is, why its children run in that order, and what it pins
####################################################################
RATIO_MAX=55      # a phase file: how much of it may be prose
LINES_MAX=250     # a phase file: how long it may be, full stop
DISPATCH_MAX=40   # an `_.sh`: how many comment lines it may carry

total=0
comment=0
overs=0
files=0

echo "🌲 prove.headers-carry-their-weight"
echo "   bar: a phase ≤ ${RATIO_MAX}% comment and ≤ ${LINES_MAX} lines"
echo "        an _.sh ≤ ${DISPATCH_MAX} comment lines"
echo ""

####################################################################
# .why `find`, not a hand-written list
#
# 🛑 a hand-written subject list is blind to whatever the tree grows next
#   - the tree IS the inventory (rule.require.bundle-as-sole-declaration)
#   - a play that names its own subjects holds a second, unaudited one
#   - measured 2026-08-13: prove.sha256-pins-bite held 6 of 8 subjects
####################################################################
while IFS= read -r f; do
  files=$((files + 1))

  n="$(grep -c '' "$f")"
  c="$(grep -c '^[[:space:]]*#' "$f")"
  total=$((total + n))
  comment=$((comment + c))

  [[ "$n" -eq 0 ]] && continue

  ##################################################################
  # 🛑 the discriminator is the CODE, never the filename
  #   - an `_.sh` is not always a dispatcher
  #   - six of them hold SHARED OPERATIONS their phases call
  #   - those carry real code, so the absolute cap misjudges them
  #   - a dispatcher declares exactly ONE function: its own entrypoint
  #   - ⇒ count the declarations, and let the file say which it is
  ##################################################################
  fns="$(grep -cE '^[a-z_0-9]+\(\) *\{' "$f")"

  over=""
  if [[ "$(basename "$f")" == "_.sh" && "$fns" -le 1 ]]; then
    # a dispatcher — bounded by its header's absolute size, never its ratio
    [[ "$c" -gt "$DISPATCH_MAX" ]] && over="${c} comment lines"
  else
    pct=$(( c * 100 / n ))
    [[ "$pct" -gt "$RATIO_MAX" ]] && over="${pct}% comment"
    if [[ "$n" -gt "$LINES_MAX" ]]; then
      [[ -n "$over" ]] && over="$over, "
      over="${over}${n} lines"
    fi
  fi

  if [[ -n "$over" ]]; then
    overs=$((overs + 1))
    printf '   ✋ %-72s %s\n' "${f#src/grove.provision/}" "$over" >&2
  fi
done < <(find src/grove.provision -name '*.sh' -type f | sort)

pct_all=$(( comment * 100 / total ))

echo ""
echo "   ├─ files:   $files"
echo "   ├─ lines:   $total"
echo "   ├─ comment: $comment (${pct_all}%)"
echo "   └─ over:    $overs"

if [[ "$overs" -gt 0 ]]; then
  echo "" >&2
  echo "   ✋ $overs file(s) carry more header than a reader will spend" >&2
  echo "      ⇒ a header is not free: every line is read on every visit," >&2
  echo "        and a 900-line file's argument is unread by construction" >&2
  echo "      fix: a header is a .what + .why OUTLINE and no more" >&2
  echo "        - .what: one line" >&2
  echo "        - .why: bullets, one sentence each, no ';' and no ', and'" >&2
  echo "        - a narrative, a measurement, or an edit-diff: rehome and cite" >&2
  echo "      read why: rule.forbid.narratives" >&2
  exit 1
fi

echo ""
echo "🌲 every bundle header carries its weight ✔"
