#!/usr/bin/env bash
######################################################################
# .what = revoke this box's open-hours election — remove the marker the
#         `5.18.openhours` bundle reads
#
# .why
#   - a family that can SET and cannot DEL converges in one direction only, and
#     the inverse here is the one a human reaches for under pressure: the fence
#     is shut and they want out of it
#   - ⇒ so the `rm` is wrapped for the same reason the write is. the path is the
#     half nobody recalls, and an `rm` aimed one character off reports success
#     while the election remains
#
# 🛑 .it revokes, and it does NOT tear down
#   the bundle removes the timer and its files. this verb moves one file and then
#   names the one command that acts on it, so the installed state has a single
#   path in and a single path out (`rule.require.install-via-procedures`).
#
# 🛑 .THE TRAP THIS VERB EXISTS TO WARN ABOUT — a stranded gate
#   the bundle's teardown opens NO gate, by design: it cannot tell a block it set
#   from one a human set by hand, and the safe direction on an unreconciled gate
#   is closed (`5.18.openhours/_.sh`).
#
#   ⚠️ so an opt-out INSIDE the window leaves the gate shut and removes the only
#     converger that would have lifted it at the window's end. the gate then
#     stays closed forever, and the bundle's verify reports ✔ throughout, because
#     by its own claim an opted-out box with no timer is correctly converged.
#
#   📜 measured 2026-10-01 on this laptop: a teardown at 14:23 on a Wednesday
#     left `global: blocked` in place, with no timer left to clear it.
#
#   ⇒ so this verb READS the gate after a revoke and says what it found. it does
#     not lift the gate itself — both gate skills refuse a caller with no tty,
#     and that guard is the point (`rule.forbid.tty-as-a-proxy-for-a-human`)
#
# usage:
#   rhx machine.openhours.optin.del                 # plan
#   rhx machine.openhours.optin.del --mode apply
#   rhx machine.openhours.optin.del help
#
# options:
#   --mode      plan (default) or apply
#
# guarantee:
#   - HUMAN ONLY in apply mode: a caller with no tty exits 2
#   - idempotent: a box already opted out is a ✔, never a failure
#   - READ-ONLY in plan mode; it names the exact path apply would remove
#   - it opens NO gate and removes NO timer — the bundle owns the teardown
#   - exit 0 = this box carries no election
#   - exit 1 = malfunction (the marker could not be removed)
#   - exit 2 = constraint (bad args, or apply from a caller with no tty)
######################################################################
set -uo pipefail

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "machine.openhours.optin.del — revoke this box's open-hours election"
  echo ""
  echo "usage:"
  echo "  rhx machine.openhours.optin.del [--mode apply]"
  echo ""
  echo "options:"
  echo "  --mode      plan (default) or apply — apply is HUMAN ONLY (needs a tty)"
  echo ""
  echo "it removes ONE file — the election. the bundle tears the timer down:"
  echo "  rhx grove.provision --what 5.18.openhours --mode apply"
  echo ""
  echo "🛑 an opt-out opens NO gate. revoke inside the window and the block"
  echo "   outlives its converger — this verb reads the gate and says so."
  exit 0
fi

# shellcheck source=./machine.openhours.optin.operations.sh
source "$(dirname "${BASH_SOURCE[0]}")/machine.openhours.optin.operations.sh"

MODE="plan"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    # ⚠️ rhachet injects these three into every skill it runs, so each is dropped
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "✋ unknown argument '$1'" >&2
       echo "   see: rhx machine.openhours.optin.del help" >&2; exit 2 ;;
  esac
done

[[ "$MODE" == "plan" || "$MODE" == "apply" ]] \
  || { echo "✋ invalid --mode '$MODE' (plan|apply)" >&2; exit 2; }

####################################################################
# guard: apply requires a TTY (human only)
#
# 🛑 the election is the human's. an agent fenced by the gate could otherwise
#   opt its own box out of every future window — so the revoke is held to the
#   same guard `git.commit.uses allow --global` holds (rhachet-roles-ehmpathy)
# note: plan stays open — it writes no file
# note: __I_AM_HUMAN=true lets a test drive the apply leg
####################################################################
if [[ "$MODE" == "apply" && ! -t 0 && "${__I_AM_HUMAN:-}" != "true" ]]; then
  echo "🐢 bummer dude..." >&2
  echo "" >&2
  echo "🕰️ machine.openhours.optin.del --mode apply" >&2
  echo "   └─ ✋ only humans can revoke the election" >&2
  echo "      run it yourself, at a terminal on this box" >&2
  exit 2
fi

STATE="$(openhours_optin_state)"

echo "🐢 lets drop the fence..."
echo ""
echo "🕰️ machine.openhours.optin.del --mode $MODE"
echo "   ├─ marker: $GROVE_OPENHOURS_OPTIN"

if [[ "$STATE" == "out" ]]; then
  echo "   └─ ✔ already opted out — this box carries no marker"
  exit 0
fi

PRIOR="$(openhours_optin_reason)"
if [[ -n "${PRIOR//[[:space:]]/}" ]]; then
  echo "   ├─ its note: ${PRIOR%%$'\n'*}"
fi

if [[ "$MODE" == "plan" ]]; then
  echo "   └─ 🌙 plan — no file removed"
  echo ""
  echo "   apply it: rhx machine.openhours.optin.del --mode apply"
  exit 0
fi

if ! rm -f "$GROVE_OPENHOURS_OPTIN"; then
  echo "   └─ ✋ could not remove $GROVE_OPENHOURS_OPTIN" >&2
  exit 1
fi

echo "   ├─ ✔ marker removed — this box no longer elects the gate"
echo "   ⇒ the election is revoked; the BOX still carries the timer"
echo "     tear it down by the one command:"
echo "       rhx grove.provision --what 5.18.openhours --mode apply"

####################################################################
# the stranded-gate read — the whole reason this verb is more than an `rm`
#
# ⚠️ it reads through `git.commit.uses get` rather than the meter file, because
#   those paths are declared inside `machine_openhours_reconcile` and a copy here
#   would be a second declaration of a fact that executable owns
####################################################################
echo ""
echo "   🛑 a teardown opens NO gate — read it before you walk away:"
if command -v rhx >/dev/null 2>&1; then
  GATE="$(rhx git.commit.uses get 2>/dev/null)"
  if [[ "$GATE" == *"global"*"blocked"* ]]; then
    echo "      ✋ the global commit gate reads BLOCKED right now"
    echo "         ⇒ the block outlived the converger that would have lifted it"
    echo "         fix — at a terminal, as a human:"
    echo "           rhx git.commit.uses allow --global"
    echo "           rhx radio.uses --global allow"
  else
    echo "      • the global commit gate is not blocked ✔"
    echo "        read it in full: rhx git.commit.uses get"
  fi
else
  echo "      🌙 rhx is off PATH here, so the gate was not read"
  echo "         read it: rhx git.commit.uses get"
fi
exit 0
