#!/bin/bash
######################################################################
# .what = hibernate this cloud grove once it has shown no stir for IDLE_LIMIT
#
# .why every signal below
#   - the newest stir wins: boot, a brain trace, a keystroke, a duct's output
#   - a fleet clone writes its brain trace INSIDE its clone, under
#     `.agent/.actors/<actor>/brain/.claude/projects/` — so the check reads
#     those rows beside the human's own `~/.claude/projects`
#   - a duct is a tmux server; each window's `#{window_activity}` moves on pane
#     output, so a duct holds the box while it prints, never by presence alone.
#     a forgotten pane is no evidence of work
#   - ⇒ to hold a box through a long job that prints naught, keep one pane that prints
#     (`while sleep 600; do date; done`); a hand stop of the timer is undone by the
#     next ground apply
#
# .why every max is one awk pass, never `sort -rn | head -1`
#   - systemd starts a service with SIGPIPE ignored, so once `head` exits,
#     `sort` gets EPIPE and logs `sort: write failed: Broken pipe` on every
#     tick that matched more than one pipe's worth of traces
#   - awk reads its whole input, so no writer is left with a closed pipe
#
# .why a keystroke is a numbered pts's ATIME
#   - the tty driver stamps mtime on a write to the pts and atime on a read from
#     it; `w(1)` reads idle from atime. output alone — a status clock an attached
#     client redraws — moves mtime forever, and would hold an idle box awake
#   - only the numbered slaves count: `/dev/pts/ptmx` is the multiplexer every
#     pty opens through, never a terminal a human types into
#
# .why each verdict is one line, in one shape, with a count per source
#   - `hold` and `sleep` both print `idle=<n>s limit=<n>s, newest=<kind> <source>`,
#     so "why is this box awake?" and "why did it sleep?" answer from one line
#   - `seen traces=<n> pts=<n> ducts=<n>` follows: the wish's defect was a source
#     that quietly read naught, and a zero on a box with crews shows it
#
# .why a source the check cannot read HOLDS the box (F6)
#   - an unread source adds no evidence, so a stale box with one would sleep —
#     and the crew the check could not see dies with it
#   - the costs are not equal: a wrong sleep kills every crew on the box; a wrong
#     hold bills one more tick, under a `💥 MalfunctionError:` line
#   - ⇒ every read routes its stderr: an absent path is no source, and every
#     other error is an unread source. a dead tmux server's socket is no source
#   - every run that met an unread source exits 1 — the hold it forced, and a
#     hold a fresh stir made anyway — so the unit's `Result` reads it and
#     `rhx grove.provision --what 1.15.hibernate` names it; a clean hold exits 0
#
# .why each duct is dialed as the socket's OWNER, never as root
#   - `/tmp` is world-writable, so any seat can plant a socket under `/tmp/tmux-*/`
#     and serve it. a tmux client obeys its server's requests to open and write
#     files, so a root client on a planted socket hands that seat root's reach
#   - the check stats each socket and drops to its uid and gid (`setpriv`) before
#     the dial. the owner can always read its own server, so no real duct is lost,
#     and tmux's own access rule — same uid — then holds by construction
#
# .why every bound is declared once, at the head
#   - the unit kills a run at `TimeoutStartSec=`. the worst run is the read budget,
#     one last dial, three imds calls, and the aws call; the drift play reads these
#     names and asserts their sum fits, so no edit to one literal breaks the bound
#
# .why a record at `/run/idle-hibernate.last`
#   - the journal is root's to read; a camper seat reads none of it. the record holds
#     the last run's verdict, its exit, and each `💥` line, at 0644, so the verify a
#     camper runs can show WHY a run failed, never only that it did
#
# .why `LC_ALL=C`
#   - the readers sort errors by their english text; a translated `find` would
#     turn an absent path into an unread one
#
# .why no knobs
#   - the clamp proves this file AND the file it replaced, so it reaches every
#     path by a rewrite of the absolute paths below and stubs `aws` and `curl`
#     on PATH. a knob here would be one the old bytes lack
#
# .needs = `NEEDS='…'` below, declared once: the bundle's verify probes each on the unit's
#   PATH, which the unit declares. `tmux` (2.8.tmux) reads the ducts and is not in the list:
#   a box with no tmux has no duct, and a server with no client holds loud (F15)
#
# .why `/run/idle-hibernate.last-sleep` beside the record
#   - a wake's first tick rewrites the record as `hold — newest=boot`, so the last SLEEP
#     verdict keeps a record of its own, written before the act; "why did it sleep?"
#     answers from it after the wake
#
# .why `TMUX_SOCKETS` is `/tmp/tmux-*/*`
#   - tmux puts each server's socket at `${TMUX_TMPDIR:-/tmp}/tmux-<uid>/`, and no
#     grove sets TMUX_TMPDIR. `2.8.tmux` computes the same dir; the drift play ties
#     the two. a box that moves TMUX_TMPDIR moves every socket off this sweep, and
#     `guard_uncounted` holds it loud until this glob follows
#
# .owner = `src/grove.provision/1.system/1.15.hibernate` byte-owns this file
#   on every cloud grove. ahbode/infrastructure writes a first-boot copy of the
#   same logic; a ground apply converges it to these bytes (F2)
######################################################################
export LC_ALL=C
IDLE_LIMIT=10800
# .what = how far past NOW a stir may sit and still count (a duct can print after NOW is read)
STIR_SLACK=60   # measured against a fresh clock read in `bump`, so it bounds skew only
# .what = the bounds, in seconds. worst run = READ_BUDGET + DIAL_BOUND + DIAL_KILL
#   + 3 * IMDS_BOUND + AWS_BOUND + AWS_KILL, held under the unit's TimeoutStartSec=
# .why the sum holds by construction: every find runs under what is left of READ_BUDGET,
#   the duct sweep stops at it, and the act refuses to start past it plus one last dial
READ_BUDGET=80
# .what = a gap between two ticks past which the box was frozen, not idle — three timer
#   periods (`OnUnitActiveSec=300`); the drift play ties the two
TICK_GAP=900
DIAL_BOUND=5
DIAL_KILL=2
IMDS_BOUND=5
AWS_BOUND=60
AWS_KILL=5

# .what = the world this check reads — every box path, declared once
# .why codex beside claude: `5.3.brains` installs both, and a codex crew writes its
#   session as `~/.codex/sessions/<y>/<m>/<d>/rollout-*.jsonl`
TRACE_ROOTS=(
  '/home/*/.claude/projects'
  '/home/*/git/*/_worktrees/*/.agent/.actors/*/brain/.claude/projects'
  '/home/*/git/*/*/.agent/.actors/*/brain/.claude/projects'
  '/home/*/.codex/sessions'
)
UPTIME_FILE=/proc/uptime
PTS_DIR=/dev/pts
TMUX_SOCKETS='/tmp/tmux-*/*'
IMDS=http://169.254.169.254/latest
LAST_RECORD=/run/idle-hibernate.last
# .what = the record of the last run that judged the box idle — a wake's first tick would
#   overwrite LAST_RECORD with `hold — newest=boot`, so "why did it sleep?" keeps its own
LAST_SLEEP=/run/idle-hibernate.last-sleep
# .what = the tools the check cannot judge or act without, on the unit's PATH. `tmux` is
#   not one: a box with no tmux has no duct, and a server with no client is loud (F15)
# .note = one plain line, so the bundle reads it as data and never evals it
NEEDS='aws curl find pgrep setpriv timeout stat awk'

NOW=$(date +%s)
STIR=0
STIR_KIND=none
STIR_FROM=
UNREAD=0
SEEN_TRACES=0
SEEN_PTS=0
SEEN_DUCTS=0
MET_DUCTS=0   # live sockets the sweep reached, answered or loud — SEEN_DUCTS ⊆ MET_DUCTS
SWEEP_ROW=""
SWEEP_AS=()
WAKE=""
RECORD=""
# the retitled tmux servers counted before and after the sweep; -1 with *_ERR on a pgrep fault
SERVERS=0
SERVERS_ERR=""
SERVERS_BEFORE=0
SERVERS_ERR_BEFORE=""
ERRS=$(mktemp)

# .what = say one line, on stdout or stderr, and keep it for the record: say <1|2> <line>
# .why each control byte becomes `?`: a socket name, a trace path, and tmux's own error
#   text are chosen by any seat, and land in the journal, the world-readable record, and
#   the terminal of a camper whose verify prints it. a newline would forge a record line;
#   an ESC would drive that terminal. under LC_ALL=C a utf-8 glyph holds no control byte
say() {
  local line="${2//[[:cntrl:]]/?}"
  RECORD+="$line"$'\n'
  [ "$1" -eq 2 ] && { echo "$line" >&2; return 0; }
  echo "$line"
}

# .what = write this run's record into $1, world-readable, by temp-then-rename: write_record <dst> <exit>
# .note = a record that cannot be written is said on stderr and leaves the exit as it was
# .note = each failure names the exit it would have recorded: the sleep record is written twice per
#   act (`unanswered`, then `0`), and two identical lines would read as one fault said twice
write_record() {
  local dst="$1" rc="$2" tmp
  local fix="   └─ fix: the unit runs as root; read why $(dirname "$dst") refused the write. the verdict above still stands"
  if ! tmp=$(mktemp "$dst.XXXXXX" 2>&1); then
    echo "idle-hibernate: 💥 MalfunctionError: could not write $dst (its record would read exit=$rc) — $tmp" >&2
    echo "$fix" >&2
    return 0
  fi
  # the wake line rides last, so the next tick carries the wake floor across its own run
  printf 'at=%s exit=%s\n%s%s' "$(date -u -d "@$NOW" +%Y-%m-%dT%H:%M:%SZ)" "$rc" "$RECORD" "${WAKE:+wake=$WAKE$'\n'}" > "$tmp" \
    && chmod 0644 "$tmp" && mv -f "$tmp" "$dst" && return 0
  rm -f "$tmp"
  echo "idle-hibernate: 💥 MalfunctionError: could not write $dst (its record would read exit=$rc) — the error is above" >&2
  echo "$fix" >&2
  return 0
}
trap 'rc=$?; write_record "$LAST_RECORD" "$rc"; rm -f "$ERRS"; exit "$rc"' EXIT

# .what = seconds left of the read budget, never below 0
budget_left() {
  local left=$((NOW + READ_BUDGET - $(date +%s)))
  [ "$left" -gt 0 ] || left=0
  echo "$left"
}

# .what = keep the newest stir seen: bump <epoch> <kind> <source>
# .why a stir stamped past the clock + STIR_SLACK is no evidence of work — a skewed clock
#   or a copy from another box — and would pin the box until the clock caught up. it
#   reads as unread: the box holds, loud, rather than sleep or hold in silence
# .why the clock is read fresh, never NOW: a slow sweep reads a duct that printed after
#   NOW, and that stir is real. against a fresh read, the slack bounds clock skew alone,
#   and owes no part of the read budget
bump() {
  local clock
  [ -n "$1" ] || return 0
  clock=$(date +%s)
  if [ "$1" -gt $((clock + STIR_SLACK)) ]; then
    unreadable "$2" "$3 is stamped $(( $1 - clock ))s in the future" "set the box clock right (timedatectl), or touch the file to now"
    return 0
  fi
  [ "$1" -gt "$STIR" ] || return 0
  STIR=$1
  STIR_KIND=$2
  STIR_FROM=$3
}

# .what = report a source that gave no evidence because it could not be read
unreadable() {
  UNREAD=$((UNREAD + 1))
  say 2 "idle-hibernate: 💥 MalfunctionError: $1 unreadable — $2"
  say 2 "   └─ fix: $3"
}

# .what = '<epoch> <count> <source>' — the newest of the '<epoch> <source>' rows on stdin, in one pass
newest() {
  awk '{ n++; t = int($1); if (t > m) { m = t; sub(/^[^ ]+ /, ""); p = $0 } } END { if (n > 0) print m, n, p }'
}

# .what = the first line of $ERRS that is not an absent path — a source that went unread
# .why anchored to the reason find puts LAST: a path is chosen by any seat, so a phrase that
#   sits anywhere in the line could make a real fault read as a benign skip
errs_unread() {
  grep -v -m1 ': No such file or directory$' "$ERRS"
}

# .what = the boot floor — a box that just booted cold is not idle
read_boot() {
  local uptime
  uptime=$(cut -d. -f1 "$UPTIME_FILE" 2>"$ERRS")
  [ -n "$uptime" ] || { unreadable boot "$(head -1 "$ERRS")" "read $UPTIME_FILE by hand; a box with no procfs cannot judge its own idle"; return 0; }
  bump $((NOW - uptime)) boot "$UPTIME_FILE"
}

# .what = the wake floor — a box that just resumed is not idle; WAKE carries it across ticks
# .why `/proc/uptime` is CLOCK_BOOTTIME, which counts the time hibernated, so a woken box reads
#   as booted long ago and the boot floor holds naught. the check's own record does not depend
#   on that kernel fact: `/run` is tmpfs and survives a hibernate, so a last tick further back
#   than TICK_GAP is a box that was frozen. the wake time rides in the record, so the box holds
#   for IDLE_LIMIT after it, never for one tick; a cold boot clears `/run`, and the boot floor
#   covers it. a timer stopped by hand reads as a wake too — a hold for one limit, the safe side
read_wake() {
  local at prev gap from
  [ -e "$LAST_RECORD" ] || return 0   # a cold boot, or a first tick: the boot floor covers it
  at=$(head -1 "$LAST_RECORD" 2>"$ERRS") || { unreadable wake "$(head -1 "$ERRS")" "the unit runs as root; read why $LAST_RECORD refused it"; return 0; }
  at="${at#at=}"; at="${at%% *}"
  if ! prev=$(date -u -d "$at" +%s 2>/dev/null); then
    unreadable wake "the last record's first line names no time: ${at:-an empty line}" \
      "the next tick rewrites $LAST_RECORD; a record this check did not write is a second writer on it"
    return 0
  fi
  # the first `wake=` line, by sed alone: no `| head`, so no writer is left on a closed pipe
  WAKE=$(sed -n 's/^wake=\([0-9][0-9]*\)$/\1/p;T;q' "$LAST_RECORD")
  from="$LAST_RECORD, carried from the tick that saw the wake"
  gap=$((NOW - prev))
  if [ "$gap" -gt "$TICK_GAP" ]; then
    WAKE=$NOW
    from="$LAST_RECORD — the last tick sat ${gap}s back, past the ${TICK_GAP}s tick gap"
  fi
  # a wake past the limit holds naught, so the record stops to carry it
  [ -n "$WAKE" ] && [ $((NOW - WAKE)) -lt "$IDLE_LIMIT" ] || { WAKE=""; return 0; }
  bump "$WAKE" wake "$from"
}

# .what = one find sweep: its '<epoch> <count> <source>' row into SWEEP_ROW, and loud if it errs
# .usage = sweep_find <kind> <where> <fix> <find args…>
#   - where = the roots this sweep walks, so each 💥 names its own and two never read alike
#   - fix   = the remedy for a REFUSAL (an error find printed). a budget overrun and a
#     kill each carry their own remedy: "read why it refused" is false for both
# .note = it sets SWEEP_ROW rather than print: a `$(…)` caller is a subshell, and the
#   UNREAD count and the record that `unreadable` grows would die with it
# .why the status is find's, never awk's: a find killed with no word (an oom, a signal)
#   would read as a short, clean sweep, and the box could sleep under a crew it never
#   reached. a non-zero exit is benign only when each error is an absent path — a file
#   that vanished mid-walk
sweep_find() {
  local kind="$1" where="$2" fix="$3" rc err left
  shift 3
  SWEEP_ROW=""
  left=$(budget_left)
  if [ "$left" -eq 0 ]; then
    unreadable "$kind" "the ${READ_BUDGET}s read budget ran out before the sweep of $where" \
      "the sweeps before this one spent the budget; the record names each — read which ran long, and why its tree is large or slow"
    return 0
  fi
  # the find runs under what is left of the budget, so a slow walk cannot push the act past the unit's bound
  # SWEEP_AS, when set, drops the walk to a root's owner (`walk`)
  SWEEP_ROW=$(set -o pipefail; timeout -k "$DIAL_KILL" "$left" "${SWEEP_AS[@]}" find "$@" </dev/null 2>"$ERRS" | newest); rc=$?
  err=$(errs_unread)
  if [ -n "$err" ]; then
    unreadable "$kind" "$err" "$fix"
  elif [ "$rc" -ne 0 ] && [ "$(budget_left)" -eq 0 ]; then
    # the clock, never the code, names the budget: 124 is timeout's TERM, 137 its KILL — and an oom's
    unreadable "$kind" "the sweep of $where passed the ${READ_BUDGET}s read budget (exit $rc)" \
      "the tree is too large or its mount too slow for one tick; read its size and its mount — the box holds meanwhile"
  elif [ "$rc" -ne 0 ] && [ ! -s "$ERRS" ]; then
    unreadable "$kind" "the sweep of $where: find exited $rc with no error text (a kill, or an oom)" \
      "read the kernel log for an oom kill or a signal (journalctl -k) — the box holds meanwhile"
  fi
  return 0
}

# .what = the newest `*.jsonl` under one trace-root glob, and loud if a walk errs
# .why each root is walked as its OWNER, never as root
#   - `-H` follows a root that is itself a symlink (a `projects` dir linked elsewhere), so it
#     is walked, never read as one link and zero traces; a link below the root stays
#     unfollowed, so no loop
#   - a seat owns its own roots, so as root that link could point at a dir the seat cannot
#     read, and the newest path there would land in the world-readable record. as the root's
#     owner, the walk sees exactly what that seat can already see
#   - the owner is the root's own (`stat` reads a link, never its target), so a link a seat
#     plants is walked as that seat
walk() {
  local roots root owned=() pair owners owner uid gid group err at n from
  # shellcheck disable=SC2206 # the root is a glob, by design
  shopt -s nullglob; roots=($1); shopt -u nullglob
  [ ${#roots[@]} -gt 0 ] || return 0   # an unmatched glob is no crew
  # each root once, as '<uid> <gid> <root>'; a root gone since the glob is no crew, any other fault is loud
  for root in "${roots[@]}"; do
    owner=$(stat -c '%u %g' "$root" 2>"$ERRS") && { owned+=("$owner $root"); continue; }
    err=$(errs_unread)
    [ -z "$err" ] || unreadable trace "stat could not read the owner of $root: $err" "the unit runs as root; read why stat refused it"
  done
  [ ${#owned[@]} -gt 0 ] || return 0
  owners=$(printf '%s\n' "${owned[@]}" | cut -d' ' -f1,2 | sort -u)
  # one walk per owner, over every root that owner holds
  while read -r uid gid; do
    group=()
    for pair in "${owned[@]}"; do
      [[ "$pair" == "$uid $gid "* ]] && group+=("${pair#"$uid $gid "}")
    done
    SWEEP_AS=()
    [ "$uid" = "$(id -u)" ] || SWEEP_AS=(setpriv --reuid="$uid" --regid="$gid" --clear-groups)
    sweep_find trace "${group[*]} (as uid $uid)" \
      "read the error as the root's owner (uid $uid): a dir it cannot enter, a mount that refuses, an i/o fault, or a loop" \
      -H "${group[@]}" -name '*.jsonl' -printf '%T@ %p\n'
    SWEEP_AS=()
    read -r at n from <<< "$SWEEP_ROW"
    SEEN_TRACES=$((SEEN_TRACES + ${n:-0}))
    bump "$at" trace "$from"
  done <<< "$owners"
}

# .what = brain traces — the human's, and every crew's
read_traces() {
  local root
  for root in "${TRACE_ROOTS[@]}"; do walk "$root"; done
}

# .what = keystrokes — a numbered pts's atime moves when a human types into it
read_pts() {
  local at n from
  sweep_find pts "$PTS_DIR" "the unit runs as root; read why $PTS_DIR refused it" \
    "$PTS_DIR" -mindepth 1 -maxdepth 1 -type c -name '[0-9]*' -printf '%A@ %p\n'
  read -r at n from <<< "$SWEEP_ROW"
  SEEN_PTS=${n:-0}
  bump "$at" pts "$from"
}

# .what = the process names a tmux server runs under
# .why both: tmux retitles its server to `tmux: server`, so `pgrep -x tmux` alone
#   never meets a live server; a tmux that does not retitle keeps `tmux`
TMUX_SERVER_COMMS=('tmux: server' 'tmux')

# .what = the pgrep scope of the servers this run can reach: every one as root, else its own
# .why tmux admits only its socket's owner, and a seat cannot list another's 0700 socket dir.
#   root (the unit) reaches every server; a run from a seat reaches only its own — so a
#   seat's run that counted every server would cry wolf over servers it can never dial
tmux_server_scope() {
  [ "$(id -u)" = 0 ] && return 0
  echo "-u"
  id -u
}

# .what = does any tmux server this run can reach run, wherever its socket sits?
# .note = exit 0 yes · 1 no · 2 pgrep could not search; pgrep itself exits 1 on
#   no match and above 1 on a fault, so a fault is never read as "none runs"
tmux_server_runs() {
  local comm rc scope
  mapfile -t scope < <(tmux_server_scope)
  for comm in "${TMUX_SERVER_COMMS[@]}"; do
    pgrep "${scope[@]}" -x "$comm" >/dev/null 2>"$ERRS"; rc=$?
    [ "$rc" -eq 0 ] && return 0
    [ "$rc" -eq 1 ] || return 2
  done
  return 1
}

# .what = is this tmux answer a server that is gone? no duct, and no defect
# .why each is tmux's own text: a socket whose server exited (`no server`),
#   a stale socket (`Connection refused`), a socket removed since the glob
#   (`error connecting to … (No such file or directory)`), a server that died
#   mid-dial (`server exited unexpectedly`, `lost server`). any other text — a
#   `protocol version mismatch` above all — is a live server this tmux cannot read
# .why each pattern is anchored to the WHOLE answer: tmux names the socket path inside its
#   text, and any seat chooses that path, so a phrase matched anywhere could make a real
#   fault read as a gone server — a silent skip, the wrong direction
tmux_server_gone() {
  case "$1" in
    "no server running on "*) return 0 ;;
    "error connecting to "*" (Connection refused)"|"error connecting to "*" (No such file or directory)") return 0 ;;
    "server exited unexpectedly"|"lost server") return 0 ;;
    # the socket was removed between the glob and the owner read
    "stat could not read the socket's owner: "*": No such file or directory") return 0 ;;
  esac
  return 1
}

# .what = the fix for a duct that did not answer, by what tmux said — never one that ends a crew
# .why a server is a crew's home: a fix-text that restarts it kills the crew it protects
duct_fix() {
  case "$1" in
    "protocol version mismatch"*)
      echo "a tmux upgrade left this server on its old protocol; never restart it under a crew — read it with the binary it runs (its pid's exe link in procfs, with -S $2 list-windows -a); the hold lifts when its crew ends" ;;
    "")
      echo "the server did not answer within ${DIAL_BOUND}s; read it by hand (tmux -S $2 list-windows), and reap the socket only once no server holds it" ;;
    *)
      echo "read tmux's text above; reap the socket only once no server holds it (lsof -U $2)" ;;
  esac
}

# .what = ask one tmux server for its windows' last output, as the socket's owner
# .output = '<epoch> <session>:<window>' rows on stdout; tmux's own text in $ERRS; exit as the dial's
# .why stdout and stderr stay apart: a stray warning a live server prints would, merged,
#   fail the row check and turn a counted duct into a permanent loud hold
dial_duct() {
  local sock="$1" owner uid gid
  local ask=(tmux -S "$sock" list-windows -a -F '#{window_activity} #{session_name}:#{window_index}')
  owner=$(stat -c '%u %g' "$sock" 2>&1) || { echo "stat could not read the socket's owner: $owner" > "$ERRS"; return 1; }
  read -r uid gid <<< "$owner"
  # a socket this seat owns is dialed as is; any other is dialed as its owner
  [ "$uid" = "$(id -u)" ] || ask=(setpriv --reuid="$uid" --regid="$gid" --clear-groups "${ask[@]}")
  timeout -k "$DIAL_KILL" "$DIAL_BOUND" "${ask[@]}" </dev/null 2>"$ERRS"
}

# .what = a live tmux server this sweep could not read is loud, never silent: guard_unseen <why> <fix>
# .why a moved TMUX_TMPDIR, or a box with no tmux client, would blind the check to every duct
# .why each caller names its own fix: a socket search cannot help a box with no client to dial it
guard_unseen() {
  local rc
  tmux_server_runs; rc=$?
  [ "$rc" -eq 0 ] && unreadable duct "a tmux server runs, and $1" "$2"
  [ "$rc" -eq 2 ] && unreadable duct "pgrep could not search for a tmux server: $(head -1 "$ERRS")" \
    "the unit runs as root; read why pgrep cannot read the process table"
  return 0
}

# .what = is this dial's answer window rows — one '<epoch> <session>:<window>' per line?
# .why a listener that answers junk with exit 0 is no duct: counted, it would let one
#   fake answer stand in for a real server that sits off the sweep
duct_rows() {
  [ -n "$1" ] || return 1
  ! grep -qv '^[0-9][0-9]* ' <<< "$1"
}

# .what = ducts — every tmux server on the box, each window's last pane output
read_ducts() {
  local sock out said row at n from
  if ! command -v tmux >/dev/null 2>&1; then
    guard_unseen "no tmux client is on PATH to read it" \
      "the server's own tmux sits off the unit's PATH: read Environment=PATH= in idle-hibernate.service against \$(command -v tmux) as the crew's seat"
    return 0
  fi
  # the servers are counted before the sweep AND after it, and only a server both counts
  # hold is unswept: one a crew opens mid-sweep, or one that exits between the count and
  # its dial, is no false 💥 on a busy box
  count_servers
  SERVERS_BEFORE=$SERVERS
  SERVERS_ERR_BEFORE=$SERVERS_ERR
  for sock in $TMUX_SOCKETS; do
    [ -S "$sock" ] || continue
    if [ "$(budget_left)" -eq 0 ]; then
      unreadable duct "the sweep passed its ${READ_BUDGET}s budget before $sock" \
        "reap stale sockets under $TMUX_SOCKETS; each live server answers in well under ${DIAL_BOUND}s"
      break
    fi
    if ! out=$(dial_duct "$sock"); then
      said=$(cat "$ERRS")
      tmux_server_gone "$said" && continue
      MET_DUCTS=$((MET_DUCTS + 1))
      unreadable duct "tmux at $sock did not answer: ${said:-timeout}" "$(duct_fix "$said" "$sock")"
      continue
    fi
    MET_DUCTS=$((MET_DUCTS + 1))
    if ! duct_rows "$out"; then
      unreadable duct "tmux at $sock answered no window rows: ${out:-an empty answer}" \
        "read what listens at $sock (lsof -U $sock); a tmux server answers one '<epoch> <session>:<window>' row per window"
      continue
    fi
    SEEN_DUCTS=$((SEEN_DUCTS + 1))
    row=$(printf '%s\n' "$out" | newest)
    read -r at n from <<< "$row"
    bump "$at" duct "$sock $from"
  done
  guard_uncounted
  [ "$MET_DUCTS" -eq 0 ] || return 0
  guard_unseen "no socket under $TMUX_SOCKETS answered" \
    "find its socket (lsof -U -a -p \$(pgrep -o -x 'tmux: server')), then widen TMUX_SOCKETS in this check to reach it"
}

# .what = more retitled tmux servers run than the sweep met: some duct sits off the sweep
# .why one server serves one socket, so a server count above MET_DUCTS is a server this
#   sweep never reached — a moved TMUX_TMPDIR, or a socket a cleaner removed under a live
#   server. one answer must not silence the rest. a tmux that keeps the comm `tmux` shares
#   it with every client, so only the retitled comm can be counted
# .why MET, never SEEN: a socket the sweep reached and could not read is already loud on
#   its own line. counted as unswept too, it would print a second and third 💥 whose fix —
#   widen TMUX_SOCKETS — is the wrong repair for a server that sits right under the glob
guard_uncounted() {
  local held
  count_servers
  if [ "$SERVERS_BEFORE" -lt 0 ] || [ "$SERVERS" -lt 0 ]; then
    # with no duct met, guard_unseen names this fault; with some met, only here
    [ "$MET_DUCTS" -eq 0 ] || unreadable duct "pgrep could not count the tmux servers: ${SERVERS_ERR_BEFORE:-$SERVERS_ERR}" \
      "the unit runs as root; read why pgrep cannot read the process table"
    return 0
  fi
  # a server that ran through the whole sweep is held by both counts
  held=$SERVERS
  [ "$SERVERS_BEFORE" -lt "$held" ] && held=$SERVERS_BEFORE
  [ "$held" -gt "$MET_DUCTS" ] || return 0
  local noun=servers; [ "$held" -eq 1 ] && noun=server
  unreadable duct "$held tmux $noun ran through the sweep, and $MET_DUCTS sat under $TMUX_SOCKETS" \
    "find each server's socket (lsof -U -a -p <pid>); widen TMUX_SOCKETS in this check, or restore the socket"
}

# .what = SERVERS = the retitled tmux servers this run can reach, or -1 with SERVERS_ERR on a fault
count_servers() {
  local pids rc scope
  mapfile -t scope < <(tmux_server_scope)
  pids=$(pgrep "${scope[@]}" -x "${TMUX_SERVER_COMMS[0]}" 2>"$ERRS"); rc=$?
  if [ "$rc" -gt 1 ]; then
    SERVERS=-1
    SERVERS_ERR=$(head -1 "$ERRS")
    return 0
  fi
  SERVERS=$(printf '%s' "$pids" | grep -c .)
}

# .what = seconds since the newest stir; a duct that printed after NOW was read is idle 0
idle_for() {
  local idle=$((NOW - STIR))
  [ "$idle" -ge 0 ] || idle=0
  echo "$idle"
}

# .what = did imds name both this instance and its region? (imds_answered <iid> <region>)
imds_answered() {
  [ -n "$1" ] || return 1
  [ -n "$2" ]
}

# .what = the fix for one aws refusal of the stop, by its cause: act_fix <rc> <aws error line>
# .why one fix for every refusal named the role and hibernate even where aws said the
#   credentials were absent, or that a dry run would have succeeded
act_fix() {
  case "$2" in
    *DryRunOperation*) echo "none owed: aws answered a dry run — the stop would have succeeded, and none was made" ;;
    *NoCredentials*|*"Unable to locate credentials"*|*ExpiredToken*)
      echo "the box holds no live aws credentials: read its instance profile (rhx aws.whoami)" ;;
    *UnauthorizedOperation*|*AccessDenied*)
      echo "the instance role lacks ec2:StopInstances on this instance: grant it in the role's policy" ;;
    *[Hh]ibernat*) echo "hibernate is off for this instance: it is set at launch, so the instance must be relaunched with it on" ;;
    *)
      [ "$1" -eq 124 ] || [ "$1" -eq 137 ] && { echo "aws did not answer within ${AWS_BOUND}s: read the box's route to the ec2 endpoint"; return 0; }
      echo "read the aws error on the 💥 line" ;;
  esac
}

# .what = stop this instance with hibernate, via imds and the aws cli
# .note = each refusal says the box did not sleep: the verdict line above it said "hibernate now"
act_hibernate() {
  local token iid region late rc said
  # the act's own bounds fit the unit only after a read window of at most READ_BUDGET plus
  # one last dial; a run past that would be killed mid-stop, so it holds and says so
  late=$(( $(date +%s) - NOW - READ_BUDGET - DIAL_BOUND - DIAL_KILL ))
  [ "$late" -le 0 ] || {
    say 2 "idle-hibernate: 💥 MalfunctionError: the reads ran ${late}s past their window, so the stop act would not fit the unit's bound, and the box did not sleep"
    say 2 "   └─ fix: the trace roots are too large or their mount too slow for one tick — read their size and their mount; the check retries next tick"
    exit 1
  }
  command -v aws >/dev/null 2>&1 || {
    say 2 "idle-hibernate: 💥 MalfunctionError: no aws cli on PATH, so stop-instances cannot be called, and the box did not sleep"
    say 2 "   └─ fix: the first boot installs aws, so read the box's cloud-init output log for why it failed; then from the ground seat, rhx grove.provision --what 5.6.aws --mode apply; the check retries next tick"
    exit 1
  }
  # .exemption = raw curl, never `web_fetch` from `src/grove.web.sh`: this file is installed to
  #   /usr/local/bin and run by systemd on a box with no checkout, so there is no boundary to
  #   source. each call carries its own `--max-time`, and the unit's `TimeoutStartSec=` bounds all
  # .trigger = the day a wire boundary ships as an installed file this check can source (a copy of
  #   `grove.web.sh` beside it in /usr/local/lib), this exemption ends and these calls move behind it
  # `-f` makes an imds error body an empty answer, so the guard below refuses it
  token=$(curl -sf --max-time "$IMDS_BOUND" -X PUT "$IMDS/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" </dev/null)
  iid=$(curl -sf --max-time "$IMDS_BOUND" -H "X-aws-ec2-metadata-token: $token" "$IMDS/meta-data/instance-id" </dev/null)
  region=$(curl -sf --max-time "$IMDS_BOUND" -H "X-aws-ec2-metadata-token: $token" "$IMDS/meta-data/placement/region" </dev/null)
  imds_answered "$iid" "$region" || {
    say 2 "idle-hibernate: 💥 MalfunctionError: imds gave no instance-id/region (iid=${iid:-empty} region=${region:-empty}), so the box did not sleep"
    say 2 "   └─ fix: read the box's metadata options (http-endpoint enabled, hop limit >= 1); the check retries next tick"
    exit 1
  }
  # `-k`: a SIGTERM is a request; the KILL after the grace is the bound. `</dev/null`: a
  # prompt for input would otherwise wait out the whole bound
  # aws's error rides on the 💥 line, so the fix can name it and the journal holds it once
  timeout -k "$AWS_KILL" "$AWS_BOUND" aws ec2 stop-instances --hibernate --instance-ids "$iid" --region "$region" </dev/null 2>"$ERRS" || {
    rc=$?
    said=$(grep -m1 -v '^[[:space:]]*$' "$ERRS")
    say 2 "idle-hibernate: 💥 MalfunctionError: aws refused stop-instances --hibernate for $iid, so the box did not sleep: ${said:-no error text (exit $rc)}"
    say 2 "   └─ fix: $(act_fix "$rc" "$said"); the check retries next tick"
    exit 1
  }
  say 1 "idle-hibernate: stop-instances --hibernate accepted for $iid"
  write_record "$LAST_SLEEP" 0
}

read_boot
read_wake
read_traces
read_pts
read_ducts

IDLE_FOR=$(idle_for)
VERDICT="idle=${IDLE_FOR}s limit=${IDLE_LIMIT}s, newest=$STIR_KIND $STIR_FROM; seen traces=$SEEN_TRACES pts=$SEEN_PTS ducts=$SEEN_DUCTS"
# an unread source exits 1 on EVERY hold, not only the one it forced: a fresh trace
# must not hide a blind source until the traces go quiet, when it starts to bill
# the verdict line names an unread source on every hold, so its exit 1 never reads as a quiet hold
if [ "$IDLE_FOR" -lt "$IDLE_LIMIT" ]; then
  [ "$UNREAD" -eq 0 ] && { say 1 "idle-hibernate: hold — $VERDICT"; exit 0; }
  say 1 "idle-hibernate: hold — $VERDICT; and $UNREAD source(s) unreadable (each a 💥 line on stderr), so this run exits 1"
  exit 1
fi
if [ "$UNREAD" -gt 0 ]; then
  say 1 "idle-hibernate: hold — $VERDICT; but $UNREAD source(s) unreadable (each a 💥 line on stderr), and a box the check cannot read is held, never slept"
  exit 1
fi
say 1 "idle-hibernate: sleep — $VERDICT — hibernate now"
# the sleep record lands BEFORE the act: a hibernate freezes this run at once, and its
# /run tmpfs survives in the saved memory, so the record is there when the box wakes.
# `exit=unanswered` until the act answers; an act that fails leaves its fault in LAST_RECORD
write_record "$LAST_SLEEP" unanswered
act_hibernate
