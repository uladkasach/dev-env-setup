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
#   duct.list                                # list all ducts (from cache)
#   duct.list --on user@host                 # list ducts on specific host
#   duct.list --refresh                      # refresh cache from all hosts
#   duct.host.add user@host                  # register a host
#   duct.host.del user@host                  # unregister a host
#   duct.host.list                           # list hosts
#
# requires: tmux (sudo apt install tmux)
######################################################################

######################################################################
# registry: ~/.ductwork/hosts/{host}.json and ~/.ductwork/ducts/{session}.json
######################################################################

__duct_ensure_dirs() {
  DUCTWORK_DIR="${DUCTWORK_DIR:-$HOME/.ductwork}"
  mkdir -p "$DUCTWORK_DIR/hosts"
  mkdir -p "$DUCTWORK_DIR/ducts"
}

__duct_register_host() {
  local host="$1"
  __duct_ensure_dirs
  local file="$DUCTWORK_DIR/hosts/$host.json"
  local now
  now=$(date +%s)
  cat > "$file" <<EOF
{
  "lastSeen": ${now}000
}
EOF
}

__duct_unregister_host() {
  local host="$1"
  __duct_ensure_dirs
  rm -f "$DUCTWORK_DIR/hosts/$host.json"
}

__duct_register_duct() {
  local session="$1"
  local host="$2"
  __duct_ensure_dirs
  local file="$DUCTWORK_DIR/ducts/$session.json"
  # session may contain a slash (e.g. treename/role) -> nested path;
  # create the parent dir so the registry write does not fail
  mkdir -p "$(dirname "$file")"
  local now
  now=$(date +%s)
  cat > "$file" <<EOF
{
  "host": "$host",
  "createdAt": ${now}000
}
EOF
}

__duct_unregister_duct() {
  local session="$1"
  __duct_ensure_dirs
  local file="$DUCTWORK_DIR/ducts/$session.json"
  rm -f "$file"
  # session may be nested (treename/role) -> remove the now-empty parent dir
  rmdir --ignore-fail-on-non-empty "$(dirname "$file")" 2>/dev/null || true
}

__duct_get_duct_host() {
  local session="$1"
  __duct_ensure_dirs
  local file="$DUCTWORK_DIR/ducts/$session.json"
  if [[ -f "$file" ]]; then
    jq -r '.host // ""' "$file" 2>/dev/null
  fi
}

# parse slug into host and session
# e.g., "user@host:work" -> host="user@host", session="work"
# e.g., "work" -> host="", session="work"
__duct_parse_slug() {
  local slug="$1"
  if [[ "$slug" == *:* ]]; then
    DUCT_HOST="${slug%:*}"
    DUCT_SESSION="${slug#*:}"
  else
    DUCT_HOST=""
    DUCT_SESSION="$slug"
  fi
}

__duct_is_remote() {
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

  __duct_parse_slug "$slug"

  if __duct_is_remote; then
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

    # register host + duct
    __duct_register_host "$DUCT_HOST"
    __duct_register_duct "$DUCT_SESSION" "$DUCT_HOST"

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

    # register duct (localhost)
    __duct_register_duct "$DUCT_SESSION" "localhost"

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

  __duct_parse_slug "$slug"

  if __duct_is_remote; then
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

  __duct_parse_slug "$slug"

  if __duct_is_remote; then
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

__duct_list_host_sessions() {
  local host="$1"
  if [[ "$host" == "localhost" ]]; then
    tmux list-sessions -F "#{session_name}" 2>/dev/null
  else
    ssh "$host" "tmux list-sessions -F '#{session_name}'" 2>/dev/null
  fi
}

__duct_refresh_host() {
  local host="$1"
  __duct_ensure_dirs

  # update host lastSeen
  if [[ "$host" != "localhost" ]]; then
    __duct_register_host "$host"
  fi

  # get live sessions
  local sessions
  sessions=$(__duct_list_host_sessions "$host")

  # register each session
  local session
  while IFS= read -r session; do
    [[ -z "$session" ]] && continue
    __duct_register_duct "$session" "$host"
  done <<< "$sessions"

  # remove stale ducts for this host
  # recurse: ducts may be nested (ducts/tree/role.json) when session holds a
  # slash; derive session as the path relative to ducts/ so the tree prefix is
  # kept and the grep comparison against live sessions matches
  local f duct_session duct_host
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    duct_host=$(jq -r '.host // ""' "$f" 2>/dev/null)
    [[ "$duct_host" != "$host" ]] && continue
    duct_session="${f#"$DUCTWORK_DIR"/ducts/}"
    duct_session="${duct_session%.json}"
    if ! echo "$sessions" | grep -qxF "$duct_session"; then
      rm -f "$f"
      rmdir --ignore-fail-on-non-empty "$(dirname "$f")" 2>/dev/null || true
    fi
  done < <(find "$DUCTWORK_DIR/ducts" -type f -name '*.json' 2>/dev/null)
}

duct.list() {
  local host=""
  local refresh=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on) host="$2"; shift 2 ;;
      --refresh) refresh="1"; shift ;;
      *) echo "✋ duct.list: unknown arg '$1'" >&2; return 2 ;;
    esac
  done

  __duct_ensure_dirs

  # if --on specified, just query that host
  if [[ -n "$host" ]]; then
    if [[ -n "$refresh" ]]; then
      __duct_refresh_host "$host"
    fi
    local sessions
    sessions=$(__duct_list_host_sessions "$host")
    if [[ -z "$sessions" ]]; then
      echo "📡 $host"
      echo "   └─ (none)"
      return
    fi
    echo "📡 $host"
    echo "$sessions" | while IFS= read -r name; do
      echo "   ├─ $name"
    done
    return
  fi

  # refresh all hosts if requested
  if [[ -n "$refresh" ]]; then
    # refresh localhost
    __duct_refresh_host "localhost"
    # refresh remote hosts
    local f h
    for f in "$DUCTWORK_DIR"/hosts/*.json; do
      [[ -f "$f" ]] || continue
      h=$(basename "$f" .json)
      __duct_refresh_host "$h"
    done
  fi

  # group ducts by host from cache
  local -A host_ducts
  local f duct_host duct_session
  # recurse: ducts may be nested (ducts/tree/role.json) when session holds a slash;
  # derive session as the path relative to ducts/ so the tree prefix is kept
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    duct_host=$(jq -r '.host // "localhost"' "$f" 2>/dev/null)
    duct_session="${f#"$DUCTWORK_DIR"/ducts/}"
    duct_session="${duct_session%.json}"
    if [[ -n "${host_ducts[$duct_host]:-}" ]]; then
      host_ducts[$duct_host]="${host_ducts[$duct_host]}|$duct_session"
    else
      host_ducts[$duct_host]="$duct_session"
    fi
  done < <(find "$DUCTWORK_DIR/ducts" -type f -name '*.json' 2>/dev/null)

  # empty assoc array is safe to probe via values expansion with :- default
  if [[ -z "${host_ducts[*]:-}" ]]; then
    echo "📡 (none)"
    return
  fi

  # print grouped by host
  local h sessions_str
  for h in "${!host_ducts[@]}"; do
    echo "📡 $h"
    sessions_str="${host_ducts[$h]}"
    echo "$sessions_str" | tr '|' '\n' | while IFS= read -r name; do
      echo "   ├─ $name"
    done
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

  __duct_parse_slug "$slug"

  if __duct_is_remote; then
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

  # unregister duct
  __duct_unregister_duct "$DUCT_SESSION"

  echo "🔧 duct://$slug stopped"
}

duct.host.add() {
  local host="$1"
  if [[ -z "$host" ]]; then
    echo "✋ duct.host.add: host required" >&2
    return 2
  fi
  __duct_register_host "$host"
  echo "📡 host $host added"
}

duct.host.del() {
  local host="$1"
  if [[ -z "$host" ]]; then
    echo "✋ duct.host.del: host required" >&2
    return 2
  fi
  __duct_ensure_dirs

  # remove host
  __duct_unregister_host "$host"

  # remove ducts for this host
  # recurse so nested ducts (ducts/tree/role.json) are found too
  local f duct_host
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    duct_host=$(jq -r '.host // ""' "$f" 2>/dev/null)
    if [[ "$duct_host" == "$host" ]]; then
      rm -f "$f"
      rmdir --ignore-fail-on-non-empty "$(dirname "$f")" 2>/dev/null || true
    fi
  done < <(find "$DUCTWORK_DIR/ducts" -type f -name '*.json' 2>/dev/null)

  echo "📡 host $host removed"
}

duct.host.list() {
  __duct_ensure_dirs

  local found=0
  local f h lastSeen ts

  # always show localhost
  echo "📡 localhost (local)"
  found=1

  for f in "$DUCTWORK_DIR"/hosts/*.json; do
    [[ -f "$f" ]] || continue
    h=$(basename "$f" .json)
    lastSeen=$(jq -r '.lastSeen // 0' "$f" 2>/dev/null)
    ts=$(date -d "@$((lastSeen / 1000))" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
    echo "📡 $h (last seen: $ts)"
    found=1
  done

  if [[ $found -eq 0 ]]; then
    echo "📡 (no hosts)"
  fi
}
