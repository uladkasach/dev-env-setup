#!/usr/bin/env zsh
######################################################################
# .what = look up an emoji by keyword or name (test surface)
#
# .why  = lets an agent exercise the same lookup the TAB widget uses,
#         without a terminal. it is NOT the hot path — the widget is
#         sourced and never pays this fork or rhx's node boot.
#
# .note = the 5-rank logic is NOT restated here. it is sourced from
#         src/emoji.zsh, the file that actually ships. an earlier draft
#         copied the ranks into this file and the contract brief
#         documented "they must stay in sync" — which is a duplicate
#         with a note attached rather than a fix. if TAB and this
#         command could disagree, the disagreement would surface as the
#         worst kind of surprise: the same query, two answers.
#
# usage:
#   rhx emoji.get --query rocket        # 🚀 to stdout
#   rhx emoji.get --query happy --all   # every hit, in rank order
#   rhx emoji.get --query happy --long  # char + name + keywords
#   rhx emoji.get --bench               # time the lookup path
#
# options:
#   --query WORD           what to look up
#   --all                  print every hit, not the top one
#   --long                 include name + keywords, tab separated
#   --from PATH            index to read (default: $XDG_DATA_HOME/emoji/emoji.tsv)
#   --bench                time 50 lookups, report ms each
#   --repo/--role/--skill  absorbed + ignored — rhachet injects these
#
# guarantee:
#   - identical rank order to the TAB widget, by construction
#   - stdout is the emoji alone; diagnostics go to stderr
#   - exit 2 when the query finds no emoji (constraint, caller fixes)
######################################################################

emulate -L zsh
setopt err_return

# .note = `emoji.get --all | head -3` closes the pipe early. that is a
#         normal caller, so it must not read as a failure.
#         HANDLE the signal, do not ignore it:
#           trap '' PIPE       -> ignored, so write() returns EPIPE and
#                                 printf reports "write error: Broken pipe"
#           (no trap)          -> default action, exit 141
#           trap 'exit 0' PIPE -> caught, quiet, exit 0  ✅
trap 'exit 0' PIPE

QUERY=""
ALL=0
LONG=0
BENCH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query) QUERY="${2:-}"; shift 2 ;;
    --from) EMOJI_INDEX="${2:-}"; shift 2 ;;
    --all) ALL=1; shift ;;
    --long) LONG=1; shift ;;
    --bench) BENCH=1; shift ;;
    --repo|--role|--skill)
      shift
      [[ $# -gt 0 ]] && shift
      ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) print -u2 "✋ unknown arg: $1"; exit 2 ;;
  esac
done

# source the shipped widget for `_emoji_lookup`. its zle/bindkey block
# is guarded on `[[ -o interactive ]]`, so this is inert here.
WIDGET="${0:A:h}/../../../../src/emoji.zsh"
if [[ ! -f $WIDGET ]]; then
  print -u2 "✋ widget absent: $WIDGET"
  exit 2
fi
export EMOJI_INDEX
source "$WIDGET" >/dev/null || {
  print -u2 "✋ could not load $WIDGET (is the index built? rhx emoji.index.set)"
  exit 2
}

######################################################################
# bench
#
# ⚠️ an UPPER BOUND, not the widget's cost. through `rhx` this runs
#    under a node parent, which inflates every fork in the loop. the
#    widget is sourced into zsh and pays none of that.
######################################################################
if [[ $BENCH -eq 1 ]]; then
  print "🐢 lets time it"
  print ""
  print "🐚 emoji.get --bench"
  print "   ├─ index: $EMOJI_INDEX ($(wc -l < $EMOJI_INDEX) emoji)"

  start=$(date +%s%N)
  for _ in {1..50}; do _emoji_lookup happy >/dev/null; done
  end=$(date +%s%N)

  total_ms=$(( (end - start) / 1000000 ))
  each_ms=$(printf '%.1f' $(( total_ms / 50.0 )))

  print "   ├─ 50 lookups : ${total_ms} ms"
  print "   ├─ each       : ${each_ms} ms  ← upper bound, includes harness"
  print "   ├─ perceptual : 100 ms"
  if (( each_ms < 100 )); then
    print "   └─ ✅ under the perceptual threshold even with harness cost"
  else
    print "   └─ ✋ over 100 ms even as an upper bound — investigate"
    exit 1
  fi
  exit 0
fi

if [[ -z $QUERY ]]; then
  print -u2 "✋ --query required (or --bench)"
  exit 2
fi

HITS="$(_emoji_lookup "$QUERY")"

if [[ -z $HITS ]]; then
  print -u2 "✋ no emoji for '$QUERY'"
  exit 2
fi

# shaped in-shell, with no internal `| cut` or `| head` — those inner
# pipes were the original SIGPIPE source.
if [[ $ALL -eq 0 ]]; then
  HITS="${HITS%%$'\n'*}"
fi

if [[ $LONG -eq 1 ]]; then
  print -r -- "$HITS"
else
  print -rl -- ${${(f)HITS}%%$'\t'*}
fi
