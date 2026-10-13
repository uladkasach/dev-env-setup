#!/usr/bin/env bash
######################################################################
# .what = point tmux's SSH_AUTH_SOCK at the desktop agent or yubikey-agent
#         — and, with --bridge, every process that already names yubikey's path
#
# .why  = tmux hands its own copy of SSH_AUTH_SOCK to every new pane — a global
#         copy, and a per-session copy that overrides it — so a server started
#         while a shell named yubikey-agent keeps that agent for every pane after,
#         and every file-key connection then asks for a passphrase.
#
#         a skill cannot change a LIVE process's env. but a live process holds a
#         PATH, never an agent: --bridge stops yubikey-agent and puts a symlink
#         to the desktop agent at its socket path, so every shell, claude, and
#         kitty that names that path reaches the desktop agent on its next call
#         — no restart. `--to yubikey` removes the bridge and restarts the agent
#
# usage:
#   rhx ssh.agent.set --to desktop
#   rhx ssh.agent.set --to desktop --bridge
#   rhx ssh.agent.set --to yubikey
#
# guarantee:
#   - idempotent: a tmux, session, or bridge already in place is left as is
#   - refuses an agent whose socket is absent (exit 2), never sets a dead path
#   - the bridge lasts until the next login; yubikey-agent starts afresh then
#   - the bridge is proven: it lists the desktop agent's keys through the path
######################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ssh.agent.operations.sh"

__ssh_agent_set_help() {
  cat <<'HELP'
🔑 ssh.agent.set — point tmux's SSH_AUTH_SOCK at one ssh agent

  usage:
    rhx ssh.agent.set --to desktop [--bridge]
    rhx ssh.agent.set --to yubikey

  options:
    --to      desktop = holds file keys (~/.ssh/id_*), unlocks once per login
              yubikey = serves the YubiKey key only
    --bridge  (with --to desktop) also redirect yubikey-agent's socket PATH to
              the desktop agent, so processes started before the fix reach it
              with no restart. lasts until the next login. undo: --to yubikey

  sets tmux's global and per-session env, so every NEW pane inherits it
HELP
}

# .what = the systemd user unit that serves the yubikey socket
YUBIKEY_UNIT='yubikey-agent.service'

# .what = stop yubikey-agent and symlink its socket path to the desktop agent
__ssh_agent_bridge_set() {
  local ysock dsock
  ysock="$(__ssh_agent_sock_of yubikey)"; dsock="$(__ssh_agent_sock_of desktop)"

  if __ssh_agent_is_bridged; then
    echo "   ├─ bridge: [KEEP] $ysock → $dsock"
    return 0
  fi

  # stop the agent, so no process re-creates the socket under the symlink
  if ! timeout 15 systemctl --user stop "$YUBIKEY_UNIT"; then
    echo "💥 MalfunctionError: could not stop $YUBIKEY_UNIT" >&2
    return 1
  fi

  # a stopped agent can leave its socket file behind; only a socket or a link is removed
  if [[ -S "$ysock" || -L "$ysock" ]]; then
    rm -f "$ysock" || { echo "💥 MalfunctionError: could not clear $ysock" >&2; return 1; }
  elif [[ -e "$ysock" ]]; then
    echo "✋ ConstraintError: $ysock is neither a socket nor a link — left untouched" >&2
    return 2
  fi
  mkdir -p "$(dirname "$ysock")"
  ln -s "$dsock" "$ysock" || { echo "💥 MalfunctionError: could not link $ysock" >&2; return 1; }

  # prove it: the desktop agent answers through the old path
  local rc=0
  SSH_AUTH_SOCK="$ysock" timeout 5 ssh-add -l >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -gt 1 ]]; then
    echo "💥 MalfunctionError: the bridge is in place and no agent answers through it (ssh-add exit $rc)" >&2
    return 1
  fi
  echo "   ├─ bridge: $YUBIKEY_UNIT stopped; $ysock → $dsock ✔ (agent answers)"
}

# .what = remove the bridge and restart yubikey-agent at its own path
__ssh_agent_bridge_del() {
  local ysock dsock
  ysock="$(__ssh_agent_sock_of yubikey)"; dsock="$(__ssh_agent_sock_of desktop)"
  __ssh_agent_is_bridged || return 0

  rm -f "$ysock" || { echo "💥 MalfunctionError: could not remove the bridge at $ysock" >&2; return 1; }
  if ! timeout 15 systemctl --user start "$YUBIKEY_UNIT"; then
    echo "💥 MalfunctionError: bridge removed, and $YUBIKEY_UNIT would not start" >&2
    return 1
  fi
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do [[ -S "$ysock" ]] && break; sleep 0.5; done
  [[ -S "$ysock" ]] || { echo "💥 MalfunctionError: $YUBIKEY_UNIT started and serves no socket at $ysock" >&2; return 1; }
  echo "   ├─ bridge: removed; $YUBIKEY_UNIT serves $ysock again"
}

main() {
  local to="" bridge=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --to) to="${2:-}"; shift 2 ;;
      --bridge) bridge=1; shift ;;
      --help|-h) __ssh_agent_set_help; return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      *) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   fix: rhx ssh.agent.set --help" >&2; return 2 ;;
    esac
  done

  if [[ "$to" != desktop && "$to" != yubikey ]]; then
    echo "✋ ConstraintError: --to must be desktop or yubikey (got '${to:-none}')" >&2
    echo "   fix: rhx ssh.agent.set --to desktop" >&2
    return 2
  fi
  if [[ "$bridge" -eq 1 && "$to" != desktop ]]; then
    echo "✋ ConstraintError: --bridge redirects TO the desktop agent; it pairs with --to desktop" >&2
    echo "   fix: rhx ssh.agent.set --to desktop --bridge" >&2
    return 2
  fi

  echo "🔑 ssh.agent.set --to $to$([[ "$bridge" -eq 1 ]] && echo ' --bridge')"

  # a return to yubikey first restores its own socket
  if [[ "$to" == yubikey ]]; then __ssh_agent_bridge_del || return $?; fi

  local sock; sock="$(__ssh_agent_sock_of "$to")"
  if [[ ! -S "$sock" ]]; then
    echo "✋ ConstraintError: the $to agent serves no socket at $sock" >&2
    echo "   fix: start it, then retry — desktop: log in to the desktop session;" >&2
    echo "        yubikey: rhx grove.provision --what 5.9.yubikey --mode apply" >&2
    return 2
  fi

  # tmux's global copy — what a new pane inherits where its session holds none
  local before rc=0
  before="$(__ssh_agent_tmux_sock)" || rc=$?
  if [[ "$rc" -eq 2 ]]; then
    echo "   ├─ tmux: no server active — a new tmux inherits its shell's value"
  elif [[ "$rc" -eq 0 && "$before" == "$sock" ]]; then
    echo "   ├─ tmux: [KEEP] already $sock"
  else
    if ! timeout 5 tmux set-environment -g SSH_AUTH_SOCK "$sock"; then
      echo "💥 MalfunctionError: tmux refused set-environment" >&2
      return 1
    fi
    echo "   ├─ tmux: ${before:-unset} → $sock"
  fi

  # each session's own copy — it overrides the global for that session's new panes
  local s v changed=0 kept=0
  while IFS=$'\t' read -r s v; do
    [[ -n "$s" ]] || continue
    if [[ "$v" == "-" || "$v" == "$sock" ]]; then kept=$(( kept + 1 )); continue; fi
    if ! timeout 5 tmux set-environment -t "$s" SSH_AUTH_SOCK "$sock"; then
      echo "💥 MalfunctionError: tmux refused set-environment for session '$s'" >&2
      return 1
    fi
    changed=$(( changed + 1 ))
  done < <(__ssh_agent_tmux_session_socks)
  [[ "$changed" -gt 0 || "$kept" -gt 0 ]] && \
    echo "   ├─ tmux sessions: $changed repointed, $kept already right"

  # the path every live process holds
  if [[ "$bridge" -eq 1 ]]; then __ssh_agent_bridge_set || return $?; fi

  # the caller's own shell — a child cannot change its env
  echo "   └─ this shell keeps its own value. to switch it now, paste:"
  echo "        export SSH_AUTH_SOCK=$sock"
  return 0
}

main "$@"
