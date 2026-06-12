#!/usr/bin/env bash
######################################################################
# .what = termwork — terminal window management via kitty IPC
# .why  = open visible terminals for humans, composable with ductwork
#
# usage:
#   term.open --via kitty                     # open kitty with shell
#   term.open --via kitty --cwd /path         # open in directory
#   term.open --via kitty --on work           # attach to duct session
#   term.open --via kitty --pid 12345         # focus terminal
#   term.stop --via kitty --on work           # stop terminal by duct name
#   term.stop --via kitty --pid 12345         # stop terminal by pid
#   term.read --via kitty --on work           # read terminal by duct name
#   term.read --via kitty --pid 12345         # read terminal by pid
#   term.send --via kitty --on work --what "cmd"   # send by duct name
#   term.send --via kitty --pid 12345 --what "cmd" # send by pid
#   term.list --via kitty                     # list open terminals
#
# namespaces:
#   duct.* = session management (tmux)
#   term.* = window management (kitty)
#
# requires: kitty (sudo apt install kitty)
######################################################################

TERMWORK_DIR="$HOME/.termwork"

_term_ensure_dir() {
  mkdir -p "$TERMWORK_DIR"
}

_term_register() {
  local pid="$1"
  local socket="$2"
  local cwd="$3"
  local duct="$4"
  _term_ensure_dir
  cat > "$TERMWORK_DIR/$pid.json" <<EOF
{
  "pid": $pid,
  "socket": "$socket",
  "cwd": "$cwd",
  "duct": "$duct",
  "startedAt": $(date +%s)000
}
EOF
}

_term_unregister() {
  local pid="$1"
  rm -f "$TERMWORK_DIR/$pid.json"
}

_term_find_by_duct() {
  local duct="$1"
  _term_ensure_dir
  local f d pid
  while IFS= read -r -d '' f; do
    [[ -f "$f" ]] || continue
    d=$(jq -r '.duct // ""' "$f" 2>/dev/null)
    if [[ "$d" == "$duct" ]]; then
      pid=$(jq -r '.pid' "$f" 2>/dev/null)
      # check if process still alive
      if kill -0 "$pid" 2>/dev/null; then
        echo "$pid"
        return 0
      else
        # stale entry, clean up
        rm -f "$f"
      fi
    fi
  done < <(find "$TERMWORK_DIR" -maxdepth 1 -name '*.json' -print0 2>/dev/null)
  return 1
}

_term_get_socket() {
  local pid="$1"
  local f="$TERMWORK_DIR/$pid.json"
  if [[ -f "$f" ]]; then
    jq -r '.socket' "$f" 2>/dev/null
  fi
}

term.open() {
  local via=""
  local cwd=""
  local duct=""
  local pid=""
  local shell="${SHELL:-/bin/bash}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --via) via="$2"; shift 2 ;;
      --cwd) cwd="$2"; shift 2 ;;
      --on) duct="$2"; shift 2 ;;
      --pid) pid="$2"; shift 2 ;;
      --shell) shell="$2"; shift 2 ;;
      *) echo "✋ term.open: unknown arg '$1'" >&2; return 2 ;;
    esac
  done

  if [[ -z "$via" ]]; then
    echo "✋ term.open: --via required (e.g., --via kitty)" >&2
    return 2
  fi

  if [[ "$via" != "kitty" ]]; then
    echo "✋ term.open: unknown terminal '$via' (supported: kitty)" >&2
    return 2
  fi

  # if --pid given, focus that terminal
  if [[ -n "$pid" ]]; then
    local socket
    socket=$(_term_get_socket "$pid")
    if [[ -z "$socket" ]]; then
      echo "✋ term.open: terminal $pid not found" >&2
      return 2
    fi
    if ! kitten @ --to "$socket" focus-window 2>/dev/null; then
      echo "💥 term.open: failed to focus $pid" >&2
      return 1
    fi
    echo "🖥️  term $pid focused"
    return 0
  fi

  # default cwd to current directory
  cwd="${cwd:-$(pwd)}"

  # if duct specified, check for extant terminal
  if [[ -n "$duct" ]]; then
    local extant_pid
    extant_pid=$(_term_find_by_duct "$duct")
    if [[ -n "$extant_pid" ]]; then
      echo "🖥️  term://$duct found (pid $extant_pid)"
      term.open --via kitty --pid "$extant_pid"
      return 0
    fi
  fi

  # spawn kitty with remote control
  # use {kitty_pid} placeholder - kitty expands this to its actual PID
  if [[ -n "$duct" ]]; then
    # attach to tmux session via interactive login shell (sources .zshrc, has PATH)
    kitty \
      -o "allow_remote_control=yes" \
      -o "listen_on=unix:/tmp/kitty-{kitty_pid}" \
      --detach \
      --directory "$cwd" \
      -e "$shell" -l -i -c "tmux attach-session -t '$duct'"
  else
    kitty \
      -o "allow_remote_control=yes" \
      -o "listen_on=unix:/tmp/kitty-{kitty_pid}" \
      --detach \
      --directory "$cwd" \
      -e "$shell"
  fi

  # find the kitty process we just spawned (most recent kitty by start time)
  sleep 0.3
  local pid
  pid=$(pgrep -n kitty)
  if [[ -z "$pid" ]]; then
    echo "💥 term.open: failed to find kitty process" >&2
    return 1
  fi

  # register terminal with file socket path
  local socket="unix:/tmp/kitty-$pid"
  _term_register "$pid" "$socket" "$cwd" "$duct"

  if [[ -n "$duct" ]]; then
    echo "🖥️  term://$duct opened (pid $pid)"
  else
    echo "🖥️  term://shell opened (pid $pid)"
  fi
}

term.stop() {
  local via=""
  local pid=""
  local duct=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --via) via="$2"; shift 2 ;;
      --pid) pid="$2"; shift 2 ;;
      --on) duct="$2"; shift 2 ;;
      *) echo "✋ term.stop: unknown arg '$1'" >&2; return 2 ;;
    esac
  done

  if [[ -z "$via" ]]; then
    echo "✋ term.stop: --via required" >&2
    return 2
  fi

  if [[ "$via" != "kitty" ]]; then
    echo "✋ term.stop: unknown terminal '$via'" >&2
    return 2
  fi

  # lookup pid from duct name
  if [[ -n "$duct" && -z "$pid" ]]; then
    pid=$(_term_find_by_duct "$duct")
    if [[ -z "$pid" ]]; then
      echo "✋ term.stop: no terminal for duct '$duct'" >&2
      return 2
    fi
  fi

  if [[ -z "$pid" ]]; then
    echo "✋ term.stop: --pid or --on required" >&2
    return 2
  fi

  local socket
  socket=$(_term_get_socket "$pid")
  if [[ -z "$socket" ]]; then
    echo "✋ term.stop: terminal $pid not found" >&2
    return 2
  fi

  if ! kitten @ --to "$socket" close-window 2>/dev/null; then
    # process might already be dead
    _term_unregister "$pid"
    echo "🖥️  term $pid already stopped"
    return 0
  fi

  _term_unregister "$pid"
  echo "🖥️  term $pid stopped"
}

term.read() {
  local via=""
  local pid=""
  local duct=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --via) via="$2"; shift 2 ;;
      --pid) pid="$2"; shift 2 ;;
      --on) duct="$2"; shift 2 ;;
      *) echo "✋ term.read: unknown arg '$1'" >&2; return 2 ;;
    esac
  done

  if [[ -z "$via" ]]; then
    echo "✋ term.read: --via required" >&2
    return 2
  fi

  if [[ "$via" != "kitty" ]]; then
    echo "✋ term.read: unknown terminal '$via'" >&2
    return 2
  fi

  # lookup pid from duct name
  if [[ -n "$duct" && -z "$pid" ]]; then
    pid=$(_term_find_by_duct "$duct")
    if [[ -z "$pid" ]]; then
      echo "✋ term.read: no terminal for duct '$duct'" >&2
      return 2
    fi
  fi

  if [[ -z "$pid" ]]; then
    echo "✋ term.read: --pid or --on required" >&2
    return 2
  fi

  local socket
  socket=$(_term_get_socket "$pid")
  if [[ -z "$socket" ]]; then
    echo "✋ term.read: terminal $pid not found" >&2
    return 2
  fi

  kitten @ --to "$socket" get-text 2>/dev/null
}

term.send() {
  local via=""
  local pid=""
  local duct=""
  local what=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --via) via="$2"; shift 2 ;;
      --pid) pid="$2"; shift 2 ;;
      --on) duct="$2"; shift 2 ;;
      --what) what="$2"; shift 2 ;;
      *) echo "✋ term.send: unknown arg '$1'" >&2; return 2 ;;
    esac
  done

  if [[ -z "$via" ]]; then
    echo "✋ term.send: --via required" >&2
    return 2
  fi

  if [[ "$via" != "kitty" ]]; then
    echo "✋ term.send: unknown terminal '$via'" >&2
    return 2
  fi

  # lookup pid from duct name
  if [[ -n "$duct" && -z "$pid" ]]; then
    pid=$(_term_find_by_duct "$duct")
    if [[ -z "$pid" ]]; then
      echo "✋ term.send: no terminal for duct '$duct'" >&2
      return 2
    fi
  fi

  if [[ -z "$pid" ]]; then
    echo "✋ term.send: --pid or --on required" >&2
    return 2
  fi

  if [[ -z "$what" ]]; then
    echo "✋ term.send: --what required" >&2
    return 2
  fi

  local socket
  socket=$(_term_get_socket "$pid")
  if [[ -z "$socket" ]]; then
    echo "✋ term.send: terminal $pid not found" >&2
    return 2
  fi

  # send text followed by Enter
  printf '%s\r' "$what" | kitten @ --to "$socket" send-text --stdin 2>/dev/null
}

term.list() {
  local via=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --via) via="$2"; shift 2 ;;
      *) echo "✋ term.list: unknown arg '$1'" >&2; return 2 ;;
    esac
  done

  if [[ -z "$via" ]]; then
    echo "✋ term.list: --via required" >&2
    return 2
  fi

  if [[ "$via" != "kitty" ]]; then
    echo "✋ term.list: unknown terminal '$via'" >&2
    return 2
  fi

  _term_ensure_dir

  local found=0
  local f pid cwd duct started socket ts

  while IFS= read -r -d '' f; do
    [[ -f "$f" ]] || continue

    pid=$(jq -r '.pid' "$f" 2>/dev/null)
    cwd=$(jq -r '.cwd' "$f" 2>/dev/null)
    duct=$(jq -r '.duct // ""' "$f" 2>/dev/null)
    started=$(jq -r '.startedAt' "$f" 2>/dev/null)
    socket=$(jq -r '.socket' "$f" 2>/dev/null)

    # check if process still alive
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$f"
      continue
    fi

    found=1
    ts=$(date -d "@$((started / 1000))" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$started")

    echo ""
    if [[ -n "$duct" ]]; then
      echo "🖥️  term://$duct"
    else
      echo "🖥️  term://shell"
    fi
    echo "   ├─ pid: $pid"
    echo "   ├─ cwd: $cwd"
    if [[ -n "$duct" ]]; then
      echo "   ├─ duct: $duct"
    fi
    echo "   └─ opened: $ts"
  done < <(find "$TERMWORK_DIR" -maxdepth 1 -name '*.json' -print0 2>/dev/null)

  if [[ $found -eq 0 ]]; then
    echo "🖥️  (none)"
  fi
}
