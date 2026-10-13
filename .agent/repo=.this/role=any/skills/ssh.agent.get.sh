#!/usr/bin/env bash
######################################################################
# .what = show which ssh agent a shell and tmux use, and which keys each holds
#
# .why  = "ssh asks for my passphrase every time" means the key is held by no
#         agent ssh talks to. the cause is which socket SSH_AUTH_SOCK names —
#         in this shell, AND in tmux, which hands its own copy to every new pane
#
# usage:
#   rhx ssh.agent.get
#
# guarantee:
#   - READ-ONLY: it changes no env, no agent, no key
#   - every probe is bounded by a timeout
#   - "no keys" and "could not reach the agent" are told apart, never folded
######################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ssh.agent.operations.sh"

__ssh_agent_get_help() {
  cat <<'HELP'
🔑 ssh.agent.get — which ssh agent a shell and tmux use, and what each holds

  usage:
    rhx ssh.agent.get

  reads: SSH_AUTH_SOCK of this shell · the copy tmux hands new panes
         · each agent's socket · the keys each agent holds
  to change tmux's agent: rhx ssh.agent.set --to desktop|yubikey
HELP
}

# .what = list the keys an agent holds, three-valued by ssh-add's exit code
__ssh_agent_keys_of() {
  local sock="$1" out rc=0
  [[ -S "$sock" ]] || { echo "      ✋ no socket — agent not active"; return 0; }
  out="$(SSH_AUTH_SOCK="$sock" timeout 5 ssh-add -l 2>&1)" || rc=$?
  case "$rc" in
    0) printf '%s\n' "$out" | sed 's/^/      • /' ;;
    1) echo "      · holds no keys" ;;
    *) echo "      ⚠️ could not reach the agent (exit $rc): $out" ;;
  esac
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h) __ssh_agent_get_help; return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      *) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   fix: rhx ssh.agent.get --help" >&2; return 2 ;;
    esac
  done

  echo "🔑 ssh.agent.get"

  # a bridged yubikey path leads to the desktop agent, so a process that still names it is served right
  local bridge_note=""
  __ssh_agent_is_bridged && bridge_note=" — bridged, so each reaches the desktop agent"

  # the socket this process inherited
  local here="${SSH_AUTH_SOCK:-}"
  echo ""
  echo "── 1. this shell"
  echo "      SSH_AUTH_SOCK = ${here:-unset}  ($(__ssh_agent_name_of "$here"))"

  # the copy tmux hands every new pane
  echo ""
  echo "── 2. tmux (what a new pane inherits)"
  local tsock rc=0
  tsock="$(__ssh_agent_tmux_sock)" || rc=$?
  case "$rc" in
    0) echo "      SSH_AUTH_SOCK = $tsock  ($(__ssh_agent_name_of "$tsock"))" ;;
    1) echo "      · tmux holds no SSH_AUTH_SOCK — a pane inherits its shell's" ;;
    *) echo "      · no tmux server active" ;;
  esac
  local s v
  while IFS=$'\t' read -r s v; do
    [[ -n "$s" ]] || continue
    if [[ "$v" == "-" ]]; then
      echo "      session '$s': · none — the global value applies"
    else
      echo "      session '$s': $v  ($(__ssh_agent_name_of "$v"))  ← overrides the global"
    fi
  done < <(__ssh_agent_tmux_session_socks)

  # each pane's shell — it keeps the value it started with, whatever tmux holds now
  local pane ppid cmd stale=0 total=0
  while IFS=$'\t' read -r pane ppid cmd v; do
    [[ -n "$pane" ]] || continue
    total=$(( total + 1 ))
    [[ "$(__ssh_agent_name_of "${v#-}")" == yubikey ]] || continue
    stale=$(( stale + 1 ))
    echo "      pane $pane (now: $cmd): yubikey  ← started before the fix"
  done < <(__ssh_agent_tmux_pane_socks)
  [[ "$total" -gt 0 ]] && echo "      panes: $stale of $total still name yubikey$bridge_note"

  # the terminal app — every new window inherits what it started with
  echo ""
  echo "── 3. kitty (what a new window inherits)"
  local pid comm seen=0
  while IFS=$'\t' read -r pid comm v; do
    [[ -n "$pid" ]] || continue
    seen=1
    [[ "$v" == "-" ]] && v=""
    echo "      pid $pid ($comm): ${v:-unset}  ($(__ssh_agent_name_of "$v"))"
  done < <(__ssh_agent_kitty_socks)
  [[ "$seen" -eq 1 ]] || echo "      · no kitty process active"

  # each agent, and what it holds
  local name sock
  for name in desktop yubikey; do
    sock="$(__ssh_agent_sock_of "$name")"
    echo ""
    echo "── agent: $name ($sock)"
    __ssh_agent_keys_of "$sock"
  done
  echo "      unit yubikey-agent.service: $(__ssh_agent_yubikey_unit_state)"
  [[ -z "$bridge_note" ]] || \
    echo "      ⇒ the yubikey path is a bridge to the desktop agent; undo: rhx ssh.agent.set --to yubikey"

  echo ""
  echo "🌲 done — a file key (~/.ssh/id_*) is kept unlocked only by the desktop agent"
  return 0
}

main "$@"
