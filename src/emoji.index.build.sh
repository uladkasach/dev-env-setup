#!/usr/bin/env bash
######################################################################
# .what = build the emoji lookup index from CLDR + the unicode emoji list
#
# .why  = the tab widget needs a flat TSV it can grep in one fork. no
#         json parse, no interpreter, no daemon in the keystroke path.
#         measured: 8.8 ms per lookup against this file.
#
# .note = CLDR annotates *characters*, not emoji. of its 1,965 entries
#         only ~1,536 are emoji. the rest include ascii punctuation and
#         5 invisible skin-tone modifiers. two of those would be real
#         defects if shipped:
#           - ':' is in CLDR, so ':colon'+TAB would insert the very
#             trigger char you just typed
#           - the skin-tone modifiers are combiners; alone they render
#             as an empty cell, which reads as a silent failure
#         so we intersect against emoji-test.txt, which *defines* what
#         is an emoji, rather than hand-roll a codepoint range.
#
# usage:
#   rhx emoji.index.set                    # build to the default path
#   rhx emoji.index.set --into path.tsv    # build elsewhere
#   rhx emoji.index.set --check            # verify an extant index
#
# options:
#   --into PATH            where to write (default: $XDG_DATA_HOME/emoji/emoji.tsv)
#   --check                verify the index, build none
#   --repo/--role/--skill  absorbed + ignored — rhachet injects these when
#                          invoked via `rhx emoji.index.set ...`
#
# guarantee:
#   - output is emoji-only; punctuation and bare combiners are filtered
#   - self-checks after build; a bad index fails loud rather than ships
#   - idempotent: safe to re-run, writes via temp + mv so a failed build
#     never truncates a good index
#   - fail-fast on errors
######################################################################

set -euo pipefail

CLDR_URL='https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/cldr-annotations-full/annotations/en/annotations.json'
TEST_URL='https://unicode.org/Public/emoji/latest/emoji-test.txt'

INTO="${EMOJI_INDEX:-${XDG_DATA_HOME:-$HOME/.local/share}/emoji/emoji.tsv}"
CHECK_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --into) INTO="${2:-}"; shift 2 ;;
    --check) CHECK_ONLY=1; shift ;;
    --repo|--role|--skill)
      # absorb the pairs rhachet injects on `rhx emoji.index.set ...`
      shift
      [[ $# -gt 0 ]] && shift
      ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ unknown arg: $1" >&2; exit 2 ;;
  esac
done

######################################################################
# verify — shared by --check and the post-build self-check
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
  # and ~600 friends. if these two are absent, the normalize step broke.
  local vs
  for vs in '❤️' '⚠️'; do
    if ! awk -F'\t' -v c="$vs" '$1==c { f=1 } END { exit !f }' "$idx"; then
      echo "💥 '$vs' absent — the FE0F normalize step regressed" >&2
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

if [[ $CHECK_ONLY -eq 1 ]]; then
  echo "🐢 lets take a look"
  echo ""
  echo "🐚 emoji.index.set --check"
  echo "   ├─ index: $INTO"
  if verify_index "$INTO"; then
    echo "   ├─ emoji: $(wc -l < "$INTO")"
    echo "   └─ ✅ index is sound"
    exit 0
  fi
  echo "   └─ ✋ index failed verification"
  exit 1
fi

######################################################################
# build
######################################################################
command -v jq   >/dev/null || { echo "✋ jq required"   >&2; exit 2; }
command -v curl >/dev/null || { echo "✋ curl required" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "🐢 heres the wave..."
echo ""
echo "🐚 emoji.index.set"
echo "   ├─ into: $INTO"

echo "   ├─ fetch cldr annotations"
curl -sfL "$CLDR_URL" -o "$WORK/cldr.json"

echo "   ├─ fetch the unicode emoji list"
curl -sfL "$TEST_URL" -o "$WORK/emoji-test.txt"

# emoji-test.txt rows look like:
#   1F680 ; fully-qualified   # 🚀 E1.0 rocket
# the char sits right after '# '. fully-qualified rows only — the
# component rows are what carry the invisible skin-tone modifiers.
#
# emit two columns: the normalized key, then the fully-qualified char.
#
# .why normalize = U+FE0F is the variation selector that promotes a
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
  norm = char; gsub(/\xef\xb8\x8f/, "", norm)   # strip U+FE0F
  if (!(norm in seen)) { seen[norm] = 1; printf "%s\t%s\n", norm, char }
}' "$WORK/emoji-test.txt" > "$WORK/allow.tsv"

# cldr shape: char -> { tts: [name], default: [keywords] }
echo "   ├─ flatten cldr to tsv"
jq -r '
  .annotations.annotations
  | to_entries[]
  | [ .key, (.value.tts | first), (.value.default | join(" ")) ]
  | @tsv
' "$WORK/cldr.json" > "$WORK/all.tsv"

# intersect on the normalized form; emit the fully-qualified char
echo "   ├─ filter to emoji only"
awk -F'\t' '
  NR==FNR { qualified[$1] = $2; next }
  {
    norm = $1; gsub(/\xef\xb8\x8f/, "", norm)
    if (norm in qualified) printf "%s\t%s\t%s\n", qualified[norm], $2, $3
  }
' "$WORK/allow.tsv" "$WORK/all.tsv" > "$WORK/emoji.tsv"

ALL=$(wc -l < "$WORK/all.tsv")
KEPT=$(wc -l < "$WORK/emoji.tsv")

echo "   ├─ verify"
if ! verify_index "$WORK/emoji.tsv"; then
  echo "   └─ 💥 built index failed verification; kept none"
  exit 1
fi

mkdir -p "$(dirname "$INTO")"
mv "$WORK/emoji.tsv" "$INTO"

echo "   └─ built ✅"
echo "      ├─ annotated chars : $ALL"
echo "      ├─ kept as emoji   : $KEPT"
echo "      ├─ filtered out    : $((ALL - KEPT))"
echo "      ├─ size            : $(du -h "$INTO" | cut -f1)"
echo "      └─ path            : $INTO"
