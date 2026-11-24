#!/usr/bin/env bash
######################################################################
# prove.hibernate-drift-names-each-gap — `1.15.hibernate`'s one drift reader
# reads a converged box as converged, and names each gap on a drifted one
#
# .what = sources the bundle's `_.sh`, points its declared paths into a temp
#         dir, puts a stateful `systemctl` stub on PATH, and asks
#         `grove_provision_1_15_hibernate_drift` about each world
#
# .why
#   - the upsert's skip-guard and the verify both ask this one reader, so a
#     reader that misses a gap leaves a stale grove reported as healed
#   - a live grove shows only its drifted side until a ground apply; the
#     converged side is proven here
#
# .the arms
#   converged  files match, every unit loaded fresh, no drop-in, timer armed → no line
#   bytes      the installed check differs                                   → names the check
#   reload     systemd still runs an old unit definition                     → names the reload
#   dropin     systemd loaded a drop-in on the timer                         → names the drop-in
#   unloadeddropin  a drop-in on disk that systemd has not loaded yet      → names it all the same
#   mode       matched bytes, the check at 644                       → names the mode it holds
#   result     the last idle check ended exit-code        → health names the result, alone; drift does not
#   symlink    the dst is a symlink to a file of the right bytes → names the link, never "converged"
#   dropinsunread  systemd cannot list drop-ins                         → names the unread list
#   unloaded   systemd holds the timer as not-found                        → names its load state
#   unread     systemd itself cannot answer                                 → names the unread unit
#   stopgap    the stopgap pre-check is present                             → names the stopgap
#   masked     the timer is masked                                           → names the mask
#   typewide   systemd loaded a type-wide drop-in and two of the unit's own  → names the two, spares the one
#   timer      the timer is neither enabled nor active                       → names both
#   execstart  the service's ExecStart= names the dst the check installs to  → one fact, two literals, tied
#   timeout    the service bounds a run with TimeoutStartSec=                → a wedged tick cannot stop the timer
#   recordpath the check's LAST_RECORD= is the path the health reader reads → one fact, two literals, tied
#   bounds     the check's declared bounds sum under TimeoutStartSec=       → the worst run cannot be killed mid-write
#   sockettie  the check's TMUX_SOCKETS is the dir 2.8.tmux computes        → one fact, two literals, tied
#   layouttie  the check's worktree root is the `_worktrees` dir beside the main clone, as the aliases make it
#   sleeprecordpath  the check's LAST_SLEEP= is the path the verify reads   → one fact, two literals, tied
#   unitpath   the PATH the probe reads is the service's Environment=PATH=  → one fact, read, never restated
#   needs      the check's NEEDS='…' names each tool it calls, tmux aside   → the probe's list is the check's own
#   tickgap    the check's TICK_GAP is 3 × the timer's OnUnitActiveSec=     → one fact, two literals, tied
#   verify.converged   the verify on a converged box → exit 0, three ✔ lines, and "no tick on record yet"
#   verify.lasttick    the same, with a record       → exit 0, and the last tick's verdict line
#   verify.drifted     the verify on a drifted box   → exit 1, the drift, the ground-seat fix, and the last tick
#   verify.unhealthy   converged, bad last run       → exit 1, the fault, its record, its gloss, the last tick, no apply
#   verify.lastsleep   a sleep, then a wake's hold   → both: the hold as the last tick, the sleep as the last sleep
#   verify.unanswered  a sleep record at exit=unanswered → a note the box may never have slept
#   verify.staletick   a tick older than 15 minutes  → a note the timer may have stopped, exit 0, no ✋
#   verify.freshtick   a tick seconds old            → its age, and no such note
#   verify.notick      no record, the timer fired    → the timer's LastTriggerUSec, beside "no tick on record"
#   verify.oldnotick   an older check, no record     → "writes none", never "the next tick writes it"
#   verify.skipnotick  a pre-check, no record        → "skips every tick", never "the next tick writes it"
#   verify.oldsleep    an older check, no sleep      → CloudTrail named, never "none since cold boot"
#   verify.norecord    the same, no record           → exit 1, the ground seat's journal read
#   verify.execcondition  a pre-check skipped the tick → no record, no journal read; the apply is the fix
#   verify.killed      a run that timed out          → the record, named as maybe an earlier run's
#   verify.hostilerecord  a control byte in the record → shown as `?`, never raw
#   verify.noaws       no aws on the unit's PATH     → exit 1, the 5.6.aws fix
#   verify.nosetpriv   no setpriv on the unit's PATH → exit 1, named from the check's NEEDS list
#   verify.risk.*      bytes / stopgap / stopped / held → the one `⇒ now:` line says what that box risks
#
# .the write — `rule.forbid.repair-plays` exception 2: a temp dir, removed by a trap
#
# usage:
#   rhx play.run --play prove.hibernate-drift-names-each-gap
######################################################################
set -uo pipefail

# the checkout is this file's own, never the cwd: rhx guarantees no cwd
REPO="${GROVE_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src}"
BUNDLE="$REPO/grove.provision/1.system/1.15.hibernate"
FIX=""
# the restore reports whether it took: a fixture that survives fails the play (`rule.forbid.repair-plays`, condition 4)
trap '[[ -n "$FIX" ]] && rm -rf "$FIX"; [[ -n "$FIX" && -e "$FIX" ]] && { echo "   ✋ residue SURVIVED — $FIX"; exit 1; }' EXIT
FAILED=0

[[ -f "$BUNDLE/_.sh" ]] || { echo "✋ ConstraintError: no bundle at $BUNDLE"; exit 2; }
export GROVE_SRC="$REPO"
# shellcheck source=/dev/null
source "$BUNDLE/_.sh"
# shellcheck source=/dev/null
source "$BUNDLE/configure.verify.sh"
# the declared pairs, before `world` points them into the fixture
DECLARED_PAIRS=("${GROVE_PROVISION_1_15_HIBERNATE_PAIRS[@]}")
DECLARED_RECORD="$GROVE_PROVISION_1_15_HIBERNATE_RECORD"

DECLARED_SLEEP_RECORD="$GROVE_PROVISION_1_15_HIBERNATE_SLEEP_RECORD"
DECLARED_UNIT_PATH="$(grove_provision_1_15_hibernate_unit_path)"
DECLARED_PERIOD="$(grove_provision_1_15_hibernate_declared "$GROVE_PROVISION_1_15_HIBERNATE_TIMER" OnUnitActiveSec)"
DECLARED_NEEDS="$(grove_provision_1_15_hibernate_needs)" \
  || { echo "✋ ConstraintError: the check declares no NEEDS='…' — the health probe has no list to read"; exit 2; }
# the probe reads the unit PATH through its one reader; each world points it at a fixture bin dir
UNITBIN=""
grove_provision_1_15_hibernate_unit_path() { echo "$UNITBIN"; }

FIX="$(mktemp -d)"
SD="$FIX/sd"
mkdir -p "$FIX/bin" "$FIX/unitbin" "$FIX/unitbin.noaws" "$FIX/unitbin.nosetpriv"
# the unit's PATH holds a stub of each need the check declares; each `.no<x>` dir lacks one
while IFS= read -r need; do
  for dir in unitbin unitbin.noaws unitbin.nosetpriv; do
    [[ "$dir" == "unitbin.no$need" ]] && continue
    printf '#!/bin/sh\nexit 0\n' > "$FIX/$dir/$need"; chmod +x "$FIX/$dir/$need"
  done
done <<< "$DECLARED_NEEDS"

# a systemctl that answers from files under $SD — the one model both bundle plays share.
# a failed source must halt: the play would then drive the box's real systemctl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/prove.hibernate.systemctl.fixture" \
  || { echo "✋ ConstraintError: the systemctl fixture would not load beside this play"; exit 2; }
hibernate_systemctl_stub "$FIX/bin" "$SD"
export PATH="$FIX/bin:$PATH"

# .what = point the declared artifacts into the fixture, all present, loaded, armed
world() {
  rm -rf "$FIX/box"; rm -f "$SD"/*; mkdir -p "$FIX/box" "$SD"
  GROVE_PROVISION_1_15_HIBERNATE_PAIRS=(
    "$FIX/box/idle-hibernate.sh:755"
    "$FIX/box/idle-hibernate.service:644"
    "$FIX/box/idle-hibernate.timer:644"
  )
  GROVE_PROVISION_1_15_HIBERNATE_OWNER="$(id -u):$(id -g)"
  GROVE_PROVISION_1_15_HIBERNATE_STOPGAP="$FIX/box/idle-hibernate-holds.sh"
  GROVE_PROVISION_1_15_HIBERNATE_UNIT_ROOTS=("$FIX/box/etc" "$FIX/box/run" "$FIX/box/lib")
  GROVE_PROVISION_1_15_HIBERNATE_RECORD="$FIX/box/idle-hibernate.last"
  GROVE_PROVISION_1_15_HIBERNATE_SLEEP_RECORD="$FIX/box/idle-hibernate.last-sleep"
  UNITBIN="$FIX/unitbin"
  cp "$BUNDLE/idle-hibernate.sh" "$BUNDLE/idle-hibernate.service" "$BUNDLE/idle-hibernate.timer" "$FIX/box/"
  chmod 755 "$FIX/box/idle-hibernate.sh"; chmod 644 "$FIX/box/idle-hibernate.service" "$FIX/box/idle-hibernate.timer"
  echo enabled > "$SD/enabled"; echo active > "$SD/active"
}

DRIFT=""
ask() { DRIFT="$(grove_provision_1_15_hibernate_drift)"; }
quote() { printf '%s\n' "${DRIFT:-(no drift)}" | sed 's/^/   │     │ /'; }
# .what = judge an arm whose drift must hold the line $2
names() {
  echo "   ├─ arm '$1'"
  if [[ "$DRIFT" != *"$2"* ]]; then echo "   │  ✋ the gap went unnamed"; quote; FAILED=1; return; fi
  echo "   │  ✔ $(grep -F -- "$2" <<< "$DRIFT" | head -n 1)"
}

echo "🔭 does the drift reader name each gap, and only a real one?"

world; ask
echo "   ├─ arm 'converged'"
if [[ -n "$DRIFT" ]]; then echo "   │  ✋ a converged box reads as drifted"; quote; FAILED=1
else echo "   │  ✔ no drift"; fi

world; echo "# drift" >> "$FIX/box/idle-hibernate.sh"; ask
names bytes "$FIX/box/idle-hibernate.sh differs"

world; touch "$SD/needreload.idle-hibernate.service"; ask
names reload "old definition of idle-hibernate.service"

# .what = put drop-in files on the fixture box, and list them as systemd would load them under unit $1
dropins() {
  local unit="$1" f; shift
  for f in "$@"; do mkdir -p "$(dirname "$f")"; echo "[Service]" > "$f"; echo "$f" >> "$SD/dropins.$unit"; done
}

world; dropins idle-hibernate.timer "$FIX/box/run/idle-hibernate.timer.d/hold.conf"; ask
names dropin "a drop-in this bundle does not write: $FIX/box/run/idle-hibernate.timer.d/hold.conf"

# on disk with no reload: the declaration holds it, and systemd has not loaded it yet
world; mkdir -p "$FIX/box/etc/idle-hibernate.service.d"; echo "[Service]" > "$FIX/box/etc/idle-hibernate.service.d/late.conf"; ask
names unloadeddropin "a drop-in this bundle does not write: $FIX/box/etc/idle-hibernate.service.d/late.conf"

world
dropins idle-hibernate.service "$FIX/box/lib/service.d/10-box.conf" "$FIX/box/etc/idle-hibernate.service.d/a.conf" \
  "$FIX/box/etc/idle-hibernate.service.d/b.conf"
ask
echo "   ├─ arm 'typewide'"
if [[ "$DRIFT" == *"service.d/10-box.conf"* ]]; then echo "   │  ✋ a type-wide drop-in, a box-wide writer's, was named as this unit's"; quote; FAILED=1
elif [[ "$DRIFT" != *"idle-hibernate.service.d/a.conf"* || "$DRIFT" != *"idle-hibernate.service.d/b.conf"* ]]; then
  echo "   │  ✋ the unit's own drop-ins, on one line from systemd, were not each named"; quote; FAILED=1
else echo "   │  ✔ names both of the unit's own drop-ins, and spares the type-wide one"; fi

world; chmod 644 "$FIX/box/idle-hibernate.sh"; ask
names mode "$FIX/box/idle-hibernate.sh is held as '644 $(id -u):$(id -g)', not '755 $(id -u):$(id -g)'"

# a bad last run is health, never drift: the apply cannot clear it, so it must not gate one
world; echo exit-code > "$SD/result"; ask; HEALTH="$(grove_provision_1_15_hibernate_health)"
echo "   ├─ arm 'result'"
if [[ -n "$DRIFT" ]]; then echo "   │  ✋ a bad last run read as drift, so it would gate an apply that cannot clear it"; quote; FAILED=1
elif [[ "$HEALTH" != "the last idle check ended 'exit-code'" ]]; then
  echo "   │  ✋ the health reader did not name the result, alone"; printf '%s\n' "${HEALTH:-(no health line)}" | sed 's/^/   │     │ /'; FAILED=1
else echo "   │  ✔ health, not drift: $HEALTH"; fi

# a symlinked dst with the right bytes is no declared copy: a chown would follow it
world; mv "$FIX/box/idle-hibernate.sh" "$FIX/box/seat.sh"; ln -s "$FIX/box/seat.sh" "$FIX/box/idle-hibernate.sh"; ask
names symlink "$FIX/box/idle-hibernate.sh is a symlink, not the file this bundle writes"

world; touch "$SD/fail.dropins"; ask
names dropinsunread "systemd could not report the drop-ins of idle-hibernate.service"

world; echo not-found > "$SD/loadstate.idle-hibernate.timer"; ask
names unloaded "idle-hibernate.timer is not-found, not loaded"

world; touch "$SD/fail.show"; ask
names unread "systemd could not report idle-hibernate.service"

world; touch "$FIX/box/idle-hibernate-holds.sh"; ask
names stopgap "the stopgap pre-check is still on the box"

world; echo masked > "$SD/enabled"; ask
names masked "is masked"

world; echo disabled > "$SD/enabled"; echo inactive > "$SD/active"; ask
echo "   ├─ arm 'timer'"
if [[ "$DRIFT" != *"is not enabled"* || "$DRIFT" != *"is not active"* ]]; then
  echo "   │  ✋ an unarmed timer went unnamed"; quote; FAILED=1
else echo "   │  ✔ names both: not enabled, not active"; fi

# the service runs the check at the path the bundle installs it to — two literals, one fact
CHECK_DST=""
for pair in "${DECLARED_PAIRS[@]}"; do
  grove_provision_1_15_hibernate_pair "$pair"
  [[ "$PAIR_NAME" == idle-hibernate.sh ]] && CHECK_DST="$PAIR_DST"
done
echo "   ├─ arm 'execstart'"
if ! grep -qxF "ExecStart=$CHECK_DST" "$BUNDLE/idle-hibernate.service"; then
  echo "   │  ✋ the service's ExecStart= does not name the declared check at '${CHECK_DST:-no declared dst}'"; FAILED=1
else echo "   │  ✔ ExecStart=$CHECK_DST, the dst the bundle installs the check to"; fi

# a oneshot with no bound waits forever on a wedged run, and the timer starts no other
echo "   ├─ arm 'timeout'"
if ! grep -qE '^TimeoutStartSec=[0-9]+$' "$BUNDLE/idle-hibernate.service"; then
  echo "   │  ✋ the service carries no TimeoutStartSec=, so a wedged check stops every later tick"; FAILED=1
else echo "   │  ✔ $(grep -E '^TimeoutStartSec=' "$BUNDLE/idle-hibernate.service")"; fi

# the record the check writes is the record the health reader reads — two literals, one fact
echo "   ├─ arm 'recordpath'"
CHECK_RECORD="$(grove_provision_1_15_hibernate_declared idle-hibernate.sh LAST_RECORD)"
if [[ -z "$CHECK_RECORD" || "$CHECK_RECORD" != "$DECLARED_RECORD" ]]; then
  echo "   │  ✋ the check writes '${CHECK_RECORD:-no record}', the bundle reads '$DECLARED_RECORD'"; FAILED=1
else echo "   │  ✔ LAST_RECORD=$CHECK_RECORD, the path the health reader reads"; fi

# the check's two crew roots are the layout the git.tree aliases make: a worktree dir is the
# `_worktrees` dir beside the main clone. one convention, two holders — tied here
echo "   ├─ arm 'layouttie'"
ALIASES="$REPO/grove.provision/2.shell/2.7.aliases/bash_aliases.sh"
WT_GLOB="$(grep -oP "^\s*'\K/home/\*/git/\*/_worktrees/\*/[^']+" "$BUNDLE/idle-hibernate.sh" | head -1)"
MC_GLOB="$(grep -oP "^\s*'\K/home/\*/git/\*/\*/\.agent[^']+" "$BUNDLE/idle-hibernate.sh" | head -1)"
if ! grep -qF 'echo "$(dirname "$git_root")/_worktrees"' "$ALIASES"; then
  echo "   │  ✋ the git.tree aliases no longer put worktrees in the _worktrees dir beside the main clone — the check's worktree root may read none"; FAILED=1
elif [[ -z "$WT_GLOB" || -z "$MC_GLOB" || "${WT_GLOB/_worktrees\/\*/*}" != "$MC_GLOB" ]]; then
  echo "   │  ✋ the worktree root '${WT_GLOB:-absent}' is not the main-clone root '${MC_GLOB:-absent}' with its repo dir as _worktrees/*"; FAILED=1
else echo "   │  ✔ a worktree root is the main-clone root with _worktrees/* for its repo dir, as _git_tree_worktrees_dir puts it"; fi

# the sleep record the check writes is the one the verify reads — two literals, one fact
echo "   ├─ arm 'sleeprecordpath'"
CHECK_SLEEP="$(grove_provision_1_15_hibernate_declared idle-hibernate.sh LAST_SLEEP)"
if [[ -z "$CHECK_SLEEP" || "$CHECK_SLEEP" != "$DECLARED_SLEEP_RECORD" ]]; then
  echo "   │  ✋ the check writes '${CHECK_SLEEP:-no sleep record}', the bundle reads '$DECLARED_SLEEP_RECORD'"; FAILED=1
else echo "   │  ✔ LAST_SLEEP=$CHECK_SLEEP, the path the verify reads"; fi

# the probe looks where the unit looks: the PATH the bundle probes IS the service's Environment=PATH=
echo "   ├─ arm 'unitpath'"
SERVICE_PATH="$(grep -oP '^Environment=PATH=\K\S+' "$BUNDLE/idle-hibernate.service")"
if [[ -z "$SERVICE_PATH" ]]; then echo "   │  ✋ the service declares no Environment=PATH=, so the unit's PATH is systemd's guess"; FAILED=1
elif [[ "$DECLARED_UNIT_PATH" != "$SERVICE_PATH" ]]; then echo "   │  ✋ the bundle probes '$DECLARED_UNIT_PATH', the unit runs on '$SERVICE_PATH'"; FAILED=1
else echo "   │  ✔ the probe reads PATH=$SERVICE_PATH, the service's own"; fi

# the list the probe reads names each tool the check calls to judge and to act
echo "   ├─ arm 'needs'"
NEEDS_LACK=""
for tool in aws curl find pgrep setpriv timeout; do grep -qx "$tool" <<< "$DECLARED_NEEDS" || NEEDS_LACK+=" $tool"; done
if [[ -n "$NEEDS_LACK" ]]; then echo "   │  ✋ the check's NEEDS lacks:$NEEDS_LACK"; FAILED=1
elif grep -qx tmux <<< "$DECLARED_NEEDS"; then echo "   │  ✋ tmux is in NEEDS — a box with no tmux has no duct, and the probe would cry wolf (F15)"; FAILED=1
else echo "   │  ✔ NEEDS='$(tr '\n' ' ' <<< "$DECLARED_NEEDS" | sed 's/ $//')'"; fi

# the gap that marks a wake is the timer's cadence, three times over — two literals, one fact
echo "   ├─ arm 'tickgap'"
CHECK_GAP="$(grove_provision_1_15_hibernate_declared idle-hibernate.sh TICK_GAP)"
if [[ -z "$DECLARED_PERIOD" || -z "$CHECK_GAP" || "$CHECK_GAP" -ne $(( 3 * DECLARED_PERIOD )) ]]; then
  echo "   │  ✋ the check's TICK_GAP=${CHECK_GAP:-absent} is not 3 × the timer's OnUnitActiveSec=${DECLARED_PERIOD:-absent}"; FAILED=1
else echo "   │  ✔ TICK_GAP=$CHECK_GAP, three ticks of OnUnitActiveSec=$DECLARED_PERIOD"; fi

# the worst run fits inside the unit's bound: read budget, a last dial, imds, aws
echo "   ├─ arm 'bounds'"
# every bound through the bundle's one reader: a value it misread would break the sum below
bound_of() { grove_provision_1_15_hibernate_declared idle-hibernate.sh "$1"; }
WORST=$(( $(bound_of READ_BUDGET) + $(bound_of DIAL_BOUND) + $(bound_of DIAL_KILL) + 3 * $(bound_of IMDS_BOUND) + $(bound_of AWS_BOUND) + $(bound_of AWS_KILL) ))
UNIT_BOUND="$(grove_provision_1_15_hibernate_declared idle-hibernate.service TimeoutStartSec)"
if [[ "$WORST" -ge "${UNIT_BOUND:-0}" ]]; then
  echo "   │  ✋ the worst run takes ${WORST}s, not under TimeoutStartSec=${UNIT_BOUND:-absent}"; FAILED=1
else echo "   │  ✔ the worst run takes ${WORST}s, under TimeoutStartSec=$UNIT_BOUND"; fi

# the check sweeps the dir 2.8.tmux puts each server's socket in — two literals, one fact
echo "   ├─ arm 'sockettie'"
CHECK_SOCKETS="$(grove_provision_1_15_hibernate_declared idle-hibernate.sh TMUX_SOCKETS)"
TMUX_DEFAULT="$(grep -oP 'TMUX_TMPDIR:-\K[^}]+(?=\}/tmux-)' "$REPO/grove.provision/2.shell/2.8.tmux/_.sh" | head -1)"
if [[ -z "$TMUX_DEFAULT" || "$CHECK_SOCKETS" != "$TMUX_DEFAULT/tmux-*/*" ]]; then
  echo "   │  ✋ the check sweeps '${CHECK_SOCKETS:-no glob}', and 2.8.tmux puts sockets under '${TMUX_DEFAULT:-an unread dir}/tmux-<uid>'"; FAILED=1
else echo "   │  ✔ TMUX_SOCKETS=$CHECK_SOCKETS, the dir 2.8.tmux computes when TMUX_TMPDIR is unset"; fi

# .what = run the verify on this world; keep stdout and stderr APART, and both joined for the patterns
# .why apart for the snap: a runner may interleave the two streams, so a merged capture reorders
VRUNS=0
verify() {
  VSTDOUT="$(grove_provision_1_15_hibernate_configure_verify 2>"$FIX/verr")"; VRC=$?
  VSTDERR="$(cat "$FIX/verr")"
  VOUT="$VSTDOUT"$'\n'"$VSTDERR"
  VRUNS=$((VRUNS + 1))
}
# .what = the verify transcript snap: EVERY world's stdout and stderr, apart and masked
# .why every world: each is one answer to "why is it awake, or why did it sleep?", and a
#   word-level pattern proves a phrase, never the line around it. vjudge keeps each run
#   once, under the first arm that judges it
VSNAP=""; VKEPT=0
# the fixture's dates are 2026-01-0*, literal; any other stamp is the run's own clock (freshtick)
# the fixture's owner is this seat's uid:gid, so it is masked: the snap holds on any seat, root included
vmask() {
  printf '%s' "$1" | sed -E -e "s#$FIX#<fix>#g" -e "s# $(id -u):$(id -g)\b# <uid>:<gid>#g" -e 's/\([0-9]+[smh] ago\)/(<age> ago)/g' \
    -e '/2026-01-0[0-9]T/!s/at=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+Z/at=<now>/g'
}
vkeep() {
  [[ "$VRUNS" -gt "$VKEPT" ]] || return 0
  VKEPT=$VRUNS
  VSNAP+="## $1 (exit $VRC)"$'\n'"### stdout"$'\n'"$(vmask "$VSTDOUT")"$'\n'"### stderr"$'\n'"$(vmask "$VSTDERR")"$'\n\n'
}
vfail() { echo "   │  ✋ $1"; printf '%s\n' "$VOUT" | sed 's/^/   │     │ /'; FAILED=1; }
# .what = judge a verify arm: exit $2, every later pattern present — a `!`-led one absent
vjudge() {
  local arm="$1" rc="$2" pat; shift 2
  echo "   ├─ arm '$arm'"
  vkeep "${arm#verify.}"
  [[ "$VRC" -eq "$rc" ]] || { vfail "exit $VRC, not $rc"; return; }
  for pat in "$@"; do
    if [[ "$pat" == '!'* ]]; then [[ "$VOUT" != *"${pat#!}"* ]] || { vfail "holds what it must not: ${pat#!}"; return; }
    else [[ "$VOUT" == *"$pat"* ]] || { vfail "lacks: $pat"; return; }; fi
  done
  echo "   │  ✔ exit $rc, and each of $# patterns as owed"
}
REC="$FIX/box/idle-hibernate.last"

# the verify the camper reads: its lines and its exit, on each side
world; verify
vjudge verify.converged 0 "match this checkout ✔" "no reload owed, and no stopgap ✔" \
  "is enabled and active, and no failed run is on record ✔" "• no tick on record yet at $REC"

# a healthy box answers "why is it awake?" from its last tick
world; printf 'at=2026-01-01T00:00:00Z exit=0\nidle-hibernate: hold — idle=5s limit=10800s, newest=duct d; seen traces=1 pts=0 ducts=1\n' > "$REC"; verify
vjudge verify.lasttick 0 "• the last tick, at=2026-01-01T00:00:00Z exit=0 (" "ago): idle-hibernate: hold — idle=5s limit=10800s, newest=duct d"

# a drifted box — every infra-born grove until its ground apply — answers "why awake?" too
world; echo "# drift" >> "$FIX/box/idle-hibernate.sh"
printf 'at=2026-01-01T00:00:00Z exit=0\nidle-hibernate: hold — idle=5s limit=10800s, newest=duct d; seen traces=1 pts=0 ducts=1\n' > "$REC"; verify
vjudge verify.drifted 1 "✋ $FIX/box/idle-hibernate.sh differs" "fix, from the ground seat: rhx grove.provision --what 1.15.hibernate --mode apply" \
  "• the last tick, at=2026-01-01T00:00:00Z exit=0 (" "ago): idle-hibernate: hold — idle=5s" "• no sleep on record at $FIX/box/idle-hibernate.last-sleep"

# converged config, bad last run: the run's own record, its gloss, the last tick, and never an apply
world; echo exit-code > "$SD/result"
printf 'at=2026-01-01T00:00:00Z exit=1\nidle-hibernate: 💥 MalfunctionError: duct unreadable — why\nidle-hibernate: hold — idle=9s limit=10800s, newest=boot\n' > "$REC"; verify
vjudge verify.unhealthy 1 "✋ the last idle check ended 'exit-code'" "its record, at $REC:" \
  "      │ idle-hibernate: 💥 MalfunctionError: duct unreadable — why" "⇒ a fault in the last run, not in the config" \
  "• the last tick, at=2026-01-01T00:00:00Z exit=1" "!✋ │" "!--mode apply"

# a wake's first tick rewrites the record: the last sleep keeps its own, and the verify shows both
world
printf 'at=2026-01-02T00:00:00Z exit=0\nidle-hibernate: hold — idle=30s limit=10800s, newest=boot\n' > "$REC"
printf 'at=2026-01-01T00:00:00Z exit=0\nidle-hibernate: sleep — idle=10900s limit=10800s, newest=trace t — hibernate now\n' > "$FIX/box/idle-hibernate.last-sleep"; verify
vjudge verify.lastsleep 0 "newest=boot" "• the last sleep, at=2026-01-01T00:00:00Z exit=0 (" "idle-hibernate: sleep — idle=10900s"

# a sleep whose act never answered is no sleep a commander may trust: the verify says so
world
printf 'at=2026-01-01T00:00:00Z exit=unanswered\nidle-hibernate: sleep — idle=10900s limit=10800s, newest=trace t — hibernate now\n' > "$FIX/box/idle-hibernate.last-sleep"; verify
vjudge verify.unanswered 0 "• the last sleep, at=2026-01-01T00:00:00Z exit=unanswered" \
  "⇒ the stop act never answered: this box judged itself idle and may never have slept" \
  "a later tick overwrote its 💥, so read why from the ground seat: rhx machine.journal.read" "!the 💥 in the last tick names why"

# while the sleep's run is still the last tick, its 💥 is on the page: the verify quotes it
# the act's 💥 exits the run 1, so systemd records `exit-code`: the fixture's Result says so too
world; echo exit-code > "$SD/result"
printf 'at=2026-01-01T00:00:00Z exit=1\nidle-hibernate: 💥 MalfunctionError: aws refused stop-instances --hibernate for stub\nidle-hibernate: sleep — idle=10900s limit=10800s, newest=trace t — hibernate now\n' > "$REC"
printf 'at=2026-01-01T00:00:00Z exit=unanswered\nidle-hibernate: sleep — idle=10900s limit=10800s, newest=trace t — hibernate now\n' > "$FIX/box/idle-hibernate.last-sleep"; verify
vjudge verify.unanswered.sametick 1 "the 💥 in the last tick names why:" \
  "       idle-hibernate: 💥 MalfunctionError: aws refused stop-instances --hibernate for stub" "!a later tick overwrote" \
  "✋ the last idle check ended 'exit-code'"

# a tick older than three periods is named — a note, never a ✋, so a just-woken box still exits 0
world; printf 'at=2026-01-01T00:00:00Z exit=0\nidle-hibernate: hold — idle=5s limit=10800s, newest=boot\n' > "$REC"; verify
vjudge verify.staletick 0 "unless this box just woke, the timer has stopped or the check cannot write its record" "!✋"

# a fresh tick carries no such note
world; printf 'at=%s exit=0\nidle-hibernate: hold — idle=5s limit=10800s, newest=boot\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$REC"; verify
vjudge verify.freshtick 0 "s ago): idle-hibernate: hold" "!the timer has stopped"

# no record at all: the timer's own last trigger tells "never fired" from "fired, wrote none"
world; echo "Sat 2026-01-03 00:00:00 UTC" > "$SD/lasttrigger"; verify
vjudge verify.notick 0 "• no tick on record yet at $REC — the timer last fired: Sat 2026-01-03 00:00:00 UTC"

# an older check writes no record: the verify says so, and never promises the next tick
world; echo "# older" >> "$FIX/box/idle-hibernate.sh"; verify
vjudge verify.oldnotick 1 "• no tick on record at $REC — the installed check is older than this checkout's, and writes none" \
  "!the next tick writes it"

# a pre-check skips every tick: no record is owed until the stopgap goes
world; touch "$FIX/box/idle-hibernate-holds.sh"; verify
vjudge verify.skipnotick 1 "• no tick on record at $REC — a pre-check skips every tick" "!the next tick writes it"

# an older check records no sleep: the verify names where a past sleep IS on record
world; echo "# older" >> "$FIX/box/idle-hibernate.sh"; verify
vjudge verify.oldsleep 1 "records no sleep; for a sleep before the ground apply, read CloudTrail's StopInstances events" \
  "!none since this box last booted cold"

# no record to read: the ground seat's journal read is named instead
world; echo exit-code > "$SD/result"; verify
vjudge verify.norecord 1 "its record at $REC is unreadable" \
  "from the ground seat, read why: rhx machine.journal.read --scope system --unit idle-hibernate.service" "⇒ a fault in the last run"

# a skipped tick ran no check: no record, no journal read, and the apply is the fix
world; echo exec-condition > "$SD/result"; touch "$FIX/box/idle-hibernate-holds.sh"
printf 'at=2026-01-01T00:00:00Z exit=0\nidle-hibernate: hold — old\n' > "$REC"; verify
vjudge verify.execcondition 1 "✋ the last idle check ended 'exec-condition'" "the stopgap pre-check is still on the box" \
  "⇒ a pre-check (ExecCondition=) skipped the tick, so the check never ran" "!its record, at $REC" "!its record at $REC is unreadable" "!machine.journal.read" "!not in the config"
vjudge verify.execcondition.stale 1 "⇒ a pre-check skips every tick, so this record is the last run before it" "!the timer has stopped"

# a killed run may leave no record of its own: the record shown is named as maybe earlier
world; echo timeout > "$SD/result"; printf 'at=2026-01-01T00:00:00Z exit=0\nidle-hibernate: hold — old\n' > "$REC"; verify
vjudge verify.killed 1 "its record, at $REC:" "⇒ the run was killed before its end, so the record above may be an earlier run's"

# the record is a world-readable boundary: a control byte in it never reaches the terminal raw
world; echo exit-code > "$SD/result"; printf 'at=x exit=1\na\033[31mb\n' > "$REC"; verify
vjudge verify.hostilerecord 1 "      │ a?[31mb" "!"$'\033'

# a record whose `at=` is no iso stamp shows no age and no staleness note — `x` most of all,
#   since GNU date reads a lone `x` as a military zone and would age it
world; printf 'at=x exit=0\nidle-hibernate: hold — idle=5s limit=10800s, newest=boot\n' > "$REC"; verify
vjudge verify.notimerecord 0 "• the last tick, at=x exit=0: idle-hibernate: hold" "! ago)" "!⇒ the timer ticks every"

# "drifted" is three boxes: the risk line names which, from facts, so a commander knows what is at stake now
world; echo "# drift" >> "$FIX/box/idle-hibernate.sh"; verify
vjudge verify.risk.bytes 1 "⇒ now: the installed check is not this checkout's, and may not count every crew: a busy box can hibernate under its crews"
world; echo "# drift" >> "$FIX/box/idle-hibernate.sh"; touch "$FIX/box/idle-hibernate-holds.sh"; verify
vjudge verify.risk.stopgap 1 "⇒ now: the stopgap pre-check holds every tick: no crew is at risk, and an idle box bills on" "!a busy box can hibernate"
world; echo inactive > "$SD/active"; verify
vjudge verify.risk.stopped 1 "⇒ now: the idle check does not tick: no crew is at risk, and an idle box bills on"
world; chmod 644 "$FIX/box/idle-hibernate.sh"; verify
vjudge verify.risk.held 1 "⇒ now: the check is this checkout's, and counts every crew; the gap is in how it is held or run" "!a busy box can hibernate"

# a wedged manager ends at the read bound and is named a gap — the verify never hangs its duct
READ_BOUND_REAL="$GROVE_PROVISION_1_15_HIBERNATE_READ_BOUND"
world; touch "$SD/hang.show"; GROVE_PROVISION_1_15_HIBERNATE_READ_BOUND=1; verify
GROVE_PROVISION_1_15_HIBERNATE_READ_BOUND="$READ_BOUND_REAL"; rm -f "$SD/hang.show"
vjudge verify.showhangs 1 "systemd could not report idle-hibernate.service: systemctl show -p LoadState --value idle-hibernate.service did not answer within 1s — systemd may be wedged"

# a box with no aws on the unit's PATH can never stop: health names it before the first idle tick
world; UNITBIN="$FIX/unitbin.noaws"; verify
vjudge verify.noaws 1 "the stop act needs aws, and none is on the unit's PATH" \
  "⇒ the grove's first boot installs aws, so its install failed: read /var/log/cloud-init-output.log" \
  "rhx grove.provision --what 5.6.aws --mode apply" "!the check needs"

# with no setpriv every seat's duct is unreadable, forever: health names it from the list, not by hand
world; UNITBIN="$FIX/unitbin.nosetpriv"; verify
vjudge verify.nosetpriv 1 "the check needs setpriv, and none is on the unit's PATH" "!needs aws"

# each gap the drift reader names, as the verify prints it to a human: its ✋, the risk, the fix.
# the `ask` arms above prove the reader; these prove the caller-faced block for each gap
VFIX="⇒ fix, from the ground seat: rhx grove.provision --what 1.15.hibernate --mode apply"
world; touch "$SD/needreload.idle-hibernate.service"; verify
vjudge verify.gap.reload 1 "✋ " "old definition of idle-hibernate.service" "⇒ now: " "$VFIX"
world; dropins idle-hibernate.timer "$FIX/box/run/idle-hibernate.timer.d/hold.conf"; verify
vjudge verify.gap.dropin 1 "✋ a drop-in this bundle does not write: $FIX/box/run/idle-hibernate.timer.d/hold.conf" "⇒ now: " "$VFIX"
world; mkdir -p "$FIX/box/etc/idle-hibernate.service.d"; echo "[Service]" > "$FIX/box/etc/idle-hibernate.service.d/late.conf"; verify
vjudge verify.gap.unloadeddropin 1 "✋ a drop-in this bundle does not write: $FIX/box/etc/idle-hibernate.service.d/late.conf" "$VFIX"
world; mv "$FIX/box/idle-hibernate.sh" "$FIX/box/seat.sh"; ln -s "$FIX/box/seat.sh" "$FIX/box/idle-hibernate.sh"; verify
vjudge verify.gap.symlink 1 "✋ $FIX/box/idle-hibernate.sh is a symlink, not the file this bundle writes" "$VFIX"
world; touch "$SD/fail.dropins"; verify
vjudge verify.gap.dropinsunread 1 "✋ systemd could not report the drop-ins of idle-hibernate.service" "$VFIX"
world; echo not-found > "$SD/loadstate.idle-hibernate.timer"; verify
vjudge verify.gap.unloaded 1 "✋ idle-hibernate.timer is not-found, not loaded" "$VFIX"
world; touch "$SD/fail.show"; verify
vjudge verify.gap.unread 1 "✋ systemd could not report idle-hibernate.service" "$VFIX"
world; echo masked > "$SD/enabled"; verify
vjudge verify.gap.masked 1 "is masked — a hand hold; the apply unmasks it" "$VFIX"
world; echo disabled > "$SD/enabled"; echo inactive > "$SD/active"; verify
vjudge verify.gap.timer 1 "✋ idle-hibernate.timer is not enabled" "✋ idle-hibernate.timer is not active" "$VFIX"

# the verify transcript, held by the shared snap — a reworded line shows in review, not in silence
# shellcheck source=/dev/null
source "$HERE/play.snap.operations.sh" || { echo "   💥 MalfunctionError: play.snap.operations.sh would not load"; exit 1; }
play_snap_verify dir="$HERE/prove.hibernate-drift-names-each-gap.snap" name=transcript actual="$VSNAP" || FAILED=1

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 the drift reader reads a converged box as converged, and names each gap"
else
  echo "✋ the contract did NOT hold — read the arms above"
fi
exit "$FAILED"
