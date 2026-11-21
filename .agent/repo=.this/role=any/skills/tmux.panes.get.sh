#!/usr/bin/env bash
######################################################################
# .what = read the screen state of every ATTACHED pane on every live
#         tmux server: its command, whether it holds the alternate
#         screen, whether it asked for the mouse, and whether it sits in
#         copy-mode
#
# .why  = a wheel tick or a scroll key over a pane goes one of three
#         ways, and these flags pick which:
#           - a pane that asked for the mouse gets the mouse event
#           - a pane on the MAIN screen gets tmux's copy-mode scroll
#           - a pane on the ALTERNATE screen that never asked gets
#             whatever the bind hands it — an arrow key, if the bind
#             re-sends one. claude-cli, less, and menus read that as
#             "up", not as a scroll
#         which apps hold which state is a live fact; this reads it
#
#         and one fact a level up: the SESSION's own `mouse` option. with it
#         off, the tmux client never asks kitty for the mouse, so kitty turns
#         every wheel tick over that window into arrow keys. a row with
#         `tmux-mouse=off` is that cause, named; `rhx grove.provision --what
#         2.8.tmux --mode apply` sources the conf that turns it on
#
# usage:
#   tmux.panes.get.sh                  # every attached pane, all servers
#   tmux.panes.get.sh --command claude # only panes whose command matches
#
# guarantee:
#   - read-only; asks each server, sets no option, sends no key
#   - only panes in a session with a client attached — the ones a human
#     can scroll right now
#   - exit 0 = answered; 2 = bad args
######################################################################
set -uo pipefail

MATCH=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) shift 2 ;;
    --command) MATCH="${2:-}"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg: $1" >&2; exit 2 ;;
  esac
done

DIR="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)"
# `#{mouse}` reads the option itself, session override included
FMT='#{session_attached}	#{session_name}	#{pane_current_command}	#{alternate_on}	#{mouse_any_flag}	#{mouse_sgr_flag}	#{pane_in_mode}	#{mouse}'

echo "🐢 heres what each pane holds"
echo ""
echo "🐚 tmux.panes.get${MATCH:+ --command $MATCH}"
echo "   ├─ columns: server · session · command · screen · mouse · mode"

ROWS=()
for sock in "$DIR"/*; do
  [[ -S "$sock" ]] || continue
  while IFS=$'\t' read -r attached session cmd alt mouse sgr mode tmuxmouse; do
    [[ "$attached" == 0 || -z "$attached" ]] && continue
    [[ -n "$MATCH" && "$cmd" != *"$MATCH"* ]] && continue
    screen=main; [[ "$alt" == 1 ]] && screen=alt
    m=none; [[ "$mouse" == 1 ]] && m=asked; [[ "$sgr" == 1 ]] && m="$m+sgr"
    md=-; [[ "$mode" == 1 ]] && md=copy-mode
    # a flag option renders `1` in a format, `on` in show-options — accept both
    off=''; [[ "$tmuxmouse" != 1 && "$tmuxmouse" != on ]] && off=" · ✋ tmux-mouse=${tmuxmouse:-unset}"
    ROWS+=("${sock##*/} · $session · $cmd · $screen · $m · $md$off")
  done < <(timeout 2 tmux -S "$sock" list-panes -a -F "$FMT" 2>/dev/null)
done

N=${#ROWS[@]}
if (( N == 0 )); then
  echo "   └─ (no attached pane)"
  exit 0
fi
I=0
for row in "${ROWS[@]}"; do
  I=$((I + 1))
  b="├─"; (( I == N )) && b="└─"
  echo "   $b $row"
done
exit 0
