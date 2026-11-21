#!/usr/bin/env bash
######################################################################
# .what = read, for every live tmux server, whether it asks the outer
#         terminal for the mouse — its global `mouse` option, any session
#         that overrides it, and the clients that would feel it
#
# .why  = kitty turns a wheel tick into ARROW KEYS for a window on the
#         alternate screen whose program never asked for the mouse.
#         behind tmux, that program is the tmux client — so one server
#         with `mouse off` makes every scroll in its windows type up/down
#         arrows into the pane (a recalled prompt in claude-cli, a moved
#         cursor in a menu). which server, and which session, is a live
#         fact; this reads it
#
# usage:
#   tmux.mouse.get.sh            # every server: its mouse option + overrides
#   tmux.mouse.get.sh --help
#
# guarantee:
#   - read-only; asks each server, sets no option
#   - a socket with no server behind it is named STALE
#   - exit 0 = answered; 2 = bad args
######################################################################
set -uo pipefail

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg: $1" >&2; exit 2 ;;
  esac
done

DIR="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)"

echo "🐢 heres who asks for the mouse"
echo ""
echo "🐚 tmux.mouse.get"
echo "   ├─ socket dir: $DIR"

mapfile -t SOCKS < <(for s in "$DIR"/*; do [[ -S "$s" ]] && printf '%s\n' "$s"; done)
N=${#SOCKS[@]}
(( N == 0 )) && { echo "   └─ (no socket)"; exit 0; }

OFF=0
I=0
for sock in "${SOCKS[@]}"; do
  I=$((I + 1))
  name="${sock##*/}"
  b="├─"; p="│ "; (( I == N )) && { b="└─"; p="  "; }
  version="$(timeout 2 tmux -S "$sock" display-message -p '#{version}' 2>/dev/null)"
  if [[ -z "$version" ]]; then
    echo "   $b $name  ✋ STALE — a socket file, no server answers"
    continue
  fi
  global="$(timeout 2 tmux -S "$sock" show-options -gv mouse 2>/dev/null)"
  clients="$(timeout 2 tmux -S "$sock" list-clients 2>/dev/null | grep -c .)"
  # a session-local `mouse` overrides the global one; show-options -t lists only locals
  overrides="$(timeout 2 tmux -S "$sock" list-sessions -F '#{session_name}' 2>/dev/null \
    | while read -r s; do
        v="$(timeout 2 tmux -S "$sock" show-options -t "$s" -v mouse 2>/dev/null)"
        [[ -n "$v" ]] && printf '%s=%s\n' "$s" "$v"
      done)"
  mark="✔"
  [[ "$global" != on ]] && { mark="✋"; OFF=1; }
  grep -q '=off$' <<<"$overrides" && { mark="✋"; OFF=1; }
  echo "   $b $name  $mark mouse=$global (tmux $version, clients attached: $clients)"
  if [[ -n "$overrides" ]]; then
    printf '%s\n' "$overrides" | sed "s/^/   $p  · session override: /"
  fi
done

echo ""
if (( OFF == 1 )); then
  echo "🥥 a ✋ server scrolls its windows as arrow keys: kitty sees mouse off on the alternate screen"
  echo "   └─ fix: rhx grove.provision --what 2.8.tmux --mode apply"
fi
exit 0
