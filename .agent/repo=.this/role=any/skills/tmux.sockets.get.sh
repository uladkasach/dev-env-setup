#!/usr/bin/env bash
######################################################################
# .what = list every live tmux SERVER this user owns, one per socket,
#         with its sessions and the hints that name who started it
#
# .why  = a tool that asks a bare `tmux …` talks to the `default` server
#         alone, so a second server is invisible to it (the copy kitten
#         was blind to `duct-org-*` this way). when an unexpected server
#         turns up, the question is always WHO made it — and the server's
#         own birth environment answers that: its PWD, its socket env,
#         the session names it carries
#
# usage:
#   tmux.sockets.get.sh             # every socket, a summary row each
#   tmux.sockets.get.sh --sessions  # also list each server's sessions
#   tmux.sockets.get.sh --key C-Up  # also each server's LIVE root bind for a key
#
#   --key answers "did this server take the conf?" — a bind change is live the
#   moment a server sources it, so a server that still shows the old bind is
#   the one a window misbehaves on. repeat --key for several keys
#
# guarantee:
#   - read-only; asks each server, signals none, unlinks no socket
#   - a socket file with no server behind it is named STALE, not removed
#   - exit 0 = answered
######################################################################
set -uo pipefail

SHOW_SESSIONS=0
KEYS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) shift 2 ;;
    --sessions) SHOW_SESSIONS=1; shift ;;
    --key) [[ -n "${2:-}" ]] || { echo "✋ ConstraintError: --key needs a key name, e.g. --key C-Up" >&2; exit 2; }
           KEYS+=("$2"); shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg: $1" >&2; exit 2 ;;
  esac
done

DIR="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)"

# one var off a process's birth environment
env_of() { tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null | grep -m1 "^$2=" | cut -d= -f2-; }

echo "🐢 heres every tmux server"
echo ""
echo "🐚 tmux.sockets.get"
echo "   ├─ socket dir: $DIR"

mapfile -t SOCKS < <(for s in "$DIR"/*; do [[ -S "$s" ]] && printf '%s\n' "$s"; done)
N=${#SOCKS[@]}
(( N == 0 )) && { echo "   └─ (no socket)"; exit 0; }

I=0
for sock in "${SOCKS[@]}"; do
  I=$((I + 1))
  name="${sock##*/}"
  b="├─"; p="│ "; (( I == N )) && { b="└─"; p="  "; }
  pid="$(timeout 2 tmux -S "$sock" display-message -p '#{pid}' 2>/dev/null)"
  if [[ -z "$pid" ]]; then
    echo "   $b $name  ✋ STALE — a socket file, no server answers"
    continue
  fi
  sessions="$(timeout 2 tmux -S "$sock" list-sessions -F '#{session_name}' 2>/dev/null)"
  count="$(printf '%s\n' "$sessions" | grep -c .)"
  clients="$(timeout 2 tmux -S "$sock" list-clients 2>/dev/null | grep -c .)"
  started="$(ps -o lstart= -p "$pid" 2>/dev/null | sed 's/  */ /g')"
  echo "   $b $name"
  echo "   $p  ├─ server pid: $pid, started $started"
  echo "   $p  ├─ sessions:   $count, clients attached: $clients"
  echo "   $p  ├─ born in:    $(env_of "$pid" PWD)"
  echo "   $p  ├─ born with DUCTWORK_TMUX_SOCKET=$(env_of "$pid" DUCTWORK_TMUX_SOCKET)"
  echo "   $p  ├─ born under TMUX=$(env_of "$pid" TMUX)"
  # one client's process title: what /proc says a client of THIS server is
  cpid="$(timeout 2 tmux -S "$sock" list-clients -F '#{client_pid}' 2>/dev/null | head -1)"
  ctitle="$( [[ -n "$cpid" ]] && tr '\0' ' ' < "/proc/$cpid/cmdline" 2>/dev/null)"
  echo "   $p  └─ a client's /proc title: ${ctitle:-(no client)}"
  if (( SHOW_SESSIONS == 1 )); then
    printf '%s\n' "$sessions" | grep . | sed "s/^/   $p     · /"
  fi
  # the live root bind, one line per key; `(unbound)` when the server holds none
  for key in "${KEYS[@]}"; do
    bind="$(timeout 2 tmux -S "$sock" list-keys -T root "$key" 2>/dev/null | tr -s ' ' | head -c 300)"
    echo "   $p     ⌨ $key: ${bind:-(unbound)}"
  done
done