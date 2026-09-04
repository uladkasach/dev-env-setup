#!/usr/bin/env bash
######################################################################
# .what = turn two upstream files into the flat emoji lookup index
#
# .why  = the tab widget needs a flat TSV it can grep in one fork. no
#         json parse, no interpreter, no daemon in the keystroke path.
#         measured: 8.8 ms per lookup against this file.
#
# 🛑 .why it reaches the wire ZERO times
#    two `curl -sfL` calls against MOVING refs — cldr-json's `main`
#    branch and unicode's `emoji/latest/` — cost three ways, and the
#    third is the one that decides the shape:
#
#      1. an unbounded curl on the provision path can hold a duct
#         (`rule.require.one-command-provision`, the four-tool measurement)
#      2. a moving ref can carry no hash, so the fetch could never
#         satisfy `prove.every-fetch-is-verified`
#      3. ⚠️ a pin declared HERE would sit outside `provision.upsert.sh`,
#         and `prove.sha256-pins-bite` discovers its subjects by a grep
#         over that filename. so the pin would be real, correct, and
#         re-proven by NOBODY — the exact omission class that hid two
#         subjects from that play for weeks
#
#    ⇒ so the BUNDLE owns the versions, the urls, the pins, and the two
#      `web_fetch` calls; this file owns the transform alone. that also
#      makes it runnable offline and testable with no network at all.
#
# .why  the intersect exists
#       CLDR annotates *characters*, not emoji. of its ~1,966 entries
#       only ~1,536 are emoji. the rest include ascii punctuation and
#       5 invisible skin-tone modifiers. two of those would be real
#       defects if shipped:
#         - ':' is in CLDR, so ':colon'+TAB would insert the very
#           trigger char you just typed
#         - the skin-tone modifiers are combiners; alone they render
#           as an empty cell, which reads as a silent failure
#       so we intersect against emoji-test.txt, which *defines* what
#       is an emoji, rather than hand-roll a codepoint range.
#
# usage:
#   bash src/emoji.index.build.sh --cldr <annotations.json> \
#                                 --list <emoji-test.txt> \
#                                 --into <emoji.tsv>
#   bash src/emoji.index.build.sh --check <emoji.tsv>
#
# guarantee:
#   - it reaches NO network; both inputs are handed to it
#   - output is emoji-only; punctuation and bare combiners are filtered
#   - it self-checks after the transform; a bad index fails loud rather
#     than ships (`rule.forbid.failhide`)
#   - idempotent: it writes via temp + mv, so a failed run never
#     truncates a good index
######################################################################

set -euo pipefail

CLDR=""
LIST=""
INTO=""
CHECK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cldr)  CLDR="${2:-}";  shift 2 ;;
    --list)  LIST="${2:-}";  shift 2 ;;
    --into)  INTO="${2:-}";  shift 2 ;;
    --check) CHECK="${2:-}"; shift 2 ;;
    --repo|--role|--skill)
      # absorb the pairs rhachet injects when this runs through `rhx`
      shift
      [[ $# -gt 0 ]] && shift
      ;;
    -h|--help) grep '^#' "$0"; exit 0 ;;
    *) echo "✋ unknown arg: $1" >&2; exit 2 ;;
  esac
done

######################################################################
# verify — shared by --check and the post-transform self-check
#
# ⚠️ each canary below is a DEFECT this transform actually shipped once,
#    kept as a row rather than as prose. a filter is only as good as the
#    cases it is known to reject
######################################################################
verify_index() {
  local idx="$1" bad=0

  if [[ ! -s $idx ]]; then
    echo "✋ index absent or empty: $idx" >&2
    return 2
  fi

  # the filter must have dropped these. each would be a live defect.
  local c
  for c in ':' ',' '{' '🏻'; do
    if awk -F'\t' -v c="$c" '$1==c { f=1 } END { exit !f }' "$idx"; then
      echo "💥 '$c' survived the filter — index is unsafe" >&2
      bad=1
    fi
  done

  # VS16 canaries. these are the emoji whose CLDR key lacks the U+FE0F
  # that emoji-test.txt carries; a naive byte-match filter drops them
  # and ~600 friends. if these two are absent, the FE0F strip regressed.
  local vs
  for vs in '❤️' '⚠️'; do
    if ! awk -F'\t' -v c="$vs" '$1==c { f=1 } END { exit !f }' "$idx"; then
      echo "💥 '$vs' absent — the FE0F strip regressed" >&2
      bad=1
    fi
  done

  # and the keywords the wish named must find an emoji
  # (note: 'warning' is CLDR's own name for ⚠️ — data, not prose)
  local q hit
  for q in happy turtle launch tada lit boom stop wave heart warning; do
    hit=$(awk -F'\t' -v q="$q" \
      '$2 ~ ("(^| )" q "( |$)") || $3 ~ ("(^| )" q "( |$)") { print $1; exit }' \
      "$idx")
    if [[ -z $hit ]]; then
      echo "💥 keyword '$q' finds no emoji" >&2
      bad=1
    fi
  done

  return "$bad"
}

if [[ -n "$CHECK" ]]; then
  echo "🐢 lets take a look"
  echo ""
  echo "🐚 emoji.index.build --check"
  echo "   ├─ index: $CHECK"
  if verify_index "$CHECK"; then
    echo "   ├─ emoji: $(wc -l < "$CHECK")"
    echo "   └─ ✅ index is sound"
    exit 0
  fi
  echo "   └─ ✋ index failed verification"
  exit 1
fi

######################################################################
# transform
######################################################################
if [[ -z "$CLDR" || -z "$LIST" || -z "$INTO" ]]; then
  echo "✋ needs --cldr FILE --list FILE --into FILE (or --check FILE)" >&2
  exit 2
fi

for f in "$CLDR" "$LIST"; do
  if [[ ! -s "$f" ]]; then
    echo "✋ input absent or empty: $f" >&2
    echo "   ⇒ this file reaches no network, so an absent input is the" >&2
    echo "     caller's fetch that did not land — never a wire fault here" >&2
    exit 2
  fi
done

command -v jq >/dev/null || { echo "✋ jq required" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "🐢 heres the wave..."
echo ""
echo "🐚 emoji.index.build"
echo "   ├─ into: $INTO"

# emoji-test.txt rows look like:
#   1F680 ; fully-qualified   # 🚀 E1.0 rocket
# the char sits right after '# '. fully-qualified rows only — the
# component rows are what carry the invisible skin-tone modifiers.
#
# emit two columns: the STRIPPED key, then the fully-qualified char.
#
# .why the strip = U+FE0F is the variation selector that promotes a
#      legacy dingbat to a color emoji. emoji-test.txt lists the
#      fully-qualified form WITH it (❤️ = 2764 FE0F), but CLDR keys the
#      same emoji WITHOUT it (❤ = 2764). a naive byte match drops every
#      such pair — measured: 933 kept instead of ~1,500, with ❤️ and ⚠️
#      among the casualties. so we match on the FE0F-stripped form.
#
# .why emit the qualified char = we insert what renders in color. the
#      bare U+2764 renders monochrome text-style in many contexts,
#      which is not what anyone means by "the heart emoji".
echo "   ├─ distill the emoji allowlist"
awk -F'# ' '/; fully-qualified/ {
  split($2, a, " ")
  char = a[1]
  bare = char; gsub(/\xef\xb8\x8f/, "", bare)   # strip U+FE0F
  if (!(bare in seen)) { seen[bare] = 1; printf "%s\t%s\n", bare, char }
}' "$LIST" > "$WORK/allow.tsv"

# cldr shape: char -> { tts: [name], default: [keywords] }
echo "   ├─ flatten cldr to tsv"
jq -r '
  .annotations.annotations
  | to_entries[]
  | [ .key, (.value.tts | first), (.value.default | join(" ")) ]
  | @tsv
' "$CLDR" > "$WORK/all.tsv"

# intersect on the stripped form; emit the fully-qualified char
echo "   ├─ filter to emoji only"
awk -F'\t' '
  NR==FNR { qualified[$1] = $2; next }
  {
    bare = $1; gsub(/\xef\xb8\x8f/, "", bare)
    if (bare in qualified) printf "%s\t%s\t%s\n", qualified[bare], $2, $3
  }
' "$WORK/allow.tsv" "$WORK/all.tsv" > "$WORK/emoji.tsv"

ALL=$(wc -l < "$WORK/all.tsv")
KEPT=$(wc -l < "$WORK/emoji.tsv")

echo "   ├─ verify"
if ! verify_index "$WORK/emoji.tsv"; then
  echo "   └─ 💥 the index failed verification; kept none"
  exit 1
fi

mkdir -p "$(dirname "$INTO")"
mv "$WORK/emoji.tsv" "$INTO"

echo "   └─ built ✅"
echo "      ├─ annotated chars : $ALL"
echo "      ├─ kept as emoji   : $KEPT"
echo "      ├─ filtered out    : $((ALL - KEPT))"
echo "      └─ path            : $INTO"
