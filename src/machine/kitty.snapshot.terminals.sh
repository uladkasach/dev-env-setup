#!/usr/bin/env bash
######################################################################
# .what = snapshot open kitty terminals with pwd, program, age, mem
#
# .why  = one-glance map of every open kitty window: where it is,
#         what it runs, how long it's been open, and its memory cost.
#         reads /proc once into memory, so it stays fast.
#
# .security = reads ONLY /proc/<pid>/{stat,statm,cwd} — all
#             owner-readable — plus each KITTY process's cmdline, from which
#             it keeps four named flags (`--class`, `--title`, and a remote
#             duct's `--host` / `--session-b64`) and discards the rest, so an
#             argv secret never reaches a record (`hazard.secrets-in-argv`).
#             never touches kitty remote control,
#             never reads /proc/<pid>/environ (secrets stay unread).
#             keeps allow_remote_control=no fully intact.
#
# .workspace = a COMPOSITOR fact, absent from /proc. it is read through
#             `crewspace get --capture` (bundle `5.26.crewspace`), a read that
#             writes no file. absent crewspace or no wayland session → `ws ?`
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

# .note = `KITTY_SNAP_DIR` lets the periodic timer save into its own subdir,
#         so its frequent snaps never bury a by-hand or low-battery snap
SNAP_DIR="${KITTY_SNAP_DIR:-$HOME/.kitty/snaps}"

MODE="human"
SAVE=0
for arg in "$@"; do
  case "$arg" in
    --json) MODE="json" ;;
    --restore) MODE="restore" ;;
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
#
# ⚠️ the SURVEY's cost, never the restore's: it reads every process on the box.
#    `--restore` skips it and reads only kitty's own direct children
scan_proc_all() {
local d pid line rest comm tailf ppid pgrp ttynr tpgid starttime res
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
}

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

# map each tmux client's tty → "<socket path>|<session>", so a kitty tmux window
# can be expanded into the real pane cwds that live under its tmux server
#
# 🛑 .why EVERY socket, never only the default server
#    - each duct runs its own server (`tmux -L duct-org-<org>`), so a read of the
#      default server alone resolved none of them
#    - 📜 measured 2026-11-24: 9 kitty windows read only `tmux: client ×N` in the
#      client's own dir — no session, no pane path — so a crash left no map of a
#      single duct
#    - a stale socket (no server answers) fails fast and is skipped
declare -A CLIENT_SESSION
if command -v tmux >/dev/null; then
  tmux_sock_dir="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)"
  for sock in "$tmux_sock_dir"/*; do
    [[ -S "$sock" ]] || continue
    while IFS=$'\t' read -r ctty csess; do
      [[ -n "$ctty" ]] && CLIENT_SESSION[$ctty]="$sock|$csess"
    done < <(tmux -S "$sock" list-clients -F '#{client_tty}	#{session_name}' 2>/dev/null)
  done
fi

######################################################################
# each kitty window's facts: its class, title, and the remote duct it attaches
#
# .why only four flags are kept
#   - a crew window is launched `kitty --class crew.<slug>`, and that class IS
#     the window's wayland app_id — the exact key to its workspace
#   - a remote duct window runs `termwork.attach.sh --host <h> --session-b64 <s>`
#     inside its `-e` command, so those two name the grove and its tmux session
#   - all else in an argv is unread: a flag may carry a secret
######################################################################
declare -A KCLASS KTITLE KHOST KPORT KSESS
kitty_window_facts() {
  local kpid=$1 i a nxt
  local -a argv=()
  mapfile -d '' -t argv < "/proc/$kpid/cmdline" 2>/dev/null || return 0
  for (( i = 0; i < ${#argv[@]}; i++ )); do
    a=${argv[$i]}
    nxt=${argv[$((i + 1))]:-}
    case "$a" in
      --class)   KCLASS[$kpid]=$(snap_as_field "$nxt") ;;
      --class=*) KCLASS[$kpid]=$(snap_as_field "${a#--class=}") ;;
      --title|-T) KTITLE[$kpid]=$(snap_as_field "$nxt") ;;
      --title=*) KTITLE[$kpid]=$(snap_as_field "${a#--title=}") ;;
    esac
    # the remote duct's flags sit inside one `-e` argument, a shell body
    if [[ "$a" =~ --host[[:space:]]+([^[:space:]]+) ]]; then
      KHOST[$kpid]=$(snap_as_field "${BASH_REMATCH[1]}")
    fi
    if [[ "$a" =~ --port[[:space:]]+([0-9]+) ]]; then
      KPORT[$kpid]=${BASH_REMATCH[1]}
    fi
    if [[ "$a" =~ --session-b64[[:space:]]+([A-Za-z0-9+/=]+) ]]; then
      KSESS[$kpid]=$(snap_as_field "$(printf '%s' "${BASH_REMATCH[1]}" | base64 -d 2>/dev/null)")
    fi
  done
}

######################################################################
# each kitty window's workspace, joined from the compositor's view
#
# .the join, strongest first
#   1. class → app_id. exact: a crew's class is unique to it
#   2. `--title` → the window's title. exact while the title holds
#   3. elimination: one plain kitty left and one plain window left → a pair
#   4. else `?`, with the candidate workspaces named — never a guess
#
# ⚠️ the compositor names no pid, so 3 and 4 are the honest limit for a plain
#    `kitty` window: two such windows on two workspaces cannot be told apart
######################################################################
declare -A KWS
WS_NOTE=""
join_workspaces() {
  local bin
  bin="$(command -v crewspace 2>/dev/null || true)"
  [[ -z "$bin" && -x "$HOME/.local/bin/crewspace" ]] && bin="$HOME/.local/bin/crewspace"
  if [[ -z "$bin" ]]; then
    WS_NOTE="crewspace absent — fix: rhx grove.provision --what 5.26.crewspace --mode apply"
    return 0
  fi

  # a systemd user timer may hold no WAYLAND_DISPLAY; the session's socket names it
  local wd="${WAYLAND_DISPLAY:-}" rt="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" s
  if [[ -z "$wd" ]]; then
    for s in "$rt"/wayland-*; do
      [[ -S "$s" ]] && { wd=${s##*/}; break; }
    done
  fi
  if [[ -z "$wd" ]]; then
    WS_NOTE="no wayland session to read"
    return 0
  fi

  local capture
  if ! capture="$(XDG_RUNTIME_DIR="$rt" WAYLAND_DISPLAY="$wd" timeout 10 "$bin" get --capture 2>/dev/null)"; then
    WS_NOTE="crewspace could not read the compositor"
    return 0
  fi

  # the view: app_id → its workspaces, and every plain kitty window apart
  declare -A ws_of_app
  local -a plain_ws=() plain_title=() plain_taken=()
  local kind ws app title
  while IFS=$'\t' read -r kind ws app title; do
    [[ "$kind" == win ]] || continue
    if [[ "$app" == kitty ]]; then
      plain_ws+=("$ws"); plain_title+=("$title"); plain_taken+=(0)
      continue
    fi
    if [[ -n "${ws_of_app[$app]:-}" && ",${ws_of_app[$app]}," != *",$ws,"* ]]; then
      ws_of_app[$app]+=",$ws"
    else
      ws_of_app[$app]=${ws_of_app[$app]:-$ws}
    fi
  done <<< "$capture"

  # 1 + 2: the exact joins
  local kpid i
  local -a left=()
  for kpid in "${KITTY_PIDS[@]}"; do
    if [[ -n "${KCLASS[$kpid]:-}" ]]; then
      KWS[$kpid]=${ws_of_app[${KCLASS[$kpid]}]:-?}
      continue
    fi
    if [[ -n "${KTITLE[$kpid]:-}" ]]; then
      for i in "${!plain_title[@]}"; do
        if [[ "${plain_taken[$i]}" == 0 && "${plain_title[$i]}" == "${KTITLE[$kpid]}" ]]; then
          KWS[$kpid]=${plain_ws[$i]}; plain_taken[$i]=1; break
        fi
      done
      [[ -n "${KWS[$kpid]:-}" ]] && continue
    fi
    left+=("$kpid")
  done

  # 3 + 4: what is left of the plain windows
  local -a free=()
  for i in "${!plain_ws[@]}"; do
    [[ "${plain_taken[$i]}" == 0 ]] && free+=("${plain_ws[$i]}")
  done
  if (( ${#left[@]} == 1 && ${#free[@]} == 1 )); then
    KWS[${left[0]}]=${free[0]}
    return 0
  fi
  local cands
  cands=$(printf '%s\n' "${free[@]}" | sort -u | paste -sd, -)
  for kpid in "${left[@]}"; do
    KWS[$kpid]="?${cands:+ (one of $cands)}"
  done
}

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
#         `set-clipboard on` in `src/grove.provision/2.shell/2.8.tmux/tmux.conf`, an OSC 52 in a directory name
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

# the window's own facts, as the record's last four fields:
#   workspace  crew class  remote host  remote session
# each is already a sanitized field; an absent one is empty, the workspace `?`
window_cols() {
  printf '%s\t%s\t%s\t%s' \
    "${KWS[$1]:-?}" "${KCLASS[$1]:-}" "${KHOST[$1]:-}" "${KSESS[$1]:-}"
}

# emit one record per shell: kpid pid comm cwd program age_seconds rss_kb,
# then the window's workspace, class, remote host, remote session.
# a tmux client is expanded into one record per pane, so pane cwds surface.
collect_records() {
  local kpid c comm cwd program start age rss tty sess
  local ppid ppath pcmd past entry sock sname label
  declare -A expanded
  for kpid in "${KITTY_PIDS[@]}"; do
    for c in ${CHILDREN[$kpid]:-}; do
      comm=${COMM[$c]:-}
      [[ -z "$comm" || "$comm" == "kitten" ]] && continue

      # a tmux client: walk into the session's panes for their real cwds
      #
      # ⚠️ the client is the kitty child itself (`kitty tmux …`) OR the
      #    foreground job of a shell (`zsh` → `tmux -L duct-org-… attach`).
      #    📜 measured 2026-11-24: every duct window was the second shape, so a
      #    test of `$comm` alone expanded none of them. the shell and its
      #    foreground client share one pts, so the shell's tty keys the lookup
      program=$(fg_program "$c")
      if [[ "$comm" == tmux* || "$program" == tmux* ]]; then
        tty=$(decode_pts "${TTY[$c]:-0}")
        entry=${CLIENT_SESSION[$tty]:-}
        if [[ -n "$entry" && -z "${expanded[$kpid|$entry]:-}" ]]; then
          expanded[$kpid|$entry]=1
          sock=${entry%%|*}
          sname=${entry#*|}
          # the label names the SERVER and the SESSION, so a crash map says
          # which duct to reattach: `tmux -L <server> attach -t <session>`
          label="tmux[$(snap_as_field "${sock##*/}"):$(snap_as_field "$sname")]"
          while IFS=$'\t' read -r ppid ppath pcmd; do
            [[ -z "$ppath" ]] && continue
            past=${START[$ppid]:-0}
            age=0
            (( past > 0 )) && age=$(( UPTIME - past / HZ ))
            (( age < 0 )) && age=0
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
              "$kpid" "$ppid" "tmux" \
              "$(snap_as_field "$ppath")" "$label/$(snap_as_field "$pcmd")" \
              "$age" "$(subtree_kb "$ppid")" "$(window_cols "$kpid")"
          done < <(tmux -S "$sock" list-panes -s -t "$sname" \
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
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$kpid" "$c" "$(snap_as_field "$comm")" \
        "$(snap_as_field "$cwd")" "$(snap_as_field "$program")" \
        "$age" "$rss" "$(window_cols "$kpid")"
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
        rss_kb:      (.[6] | tonumber? // 0),
        workspace:   (.[7] // "?"),
        crew:        (.[8] // ""),
        duct_host:   (.[9] // ""),
        duct_session: (.[10] // "")
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
    echo "   ├─ kitty pid=$kpid   mem=$window_mem   ws=${KWS[$kpid]:-?}${KCLASS[$kpid]:+   ${KCLASS[$kpid]}}"
    # a remote duct: the grove and its tmux session, so a crash map can reattach it
    [[ -n "${KHOST[$kpid]:-}" ]] && \
      echo "   │  └─ duct: ${KHOST[$kpid]} · ${KSESS[$kpid]:-?}"
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
  [[ -n "$WS_NOTE" ]] && echo "   └─ 🌙 workspaces unread: $WS_NOTE"
  return 0
}

######################################################################
# 🛑 --restore: the crash map, and ONLY the crash map — the timer's mode
#
# .what = per kitty window, in on-screen order: its workspace, its crew class,
#         its launch title, its remote duct (host, port, session), and each
#         terminal inside it, in spawn order, with its cwd and the exact tmux
#         server + session it attaches to
#
# .why  = the one purpose of a periodic snap is to put the crews back after a
#         crash: the same windows, on the same workspaces, attached to the same
#         ducts, in the same order. a tmux server outlives a kitty crash, so the
#         attach target is all a restore needs — never the panes inside it
#
# .why it is cheap
#   - no full /proc scan: `pgrep` finds kitty, and its `task/<pid>/children`
#     names its direct children, so only those few stats are read
#   - no pane walk and no memory sum: neither helps a restore
#   - one `tmux list-clients` per live server, one `crewspace get --capture`
#
# ⚠️ .the order a restore can keep
#   - across windows: workspace order (a COSMIC workspace number is a POSITION,
#     and renumbers when one empties, so the ORDER is the durable fact)
#   - within a window: spawn order. kitty's own tab order after a human drags
#     a tab is unread here — that needs kitty remote control, which stays off
######################################################################
restore_rows() {
  local kpid c line rest comm tailf ttynr tpgid kstart fg tty entry sock sname cwd idx
  for kpid in "${KITTY_PIDS[@]}"; do
    { read -r line < "/proc/$kpid/stat"; } 2>/dev/null || continue
    tailf=${line##*) }
    # shellcheck disable=SC2086
    set -- $tailf
    kstart=${20}
    idx=0
    local kids=""
    { read -r kids < "/proc/$kpid/task/$kpid/children"; } 2>/dev/null || true
    for c in $kids; do
      { read -r line < "/proc/$c/stat"; } 2>/dev/null || continue
      rest=${line#*(}
      comm=${rest%)*}
      [[ "$comm" == kitten ]] && continue
      tailf=${rest##*) }
      # shellcheck disable=SC2086
      set -- $tailf
      ttynr=$5; tpgid=$6
      fg=$comm
      [[ "$tpgid" -gt 0 ]] && { read -r fg < "/proc/$tpgid/comm"; } 2>/dev/null
      cwd=$(readlink "/proc/$c/cwd" 2>/dev/null || true)
      sock=""; sname=""
      if [[ "$comm" == tmux* || "$fg" == tmux* ]]; then
        tty=$(decode_pts "$ttynr")
        entry=${CLIENT_SESSION[$tty]:-}
        [[ -n "$entry" ]] && { sock=${entry%%|*}; sname=${entry#*|}; }
      fi
      idx=$((idx + 1))
      # ws  kitty_start  kitty_pid  class  title  host  port  session  term_idx  cwd  fg  tmux_server  tmux_session
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${KWS[$kpid]:-?}" "$kstart" "$kpid" \
        "${KCLASS[$kpid]:-}" "${KTITLE[$kpid]:-}" \
        "${KHOST[$kpid]:-}" "${KPORT[$kpid]:-}" "${KSESS[$kpid]:-}" \
        "$idx" "$(snap_as_field "$cwd")" "$(snap_as_field "$fg")" \
        "$(snap_as_field "${sock##*/}")" "$(snap_as_field "$sname")"
    done
  done | sort -t$'\t' -k1,1V -k2,2n -k9,9n
}

# the restore map a human reads: one block per window, in restore order
render_restore() {
  local rows=$1 last="" row ws kst kpid class title host port sess idx cwd fg srv sname
  echo "🐢 crash map — ${#KITTY_PIDS[@]} kitty windows, in restore order"
  echo ""
  echo "🐚 kitty.snapshot.terminals --restore"
  # 🛑 split on US (0x1f), never on TAB: TAB is whitespace to `read`, so a run
  #    of tabs merges and every empty field after it slides left one column.
  #    📜 measured 2026-11-24: an absent class put the title in the class slot
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    IFS=$'\x1f' read -r ws kst kpid class title host port sess idx cwd fg srv sname <<< "${row//$'\t'/$'\x1f'}"
    if [[ "$kpid" != "$last" ]]; then
      last=$kpid
      echo "   ├─ ws $ws   kitty pid=$kpid${class:+   $class}${title:+   title=$title}"
      [[ -n "$host" ]] && echo "   │  ├─ duct: $host${port:+:$port} · ${sess:-?}"
    fi
    if [[ -n "$srv" ]]; then
      echo "   │  └─ $idx. $cwd → tmux -L $srv attach -t $sname"
    else
      echo "   │  └─ $idx. $cwd → $fg"
    fi
  done <<< "$rows"
  [[ -n "$WS_NOTE" ]] && echo "   └─ 🌙 workspaces unread: $WS_NOTE"
  return 0
}

if [[ "$MODE" == "restore" ]]; then
  mapfile -t KITTY_PIDS < <(pgrep -u "$(id -u)" -x kitty)
  if [[ ${#KITTY_PIDS[@]} -eq 0 ]]; then
    echo "🐢 no open kitty terminals found"
    exit 0
  fi
  for kpid in "${KITTY_PIDS[@]}"; do
    kitty_window_facts "$kpid"
  done
  join_workspaces
  ROWS=$(restore_rows)
  MAP=$(render_restore "$ROWS")
  printf '%s\n' "$MAP"
  if [[ "$SAVE" -eq 1 ]]; then
    mkdir -p "$SNAP_DIR"
    ts=$(date +%Y-%m-%dT%H-%M-%S)
    { printf '# ws\tkitty_start\tkitty_pid\tclass\ttitle\thost\tport\tsession\tterm_idx\tcwd\tfg\ttmux_server\ttmux_session\n'
      printf '%s\n' "$ROWS"; } > "$SNAP_DIR/$ts.tsv"
    printf '%s\n' "$MAP" > "$SNAP_DIR/$ts.txt"
    echo ""
    echo "📸 crash map saved → $SNAP_DIR/$ts.{tsv,txt}"
  fi
  exit 0
fi

# the SURVEY: every process, every pane, every window's memory
scan_proc_all
if [[ ${#KITTY_PIDS[@]} -eq 0 ]]; then
  echo "🐢 no open kitty terminals found"
  exit 0
fi

# the window facts and the workspace join, before the records that carry them
for kpid in "${KITTY_PIDS[@]}"; do
  kitty_window_facts "$kpid"
done
join_workspaces

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