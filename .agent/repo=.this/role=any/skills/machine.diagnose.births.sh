#!/usr/bin/env bash
######################################################################
# .what = name WHAT a spawn storm runs — the full command of every newborn,
#         grouped, with the command of the parent that forked it
#
# .why  = `machine.diagnose.churn` gives the RATE and the runtime names
#         ("zsh", "tmux:"), which name no culprit. the culprit is in the
#         ARGS: a `zsh -c 'tmux list-panes ...'` is a poller, a bare `zsh`
#         is a new pane. ps can read a newborn's args only in its first
#         moments, so this sweeps fast and keeps only processes < 1s old
#
# usage:
#   rhx machine.diagnose.births                # 5s, 25 sweeps
#   rhx machine.diagnose.births --secs 10 --top 20
#
# guarantee:
#   - read-only; spawns only its own ps sweeps
#   - exits 0 always (a report is not a verdict)
######################################################################
set -u

secs=5 sweeps=25 top=15
while [[ $# -gt 0 ]]; do
  case "$1" in
    --secs) secs="$2"; shift 2 ;;
    --sweeps) sweeps="$2"; shift 2 ;;
    --top) top="$2"; shift 2 ;;
    --help|-h)
      echo "machine.diagnose.births — group newborn processes by command, with their parent"
      echo "  usage: rhx machine.diagnose.births [--secs 5] [--sweeps 25] [--top 15]"
      exit 0 ;;
    # rhx passes its own args (--skill, --repo, --role …) through; let them pass
    *) shift ;;
  esac
done

gap="$(awk -v s="$secs" -v n="$sweeps" 'BEGIN { printf "%.3f", s / n }')"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# sweep: keep processes under 1s old; record "pid<TAB>child args<TAB>parent args"
for ((i = 0; i < sweeps; i++)); do
  ps -eo pid=,ppid=,etimes=,args= | awk '$3 == 0' | while read -r pid ppid _ args; do
    [[ "$args" == ps\ -eo* ]] && continue
    pargs="$(tr '\0' ' ' < "/proc/$ppid/cmdline" 2>/dev/null | cut -c1-90)"
    printf '%s\t%s\t%s\n' "$pid" "$(cut -c1-110 <<<"$args")" "${pargs:-?}"
  done >> "$tmp"
  sleep "$gap"
done

echo "🐈 heres who keeps up the births...  (${secs}s, ${sweeps} sweeps)"
echo "   │"
echo "   └─ distinct newborn pids, by command  ←  the parent that forked them"
# one pid seen in several sweeps counts once
sort -u -t$'\t' -k1,1 "$tmp" | cut -f2,3 | sort | uniq -c | sort -rn | head -n "$top" |
  while read -r n rest; do
    child="${rest%%$'\t'*}" parent="${rest#*$'\t'}"
    printf '      ├─ %4d  %s\n      │        ← %s\n' "$n" "$child" "$parent"
  done
exit 0
