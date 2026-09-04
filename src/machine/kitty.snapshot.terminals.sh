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
# ⚠️ .where this file LIVES, and why it lives here
#         it is a declared asset of `src/`, and `4.3.4.snapshot`'s
#         `provision.upsert` installs it to `~/.local/bin/kitty.snap`.
#         it used to live only under `.agent/…/skills/`, which put it
#         OUTSIDE the deployable unit — `git.grove.push --from src`
#         carries no adjacent dir — so a box provisioned the documented
#         way got the systemd unit that CALLS it and never the file
#         itself (`rule.require.bundles-own-their-dependencies`).
#
#         `.agent/…/skills/kitty.snapshot.terminals.sh` is now a thin
#         shim onto this file, so `rhx` still reaches it from a checkout
#         where the install has not run yet. one implementation, one
#         writer (`rule.forbid.two-writers-on-one-artifact`).
#
# usage:
#   kitty.snap                             # human tree (default), once installed
#   kitty.snap --json                      # one json object per shell
#   kitty.snap --save                      # also persist to ~/.kitty/snaps
#
#   rhx kitty.snapshot.terminals           # the same, from a checkout, via the shim
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

######################################################################
# 🛑 every TEXT field is sanitized AT CAPTURE, before it enters a record
#
# .what = drop every control byte from a field. no ESC, no BEL, no TAB, no LF.
#
# .why  = 📜 measured 2026-08-31. two of the three text fields are chosen by a
#         party other than this reader:
#           · `cwd` / `ppath` — a directory NAME. a linux dir name may hold any
#             byte but `/` and NUL, and `#{pane_current_path}` reports the cwd of
#             a DUCT pane, so a grove steers it: `git.grove.pull` writes a tree
#             the grove named, and a pane `cd`s into it.
#           · `comm` / `program` / `pcmd` — a process NAMES ITSELF
#             (`prctl(PR_SET_NAME)`, or just its exec name).
#
#         `render_json` was hardened for this and `render_human` was not — it
#         `echo`s both straight to a terminal that OBEYS them. with
#         `set-clipboard on` in `src/tmux.conf`, an OSC 52 in a directory name
#         REWRITES THIS HUMAN'S CLIPBOARD, and `--save` writes the same bytes to
#         a file a howto tells a human to `cat`.
#
# 🛑 .why here and not in `render_human`
#      two renders, one rule, and only one of them held it — the m.9 shape
#      exactly. at capture there is ONE holder, and a third render tomorrow
#      inherits it (`rule.require.solve-at-cause`).
#
# ⚠️ it drops TAB and LF too, which the duct's own sink deliberately KEEPS. the
#    trigger is different: this is a TSV FIELD, and a tab splits it while a
#    newline splits its row. that retires the caveat `render_json`'s header
#    carries about an embedded newline — it can no longer reach the record.
#
# .note = it is bash-native on purpose. this file installs to
#         `~/.local/bin/kitty.snap` and runs from a systemd unit, so it sources
#         no aliases and may borrow no function from them
######################################################################
snap_as_field() {
  local v="${1//[[:cntrl:]]/}"
  printf '%s' "$v"
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
              "$kpid" "$ppid" "tmux" \
              "$(snap_as_field "$ppath")" "tmux/$(snap_as_field "$pcmd")" \
              "$age" "$(subtree_kb "$ppid")"
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
        "$kpid" "$c" "$(snap_as_field "$comm")" \
        "$(snap_as_field "$cwd")" "$(snap_as_field "$program")" \
        "$age" "$rss"
    done
  done
}

# json render: one object per shell
#
# 🛑 .why `jq` composes this, and never a hand-rolled escape
#
#    it built each object with `printf` and a two-substitution escape until
#    2026-08-31 — and that escape had TWO holes, both of the same shape:
#
#      1. it ran on `cwd` and `program`, and NOT on `comm`. so a process that
#         names itself `x"` forges a key. a process picks its own comm
#         (`prctl(PR_SET_NAME)`, or just its exec name), so this is a value the
#         reader does not choose.
#      2. it substituted `\` and `"` and no control byte. a linux path may hold
#         any byte but `/` and NUL, so a `cwd` with a raw ESC or newline
#         produced JSON no parser accepts — and this output is meant to be
#         piped to one.
#
#    ⇒ the cause is not either hole; it is that ONE rule (how to escape a
#      string for JSON) had THREE holders, so the one that drifted is the one
#      nobody re-read (m.9, `gotcha.a-check-that-cries-wolf-gets-silenced`).
#      `jq -R -s` gives it exactly one holder, and that holder is a JSON
#      encoder rather than a pair of substitutions.
#
# ⚠️ `tonumber? // 0` and not a bare `tonumber`: an absent field would
#    otherwise abort the whole render, so one odd row would cost every row.
#
# ⚠️ a valid-JSON guarantee is not a valid-ROW one, and this render owns only
#    the first. the ROW is `snap_as_field`'s claim, upstream at capture: it
#    drops every control byte, so no `cwd` can split its own TSV row or field.
#    ⇒ do not relax that sink on the argument that jq escapes what reaches it —
#      jq sees whatever the split already produced.
render_json() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "✋ kitty.snapshot.terminals: --json needs jq, and it is absent" >&2
    echo "   └─ fix: rhx grove.provision --what 2.1.toolkit --mode apply" >&2
    return 1
  fi
  printf '%s\n' "$RECORDS" | jq -R -s '
    split("\n")
    | map(select(length > 0))
    | map(split("\t"))
    | map({
        kitty_pid:   (.[0] | tonumber? // 0),
        pid:         (.[1] | tonumber? // 0),
        comm:        (.[2] // ""),
        cwd:         (.[3] // ""),
        program:     (.[4] // ""),
        age_seconds: (.[5] | tonumber? // 0),
        rss_kb:      (.[6] | tonumber? // 0)
      })'
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