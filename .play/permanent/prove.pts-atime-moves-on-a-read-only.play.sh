#!/usr/bin/env bash
######################################################################
# prove.pts-atime-moves-on-a-read-only — on THIS box's kernel, a pty's atime
# moves when its process reads input, and holds while it only prints or waits
#
# .what = starts a private tmux server on a temp socket, with three panes:
#         one that prints, one that waits in a read, and one TUI that redraws
#         and polls its keyboard. it stats each pane's real `/dev/pts/<n>`
#         across 10s windows, sends one typed line to the reader, and stats again
#
# .why a real kernel, never a fixture
#   - the idle check reads a numbered pts's `%A@` as "a human typed here" (F13)
#   - the clamp proves that rule on a regular file; only a real pty shows what
#     the kernel stamps. this is the measure F10 owes for facts 2 and 4
#
# .why 10s windows
#   - linux stamps a tty's inode only when the time crosses an 8s bucket
#     (`tty_update_time`), so a shorter window can read "held" on a moved stamp
#
# .the claims
#   printer   a pane that only prints moves its pty's mtime, and holds its atime
#   waiter    a pane blocked in a read, with no input, holds its atime
#   keystroke one typed line, read by that pane, moves its atime
#   tui       a TUI that redraws and polls its keyboard (`top`) holds its atime
#   ptmx      `/dev/pts/ptmx`'s stamps before and after a new pty, as a record
#             only: the check reads numbered slaves, never ptmx
#
# .the write — `rule.forbid.repair-plays` exception 2: a temp dir for the
#   private server's socket, killed and removed by a trap. no extant tmux
#   server, pane, or pty is touched
#
# usage:
#   rhx play.run --play prove.pts-atime-moves-on-a-read-only
######################################################################
set -uo pipefail

FAILED=0
D=""
SOCK=""
# .what = tmux, bounded — a wedged server never hangs the play, its trap, or the duct it runs in
tx() { timeout -k 2 5 tmux "$@" </dev/null; }
cleanup() {
  [[ -n "$SOCK" && -S "$SOCK" ]] && tx -S "$SOCK" kill-server 2>/dev/null
  [[ -n "$D" ]] && rm -rf "$D"
  # the restore reports whether it took: a dir that survives fails the play (`rule.forbid.repair-plays`, condition 4)
  [[ -n "$D" && -e "$D" ]] && { echo "   ✋ residue SURVIVED — $D"; exit 1; }
  return 0
}
trap cleanup EXIT

command -v tmux >/dev/null || { echo "✋ ConstraintError: no tmux on PATH — fix: rhx grove.provision --what 2.8.tmux --mode apply"; exit 2; }
command -v top >/dev/null || { echo "✋ ConstraintError: no top on PATH — the tui arm needs procps"; exit 2; }

D="$(mktemp -d)"
SOCK="$D/s"

# .what = `<atime> <mtime>` of a path, in epoch seconds
stamps() { stat -c '%X %Y' "$1"; }
# .what = the pty of a pane in the private server
pane_tty() { tx -S "$SOCK" display -p -t "$1" '#{pane_tty}'; }

PTMX_BEFORE="$(stamps /dev/pts/ptmx)"

# three panes, each its own window, so each holds its own pty
tx -f /dev/null -S "$SOCK" new-session -d -s m -n printer -x 80 -y 20 'while :; do date; sleep 1; done' \
  || { echo "💥 MalfunctionError: tmux could not start a private server at $SOCK"; exit 1; }
tx -S "$SOCK" new-window -d -t m -n waiter 'cat' \
  || { echo "💥 MalfunctionError: tmux could not open the waiter pane"; exit 1; }
tx -S "$SOCK" new-window -d -t m -n tui 'top -d 1' \
  || { echo "💥 MalfunctionError: tmux could not open the tui pane"; exit 1; }

PRINTER="$(pane_tty m:printer)"; WAITER="$(pane_tty m:waiter)"; TUI="$(pane_tty m:tui)"
for t in "$PRINTER" "$WAITER" "$TUI"; do
  [[ "$t" == /dev/pts/[0-9]* && -c "$t" ]] \
    || { echo "💥 MalfunctionError: a pane's pty is not a numbered pts: '$t'"; exit 1; }
done
PTMX_AFTER="$(stamps /dev/pts/ptmx)"

echo "🔭 does a pty's atime move on a read, and only on a read?"
echo "   ├─ ptys: printer=$PRINTER waiter=$WAITER tui=$TUI"

# window 1: no input anywhere
sleep 2
P0="$(stamps "$PRINTER")"; W0="$(stamps "$WAITER")"; T0="$(stamps "$TUI")"
sleep 10
P1="$(stamps "$PRINTER")"; W1="$(stamps "$WAITER")"; T1="$(stamps "$TUI")"

# window 2: one typed line to the reader
tx -S "$SOCK" send-keys -t m:waiter 'typed' Enter \
  || { echo "💥 MalfunctionError: tmux could not type into the waiter pane"; exit 1; }
sleep 10
W2="$(stamps "$WAITER")"

# .what = judge one claim: judge <arm> <ok 0|1> <what> <evidence>; each verdict line joins the snap
# .why the snap masks the epochs: they differ per run and per box, and the verdict shape does not
# .why by RELATION, per pair: each `before→after` reads `<t0>→<t0>` (held) or `<t0>→<t1>` (moved).
#   a count across the whole line would tie one field's numbers to another's, so whether atime
#   happened to equal mtime would drift the snap with no change in the verdict
SNAP="# each before→after pair: <t0>→<t0> held, <t0>→<t1> moved"$'\n'
asRelativeEpochs() {
  awk '{ out = ""
    while (match($0, /[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]+(\.[0-9]+)?→[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]+(\.[0-9]+)?/)) {
      pair = substr($0, RSTART, RLENGTH); split(pair, side, "→")
      out = out substr($0, 1, RSTART - 1) (side[1] == side[2] ? "<t0>→<t0>" : "<t0>→<t1>")
      $0 = substr($0, RSTART + RLENGTH)
    }
    print out $0 }'
}
judge() {
  local line
  echo "   ├─ arm '$1'"
  if [[ "$2" -eq 0 ]]; then line="✔ $3 ($4)"
  else line="✋ $3 did NOT hold ($4)"; FAILED=1; fi
  echo "   │  $line"
  SNAP+="$1: $(asRelativeEpochs <<< "$line")"$'\n'
}
read -r p0a p0m <<< "$P0"; read -r p1a p1m <<< "$P1"
read -r w0a _ <<< "$W0"; read -r w1a _ <<< "$W1"; read -r w2a _ <<< "$W2"
read -r t0a _ <<< "$T0"; read -r t1a _ <<< "$T1"

[[ "$p1m" -gt "$p0m" && "$p1a" -eq "$p0a" ]]; judge printer $? \
  "a pane that only prints moves mtime and holds atime" "atime $p0a→$p1a, mtime $p0m→$p1m"
[[ "$w1a" -eq "$w0a" ]]; judge waiter $? \
  "a pane blocked in a read, with no input, holds atime" "atime $w0a→$w1a"
[[ "$w2a" -gt "$w1a" ]]; judge keystroke $? \
  "one typed line, read by the pane, moves atime" "atime $w1a→$w2a"
[[ "$t1a" -eq "$t0a" ]]; judge tui $? \
  "a TUI that redraws and polls its keyboard holds atime" "atime $t0a→$t1a"
echo "   └─ ptmx, a record only — atime mtime before: $PTMX_BEFORE, after a new pty: $PTMX_AFTER"

# the verdict transcript, held by the shared snap — a reworded claim shows in review
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/play.snap.operations.sh" || { echo "   💥 MalfunctionError: play.snap.operations.sh would not load"; exit 1; }
play_snap_verify dir="$HERE/prove.pts-atime-moves-on-a-read-only.snap" name=transcript actual="$SNAP" || FAILED=1

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 on this kernel a pty's atime moves on a read of input, and holds while a pane prints, waits, or redraws"
else
  echo "✋ the kernel did NOT stamp ptys as the idle check reads them — read the arms above"
fi
exit "$FAILED"
