#!/usr/bin/env bash
######################################################################
# .what = ductwork — headless terminal streams via tmux
# .why  = start headless, attach later, send commands, read logs
#
# usage:
#   duct.open --on work                      # findsert headless
#   duct.open --on work --mode headfull      # findsert + attach (ctrl+x d to detach)
#   duct.send --on work --what "npm run build"
#   duct.read --on work | tail -100
#   duct.list
#
# requires: tmux (sudo apt install tmux)
######################################################################

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

  # findsert: create if not extant
  if ! tmux has-session -t "$slug" 2>/dev/null; then
    if ! tmux new-session -d -s "$slug"; then
      echo "💥 duct.open: failed to create session '$slug'" >&2
      return 1
    fi
    echo "🔧 duct://$slug created"
  else
    echo "🔧 duct://$slug found"
  fi

  # attach if headfull
  if [[ "$mode" == "headfull" ]]; then
    echo "🔧 duct://$slug attach (ctrl+x d to detach)"
    tmux attach -t "$slug"
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

  if ! tmux has-session -t "$slug" 2>/dev/null; then
    echo "✋ duct.send: session '$slug' not found" >&2
    return 2
  fi

  if ! tmux send-keys -t "$slug" "$what" Enter; then
    echo "💥 duct.send: failed to send to '$slug'" >&2
    return 1
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

  if ! tmux has-session -t "$slug" 2>/dev/null; then
    echo "✋ duct.read: session '$slug' not found" >&2
    return 2
  fi

  echo "🔭 duct://$slug"
  # capture scrollback buffer (clean, no escape sequences)
  tmux capture-pane -t "$slug" -p -S "-$lines"
}

duct.list() {
  local sessions
  sessions=$(tmux list-sessions -F "#{session_name}|#{session_created}" 2>/dev/null)
  if [[ -z "$sessions" ]]; then
    echo "🔧 (none)"
    return
  fi

  echo "$sessions" | while IFS='|' read -r name created; do
    local ts=$(date -d "@$created" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$created")
    echo ""
    echo "🔧 $name"
    echo "   ├─ uri: duct://$name"
    echo "   └─ opened: $ts"
  done
}
