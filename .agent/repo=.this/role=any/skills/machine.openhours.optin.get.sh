#!/usr/bin/env bash
######################################################################
# .what = report whether THIS box has elected the open-hours gate, what note the
#         marker carries, and whether the box is converged to that election
#
# .why
#   - the election is a FILE, and a file is invisible. "is this box fenced?" is
#     the first question a human has at a new seat, and it had no verb — so it
#     was answered by a remembered `ls ~/.config/grove/` (`rule.forbid.adhoc-shell`:
#     an absent skill is the defect to fix)
#   - ⇒ and the marker alone is only HALF the answer. a box can be elected and
#     un-converged, which looks identical from the filesystem and behaves the
#     opposite way
#
# 🛑 .why it reports the ELECTION and the CONVERGE as two rows
#   they drift apart by one apply, and each has its own repair. a single verdict
#   would send a human to the wrong one half the time
#   (`gotcha.a-check-that-cries-wolf-gets-silenced`)
#
# ⚠️ .why the GATE's own state is pointed at and never read here
#   the two meter paths are declared inside `machine_openhours_reconcile`, which
#   is a payload and not a sourceable library. a copy of those paths here would
#   be a second declaration of a fact that executable owns.
#   ⇒ so this names the skill that answers for the gate, and reads neither file.
#     `rhx git.commit.uses get` is the authority on a gate's state.
#
# usage:
#   rhx machine.openhours.optin.get
#   rhx machine.openhours.optin.get --quiet     # the state word alone
#   rhx machine.openhours.optin.get help
#
# options:
#   --quiet     print `in` or `out` alone, for a caller to branch on
#
# guarantee:
#   - READ-ONLY, always. it writes no file and moves no gate
#   - exit 0 = the read completed, whatever it found. an opted-out box is a
#     FACT and never a failure, so it is never an error exit
#   - exit 2 = constraint (bad args)
######################################################################
set -uo pipefail

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "machine.openhours.optin.get — has this box elected the open-hours gate?"
  echo ""
  echo "usage:"
  echo "  rhx machine.openhours.optin.get [--quiet]"
  echo ""
  echo "options:"
  echo "  --quiet     print 'in' or 'out' alone, for a caller to branch on"
  echo ""
  echo "it reports TWO rows, because they drift by one apply:"
  echo "  1. the ELECTION — the marker this box carries"
  echo "  2. the CONVERGE — whether the timer matches that election"
  echo ""
  echo "the GATE's own state is a separate question:"
  echo "  rhx git.commit.uses get"
  exit 0
fi

# shellcheck source=./machine.openhours.optin.operations.sh
source "$(dirname "${BASH_SOURCE[0]}")/machine.openhours.optin.operations.sh"

QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    # ⚠️ rhachet injects these three into every skill it runs, so each is dropped
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "✋ unknown argument '$1'" >&2
       echo "   see: rhx machine.openhours.optin.get help" >&2; exit 2 ;;
  esac
done

STATE="$(openhours_optin_state)"

####################################################################
# --quiet — the machine face. one word, no banner
#
# 🛑 `rhx` writes a banner to STDOUT ahead of every skill, so a caller that
#   reads this must strip it or source the operations file directly
#   (`aws.reach.get`'s `--names` note carries the measurement)
####################################################################
if [[ "$QUIET" -eq 1 ]]; then
  printf '%s\n' "$STATE"
  exit 0
fi

echo "🐢 lets read the fence..."
echo ""
echo "🕰️ machine.openhours.optin.get"

####################################################################
# 1. the ELECTION
####################################################################
if [[ "$STATE" == "in" ]]; then
  echo "   ├─ election: IN — this box asked for the gate"
  echo "   │  └─ marker: $GROVE_OPENHOURS_OPTIN"

  REASON="$(openhours_optin_reason)"
  if [[ -n "${REASON//[[:space:]]/}" ]]; then
    echo "   │     note: ${REASON%%$'\n'*}"
  else
    echo "   │     note: （the marker is empty — presence is the contract）"
  fi
else
  echo "   ├─ election: OUT — this box carries no marker, and the default is off"
  echo "   │  └─ would be at: $GROVE_OPENHOURS_OPTIN"
fi

####################################################################
# 2. the CONVERGE — is the box at its own election?
#
# ⚠️ an `is-active` read is the honest probe here. a file on disk can be
#   byte-perfect while the timer is down, and only the unit answers for that
####################################################################
TIMER="$(systemctl --user is-active machine_openhours_reconcile.timer 2>/dev/null)"
[[ -n "$TIMER" ]] || TIMER="absent"

if [[ "$STATE" == "in" && "$TIMER" == "active" ]]; then
  echo "   ├─ converge: ✔ the timer is active, so the box is at its election"
elif [[ "$STATE" == "out" && "$TIMER" != "active" ]]; then
  echo "   ├─ converge: ✔ no timer, as an opted-out box should carry none"
elif [[ "$STATE" == "in" ]]; then
  echo "   ├─ converge: ✋ elected, and the timer is '$TIMER'"
  echo "   │  ⇒ this box asked for the gate and does not run it, so the"
  echo "   │    hours are declared and never enforced"
  echo "   │  fix: rhx grove.provision --what 5.18.openhours --mode apply"
else
  echo "   ├─ converge: ✋ opted out, and the timer is '$TIMER'"
  echo "   │  ⇒ a schedule no declaration holds still moves this box's gates"
  echo "   │  fix: rhx grove.provision --what 5.18.openhours --mode apply"
fi

####################################################################
# 3. the GATE — pointed at, never read (see the header)
#
# 🛑 .why an opted-OUT box is told to check it anyway
#   a teardown opens no gate, by design — so a box that opted out while the gate
#   was CLOSED keeps that block, with the converger that would have lifted it
#   removed. measured 2026-10-01 on this laptop: `global: blocked` outlived the
#   teardown, and the bundle's verify reported ✔ the whole time, correctly
####################################################################
echo "   └─ the GATE itself is a separate question, and this verb never reads it"
echo "      read it:  rhx git.commit.uses get"
if [[ "$STATE" == "out" ]]; then
  echo "      ⚠️ an opt-out opens NO gate. if it reads 'blocked' here, the block"
  echo "         outlived its converger and only a human can lift it:"
  echo "           rhx git.commit.uses allow --global"
  echo "           rhx radio.uses --global allow"
fi
exit 0
