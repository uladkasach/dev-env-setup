#!/usr/bin/env bash
######################################################################
# prove.idle-check-reads-this-box — the checkout's idle check reads THIS box's
# real traces and tmux servers with no alarm, and renders a verdict
#
# .what = runs `src/grove.provision/1.system/1.15.hibernate/idle-hibernate.sh`
#         against the live box, with `aws` and `curl` stubbed on PATH, so no
#         verdict can stop the instance. then lists each tmux socket it read
#
# .why a second play beside `prove.idle-check-counts-every-crew`
#   - that clamp proves the logic in a fixture. this proves the logic meets a
#     real box: its socket names, its layouts, and its seat's privilege
#   - from the GROUND seat it is the proof that root reads every camper's tmux
#     server — the duct signal rests on that, and no fixture can show it
#
# .the claims
#   verdict   the check exits 0 and prints a `hold` or a `hibernate now` line
#   quiet     no `💥 MalfunctionError:` on stderr — every socket and trace walk was read
#   counts    the verdict's `seen traces= pts= ducts=` sit within what this seat counts just
#             before and just after the run (a live box moves), by its own literals for where
#             crews write — so a root dropped from the check reads as a short count
#             — the shipped `-type c` predicate, which the clamp rewrites, is proven here
#   fast      the check ran in under half its unit's `TimeoutStartSec=`, at this box's scale
#
# .the write — `rule.forbid.repair-plays` exception 2: a temp dir for the
#   stubs, removed by a trap. the box is only read
#
# usage:
#   rhx play.run --play prove.idle-check-reads-this-box
#   rhx git.grove.send <grove>.ground --play prove.idle-check-reads-this-box
######################################################################
set -uo pipefail

# the checkout is this file's own, never the cwd: rhx guarantees no cwd
REPO="${GROVE_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src}"
CHECK="$REPO/grove.provision/1.system/1.15.hibernate/idle-hibernate.sh"
STUB=""
# the restore reports whether it took: a stub dir that survives fails the play (`rule.forbid.repair-plays`, condition 4)
trap '[[ -n "$STUB" ]] && rm -rf "$STUB"; [[ -n "$STUB" && -e "$STUB" ]] && { echo "   ✋ residue SURVIVED — $STUB"; exit 1; }' EXIT

[[ -f "$CHECK" ]] || { echo "✋ ConstraintError: no check at $CHECK — this play measures the real file"; exit 2; }

STUB="$(mktemp -d)"
# the stub logs its call to a file, never to stdout, which holds the check's lines alone
printf '#!/bin/sh\necho "stub aws $*" >> "%s/aws.log"\n' "$STUB" > "$STUB/aws"
printf '#!/bin/sh\necho stub\n' > "$STUB/curl"
chmod +x "$STUB/aws" "$STUB/curl"
# the one write the check makes goes into the stub dir; every READ stays on the live box
RUN="$STUB/idle-hibernate.sh"
sed -e "s#^LAST_RECORD=.*#LAST_RECORD=$STUB/idle-hibernate.last#" \
    -e "s#^LAST_SLEEP=.*#LAST_SLEEP=$STUB/idle-hibernate.last-sleep#" "$CHECK" > "$RUN"
# a missed rewrite, run from the ground seat, would overwrite the box's live record with a stubbed run's
grep -qx "LAST_RECORD=$STUB/idle-hibernate.last" "$RUN" \
  || { echo "✋ ConstraintError: the record path was not rewritten into the stub dir — this play would write the box's live record"; exit 2; }
grep -qx "LAST_SLEEP=$STUB/idle-hibernate.last-sleep" "$RUN" \
  || { echo "✋ ConstraintError: the sleep record path was not rewritten into the stub dir — this play would write the box's live sleep record"; exit 2; }

# .what = what this seat can see for itself, to hold the check's own counts against
count_pts() { local p n=0; for p in /dev/pts/[0-9]*; do [[ -c "$p" ]] && n=$((n + 1)); done; echo "$n"; }
count_ducts() {
  local sock n=0
  for sock in /tmp/tmux-*/*; do
    [[ -S "$sock" ]] || continue
    timeout -k 2 5 tmux -S "$sock" </dev/null list-windows -a >/dev/null 2>&1 && n=$((n + 1))
  done
  echo "$n"
}
# .what = every brain trace where a crew or a human writes one, as this seat sees them
# .why its own literals, never the check's: a count the check makes of its own globs
#   proves naught if a root is dropped from them. these name where crews write — the
#   human's projects, each worktree's actors, each main clone's actors, each codex session
count_traces() {
  local roots=() n
  shopt -s nullglob
  roots=(/home/*/.claude/projects /home/*/git/*/_worktrees/*/.agent/.actors/*/brain/.claude/projects
    /home/*/git/*/*/.agent/.actors/*/brain/.claude/projects /home/*/.codex/sessions)
  shopt -u nullglob
  [[ ${#roots[@]} -gt 0 ]] || { echo 0; return; }
  # bounded, as the check's own walk is: a tree a fleet left behind never hangs the play.
  # a walk the bound ends reads as -1, which no count sits within, so `counts` names it
  local rc
  timeout -k 5 60 find -H "${roots[@]}" -name '*.jsonl' > "$STUB/traces" 2>/dev/null; rc=$?
  [[ "$rc" -eq 124 || "$rc" -eq 137 ]] && { echo -1; return; }
  n="$(grep -c . "$STUB/traces")"
  echo "$n"
}
# .what = is $1 between $2 and $3, in either order?
# .why a negative bound refuses: -1 means "could not measure", never a count, so a range
#   with it as one end would accept any count below the other sample
within() {
  [[ "$2" -ge 0 && "$3" -ge 0 ]] || return 1
  [[ "$1" -ge $(( $2 < $3 ? $2 : $3 )) && "$1" -le $(( $2 > $3 ? $2 : $3 )) ]]
}

# a live box opens and shuts ptys and ducts while the check runs, so each count is
# sampled on both sides of the run, and the check's own count must sit between them
PTS_BEFORE="$(count_pts)"; DUCTS_BEFORE="$(count_ducts)"; TRACES_BEFORE="$(count_traces)"
T0=$SECONDS
OUT="$(PATH="$STUB:$PATH" bash "$RUN" 2>"$STUB/err")"; RC=$?
ELAPSED=$((SECONDS - T0))
PTS_AFTER="$(count_pts)"; DUCTS_AFTER="$(count_ducts)"; TRACES_AFTER="$(count_traces)"
ERR="$(cat "$STUB/err")"
# the unit stops a run at `TimeoutStartSec=`; half of it is the budget a tick may spend
BOUND="$(grep -oP '^TimeoutStartSec=\K[0-9]+' "$REPO/grove.provision/1.system/1.15.hibernate/idle-hibernate.service")"

echo "🔭 does the idle check read this box, as $(id -un)?"
echo "   ├─ out: $(printf '%s' "$OUT" | head -n 1 | cut -c1-140)"
[[ -z "$ERR" ]] || printf '%s\n' "$ERR" | head -n 6 | sed 's/^/   ├─ err: /'

echo "   ├─ each tmux socket"
for sock in /tmp/tmux-*/*; do
  [[ -e "$sock" ]] || continue
  if [[ ! -S "$sock" ]]; then echo "   │  ├─ $sock — not a socket, skipped"; continue; fi
  row="$(timeout -k 2 5 tmux -S "$sock" </dev/null list-windows -a -F '#{window_activity} #{session_name}:#{window_index}' 2>&1)"
  echo "   │  ├─ $sock — $(head -n 1 <<< "$row")"
done
echo "   │"

SEEN="$(grep -oE 'seen traces=[0-9]+ pts=[0-9]+ ducts=[0-9]+' <<< "$OUT" | head -n 1)"
read -r SEEN_TRACES SEEN_PTS SEEN_DUCTS <<< "$(sed -E 's/seen traces=([0-9]+) pts=([0-9]+) ducts=([0-9]+)/\1 \2 \3/' <<< "$SEEN")"

FAILED=0
if [[ "$RC" -ne 0 ]] || [[ "$OUT" != *"idle-hibernate: hold"* && "$OUT" != *"hibernate now"* ]]; then
  echo "   ├─ ✋ verdict — exit=$RC, and no hold or hibernate line"; FAILED=1
else
  echo "   ├─ ✔ verdict — $(printf '%s' "$OUT" | head -n 1 | cut -c16-60)…"
fi
if [[ "$ERR" == *"MalfunctionError"* ]]; then
  echo "   ├─ ✋ quiet — the check could not read a source on this box (err above)"; FAILED=1
else
  echo "   ├─ ✔ quiet — every trace walk and tmux server was read"
fi
# a crew runs this play, so its own trace is on the box; a zero is a source that read naught
if [[ -z "$SEEN" ]]; then
  echo "   ├─ ✋ counts — the verdict names no \`seen traces=… pts=… ducts=…\`"; FAILED=1
elif [[ "$TRACES_BEFORE" -lt 0 || "$TRACES_AFTER" -lt 0 ]]; then
  echo "   ├─ ✋ counts — this seat's own trace census hit its bound, so the check's count could not be held against it"; FAILED=1
elif [[ "$SEEN_TRACES" -eq 0 ]] || ! within "$SEEN_TRACES" "$TRACES_BEFORE" "$TRACES_AFTER" \
  || ! within "$SEEN_PTS" "$PTS_BEFORE" "$PTS_AFTER" || ! within "$SEEN_DUCTS" "$DUCTS_BEFORE" "$DUCTS_AFTER"; then
  echo "   ├─ ✋ counts — the check saw $SEEN; this seat sees traces=$TRACES_BEFORE..$TRACES_AFTER pts=$PTS_BEFORE..$PTS_AFTER ducts=$DUCTS_BEFORE..$DUCTS_AFTER"; FAILED=1
else
  echo "   ├─ ✔ counts — $SEEN, each within what this seat saw before and after (traces=$TRACES_BEFORE..$TRACES_AFTER pts=$PTS_BEFORE..$PTS_AFTER ducts=$DUCTS_BEFORE..$DUCTS_AFTER)"
fi
if [[ -z "$BOUND" || "$ELAPSED" -gt $(( ${BOUND:-0} / 2 )) ]]; then
  echo "   └─ ✋ fast — the check took ${ELAPSED}s, past half its unit's TimeoutStartSec=${BOUND:-absent}"; FAILED=1
else
  echo "   └─ ✔ fast — ${ELAPSED}s on this box, under half its TimeoutStartSec=${BOUND}"
fi

# the transcript snap: the verdict's GRAMMAR and the claim set, every box-bound value masked.
# a live box holds or sleeps by its own crews, so the verdict word is masked too — what the snap
# pins is that the line still reads `<verdict> — idle=… limit=…, newest=<kind> <source>; seen …`
SNAP="verdict line: $(printf '%s' "$OUT" | head -n 1 | sed -E -e 's/: (hold|sleep) — /: <verdict> — /' \
  -e 's/newest=[a-z]+ [^;]*;/newest=<kind> <source>;/' -e 's/=[0-9]+/=<n>/g' -e 's/ — hibernate now$//')"$'\n'
SNAP+="claims: verdict quiet counts fast"$'\n'
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/play.snap.operations.sh" || { echo "   💥 MalfunctionError: play.snap.operations.sh would not load"; exit 1; }
play_snap_verify dir="$HERE/prove.idle-check-reads-this-box.snap" name=transcript actual="$SNAP" || FAILED=1

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 the idle check reads this box as $(id -un), and renders a verdict"
else
  echo "✋ the check did NOT read this box cleanly — read the lines above"
fi
exit "$FAILED"
