#!/usr/bin/env bash
######################################################################
# .what = read the LIVE ctrl+shift+c copy chain, as the kitty kitten and
#         the tmux server see it right now, per attached client
#
# .why  = the chain is kitty kitten → tmux root bind → nvim keymap, and the
#         repo can declare every layer correctly while the live box drops
#         the key (`define.kitty-tmux-nvim-copy`):
#           - the live server holds its conf IN MEMORY; a bind or an
#             extended-keys value the repo has, the server may not
#           - the kitten asks tmux "what runs in the active pane?" with a
#             1s timeout per call, and FAILS CLOSED on a slow answer — a
#             busy server reads to the kitten as "not nvim", so the key is
#             never forwarded
#         `prove.copy-gate-discriminates` proves the repo's conf on a fresh
#         server; this reads the one that is actually live
#
# usage:
#   tmux.copy.gate.get.sh            # server layer + one row per client
#
# guarantee:
#   - read-only; asks the server, signals none, sets no option
#   - the per-client reads are the kitten's own two calls, same args, same
#     1s bound, so a row that reads `timeout` is a key the kitten dropped
#   - exit 0 = answered; 2 = no tmux server
######################################################################
set -uo pipefail

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg: $1" >&2; exit 2 ;;
  esac
done

tmux display-message -p '#{pid}' >/dev/null 2>&1 || {
  echo "✋ ConstraintError: no tmux server answers on the default socket" >&2
  exit 2
}

# one call, timed, under the kitten's own 1s bound; prints "<ms> <exit>"
timed() {
  local t0 t1 rc
  t0=$(date +%s%N)
  timeout 1 "$@" >/dev/null 2>&1
  rc=$?
  t1=$(date +%s%N)
  printf '%d %d\n' $(( (t1 - t0) / 1000000 )) "$rc"
}

BIND="$(tmux list-keys -T root C-S-c 2>/dev/null | head -1)"
EXTKEYS="$(tmux show-options -sv extended-keys 2>/dev/null)"
CLIP="$(tmux show-options -sv set-clipboard 2>/dev/null)"

echo "🐢 heres the copy chain, live"
echo ""
echo "🐚 tmux.copy.gate.get"
echo "   ├─ server layer"
echo "   │  ├─ root bind C-S-c: ${BIND:+present}${BIND:-✋ ABSENT — re-source the conf}"
echo "   │  ├─ extended-keys:   ${EXTKEYS:-?}$([[ "$EXTKEYS" == on || "$EXTKEYS" == always ]] || echo '  ✋ the CSI u never reaches the bind')"
echo "   │  └─ set-clipboard:   ${CLIP:-?}"
echo "   │"

# the kitten's first call: list-clients, timed
read -r LC_MS LC_RC < <(timed tmux list-clients -F '#{client_tty}	#{session_name}')
echo "   ├─ kitten read 1: list-clients  ${LC_MS}ms$([[ "$LC_RC" == 124 ]] && echo '  ✋ TIMEOUT — the kitten fails closed, no key forwarded')"
echo "   │"
# every pane whose tty runs an nvim: what does tmux NAME it? the gate and the
#   kitten both match `#{pane_current_command}`, never the process tree, so an
#   nvim that tmux names otherwise is an nvim the key can never reach
#   ⚠️ every SOCKET is read, not only the default one: a duct runs on its own
#   server (`duct-org-<org>`); the kitten reads which off the client's argv
echo "   ├─ panes that run nvim, per tmux socket (the gate matches *nvim*)"
NV=0
SOCKDIR="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)"
for sock in "$SOCKDIR"/*; do
  [[ -S "$sock" ]] || continue
  name="${sock##*/}"
  # each server holds its OWN bind table; the gate must be live on this one
  seen="bind live"
  timeout 2 tmux -L "$name" list-keys -T root C-S-c 2>/dev/null | grep -q . \
    || seen="✋ this server has NO C-S-c bind — re-source its conf"
  while IFS=$'\t' read -r target tty cmd; do
    ps -t "${tty#/dev/}" -o comm= 2>/dev/null | grep -qx 'nvim' || continue
    NV=$((NV + 1))
    mark="✔"; [[ "$cmd" == *nvim* ]] || mark="✋ the gate reads this as NOT nvim"
    echo "   │  ├─ socket=$name  $target  pane_current_command=$cmd  $mark  ($seen)"
  done < <(timeout 2 tmux -L "$name" list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}	#{pane_tty}	#{pane_current_command}' 2>/dev/null)
done
(( NV == 0 )) && echo "   │  └─ (no pane on any socket runs nvim)"
echo "   │"
echo "   └─ per client (the kitten's read 2: list-panes on that session)"

mapfile -t CLIENTS < <(tmux list-clients -F '#{client_tty}	#{session_name}' 2>/dev/null)
N=${#CLIENTS[@]}
I=0
for row in "${CLIENTS[@]}"; do
  I=$((I + 1))
  tty="${row%%	*}"
  session="${row#*	}"
  read -r LP_MS LP_RC < <(timed tmux list-panes -t "$session" -F '#{pane_active}')
  active="$(tmux list-panes -t "$session" -F '#{pane_active}	#{pane_in_mode}	#{pane_current_command}' 2>/dev/null | awk -F'\t' '$1==1 {print $3 (($2==1) ? " (copy-mode)" : ""); exit}')"
  verdict="drop"
  [[ "$active" == nvim* ]] && verdict="forward"
  [[ "$active" == *"(copy-mode)" ]] && verdict="forward"
  (( LC_RC == 124 || LP_RC == 124 )) && verdict="drop (timeout)"
  branch="├─"; (( I == N )) && branch="└─"
  echo "      $branch $tty  ${session}  active=${active:-?}  ${LP_MS}ms  → $verdict"
done