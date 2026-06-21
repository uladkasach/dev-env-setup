#!/usr/bin/env bash
######################################################################
# .what = termwork — terminal window management via kitty IPC
# .why  = open visible terminals for humans, composable with ductwork
#
# usage:
#   term.open --via kitty                     # open kitty with shell
#   term.open --via kitty --cwd /path         # open in directory
#   term.open --via kitty --on work           # attach to local duct
#   term.open --via kitty --on user@host:work # attach to remote duct (cloud)
#   term.open --via kitty --pid 12345         # focus terminal
#   term.stop --via kitty --on work           # stop terminal by duct name
#   term.stop --via kitty --on user@host:work # stop terminal by remote duct
#   term.stop --via kitty --pid 12345         # stop terminal by pid
#   term.read --via kitty --on work           # read terminal by duct name
#   term.read --via kitty --on user@host:work # read terminal by remote duct
#   term.read --via kitty --pid 12345         # read terminal by pid
#   term.send --via kitty --on work --what "cmd"           # send by duct name
#   term.send --via kitty --on user@host:work --what "cmd" # send to remote duct
#   term.send --via kitty --pid 12345 --what "cmd"         # send by pid
#   term.list --via kitty                     # list open terminals
#
# remote ducts:
#   - use ductwork to create remote session: duct.open --on user@host:work
#   - use termwork to attach local window:   term.open --via kitty --on user@host:work
#   - kitty runs locally, ssh tunnels to remote tmux session
#   - ctrl+x d detaches locally, remote session continues
#
# namespaces:
#   duct.* = session management (tmux, local or cloud)
#   term.* = window management (kitty, always local)
#
# requires: kitty (sudo apt install kitty)
######################################################################

__term_ensure_dir() {
  TERMWORK_DIR="${TERMWORK_DIR:-$HOME/.termwork}"
  mkdir -p "$TERMWORK_DIR"
}

# parse duct slug into host and session
# e.g., "user@host:work" -> TERM_HOST="user@host", TERM_SESSION="work"
# e.g., "work" -> TERM_HOST="", TERM_SESSION="work"
__term_parse_duct_slug() {
  local slug="$1"
  if [[ "$slug" == *:* ]]; then
    TERM_HOST="${slug%:*}"
    TERM_SESSION="${slug#*:}"
  else
    TERM_HOST=""
    TERM_SESSION="$slug"
  fi
}

__term_is_remote() {
  [[ -n "$TERM_HOST" ]]
}

__term_register() {
  local pid="$1"
  local socket="$2"
  local cwd="$3"
  local duct="$4"
  local host="$5"
  __term_ensure_dir
  cat > "$TERMWORK_DIR/$pid.json" <<EOF
{
  "pid": $pid,
  "socket": "$socket",
  "cwd": "$cwd",
  "duct": "$duct",
  "host": "$host",
  "startedAt": $(date +%s)000
}
EOF
}

__term_unregister() {
  __term_ensure_dir
  local pid="$1"
  rm -f "$TERMWORK_DIR/$pid.json"
}

__term_find_by_duct() {
  local slug="$1"
  __term_ensure_dir

  # parse the slug to match against stored duct+host
  __term_parse_duct_slug "$slug"
  local want_host="$TERM_HOST"
  local want_session="$TERM_SESSION"

  local f d h pid
  while IFS= read -r -d '' f; do
    [[ -f "$f" ]] || continue
    d=$(jq -r '.duct // ""' "$f" 2>/dev/null)
    h=$(jq -r '.host // ""' "$f" 2>/dev/null)
    if [[ "$d" == "$want_session" && "$h" == "$want_host" ]]; then
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
  # return 0 even when not found — empty output is valid, not an error
  # (return 1 breaks scripts with set -euo pipefail)
  return 0
}

__term_get_socket() {
  __term_ensure_dir
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
    socket=$(__term_get_socket "$pid")
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
    extant_pid=$(__term_find_by_duct "$duct")
    if [[ -n "$extant_pid" ]]; then
      echo "🖥️  term://$duct found (pid $extant_pid)"
      term.open --via kitty --pid "$extant_pid"
      return 0
    fi
  fi

  # parse duct slug for remote support
  local duct_host=""
  local duct_session=""
  if [[ -n "$duct" ]]; then
    __term_parse_duct_slug "$duct"
    duct_host="$TERM_HOST"
    duct_session="$TERM_SESSION"
  fi

  # spawn kitty with remote control
  # use {kitty_pid} placeholder - kitty expands this to its actual PID
  if [[ -n "$duct" ]]; then
    if [[ -n "$duct_host" ]]; then
      # remote duct: ssh to host and attach to tmux session
      kitty \
        -o "allow_remote_control=yes" \
        -o "listen_on=unix:/tmp/kitty-{kitty_pid}" \
        --detach \
        --directory "$cwd" \
        -e ssh -t "$duct_host" "tmux attach-session -t '$duct_session'"
    else
      # local duct: attach to tmux session via interactive login shell
      kitty \
        -o "allow_remote_control=yes" \
        -o "listen_on=unix:/tmp/kitty-{kitty_pid}" \
        --detach \
        --directory "$cwd" \
        -e "$shell" -l -i -c "tmux attach-session -t '$duct_session'"
    fi
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
  __term_register "$pid" "$socket" "$cwd" "$duct_session" "$duct_host"

  if [[ -n "$duct" ]]; then
    if [[ -n "$duct_host" ]]; then
      echo "🖥️  term://$duct opened (pid $pid, cloud)"
    else
      echo "🖥️  term://$duct opened (pid $pid, local)"
    fi
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
    pid=$(__term_find_by_duct "$duct")
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
  socket=$(__term_get_socket "$pid")
  if [[ -z "$socket" ]]; then
    echo "✋ term.stop: terminal $pid not found" >&2
    return 2
  fi

  if ! kitten @ --to "$socket" close-window 2>/dev/null; then
    # process might already be dead
    __term_unregister "$pid"
    echo "🖥️  term $pid already stopped"
    return 0
  fi

  __term_unregister "$pid"
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
    pid=$(__term_find_by_duct "$duct")
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
  socket=$(__term_get_socket "$pid")
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
    pid=$(__term_find_by_duct "$duct")
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
  socket=$(__term_get_socket "$pid")
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

  __term_ensure_dir

  local found=0
  local f pid cwd duct host started socket ts slug

  while IFS= read -r -d '' f; do
    [[ -f "$f" ]] || continue

    pid=$(jq -r '.pid' "$f" 2>/dev/null)
    cwd=$(jq -r '.cwd' "$f" 2>/dev/null)
    duct=$(jq -r '.duct // ""' "$f" 2>/dev/null)
    host=$(jq -r '.host // ""' "$f" 2>/dev/null)
    started=$(jq -r '.startedAt' "$f" 2>/dev/null)
    socket=$(jq -r '.socket' "$f" 2>/dev/null)

    # check if process still alive
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$f"
      continue
    fi

    found=1
    ts=$(date -d "@$((started / 1000))" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$started")

    # reconstruct full slug for display
    if [[ -n "$host" ]]; then
      slug="$host:$duct"
    else
      slug="$duct"
    fi

    echo ""
    if [[ -n "$duct" ]]; then
      echo "🖥️  term://$slug"
    else
      echo "🖥️  term://shell"
    fi
    echo "   ├─ pid: $pid"
    echo "   ├─ cwd: $cwd"
    if [[ -n "$duct" ]]; then
      echo "   ├─ duct: $slug"
      if [[ -n "$host" ]]; then
        echo "   ├─ host: $host (cloud)"
      else
        echo "   ├─ host: localhost (local)"
      fi
    fi
    echo "   └─ opened: $ts"
  done < <(find "$TERMWORK_DIR" -maxdepth 1 -name '*.json' -print0 2>/dev/null)

  if [[ $found -eq 0 ]]; then
    echo "🖥️  (none)"
  fi
}
