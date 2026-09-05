#!/usr/bin/env bash
######################################################################
# .what = snapshot open kitty terminals with pwd, program, age, mem
#
# .why  = one-glance map of every open kitty window: where it is,
#         what it runs, how long it's been open, and its memory cost.
#         reads /proc once into memory, so it stays fast.
#
# .security = reads ONLY /proc/<pid>/{stat,statm,cwd} — all
#             owner-readable. never touches kitty remote control,
#             never reads /proc/<pid>/environ (secrets stay unread).
#             keeps allow_remote_control=no fully intact.
#             see .agent/repo=.this/role=any/briefs/creds/rule.require.security-paramount.md
#
# usage:
#   kitty.snapshot.terminals.sh            # human tree (default)
#   kitty.snapshot.terminals.sh --json     # one json object per shell
#
# columns:
#   cwd        working dir of the shell
#   → program  foreground program (terminal foreground process group);
#              tmux windows are walked into their panes, shown as tmux/<cmd>
#   (age)      how long the shell has been open
#   mem=       total resident memory of the whole window subtree
#
# --save persists the snapshot to ~/.kitty/snaps/<timestamp>.{txt,json}
# so a session layout can be recovered/resumed later from the pwds.
######################################################################

set -uo pipefail

SNAP_DIR="$HOME/.kitty/snaps"

MODE="human"
SAVE=0
for arg in "$@"; do
  case "$arg" in
    --json) MODE="json" ;;
    --save) SAVE=1 ;;
  esac
done

PAGE_KB=$(( $(getconf PAGESIZE) / 1024 ))
HZ=$(getconf CLK_TCK)
read -r UPTIME _ < /proc/uptime
UPTIME=${UPTIME%.*}

declare -A COMM PGRP TPGID START RESIDENT CHILDREN TTY
KITTY_PIDS=()

# single pass over /proc: read each process's stat + statm into maps
for d in /proc/[0-9]*; do
  pid=${d#/proc/}
  { read -r line < "$d/stat"; } 2>/dev/null || continue
  # comm sits in parens and may hold spaces; split around the last ')'
  rest=${line#*(}
  comm=${rest%)*}
  tailf=${rest##*) }
  # shellcheck disable=SC2086
  set -- $tailf
  # fields (offset by 2 from the man-page order, which counts pid+comm):
  #   $1 state  $2 ppid  $3 pgrp  $5 tty_nr  $6 tpgid  ${20} starttime
  ppid=$2; pgrp=$3; ttynr=$5; tpgid=$6; starttime=${20}
  COMM[$pid]=$comm
  PGRP[$pid]=$pgrp
  TPGID[$pid]=$tpgid
  TTY[$pid]=$ttynr
  START[$pid]=$starttime
  CHILDREN[$ppid]+=" $pid"
  { read -r _ res _ < "$d/statm"; } 2>/dev/null && RESIDENT[$pid]=$res
  [[ "$comm" == "kitty" ]] && KITTY_PIDS+=("$pid")
done

if [[ ${#KITTY_PIDS[@]} -eq 0 ]]; then
  echo "🐢 no open kitty terminals found"
  exit 0
fi

# sum resident memory (kB) across a pid's whole subtree — pure map walk
subtree_kb() {
  local pid=$1 sum c
  sum=$(( ${RESIDENT[$pid]:-0} * PAGE_KB ))
  for c in ${CHILDREN[$pid]:-}; do
    sum=$(( sum + $(subtree_kb "$c") ))
  done
  echo "$sum"
}

# foreground program of a shell = comm of its terminal's foreground pgrp.
# tpgid is the process-group leader pid, so COMM[tpgid] is the running job.
fg_program() {
  local s=$1
  local t=${TPGID[$s]:--1}
  local sp=${PGRP[$s]:-0}
  if [[ "$t" -le 0 || "$t" == "$sp" ]]; then
    echo "${COMM[$s]:-?}"
  else
    echo "${COMM[$t]:-${COMM[$s]:-?}}"
  fi
}

# decode a stat tty_nr into a /dev/pts/N path (empty if not a pts device)
decode_pts() {
  local t=$1 major minor
  major=$(( (t >> 8) & 0xfff ))
  minor=$(( (t & 0xff) | ((t >> 12) & 0xfff00) ))
  if (( major >= 136 && major <= 143 )); then
    echo "/dev/pts/$minor"
  fi
}

# map each tmux client's tty → session, so a kitty tmux window can be
# expanded into the real pane cwds that live under the tmux server tree
declare -A CLIENT_SESSION
if command -v tmux >/dev/null; then
  while IFS=$'\t' read -r ctty csess; do
    [[ -n "$ctty" ]] && CLIENT_SESSION[$ctty]=$csess
  done < <(tmux list-clients -F '#{client_tty}	#{session_name}' 2>/dev/null)
fi

humanize_kb() {
  local kb=$1
  if   (( kb >= 1048576 )); then awk -v k="$kb" 'BEGIN{printf "%.1fG", k/1048576}'
  elif (( kb >= 1024    )); then awk -v k="$kb" 'BEGIN{printf "%.0fM", k/1024}'
  else echo "${kb}K"
  fi
}

humanize_age() {
  local delta=$1
  if   (( delta < 60    )); then echo "${delta}s"
  elif (( delta < 3600  )); then echo "$((delta/60))m"
  elif (( delta < 86400 )); then echo "$((delta/3600))h"
  else echo "$((delta/86400))d"
  fi
}

# emit one record per shell: kpid pid comm cwd program age_seconds rss_kb.
# a tmux client is expanded into one record per pane, so pane cwds surface.
collect_records() {
  local kpid c comm cwd program start age rss tty sess
  local ppid ppath pcmd past
  declare -A expanded
  for kpid in "${KITTY_PIDS[@]}"; do
    for c in ${CHILDREN[$kpid]:-}; do
      comm=${COMM[$c]:-}
      [[ -z "$comm" || "$comm" == "kitten" ]] && continue

      # a tmux client: walk into the session's panes for their real cwds
      if [[ "$comm" == tmux* ]]; then
        tty=$(decode_pts "${TTY[$c]:-0}")
        sess=${CLIENT_SESSION[$tty]:-}
        if [[ -n "$sess" && -z "${expanded[$kpid|$sess]:-}" ]]; then
          expanded[$kpid|$sess]=1
          while IFS=$'\t' read -r ppid ppath pcmd; do
            [[ -z "$ppath" ]] && continue
            past=${START[$ppid]:-0}
            age=0
            (( past > 0 )) && age=$(( UPTIME - past / HZ ))
            (( age < 0 )) && age=0
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
              "$kpid" "$ppid" "tmux" "$ppath" "tmux/$pcmd" "$age" "$(subtree_kb "$ppid")"
          done < <(tmux list-panes -s -t "$sess" \
                    -F '#{pane_pid}	#{pane_current_path}	#{pane_current_command}' 2>/dev/null)
          continue
        fi
      fi

      cwd=$(readlink "/proc/$c/cwd" 2>/dev/null || true)
      [[ -z "$cwd" ]] && continue
      program=$(fg_program "$c")
      start=${START[$c]:-0}
      age=$(( UPTIME - start / HZ ))
      (( age < 0 )) && age=0
      rss=$(subtree_kb "$c")
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$kpid" "$c" "$comm" "$cwd" "$program" "$age" "$rss"
    done
  done
}

# json render: one object per shell, safe escape for string fields
render_json() {
  echo "["
  local first=1
  while IFS=$'\t' read -r kpid pid comm cwd program age rss; do
    local esc_cwd=${cwd//\\/\\\\}; esc_cwd=${esc_cwd//\"/\\\"}
    local esc_prg=${program//\\/\\\\}; esc_prg=${esc_prg//\"/\\\"}
    [[ $first -eq 0 ]] && echo ","
    first=0
    printf '  {"kitty_pid":%s,"pid":%s,"comm":"%s","cwd":"%s","program":"%s","age_seconds":%s,"rss_kb":%s}' \
      "$kpid" "$pid" "$comm" "$esc_cwd" "$esc_prg" "$age" "$rss"
  done <<< "$RECORDS"
  echo ""
  echo "]"
}

# human render: group by kitty window; per window show mem, then each
# distinct (cwd, program) with its shell count and the oldest age
render_human() {
  echo "🐢 open kitty terminals — ${#KITTY_PIDS[@]} windows"
  echo ""
  echo "🐚 kitty.snapshot.terminals"
  local kpid rows window_mem
  for kpid in "${KITTY_PIDS[@]}"; do
    rows=$(echo "$RECORDS" | awk -F'\t' -v k="$kpid" '$1==k {print $4"\t"$5"\t"$6}')
    [[ -z "$rows" ]] && continue
    window_mem=$(humanize_kb "$(subtree_kb "$kpid")")
    echo "   ├─ kitty pid=$kpid   mem=$window_mem"
    echo "$rows" \
      | awk -F'\t' '{
          key=$1 SUBSEP $2; cnt[key]++; cwd[key]=$1; prog[key]=$2;
          if ($3 > age[key]) age[key]=$3
        }
        END { for (k in cnt) printf "%s\t%s\t%s\t%s\n", cnt[k], cwd[k], prog[k], age[k] }' \
      | sort -t$'\t' -k2 \
      | while IFS=$'\t' read -r count cwd program age; do
          tag="$program"
          [[ "$count" -gt 1 ]] && tag="$program ×$count"
          echo "   │  └─ $cwd  → $tag  ($(humanize_age "$age"))"
        done
  done
}

RECORDS=$(collect_records)

if [[ -z "$RECORDS" ]]; then
  echo "🐢 kitty is open but no shells resolved (windows not yet ready)"
  exit 0
fi

# display: json if asked, else the human tree
if [[ "$MODE" == "json" ]]; then
  render_json
else
  render_human
fi

# persist both formats for later recovery/resume: json for scripts, txt to read
if [[ "$SAVE" -eq 1 ]]; then
  mkdir -p "$SNAP_DIR"
  ts=$(date +%Y-%m-%dT%H-%M-%S)
  render_human > "$SNAP_DIR/$ts.txt"
  render_json  > "$SNAP_DIR/$ts.json"
  echo ""
  echo "📸 snap saved → $SNAP_DIR/$ts.{txt,json}"
fi
