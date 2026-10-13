#!/usr/bin/env bash
######################################################################
# .what = shared operations for the ssh.agent.* skills
#
# .why  = ssh speaks to ONE agent — the one SSH_AUTH_SOCK names — and this
#         laptop runs two: the desktop agent (holds file keys, unlocks them
#         once per login) and yubikey-agent (serves the YubiKey key only).
#         get and set must name the two sockets the same way, or they drift
#
# usage:
#   source "$SCRIPT_DIR/ssh.agent.operations.sh"
######################################################################

__ssh_agent_rundir() { echo "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"; }

# .what = the socket each named agent serves
# .note = the desktop agent is gcr-ssh-agent; older gnome-keyring used keyring/ssh
__ssh_agent_sock_of() {
  local rundir; rundir="$(__ssh_agent_rundir)"
  case "$1" in
    desktop)
      if [[ -S "$rundir/gcr/ssh" ]]; then echo "$rundir/gcr/ssh"; return 0; fi
      if [[ -S "$rundir/keyring/ssh" ]]; then echo "$rundir/keyring/ssh"; return 0; fi
      echo "$rundir/gcr/ssh"
      ;;
    yubikey) echo "$rundir/yubikey-agent/yubikey-agent.sock" ;;
    *) return 2 ;;
  esac
}

# .what = which named agent a socket path belongs to
__ssh_agent_name_of() {
  local sock="$1"
  [[ -z "$sock" ]] && { echo "unset"; return 0; }
  [[ "$sock" == "$(__ssh_agent_sock_of yubikey)" ]] && { echo "yubikey"; return 0; }
  [[ "$sock" == */gcr/ssh || "$sock" == */keyring/ssh ]] && { echo "desktop"; return 0; }
  echo "other"
}

# .what = each tmux session's own SSH_AUTH_SOCK, one `<session>\t<value>` line per session
# .note = a session value OVERRIDES the global one for that session's new panes, and tmux's
#         default update-environment re-copies it from every client that attaches. "-" = none set
__ssh_agent_tmux_session_socks() {
  command -v tmux >/dev/null 2>&1 || return 0
  local s v
  while IFS= read -r s; do
    [[ -n "$s" ]] || continue
    v="$(timeout 5 tmux show-environment -t "$s" SSH_AUTH_SOCK 2>/dev/null)"
    [[ "$v" == SSH_AUTH_SOCK=* ]] && v="${v#SSH_AUTH_SOCK=}" || v="-"
    printf '%s\t%s\n' "$s" "$v"
  done < <(timeout 5 tmux list-sessions -F '#{session_name}' 2>/dev/null)
}

# .what = each tmux pane's shell SSH_AUTH_SOCK, read off its /proc environ
# .note = one `<pane>\t<pid>\t<foreground command>\t<value>` line per pane; "-" = unset
__ssh_agent_tmux_pane_socks() {
  command -v tmux >/dev/null 2>&1 || return 0
  local pane pid cmd v
  while IFS=$'\t' read -r pane pid cmd; do
    [[ -n "$pane" ]] || continue
    v="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^SSH_AUTH_SOCK=//p')"
    printf '%s\t%s\t%s\t%s\n' "$pane" "$pid" "$cmd" "${v:--}"
  done < <(timeout 5 tmux list-panes -a -F $'#{session_name}:#{window_index}.#{pane_index}\t#{pane_pid}\t#{pane_current_command}' 2>/dev/null)
}

# .what = the SSH_AUTH_SOCK each active kitty process started with — every new window inherits it
__ssh_agent_kitty_socks() {
  local pid v
  for pid in $(pgrep -u "$(id -u)" kitty 2>/dev/null); do
    v="$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^SSH_AUTH_SOCK=//p')"
    printf '%s\t%s\t%s\n' "$pid" "$(cat "/proc/$pid/comm" 2>/dev/null)" "${v:--}"
  done
}

# .what = the SSH_AUTH_SOCK tmux hands to new panes, three-valued
# .note = prints the value; returns 0 = read, 1 = tmux holds none, 2 = no tmux server
__ssh_agent_tmux_sock() {
  command -v tmux >/dev/null 2>&1 || return 2
  local line rc=0
  line="$(timeout 5 tmux show-environment -g SSH_AUTH_SOCK 2>/dev/null)" || rc=$?
  [[ "$rc" -ne 0 ]] && { timeout 5 tmux list-sessions >/dev/null 2>&1 && return 1 || return 2; }
  [[ "$line" == -* ]] && return 1
  echo "${line#SSH_AUTH_SOCK=}"
}

# .what = is the yubikey socket path a symlink to the desktop agent? (ssh.agent.set --bridge)
__ssh_agent_is_bridged() {
  local ysock dsock
  ysock="$(__ssh_agent_sock_of yubikey)"; dsock="$(__ssh_agent_sock_of desktop)"
  [[ -L "$ysock" && "$(readlink "$ysock")" == "$dsock" ]]
}

# .what = the yubikey-agent unit's active state: active, inactive, failed, ...
__ssh_agent_yubikey_unit_state() {
  local state
  state="$(timeout 5 systemctl --user is-active yubikey-agent.service 2>/dev/null)"
  echo "${state:-unknown}"
}
