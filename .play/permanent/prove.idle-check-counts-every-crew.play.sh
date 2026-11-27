#!/usr/bin/env bash
######################################################################
# prove.idle-check-counts-every-crew — the grove's idle check holds a box with
# a crew at work, still sleeps an idle one, and holds loud when it cannot read
#
# .what = drives a COPY of the checkout's
#         `src/grove.provision/1.system/1.15.hibernate/idle-hibernate.sh`
#         against a hermetic fixture root:
#           - every absolute path the check reads (`/home/`, `/proc/uptime`,
#             `/dev/pts`, `/tmp/tmux-`) is rewritten into the fixture, and the
#             copy is read back to prove no live-box read survived the rewrite
#           - the pts read's `-type c` becomes `-type f`, so a regular file with a
#             set atime and mtime stands in for a pts — an unprivileged seat cannot
#             mint a char device, and the atime-vs-mtime rule is what the arm proves
#           - `aws`, `curl`, and `pgrep` are stubs on PATH, so a `hibernate`
#             verdict calls no cloud and no imds, and "does a tmux server run?"
#             answers from the fixture, never from this box
#
# .why a rewrite, never a knob in the check
#   - the clamp must go red against the check it replaced, and those bytes have
#     no knob. a rewrite reaches old bytes and new bytes alike
#   - ⇒ the red proof is a play of its own: `prove.idle-check-clamp-bites-the-legacy-check`
#     runs this play with `IDLE_CHECK` at the frozen old bytes, and demands red
#     (`rule.require.clamp-edge-cases`)
#
# .the arms — the check
#   worktree   a crew trace in a worktree is fresh                    → hold
#   mainclone  a crew trace in a main clone is fresh                  → hold
#   human      the human's own trace is fresh                         → hold
#   boot       the box resumed a minute ago                           → hold, newest=boot
#   keystroke  a pts read a minute ago, written to 5h ago             → hold, newest=pts
#   output     a pts written a minute ago, read 5h ago                → hibernate
#              (a keystroke is atime; output alone moves mtime)
#   ptmx       the pty multiplexer was read a minute ago              → hibernate (no human typed)
#   idle       every trace stale, no duct                             → `sleep — …` line, stop act called
#   counts     the idle verdict names what each source read           → `seen traces=3 pts=1 ducts=0`
#   imdsempty  imds answers naught on a stale box                     → exit 1, `💥 … imds gave no …`
#   awsrefused aws refuses the stop on a stale box                    → exit 1, `💥 … aws refused …`
#              (.sleep: the sleep record stays `exit=unanswered`)
#   duct       a live tmux server whose pane just printed             → hold
#   silentduct a live tmux server whose panes last printed 5h ago     → hibernate
#              (a duct holds by OUTPUT, never by presence alone)
#   pipe       10k stale traces, SIGPIPE ignored as systemd does      → no `Broken pipe`
#   (each loud hold below exits 1, so the unit's Result names it)
#   unreadable a tmux socket that refuses                             → `💥 … duct unreadable`, hold
#   refused    a crew dir the walk cannot enter                       → `💥 … trace unreadable`, hold
#   ioerror    a trace walk that reports an i/o fault, not a refusal  → `💥 … trace unreadable`, hold
#   noboot     no /proc/uptime to read                                → `💥 … boot unreadable`, hold
#   ptsunread  a pts dir the check cannot list                        → `💥 … pts unreadable`, hold
#   dropowner  a root check on a seat's socket                        → dialed via `setpriv` as the owner
#   notmux     a server runs, and no tmux client is on PATH           → `💥 … duct unreadable`, hold
#   pgrepfault pgrep cannot search the process table                  → `💥 … duct unreadable`, hold
#   hung       a tmux that never answers                              → ended by the dial bound, loud
#   budget     the sweep passed its read budget                       → stops, names the socket, loud
#   unswept    one socket answered, and a second server runs off the sweep → `💥 … duct unreadable`, hold
#   scope      a seat's run, and a root run                          → pgrep asked for its own uid / every server
#   findkill   a find killed mid-walk, with no word on stderr         → `💥 … trace unreadable`, hold
#   hostilename  a socket named with ESC and a newline                → each control byte reads `?`, no forged line
#   linkedroot a fresh trace under a `projects` dir that is a symlink   → hold (`find -H`)
#   codex      a codex crew's fresh `~/.codex/sessions/…/rollout-*.jsonl` → hold
#   junkduct   a socket that answers exit 0 with no window rows         → `💥 … duct unreadable`, hold
#   lostserver tmux says `lost server` — the server died mid-dial        → hibernate, quiet
#   mismatch   tmux says `protocol version mismatch`                     → `💥 … duct unreadable`, hold
#   bornmidsweep  a crew opens a second server mid-sweep                → hold, quiet: counted before the sweep
#   slowwalk   a walk slower than the read budget                       → killed at it, hold loud, no stop act
#   actlate    reads that end past their window                         → exit 1, the act refused
#   hostilepath  an unreadable dir named `x: No such file or directory`  → `💥 … trace unreadable`, hold
#   hostilename.benign  a refused socket named `x (Connection refused)` → `💥 … duct unreadable`, hold
#   traceowner a root run on a seat's trace roots                       → walked via `setpriv` as their owner
#   wakegap    the last tick 2h back — a hibernate the uptime cannot see → hold, newest=wake, the wake recorded
#   wakecarry  the tick after a wake                                    → hold, newest=wake — the floor lasts the limit
#   wakeover   a wake 4h back                                           → hibernate, the wake dropped from the record
#   wakebadrecord  a record that names no time                          → `💥 … wake unreadable`, hold
#   sleeprecord  a sleep, then a hold                                   → `/run/idle-hibernate.last-sleep` keeps the sleep
#   record     each run leaves `/run/idle-hibernate.last` at 0644     → when, the exit, every line said
#   recordnodir     no dir for the record                            → 💥 could not write (its record would read exit=<n>) — <why>, once per write, its fix, exit unchanged
#   recordnorename  the rename into place fails                      → 💥 could not write (its record would read exit=<n>) — the error is above, no temp left
#   future     a trace stamped an hour ahead                          → `💥 … trace unreadable`, hold
#   freshunread  a fresh trace beside a crew dir the walk cannot enter → hold, loud, exit 1
#   edgehold / edgesleep   a trace one minute inside / past the 3h limit → hold / hibernate
#   noaws      no aws cli on PATH, on a stale box                    → exit 1, the 5.6.aws fix named
#   moved      a tmux server runs, and no swept socket answers        → `💥 … duct unreadable`, hold
#   stale      a socket left by a killed server                       → hibernate, quiet
#   vanished   a socket whose file is gone when tmux dials it         → hibernate, quiet
#
# .the arms — the two tmux facts the check rests on (they run no check)
#   activity   a real pane's `#{window_activity}` holds still while silent, and moves on output
#   pgrepreal  `pgrep -x tmux` names a real tmux server's pid
#
# .the arm record — each verdict appends `<arm> pass|fail` to `$IDLE_ARMS` when
#   it is set, so `prove.idle-check-clamp-bites-the-legacy-check` reads one
#   machine line per arm and refuses an arm it has no class for
#
# .the write — `rule.forbid.repair-plays` exception 2. the break is a temp dir
#   and tmux servers on sockets inside it; a trap kills both
#
# ⚠️ .what it does NOT prove
#   - that the kernel stamps a pts's atime on a read; `w(1)` rests on the same
#     fact, and `prove.idle-check-reads-this-box` reads the live pts set
#   - root may attach to another user's tmux server — the grove proof reads that
#   - the unit and timer on a real grove — `1.15.hibernate`'s verify reads that
#
# ⚠️ .why it refuses root
#   - `unreadable` and `refused` break a read with `chmod 0000`, and root reads
#     through that. as root those two arms would measure no world
#
# usage:
#   rhx play.run --play prove.idle-check-counts-every-crew
######################################################################
set -uo pipefail

# the checkout is this file's own, never the cwd: rhx guarantees no cwd
REPO="${GROVE_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src}"
CHECK="${IDLE_CHECK:-$REPO/grove.provision/1.system/1.15.hibernate/idle-hibernate.sh}"
ARMS="${IDLE_ARMS:-/dev/null}"
FIX=""
FAILED=0

# .what = tmux, bounded — a wedged server never hangs the play or its trap
tx() { timeout -k 2 5 tmux "$@" </dev/null; }

cleanup() {
  local sock
  if [[ -n "$FIX" ]]; then
    for sock in "$FIX"/tmp/tmux-*/* "$FIX"/fact/*; do
      [[ -S "$sock" ]] || continue
      chmod 0700 "$sock" 2>/dev/null
      tx -S "$sock" kill-server 2>/dev/null
    done
    rm -rf "$FIX"
  fi
  echo ""
  # a fixture this play may write only if the trap removes it: one that survives fails the play
  if [[ -n "$FIX" && -e "$FIX" ]]; then
    echo "   ✋ residue SURVIVED — $FIX"
    exit 1
  else
    echo "   🧹 restored: fixture and tmux servers gone"
  fi
}
trap cleanup EXIT

[[ -f "$CHECK" ]] || { echo "✋ ConstraintError: no check at $CHECK — this play measures the real file"; exit 2; }
command -v tmux >/dev/null 2>&1 || { echo "✋ ConstraintError: no tmux on PATH — the duct arms need a real server"; exit 2; }
[[ "$EUID" -ne 0 ]] || { echo "✋ ConstraintError: run from a seat without root — chmod 0000 does not bind root, so two arms would measure no world"; exit 2; }

# a short root, so a tmux socket path stays under the 108-byte limit
FIX="$(mktemp -d /tmp/pih.XXXXXX)"
mkdir -p "$FIX/bin" "$FIX/bin.silent" "$FIX/bin.vanished" "$FIX/fact"
# the stub logs its call to a file, never to stdout: a real aws prints its own answer, and
# the snap's stdout must hold the check's lines alone
printf '#!/bin/sh\necho "stub aws $*" >> "%s/aws.log"\n' "$FIX" > "$FIX/bin/aws"
printf '#!/bin/sh\necho stub\n' > "$FIX/bin/curl"
# pgrep answers "a tmux server runs" from a flag file the arm sets, or faults on another.
# the file holds one pid line per server, as pgrep prints them; an empty file is a server
# that runs under a comm the check cannot count
printf '#!/bin/sh\necho "$*" >> "%s/pgrep.log"\n[ -e "%s/pgrep.fault" ] && { echo "pgrep: cannot read the process table" >&2; exit 3; }\n[ -e "%s/pgrep.tmux" ] || exit 1\ncat "%s/pgrep.tmux"\n' \
  "$FIX" "$FIX" "$FIX" "$FIX" > "$FIX/bin/pgrep"
# a find killed mid-walk: no output, no word on stderr, a signal's exit
mkdir -p "$FIX/bin.findkill"
printf '#!/bin/sh\nexit 137\n' > "$FIX/bin.findkill/find"; chmod +x "$FIX/bin.findkill/find"
# a seat that reads as root: `id -u` says 0, and `setpriv` logs the drop it was asked for,
# then runs the dial as this seat — which owns every fixture socket
mkdir -p "$FIX/bin.root"
printf '#!/bin/sh\n[ "$1" = -u ] && { echo 0; exit 0; }\nexec %s "$@"\n' "$(command -v id)" > "$FIX/bin.root/id"
printf '#!/bin/sh\necho "$*" >> "%s/setpriv.log"\nwhile [ "${1#--}" != "$1" ]; do shift; done\nexec "$@"\n' "$FIX" > "$FIX/bin.root/setpriv"
chmod +x "$FIX/bin.root/id" "$FIX/bin.root/setpriv"
# a tmux that never answers, so the dial's bound is what ends it
mkdir -p "$FIX/bin.hung"
printf '#!/bin/sh\nexec sleep 60\n' > "$FIX/bin.hung/tmux"; chmod +x "$FIX/bin.hung/tmux"
# a PATH with every base tool and the stubs, and no tmux client at all
mkdir -p "$FIX/bin.notmux"
for tool in /usr/bin/* /bin/*; do
  case "${tool##*/}" in tmux|pgrep|aws|curl) continue ;; esac
  # `-n`: a link that names a dir (`X11 -> .`) is replaced, never descended into
  ln -sfn "$tool" "$FIX/bin.notmux/${tool##*/}"
done
# a tmux whose every window last printed 5h1m ago — a duct present and silent. a minute older
# than the world's 5h traces, so the newest stir never turns on which second each was read
printf '#!/bin/sh\necho "$(( $(date +%%s) - 18060 )) crew:0"\n' > "$FIX/bin.silent/tmux"
# a tmux that dials a socket gone since the glob — tmux names it by its errno text
printf '#!/bin/sh\nrm -f "%s/pgrep.tmux"\necho "error connecting to $2 (No such file or directory)" >&2\nexit 1\n' "$FIX" > "$FIX/bin.vanished/tmux"
# tmux's own texts for a server that died mid-dial, and for one this client cannot speak to
mkdir -p "$FIX/bin.lost" "$FIX/bin.mismatch" "$FIX/bin.junk" "$FIX/bin.born" "$FIX/bin.slowfind"
# each exits its server at the dial: the count before the sweep saw it, the count after does not
printf '#!/bin/sh\nrm -f "%s/pgrep.tmux"\necho "lost server" >&2\nexit 1\n' "$FIX" > "$FIX/bin.lost/tmux"
printf '#!/bin/sh\necho "protocol version mismatch (client 8, server 7)" >&2\nexit 1\n' > "$FIX/bin.mismatch/tmux"
# a listener that answers exit 0 with no window rows
printf '#!/bin/sh\necho "hello"\n' > "$FIX/bin.junk/tmux"
# a crew opens a second server at the moment the sweep dials the first
printf '#!/bin/sh\necho 98 >> "%s/pgrep.tmux"\nexec %s "$@"\n' "$FIX" "$(command -v tmux)" > "$FIX/bin.born/tmux"
# a walk slower than the whole read budget
printf '#!/bin/sh\nsleep 4\nexec %s "$@"\n' "$(command -v find)" > "$FIX/bin.slowfind/find"
chmod +x "$FIX/bin.lost/tmux" "$FIX/bin.mismatch/tmux" "$FIX/bin.junk/tmux" "$FIX/bin.born/tmux" "$FIX/bin.slowfind/find"
# an imds that refuses (`curl -f` exits 22, prints naught), and an aws that refuses the stop
mkdir -p "$FIX/bin.noimds" "$FIX/bin.awsno"
printf '#!/bin/sh\nexit 22\n' > "$FIX/bin.noimds/curl"
printf '#!/bin/sh\necho "An error occurred (UnauthorizedOperation)" >&2\nexit 254\n' > "$FIX/bin.awsno/aws"
chmod +x "$FIX/bin.noimds/curl" "$FIX/bin.awsno/aws"
# a PATH with the stub curl and pgrep, the base tools, and no aws at all
mkdir -p "$FIX/bin.noaws"
ln -s "$FIX/bin/curl" "$FIX/bin.noaws/curl"; ln -s "$FIX/bin/pgrep" "$FIX/bin.noaws/pgrep"
# a find that walks, then reports an i/o fault — an error that is not a refusal
mkdir -p "$FIX/bin.ioerr"
# the fault names the first root the walk was handed, as a real find names the dir it failed on
printf '%s\n' '#!/bin/sh' "$(command -v find) \"\$@\"" \
  'for a in "$@"; do [ -d "$a" ] && { echo "find: '"'"'$a'"'"': Input/output error" >&2; break; }; done' > "$FIX/bin.ioerr/find"
chmod +x "$FIX/bin/aws" "$FIX/bin/curl" "$FIX/bin/pgrep" "$FIX/bin.silent/tmux" "$FIX/bin.vanished/tmux" "$FIX/bin.ioerr/find"
ln -s "$FIX/bin/curl" "$FIX/bin.notmux/curl"; ln -s "$FIX/bin/pgrep" "$FIX/bin.notmux/pgrep"; ln -s "$FIX/bin/aws" "$FIX/bin.notmux/aws"

# the copy, with every absolute path the check reads moved into the fixture
COPY="$FIX/idle-hibernate.sh"
sed -e "s#/home/#$FIX/home/#g" \
    -e "s#/proc/uptime#$FIX/proc/uptime#g" \
    -e "s#/dev/pts#$FIX/dev/pts#g" \
    -e "s#-type c#-type f#g" \
    -e "s#/tmp/tmux-#$FIX/tmp/tmux-#g" \
    -e "s#/run/idle-hibernate.last#$FIX/run/idle-hibernate.last#g" "$CHECK" > "$COPY"
RECORD_FILE="$FIX/run/idle-hibernate.last"

# a read the rewrite missed would measure THIS box and pass for the wrong reason.
# an ALLOW-list, never a deny-list: on a code line, every absolute path must sit
# under the fixture (read as `@FIX`) or be `/dev/null`; a new read of any box path
# — `/var`, `/root`, `/sys`, `/run` — fails here. `$HOME`, `~/`, and a pts
# predicate the rewrite missed are named too
LEAK="$(awk -v fix="$FIX" '
  /^[[:space:]]*#/ { next }
  { s = $0; gsub(fix, "@FIX", s); line = s
    # a path segment after a word, a glob star, or a brace continues a path; it starts none
    while (match(s, /(^|[^A-Za-z0-9_.@:\/$*}-])\/[A-Za-z][^ \047"):;|]*/)) {
      tok = substr(s, RSTART, RLENGTH); sub(/^[^\/]/, "", tok)
      if (tok != "/dev/null") print NR ": " tok "   ← " line
      s = substr(s, RSTART + RLENGTH)
    }
    if (line ~ /\$HOME|~\/|-type c/) print NR ": " line
  }' "$COPY")"
if [[ -n "$LEAK" ]]; then
  echo "💥 MalfunctionError: the rewrite left a live-box read in the copy — this play would measure this box:"
  printf '%s\n' "$LEAK" | sed 's/^/   │ /'
  exit 1
fi

HUMAN="$FIX/home/u/.claude/projects/d"
CREW="$FIX/home/u/git/org/_worktrees/tree/.agent/.actors/actor/brain/.claude/projects/d"
MAIN="$FIX/home/u/git/org/repo/.agent/.actors/actor/brain/.claude/projects/d"
PTS="$FIX/dev/pts/0"

# .what = a fresh world: boot long ago, a stale trace in every row, a stale pts, no tmux
world() {
  local sock
  for sock in "$FIX"/tmp/tmux-*/*; do
    [[ -S "$sock" ]] || continue
    chmod 0700 "$sock"; tx -S "$sock" kill-server 2>/dev/null
  done
  rm -rf "$FIX/home" "$FIX/proc" "$FIX/dev" "$FIX/tmp" "$FIX/run" "$FIX/pgrep.tmux" "$FIX/pgrep.fault" "$FIX/setpriv.log" "$FIX/pgrep.log"
  mkdir -p "$HUMAN" "$CREW" "$MAIN" "$FIX/proc" "$FIX/dev/pts" "$FIX/tmp" "$FIX/run"
  echo "999999.00 0" > "$FIX/proc/uptime"
  touch -d '-5 hours' "$HUMAN/h.jsonl" "$CREW/c.jsonl" "$MAIN/m.jsonl" "$PTS"
}

# .what = a live tmux server on a socket under $1's dir; echoes the socket path
server() {
  local dir="$1" sock
  mkdir -p "$dir"; chmod 0700 "$dir"
  sock="$dir/default"
  tx -f /dev/null -S "$sock" new-session -d -s crew "${2:-sleep 600}" || return 1
  echo "$sock"
}
# .what = a fixture duct, swept by the check's glob; adds one server to pgrep's answer
duct() { server "$FIX/tmp/tmux-$1" && echo "$1" >> "$FIX/pgrep.tmux"; }
# .what = halt the play: the world the arm needs did not come up
nowall() { echo "   💥 MalfunctionError: $1 — this play measured no world"; exit 1; }

# .what = run the copy; keep stdout, stderr, rc in globals
OUT=""; ERR=""; RC=""; RUNS=0
run() {
  local errf="$FIX/err"
  # the stop act's log speaks for this run alone
  rm -f "$FIX/aws.log"
  # XWHOLEPATH replaces the whole PATH, for an arm that must hide a binary the box holds
  OUT="$(PATH="${XWHOLEPATH:-${XPATH:-}$FIX/bin:$PATH}" "$@" 2>"$errf")"; RC=$?
  ERR="$(cat "$errf")"
  RUNS=$((RUNS + 1))
}
# .what = run the copy as systemd would, minus the SIGPIPE disposition
check() { run bash "$COPY"; }
# .what = print the last run's exit, stdout, and stderr under a failed arm
quote() {
  echo "   │     │ exit=$RC"
  printf '%s\n' "$OUT" | head -5 | sed 's/^/   │     │ out: /'
  printf '%s\n' "$ERR" | head -5 | sed 's/^/   │     │ err: /'
}
# .what = record one arm's verdict, for a human and for the bite play
pass() { echo "   │  ✔ $2"; echo "$1 pass" >> "$ARMS"; keep "$1"; }
fail() { echo "   │  ✋ $2"; quote; echo "$1 fail" >> "$ARMS"; FAILED=1; keep "$1"; }
# .what = the check's verdict lines; exactly one is owed per run
verdicts() { grep '^idle-hibernate: ' <<< "$OUT"; }
# .what = did the last run judge the box idle?
slept() { [[ "$OUT" == *"hibernate now"* ]]; }
# .what = judge an arm that must hold, with the newest stir named as $2
holds() {
  local line
  echo "   ├─ arm '$1'"
  slept && { fail "$1" "hibernate — $3"; return; }
  line="$(verdicts)"
  [[ "$line" =~ ^idle-hibernate:\ hold\ —\ idle=[0-9]+s\ limit=10800s,\ newest= && "$line" != *$'\n'* ]] \
    || { fail "$1" "held, and the verdict is not one \`hold — idle=<n>s limit=<n>s, newest=…\` line"; return; }
  [[ "$line" == *"newest=$2"* ]] || { fail "$1" "held, and the hold line does not name $2"; return; }
  pass "$1" "hold — newest=$2"
}
# .what = judge an arm that must sleep, quiet — then, as `<arm>.line`, the shape of its verdict
# .why two records: the old check sleeps these boxes correctly and words the line
#   another way; the bite play must read the behavior apart from the wording
sleeps() {
  local line
  echo "   ├─ arm '$1'"
  slept || { fail "$1" "held — $2"; return; }
  [[ "$ERR" == *"MalfunctionError"* || "$ERR" == *"⚠️"* ]] && { fail "$1" "slept, and raised an alarm — $3"; return; }
  pass "$1" "hibernate, quiet — $4"
  line="$(verdicts | head -1)"
  if [[ "$line" =~ ^idle-hibernate:\ sleep\ —\ idle=[0-9]+s\ limit=10800s,\ newest=.+\ —\ hibernate\ now$ ]]; then
    pass "$1.line" "one \`sleep — idle=<n>s limit=<n>s, newest=… — hibernate now\` line"
  else
    fail "$1.line" "the verdict is not one \`sleep — idle=<n>s limit=<n>s, newest=… — hibernate now\` line"
  fi
}
# .what = judge an arm that must hold LOUD: a malfunction of kind $2, its fix, and a hold
holdsloud() {
  echo "   ├─ arm '$1'"
  [[ "$ERR" == *"💥 MalfunctionError: $2 unreadable"* ]] || { fail "$1" "a $2 the check could not read was silent"; return; }
  [[ "$ERR" == *"fix:"* ]] || { fail "$1" "the unreadable line names no fix"; return; }
  slept && { fail "$1" "hibernate — a box with an unread source must hold"; return; }
  [[ "$OUT" == *"unreadable"* ]] || { fail "$1" "held, and the hold line does not say a source went unread"; return; }
  [[ "$RC" -eq 1 ]] || { fail "$1" "held on an unread source and exited $RC — the unit's Result could not name it"; return; }
  pass "$1" "loud, held — $(printf '%s' "$ERR" | head -1 | cut -c1-70)…"
}

# .what = the transcript snap: EVERY run's stdout and stderr, kept APART and masked
# .why every run: a word-level assert proves a phrase is present, never that the rest of the
#   line still reads right — so each variant a caller can meet is a reviewed artifact
#   (`rule.require.contract-snapshot-exhaustiveness`). pass and fail keep the run once, under
#   the first arm that judges it; an arm that runs no check (nohead, activity) keeps none
# .why apart: a runner may interleave the two streams, and a merged capture reorders
#   on another box. masked: the fixture root, epochs, and idle counts differ per run, and the
#   fixture owner's uid differs per seat
SNAP=""; KEPT=0
mask() {
  printf '%s' "$1" | sed -E -e "s#$FIX#<fix>#g" -e 's/idle=[0-9]+s/idle=<n>s/g' -e "s/\((as )?uid $(id -u)\)/(\1uid <uid>)/g" \
    -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+Z/<t>/g' -e 's/[0-9]{9,}/<t>/g' -e 's/sat [0-9]+s back/sat <n>s back/g' \
    -e 's/ran -?[0-9]+s past/ran <n>s past/g' -e 's/stamped [0-9]+s in the future/stamped <n>s in the future/g'
}
keep() {
  [[ "$RUNS" -gt "$KEPT" ]] || return 0
  KEPT=$RUNS
  SNAP+="## $1 (exit $RC)"$'\n'"### stdout"$'\n'"$(mask "$OUT")"$'\n'"### stderr"$'\n'"$(mask "$ERR")"$'\n'
  [[ -s "$FIX/aws.log" ]] && SNAP+="### aws"$'\n'"$(mask "$(cat "$FIX/aws.log")")"$'\n'
  SNAP+=$'\n'
}
# .what = did the last run call the stop act?
acted() { [[ -s "$FIX/aws.log" ]]; }

echo "🔭 does the idle check count every crew, and only real stir?"

# the pipe arm sees a broken pipe only where it builds the input; a static read sees every one.
# a `| head` on any code line leaves its writer on a closed pipe under systemd's ignored SIGPIPE
echo "   ├─ arm 'nohead'"
HEADS="$(grep -nE '\|[[:space:]]*head\b' "$COPY" | grep -vE '^[0-9]+:[[:space:]]*#')"
if [[ -z "$HEADS" ]]; then pass nohead "no \`| head\` on any code line of the check"
else fail nohead "a \`| head\` sits on a code line: $(head -1 <<< "$HEADS" | cut -c1-80)"; fi

world; touch "$CREW/c.jsonl"; check
holds worktree "trace $CREW/c.jsonl" "a crew at work in its worktree was not counted"

world; touch "$MAIN/m.jsonl"; check
holds mainclone "trace $MAIN/m.jsonl" "a crew at work in a main clone was not counted"

world; touch "$HUMAN/h.jsonl"; check
holds human "trace $HUMAN/h.jsonl" "the human's own fresh trace was not counted"

world; echo "60.00 0" > "$FIX/proc/uptime"; check
holds boot "boot" "a box that resumed a minute ago was judged idle"

world; touch -a -d '-1 minute' "$PTS"; check
holds keystroke "pts $PTS" "a pts a human typed into a minute ago was not counted"

world; touch -m -d '-1 minute' "$PTS"; check
sleeps output "a pts that only printed holds the box — output moves mtime, a keystroke moves atime" \
  "output is no fault" "a printed-to pts is no keystroke"

world; touch -a -d '-1 minute' "$FIX/dev/pts/ptmx"; touch -m -d '-5 hours' "$FIX/dev/pts/ptmx"; check
sleeps ptmx "the pty multiplexer's atime held the box — any pty's output stamps it, no human typed" \
  "the multiplexer is no fault" "ptmx is no keystroke"

world; check
sleeps idle "an idle box must still sleep" "an idle box is no fault" "every source stale"
grep -q '^stub aws ec2 stop-instances --hibernate' "$FIX/aws.log" 2>/dev/null \
  || { echo "   ├─ arm 'idle.act'"; fail idle.act "slept, and the stop act was not called"; }
echo "   ├─ arm 'counts'"
if [[ "$OUT" == *"; seen traces=3 pts=1 ducts=0"* ]]; then pass counts "seen traces=3 pts=1 ducts=0 — each source names what it read"
else fail counts "the verdict does not name what each source read (want: seen traces=3 pts=1 ducts=0)"; fi

# .what = judge a stop act that must fail loud: exit 1, the malfunction $2, and no accepted line
actfails() {
  echo "   ├─ arm '$1'"
  [[ "$RC" -eq 1 ]] || { fail "$1" "the stop act failed and the check exited $RC"; return; }
  [[ "$ERR" == *"💥 MalfunctionError: $2"* ]] || { fail "$1" "the stop act failed, and no \`💥 MalfunctionError: $2\` line names it"; return; }
  [[ "$ERR" == *"$2"*"└─ fix: "* ]] || { fail "$1" "the stop act failed, and no \`└─ fix:\` line follows its malfunction"; return; }
  [[ "$OUT" != *"accepted"* ]] || { fail "$1" "the stop act failed, and the check said it was accepted"; return; }
  pass "$1" "exit 1 — $2, with its fix"
}

world; XPATH="$FIX/bin.noimds:" check
actfails imdsempty "imds gave no instance-id/region"

world; XPATH="$FIX/bin.awsno:" check
actfails awsrefused "aws refused stop-instances --hibernate"
# a refused act leaves the sleep record `unanswered`: the verify reads that as "may never have slept"
echo "   ├─ arm 'awsrefused.sleep'"
if [[ "$(head -1 "$FIX/run/idle-hibernate.last-sleep" 2>/dev/null)" == *" exit=unanswered" ]]; then
  pass awsrefused.sleep "the sleep record reads exit=unanswered, never exit=0"
else fail awsrefused.sleep "a refused act left no unanswered sleep record"; fi

world; XWHOLEPATH="$FIX/bin.noaws:/usr/bin:/bin" check
actfails noaws "no aws cli on PATH"
[[ "$ERR" == *"5.6.aws"* ]] || { echo "   ├─ arm 'noaws.fix'"; fail noaws.fix "the no-aws fix does not name the 5.6.aws bundle"; }

# the 3h edge, one minute either side: `-lt` holds at 2h59m, sleeps at 3h01m
# the human's own trace, which the old check reads too, so the arm tests the edge alone
world; touch -d '-10740 seconds' "$HUMAN/h.jsonl"; check
holds edgehold "trace $HUMAN/h.jsonl" "a trace one minute inside the limit was judged idle"
world; touch -d '-10860 seconds' "$HUMAN/h.jsonl"; check
sleeps edgesleep "a trace one minute past the limit held the box" "an idle box is no fault" "one minute past the limit"

# a trace stamped an hour ahead — a skewed clock — is no evidence; the box holds LOUD
world; touch -d '+1 hour' "$HUMAN/h.jsonl"; check
holdsloud future trace
[[ "$ERR" == *"stamped"*"in the future"* ]] || { echo "   ├─ arm 'future.why'"; fail future.why "the future stamp is not named as the cause"; }

# a fresh stir must not hide a blind source: the hold exits 1, so the Result names it
world; touch "$HUMAN/h.jsonl"; chmod 0000 "$CREW"; check; chmod 0700 "$CREW"
echo "   ├─ arm 'freshunread'"
if slept; then fail freshunread "hibernate — a fresh trace was on the box"
elif [[ "$ERR" != *"💥 MalfunctionError: trace unreadable"* ]]; then fail freshunread "a source the check could not read was silent beside a fresh trace"
elif [[ "$RC" -ne 1 ]]; then fail freshunread "held on a fresh trace with a blind source, and exited $RC — the unit's Result hides it"
else pass freshunread "held on the fresh trace, loud on the blind one, exit 1"; fi

# a pts dir the check cannot list is no proof no human types: the box holds LOUD
world; chmod 0000 "$FIX/dev/pts"; check; chmod 0755 "$FIX/dev/pts"
holdsloud ptsunread pts

world
SOCK="$(duct 1)" || nowall "the tmux server did not start"
check
holds duct "duct $SOCK" "a duct that just printed was not counted"

world
SOCK="$(duct 4)" || nowall "the tmux server did not start"
XPATH="$FIX/bin.silent:" check
sleeps silentduct "a duct present but silent for 5h is no stir" "a silent duct is no fault" \
  "a duct holds by output, never by presence"

world
# an hour older than the world's own traces: on a tie the newest path is whichever the walk met
#   first, so the snapped verdict would flake; this way `h.jsonl` is the one newest
( cd "$HUMAN" && seq -f 'p%g.jsonl' 1 10000 | xargs touch -d '-6 hours' )
[[ "$(find "$HUMAN" -name '*.jsonl' | wc -l)" -gt 10000 ]] || nowall "the 10k traces did not land"
run bash -c 'trap "" PIPE; exec bash "$1"' _ "$COPY"
echo "   ├─ arm 'pipe'"
if [[ "$ERR" == *"Broken pipe"* ]]; then fail pipe "the max reader broke its pipe"
elif ! slept; then fail pipe "no hibernate verdict on a stale box"
else pass pipe "clean stderr at 10k traces"; fi

world
SOCK="$(duct 2)" || nowall "the tmux server did not start"
chmod 0000 "$SOCK"
check
holdsloud unreadable duct
# one refused socket is one fault: the sweep met it, so it is never also "off the sweep"
echo "   ├─ arm 'unreadable.once'"
if [[ "$(grep -c 'duct unreadable' <<< "$ERR")" -eq 1 ]]; then pass unreadable.once "one refused socket, one 💥 line"
else fail unreadable.once "one refused socket printed $(grep -c 'duct unreadable' <<< "$ERR") 💥 duct lines"; fi

world; chmod 0000 "$CREW"; check; chmod 0700 "$CREW"
holdsloud refused trace

world; XPATH="$FIX/bin.ioerr:" check
holdsloud ioerror trace

world; rm -f "$FIX/proc/uptime"; check
holdsloud noboot boot

world; touch "$FIX/pgrep.tmux"; check
holdsloud moved duct

world
SOCK="$(duct 3)" || nowall "the tmux server did not start"
PID="$(tx -S "$SOCK" display -p '#{pid}')"
kill -9 "$PID"; rm -f "$FIX/pgrep.tmux"
# the server's death is a poll, never a fixed wait: a loaded box reaps it late
for _ in $(seq 1 50); do tx -S "$SOCK" list-windows >/dev/null 2>&1 || break; sleep 0.1; done
tx -S "$SOCK" list-windows >/dev/null 2>&1 && nowall "the killed server still answers after 5s"
[[ -S "$SOCK" ]] || nowall "the killed server left no socket"
check
sleeps stale "a dead server's socket is no duct" "that cries wolf on every crash" "a dead socket is no duct"

world
SOCK="$(duct 5)" || nowall "the tmux server did not start"
# pgrep counts the server before the sweep; the stub exits it at the dial, as a real one would
XPATH="$FIX/bin.vanished:" check
sleeps vanished "a socket gone since the glob is no duct" "that cries wolf on every server exit" \
  "a vanished socket is no duct"

# a root check dials a socket as its OWNER: any seat can plant a socket under /tmp, and a
# tmux client obeys its server's requests to open files
world
SOCK="$(duct 6)" || nowall "the tmux server did not start"
XPATH="$FIX/bin.root:" check
echo "   ├─ arm 'dropowner'"
if ! grep -q -- "--reuid=$(id -u) --regid=$(id -g) --clear-groups tmux -S $SOCK" "$FIX/setpriv.log" 2>/dev/null; then
  fail dropowner "a root check dialed a seat's socket as root, never as its owner"
elif slept; then fail dropowner "the dial dropped to the owner, and the duct that just printed was lost"
else pass dropowner "dialed as the socket's owner (uid $(id -u)), and the duct still holds"; fi

# a live server with no tmux client on PATH to read it is a blind duct, never "no duct"
world; touch "$FIX/pgrep.tmux"; XWHOLEPATH="$FIX/bin.notmux" check
holdsloud notmux duct

# a pgrep that cannot search is no proof no server runs
world; touch "$FIX/pgrep.fault"; check
holdsloud pgrepfault duct

# a server that never answers is ended by the dial's bound, and is loud
world
SOCK="$(duct 7)" || nowall "the tmux server did not start"
XPATH="$FIX/bin.hung:" check
holdsloud hung duct

# a sweep past its budget stops, and names the socket it never reached
world
SOCK="$(duct 8)" || nowall "the tmux server did not start"
# -1, never 0: a negative budget is the one value that reaches `budget_left`'s clamp to 0 on every
#   run, so the arm still bites if the clamp goes. a 0 is 0 only inside the run's first second
sed 's/^READ_BUDGET=.*/READ_BUDGET=-1/' "$COPY" > "$FIX/budget.sh"
run bash "$FIX/budget.sh"
holdsloud budget duct
[[ "$ERR" == *"passed its -1s budget before $SOCK"* ]] || { echo "   ├─ arm 'budget.why'"; fail budget.why "the sweep's stop does not name the budget and the socket"; }
# a spent budget's remedy names the long sweep, never "read the error": no error was printed
[[ "$ERR" == *"ran out before the sweep of"*"read which ran long"* && "$ERR" != *"read the error as the root's owner"* ]] \
  || { echo "   ├─ arm 'budget.fix'"; fail budget.fix "a spent budget was handed the remedy for a refusal"; }

# one answered socket must not silence a second server the sweep never reached
world
SOCK="$(duct 9)" || nowall "the tmux server did not start"
echo 99 >> "$FIX/pgrep.tmux"
# the answered duct is silent, so the hold rests on the unswept server alone
XPATH="$FIX/bin.silent:" check
holdsloud unswept duct
[[ "$ERR" == *"2 tmux servers ran through the sweep, and 1 sat under"* ]] || { echo "   ├─ arm 'unswept.why'"; fail unswept.why "the count of servers against answered sockets is not named"; }

# a seat counts only the servers it can dial (its own uid); root, every server on the box
world
SOCK="$(duct 10)" || nowall "the tmux server did not start"
check; SEAT_ASK="$(grep -c -- "^-u $(id -u) -x tmux: server$" "$FIX/pgrep.log")"
: > "$FIX/pgrep.log"; XPATH="$FIX/bin.root:" check; ROOT_ASK="$(grep -c -- "^-x tmux: server$" "$FIX/pgrep.log")"
echo "   ├─ arm 'scope'"
if [[ "$SEAT_ASK" -eq 0 ]]; then fail scope "a seat's run counted servers beyond its own uid — it cries wolf over servers it can never dial"
elif [[ "$ROOT_ASK" -eq 0 ]]; then fail scope "a root run scoped its count to one uid — a crew's server would go uncounted"
else pass scope "a seat asks pgrep for its own uid; root asks for every server"; fi

# a find killed with no word is no clean sweep: the box holds, loud
world; XPATH="$FIX/bin.findkill:" check
holdsloud findkill trace
[[ "$ERR" == *"the sweep of $FIX/home/"*": find exited 137 with no error text"* ]] || { echo "   ├─ arm 'findkill.why'"; fail findkill.why "the silent find's exit is not named"; }
# a kill's remedy is the kernel log, never "read the error": there is no error text to read
[[ "$ERR" == *"journalctl -k"* && "$ERR" != *"read the error as the root's owner"* ]] \
  || { echo "   ├─ arm 'findkill.fix'"; fail findkill.fix "a kill was handed the remedy for a refusal"; }

# a socket name any seat chooses reaches the record and a camper's terminal: no control byte may
world
HOSTILE="$FIX/tmp/tmux-h/$(printf 'x\033[31m\nidle-hibernate: sleep forged')"
mkdir -p "$FIX/tmp/tmux-h"; chmod 0700 "$FIX/tmp/tmux-h"
tx -f /dev/null -S "$HOSTILE" new-session -d -s crew 'sleep 600' || nowall "the hostile-named server did not start"
XPATH="$FIX/bin.hung:" check
echo "   ├─ arm 'hostilename'"
if [[ "$ERR$(cat "$RECORD_FILE" 2>/dev/null)" == *$'\033'* ]]; then fail hostilename "a raw ESC from a socket name reached stderr or the record"
elif grep -q '^idle-hibernate: sleep forged' "$RECORD_FILE" 2>/dev/null; then fail hostilename "a newline in a socket name forged a record line"
elif [[ "$ERR" != *"tmux-h/x?[31m?idle-hibernate: sleep forged"* ]]; then fail hostilename "the hostile name is not shown with its control bytes as ?"
else pass hostilename "each control byte in the name reads as ?, one record line per line said"; fi

# a crew whose `projects` dir is a symlink is walked, never read as one link and zero traces
world
mkdir -p "$FIX/home/v/linked/d" "$FIX/home/v/.claude"
ln -s ../linked "$FIX/home/v/.claude/projects"; touch "$FIX/home/v/linked/d/l.jsonl"
check
holds linkedroot "trace $FIX/home/v/.claude/projects/d/l.jsonl" "a fresh trace under a symlinked projects dir was not counted"

# a codex crew writes its session under ~/.codex/sessions/<y>/<m>/<d>/
world
CODEX="$FIX/home/u/.codex/sessions/2026/11/21"
mkdir -p "$CODEX"; touch "$CODEX/rollout-x.jsonl"; check
holds codex "trace $CODEX/rollout-x.jsonl" "a codex crew at work was not counted"

# a listener that answers exit 0 with no window rows is no duct, and stands in for no server
world
SOCK="$(duct 11)" || nowall "the tmux server did not start"
XPATH="$FIX/bin.junk:" check
holdsloud junkduct duct
[[ "$ERR" == *"answered no window rows: hello"* ]] || { echo "   ├─ arm 'junkduct.why'"; fail junkduct.why "the junk answer is not named as no window rows"; }

# tmux's own texts for a server that died mid-dial: no duct, and no alarm
world
SOCK="$(duct 12)" || nowall "the tmux server did not start"
# pgrep counts the server before the sweep; the stub exits it at the dial, as a real one would
XPATH="$FIX/bin.lost:" check
sleeps lostserver "a server lost mid-dial is no duct" "that cries wolf on every server exit" "a lost server is no duct"

# a live server this tmux cannot speak to is a blind duct, never a gone one
world
SOCK="$(duct 13)" || nowall "the tmux server did not start"
XPATH="$FIX/bin.mismatch:" check
holdsloud mismatch duct
[[ "$ERR" == *"protocol version mismatch"* ]] || { echo "   ├─ arm 'mismatch.why'"; fail mismatch.why "tmux's own mismatch text is not shown"; }

# a server born mid-sweep is counted after it, so it reads as unswept: the count runs first
world
SOCK="$(duct 14)" || nowall "the tmux server did not start"
XPATH="$FIX/bin.born:" check
echo "   ├─ arm 'bornmidsweep'"
if slept; then fail bornmidsweep "hibernate — a duct that just printed was on the box"
elif [[ "$ERR" == *"MalfunctionError"* || "$RC" -ne 0 ]]; then fail bornmidsweep "a server a crew opened mid-sweep raised a false 💥 — the count ran after the sweep"
else pass bornmidsweep "held on the duct, quiet: the servers were counted before the sweep"; fi

# a walk slower than the read budget is killed at it: the box holds loud, and the act never runs
world
sed 's/^READ_BUDGET=.*/READ_BUDGET=1/' "$COPY" > "$FIX/slowwalk.sh"
XPATH="$FIX/bin.slowfind:" run bash "$FIX/slowwalk.sh"
holdsloud slowwalk trace
echo "   ├─ arm 'slowwalk.act'"
if acted; then fail slowwalk.act "the stop act ran after the reads passed their budget"
elif [[ "$ERR" != *"read budget"* ]]; then fail slowwalk.act "the hold does not name the read budget"
elif [[ "$ERR" == *"read the error as the root's owner"* || "$ERR" == *"refused it"* ]]; then
  fail slowwalk.act "a budget overrun was handed the remedy for a refusal"
else pass slowwalk.act "no stop act, the read budget named, and its own remedy given"; fi

# reads that end past their window leave the act no room inside the unit's bound: it refuses
world
sed 's/^DIAL_BOUND=.*/DIAL_BOUND=-200/' "$COPY" > "$FIX/actlate.sh"
run bash "$FIX/actlate.sh"
actfails actlate "the reads ran"
! acted || { echo "   ├─ arm 'actlate.act'"; fail actlate.act "the stop act ran past the read window"; }

# a seat names its own paths: a benign phrase inside one must not make a real fault read as benign
world
mkdir "$HUMAN/x: No such file or directory"; chmod 0000 "$HUMAN/x: No such file or directory"
check; chmod 0700 "$HUMAN/x: No such file or directory"
holdsloud hostilepath trace
world
BSOCK="$FIX/tmp/tmux-b/x (Connection refused)"
mkdir -p "$FIX/tmp/tmux-b"; chmod 0700 "$FIX/tmp/tmux-b"
tx -f /dev/null -S "$BSOCK" new-session -d -s crew 'sleep 600' || nowall "the benign-named server did not start"
echo b >> "$FIX/pgrep.tmux"; chmod 0000 "$BSOCK"
check
holdsloud hostilename.benign duct
echo "   ├─ arm 'hostilename.benign.why'"
if [[ "$ERR" == *"(Permission denied)"* ]]; then pass hostilename.benign.why "tmux's real refusal is shown, past the benign words in the name"
else fail hostilename.benign.why "tmux's real refusal is not shown"; fi

# a root run walks each trace root as its owner: a seat's symlinked root shows only what that seat can see
world; touch "$CREW/c.jsonl"; XPATH="$FIX/bin.root:" check
echo "   ├─ arm 'traceowner'"
if ! grep -q -- "--reuid=$(id -u) --regid=$(id -g) --clear-groups find -H" "$FIX/setpriv.log" 2>/dev/null; then
  fail traceowner "a root check walked a seat's trace roots as root, never as their owner"
elif slept; then fail traceowner "the walk dropped to the owner, and the fresh trace was lost"
else pass traceowner "walked as the roots' owner (uid $(id -u)), and the fresh trace still holds"; fi

# .what = write a prior tick's record: at <epoch>, and optionally the wake it carried
prior() { { echo "at=$(date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ) exit=0"; echo "idle-hibernate: hold — prior"; [[ -n "${2:-}" ]] && echo "wake=$2"; } > "$RECORD_FILE"; }

# a box frozen by a hibernate: its last tick sits far back, and /proc/uptime counts the frozen time
world; prior $(( $(date +%s) - 7200 )); check
holds wakegap "wake" "a box that just woke from a long freeze was judged idle"
echo "   ├─ arm 'wakegap.carry'"
if [[ "$(cat "$RECORD_FILE" 2>/dev/null)" == *$'\nwake='[0-9]* ]]; then pass wakegap.carry "the wake rides in the record, for the next tick"
else fail wakegap.carry "the wake was not written for the next tick to carry"; fi

# the next tick, five minutes on, still holds: the wake floor lasts the limit, never one tick
world; prior $(( $(date +%s) - 300 )) $(( $(date +%s) - 600 )); check
holds wakecarry "wake" "the tick after a wake dropped the wake floor and judged the box idle"

# a wake older than the limit holds naught, and the record stops to carry it
world; prior $(( $(date +%s) - 300 )) $(( $(date +%s) - 14400 )); check
sleeps wakeover "a wake past the limit held the box" "a spent wake is no fault" "a spent wake is no stir"
echo "   ├─ arm 'wakeover.drop'"
if [[ "$(cat "$RECORD_FILE" 2>/dev/null)" != *$'\nwake='* ]]; then pass wakeover.drop "the spent wake is dropped from the record"
else fail wakeover.drop "the record still carries a spent wake"; fi

# a record whose first line names no time is a writer this check does not know: hold, loud
world; printf 'garbage\n' > "$RECORD_FILE"; check
holdsloud wakebadrecord wake

# a sleep keeps its own record: the wake's first hold must not erase "why did it sleep?"
world; check
touch "$HUMAN/h.jsonl"; check
SLEEP_FILE="$FIX/run/idle-hibernate.last-sleep"
echo "   ├─ arm 'sleeprecord'"
if [[ ! -f "$SLEEP_FILE" ]]; then fail sleeprecord "the sleep left no record at $SLEEP_FILE"
elif [[ "$(cat "$SLEEP_FILE")" != *"idle-hibernate: sleep — "*"stop-instances --hibernate accepted"* ]]; then
  fail sleeprecord "the sleep record lacks the sleep verdict or the accepted act"; sed 's/^/   │     │ sleep: /' "$SLEEP_FILE"
elif [[ "$(stat -c %a "$SLEEP_FILE")" != 644 ]]; then fail sleeprecord "the sleep record is held at $(stat -c %a "$SLEEP_FILE"), not 644"
elif [[ "$(cat "$RECORD_FILE")" != *"idle-hibernate: hold — "* ]]; then fail sleeprecord "the later hold is not the last tick's record"
else pass sleeprecord "the sleep survives the next hold, at 0644, with its accepted act"; fi

# each run leaves a record a camper can read: when, the exit, and every line it said
world; check
echo "   ├─ arm 'record'"
if [[ ! -f "$RECORD_FILE" ]]; then fail record "the run left no record at $RECORD_FILE"
elif [[ "$(stat -c %a "$RECORD_FILE")" != 644 ]]; then fail record "the record is held at $(stat -c %a "$RECORD_FILE"), not 644"
elif [[ "$(head -1 "$RECORD_FILE")" != "at="*" exit=0" || "$(cat "$RECORD_FILE")" != *"idle-hibernate: sleep — "* ]]; then
  fail record "the record does not hold the run's exit and its verdict"; sed 's/^/   │     │ record: /' "$RECORD_FILE"
else pass record "at=…, exit=0, and the sleep verdict, at 0644"; fi
world; touch "$FIX/pgrep.tmux"; check
echo "   ├─ arm 'record.loud'"
if [[ "$(head -1 "$RECORD_FILE" 2>/dev/null)" != *" exit=1" || "$(cat "$RECORD_FILE" 2>/dev/null)" != *"💥 MalfunctionError: duct unreadable"*"└─ fix:"*"idle-hibernate: hold — "* ]]; then
  fail record.loud "a loud hold's record lacks its exit, its 💥 and fix lines, or its verdict"
else pass record.loud "exit=1, the 💥 line, its fix, and the hold verdict"; fi

# a record that cannot be written is said, with its fix, and never changes the verdict's exit.
# two shapes: the temp file cannot be made (no dir), and the rename into place fails
world; rm -rf "$FIX/run"; check
echo "   ├─ arm 'recordnodir'"
if [[ "$RC" -ne 0 || "$ERR" != *"💥 MalfunctionError: could not write $RECORD_FILE (its record would read exit=0) —"* \
  || "$ERR" != *"could not write $FIX/run/idle-hibernate.last-sleep (its record would read exit=unanswered) —"* \
  || "$ERR" != *"could not write $FIX/run/idle-hibernate.last-sleep (its record would read exit=0) —"* \
  || "$ERR" != *"└─ fix: the unit runs as root; read why $FIX/run refused the write. the verdict above still stands"* ]]; then
  fail recordnodir "a record with no dir to land in is not said with its fix, or it changed the exit"
else pass recordnodir "💥 could not write, the mktemp error, the fix, and exit 0 as the verdict set it"; fi
mkdir -p "$FIX/bin.mvfail"
printf '#!/bin/sh\necho "mv: cannot move to %s: Read-only file system" >&2\nexit 1\n' "'\$3'" > "$FIX/bin.mvfail/mv"
chmod +x "$FIX/bin.mvfail/mv"
world; XPATH="$FIX/bin.mvfail:" check
echo "   ├─ arm 'recordnorename'"
if [[ "$RC" -ne 0 || "$ERR" != *"💥 MalfunctionError: could not write $RECORD_FILE (its record would read exit=0) — the error is above"* \
  || "$ERR" != *"Read-only file system"* || -n "$(find "$FIX/run" -name 'idle-hibernate.last.*')" ]]; then
  fail recordnorename "a failed rename is not said with the error above it, its temp file was left, or the exit changed"
else pass recordnorename "💥 could not write (the error is above), the temp file removed, exit 0"; fi

echo "🔭 do the two tmux facts the check rests on hold on a real server?"

# a shell pane, so a send-keys can make it print
FSOCK="$(server "$FIX/fact" sh)" || nowall "the fact server did not start"
act() { tx -S "$FSOCK" display -p -t crew '#{window_activity}'; }
# 2.1s spans tmux's 1s activity stamp twice over; a longer stillness is unprovable by any wait,
#   so the arm claims a window held still, never that the pane is silent for good
A1="$(act)"; sleep 2.1; A2="$(act)"
# a bounded poll, never a fixed wait: on a loaded box the pane may print late
tx -S "$FSOCK" send-keys -t crew 'echo stir' Enter
A3="$A2"; TRIES=0
while [[ "$A3" == "$A2" && $TRIES -lt 50 ]]; do sleep 0.1; A3="$(act)"; TRIES=$((TRIES + 1)); done
echo "   ├─ arm 'activity'"
if [[ -z "$A1" || "$A1" != "$A2" ]]; then fail activity "a silent pane's window_activity moved ($A1 → $A2) — presence, not output, would hold the box"
elif [[ ! "$A3" -gt "$A2" ]]; then fail activity "a pane printed and window_activity held still ($A2 → $A3)"
else pass activity "still while silent ($A1 = $A2), moved on output ($A3)"; fi

# the comms the check declares, read from the check itself, against a real server
FPID="$(tx -S "$FSOCK" display -p '#{pid}')"
COMMS_LINE="$(grep -m1 '^TMUX_SERVER_COMMS=' "$CHECK" || true)"
TMUX_SERVER_COMMS=()
[[ -n "$COMMS_LINE" ]] && eval "$COMMS_LINE"
MET=""
for comm in "${TMUX_SERVER_COMMS[@]}"; do
  pgrep -x "$comm" | grep -qx "$FPID" && { MET="$comm"; break; }
done
echo "   └─ arm 'pgrepreal'"
if [[ -z "$COMMS_LINE" ]]; then fail pgrepreal "the check declares no TMUX_SERVER_COMMS — its moved guard has no way to see a live server"
elif [[ -z "$MET" ]]; then fail pgrepreal "no declared comm (${TMUX_SERVER_COMMS[*]}) names the real server pid $FPID ($(ps -o comm= -p "$FPID")) — the moved guard would be blind"
else pass pgrepreal "\`pgrep -x '$MET'\` names the real server, pid $FPID"; fi

# the transcript snap — only of this checkout's check. the bite play runs this play on the
# old bytes, whose transcript is no baseline
if [[ -z "${IDLE_CHECK:-}" ]]; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=/dev/null
  source "$HERE/play.snap.operations.sh" || { echo "   💥 MalfunctionError: play.snap.operations.sh would not load"; exit 1; }
  play_snap_verify dir="$HERE/prove.idle-check-counts-every-crew.snap" name=transcript actual="$SNAP" || FAILED=1
else
  # said aloud, never dropped in silence: a reader of an IDLE_CHECK run must see the snap was not compared
  echo "   • snapshot not compared: IDLE_CHECK names another copy ($CHECK), and this checkout's transcript is no baseline for it"
fi

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 the idle check holds every crew at work, sleeps an idle box, and holds loud on what it cannot read"
else
  echo "✋ the contract did NOT hold — read the arms above"
fi
exit "$FAILED"
