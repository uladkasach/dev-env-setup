#!/usr/bin/env bash
######################################################################
# .what = ductwork — headless terminal streams via tmux
# .why  = start headless, attach later, send commands, read logs
#
# usage:
#   duct.open --on work                      # local: findsert headless
#   duct.open --on work --mode headfull      # local: findsert + attach (ctrl+x d to detach)
#   duct.open --on user@host:work            # remote: findsert headless
#   duct.open --on user@host:work --mode headfull  # remote: ssh + attach
#   duct.send --on work --what "npm run build"
#   duct.send --on user@host:work --what "npm run build"
#   duct.read --on work
#   duct.read --on user@host:work
#   duct.stop --on work                      # kill session
#   duct.stop --on user@host:work
#   duct.list                                # local sessions
#   duct.list --on user@host                 # remote sessions
#
# requires: tmux (sudo apt install tmux)
######################################################################

# parse slug into host and session
# e.g., "user@host:work" -> host="user@host", session="work"
# e.g., "work" -> host="", session="work"
_duct_parse_slug() {
  local slug="$1"
  if [[ "$slug" == *:* ]]; then
    DUCT_HOST="${slug%:*}"
    DUCT_SESSION="${slug#*:}"
  else
    DUCT_HOST=""
    DUCT_SESSION="$slug"
  fi
}

_duct_is_remote() {
  [[ -n "$DUCT_HOST" ]]
}

duct.open() {
  local slug=""
  local mode="headless"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on) slug="$2"; shift 2 ;;
      --mode) mode="$2"; shift 2 ;;
      *) echo "✋ duct.open: unknown arg '$1'" >&2; return 2 ;;
    esac
  done
  if [[ -z "$slug" ]]; then
    echo "✋ duct.open: --on required" >&2
    return 2
  fi

  _duct_parse_slug "$slug"

  if _duct_is_remote; then
    # remote: ssh to create/attach
    if ! ssh "$DUCT_HOST" "tmux has-session -t '$DUCT_SESSION' 2>/dev/null"; then
      if ! ssh "$DUCT_HOST" "tmux new-session -d -s '$DUCT_SESSION'"; then
        echo "💥 duct.open: failed to create remote session '$slug'" >&2
        return 1
      fi
      echo "🔧 duct://$slug created (cloud)"
    else
      echo "🔧 duct://$slug found (cloud)"
    fi

    if [[ "$mode" == "headfull" ]]; then
      echo "🔧 duct://$slug attach (ctrl+x d to detach)"
      ssh -t "$DUCT_HOST" "tmux attach -t '$DUCT_SESSION'"
    fi
  else
    # local
    if ! tmux has-session -t "$DUCT_SESSION" 2>/dev/null; then
      if ! tmux new-session -d -s "$DUCT_SESSION"; then
        echo "💥 duct.open: failed to create session '$slug'" >&2
        return 1
      fi
      echo "🔧 duct://$slug created (local)"
    else
      echo "🔧 duct://$slug found (local)"
    fi

    if [[ "$mode" == "headfull" ]]; then
      echo "🔧 duct://$slug attach (ctrl+x d to detach)"
      tmux attach -t "$DUCT_SESSION"
    fi
  fi
}

duct.send() {
  local slug=""
  local what=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on) slug="$2"; shift 2 ;;
      --what) what="$2"; shift 2 ;;
      *) echo "✋ duct.send: unknown arg '$1'" >&2; return 2 ;;
    esac
  done
  if [[ -z "$slug" ]]; then
    echo "✋ duct.send: --on required" >&2
    return 2
  fi
  if [[ -z "$what" ]]; then
    echo "✋ duct.send: --what required" >&2
    return 2
  fi

  _duct_parse_slug "$slug"

  if _duct_is_remote; then
    if ! ssh "$DUCT_HOST" "tmux has-session -t '$DUCT_SESSION' 2>/dev/null"; then
      echo "✋ duct.send: session '$slug' not found" >&2
      return 2
    fi
    if ! ssh "$DUCT_HOST" "tmux send-keys -t '$DUCT_SESSION' '$what' Enter"; then
      echo "💥 duct.send: failed to send to '$slug'" >&2
      return 1
    fi
  else
    if ! tmux has-session -t "$DUCT_SESSION" 2>/dev/null; then
      echo "✋ duct.send: session '$slug' not found" >&2
      return 2
    fi
    if ! tmux send-keys -t "$DUCT_SESSION" "$what" Enter; then
      echo "💥 duct.send: failed to send to '$slug'" >&2
      return 1
    fi
  fi
  echo "🔧 duct://$slug sent"
}

duct.read() {
  local slug=""
  local lines=500
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on) slug="$2"; shift 2 ;;
      --lines) lines="$2"; shift 2 ;;
      *) echo "✋ duct.read: unknown arg '$1'" >&2; return 2 ;;
    esac
  done
  if [[ -z "$slug" ]]; then
    echo "✋ duct.read: --on required" >&2
    return 2
  fi

  _duct_parse_slug "$slug"

  if _duct_is_remote; then
    if ! ssh "$DUCT_HOST" "tmux has-session -t '$DUCT_SESSION' 2>/dev/null"; then
      echo "✋ duct.read: session '$slug' not found" >&2
      return 2
    fi
    echo "🔭 duct://$slug (cloud)"
    ssh "$DUCT_HOST" "tmux capture-pane -t '$DUCT_SESSION' -p -S '-$lines'"
  else
    if ! tmux has-session -t "$DUCT_SESSION" 2>/dev/null; then
      echo "✋ duct.read: session '$slug' not found" >&2
      return 2
    fi
    echo "🔭 duct://$slug (local)"
    tmux capture-pane -t "$DUCT_SESSION" -p -S "-$lines"
  fi
}

duct.list() {
  local host=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on) host="$2"; shift 2 ;;
      *) echo "✋ duct.list: unknown arg '$1'" >&2; return 2 ;;
    esac
  done

  local sessions
  local location

  if [[ -n "$host" ]]; then
    location="cloud"
    sessions=$(ssh "$host" "tmux list-sessions -F '#{session_name}|#{session_created}'" 2>/dev/null)
  else
    location="local"
    sessions=$(tmux list-sessions -F "#{session_name}|#{session_created}" 2>/dev/null)
  fi

  if [[ -z "$sessions" ]]; then
    echo "🔧 ($location: none)"
    return
  fi

  local ts
  echo "$sessions" | while IFS='|' read -r name created; do
    if [[ -n "$host" ]]; then
      ts=$(ssh "$host" "date -d '@$created' '+%Y-%m-%d %H:%M'" 2>/dev/null || echo "$created")
    else
      ts=$(date -d "@$created" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$created")
    fi
    echo ""
    echo "🔧 $name"
    if [[ -n "$host" ]]; then
      echo "   ├─ uri: duct://$host:$name"
      echo "   ├─ host: $host (cloud)"
    else
      echo "   ├─ uri: duct://$name"
      echo "   ├─ host: localhost (local)"
    fi
    echo "   └─ opened: $ts"
  done
}

duct.stop() {
  local slug=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on) slug="$2"; shift 2 ;;
      *) echo "✋ duct.stop: unknown arg '$1'" >&2; return 2 ;;
    esac
  done
  if [[ -z "$slug" ]]; then
    echo "✋ duct.stop: --on required" >&2
    return 2
  fi

  _duct_parse_slug "$slug"

  if _duct_is_remote; then
    if ! ssh "$DUCT_HOST" "tmux has-session -t '$DUCT_SESSION' 2>/dev/null"; then
      echo "✋ duct.stop: session '$slug' not found" >&2
      return 2
    fi
    if ! ssh "$DUCT_HOST" "tmux kill-session -t '$DUCT_SESSION'"; then
      echo "💥 duct.stop: failed to stop '$slug'" >&2
      return 1
    fi
  else
    if ! tmux has-session -t "$DUCT_SESSION" 2>/dev/null; then
      echo "✋ duct.stop: session '$slug' not found" >&2
      return 2
    fi
    if ! tmux kill-session -t "$DUCT_SESSION"; then
      echo "💥 duct.stop: failed to stop '$slug'" >&2
      return 1
    fi
  fi
  echo "🔧 duct://$slug stopped"
}
