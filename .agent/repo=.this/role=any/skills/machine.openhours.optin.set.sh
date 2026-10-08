#!/usr/bin/env bash
######################################################################
# .what = elect the open-hours gate on THIS box — place the marker the
#         `5.18.openhours` bundle reads
#
# .why
#   - the election is a file in a dir that may not exist, so the ad-hoc form is
#     two commands a human must remember in order (`mkdir -p`, then a redirect
#     into an exact path). that is the shape `rule.forbid.adhoc-shell` names, and
#     the path is the half nobody recalls
#   - ⇒ and a redirect typo'd by one character makes a marker the bundle never
#     reads, which fails SILENTLY: the next apply tears the gate down and reports
#     success, because by its own reader the box asked for no gate
#
# 🛑 .it elects, and it does NOT converge
#   the bundle is what installs the timer. this verb writes one file and then
#   names the one command that acts on it, so there is a single path to the
#   installed state (`rule.require.install-via-procedures`).
#
# ⚠️ .why `--why` is offered and never required
#   the marker's body is free text and is NEVER parsed — presence of the path is
#   the whole contract. so a note is cheap to carry and answers the question a
#   later self will actually have ("why is this box fenced and that one not?").
#   an empty marker is equally valid, and the get verb says so rather than warn.
#
# ⚠️ .why it is IDEMPOTENT and reports the prior note
#   a re-run on an elected box is a ✔, never a failure. but a second `--why`
#   OVERWRITES the first, so the prior body is printed before it is replaced —
#   a human who re-elects a box should see the note they are about to lose
#
# usage:
#   rhx machine.openhours.optin.set                                 # plan
#   rhx machine.openhours.optin.set --mode apply
#   rhx machine.openhours.optin.set --why 'my desk hours' --mode apply
#   rhx machine.openhours.optin.set help
#
# options:
#   --why       the note the marker carries   (default: a dated line)
#   --mode      plan (default) or apply
#
# guarantee:
#   - idempotent: a box already elected is a ✔
#   - READ-ONLY in plan mode; it names the exact path apply would write
#   - it moves NO gate and installs NO timer — the bundle owns both
#   - exit 0 = this box's election is set
#   - exit 1 = malfunction (the marker could not be written)
#   - exit 2 = constraint (bad args)
######################################################################
set -uo pipefail

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "machine.openhours.optin.set — elect the open-hours gate on this box"
  echo ""
  echo "usage:"
  echo "  rhx machine.openhours.optin.set [--why <note>] [--mode apply]"
  echo ""
  echo "options:"
  echo "  --why       the note the marker carries   (default: a dated line)"
  echo "  --mode      plan (default) or apply"
  echo ""
  echo "it writes ONE file — the election. the bundle installs the timer:"
  echo "  rhx grove.provision --what 5.18.openhours --mode apply"
  echo ""
  echo "the note is never parsed. presence of the path is the whole contract."
  exit 0
fi

# shellcheck source=./machine.openhours.optin.operations.sh
source "$(dirname "${BASH_SOURCE[0]}")/machine.openhours.optin.operations.sh"

MODE="plan"
WHY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --why)  WHY="$2";  shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    # ⚠️ rhachet injects these three into every skill it runs, so each is dropped
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "✋ unknown argument '$1'" >&2
       echo "   see: rhx machine.openhours.optin.set help" >&2; exit 2 ;;
  esac
done

[[ "$MODE" == "plan" || "$MODE" == "apply" ]] \
  || { echo "✋ invalid --mode '$MODE' (plan|apply)" >&2; exit 2; }

[[ -n "$WHY" ]] || WHY="elected $(date +%Y-%m-%d) — this seat is fenced to the declared hours"

STATE="$(openhours_optin_state)"

echo "🐢 lets set the fence..."
echo ""
echo "🕰️ machine.openhours.optin.set --mode $MODE"
echo "   ├─ marker: $GROVE_OPENHOURS_OPTIN"

####################################################################
# the prior note — printed BEFORE a write that would replace it
####################################################################
if [[ "$STATE" == "in" ]]; then
  PRIOR="$(openhours_optin_reason)"
  echo "   ├─ already elected ✔"
  if [[ -n "${PRIOR//[[:space:]]/}" ]]; then
    echo "   │  └─ its note: ${PRIOR%%$'\n'*}"
    echo "   │     ⚠️ an apply REPLACES that note with the one below"
  fi
fi

echo "   ├─ note: $WHY"

if [[ "$MODE" == "plan" ]]; then
  echo "   └─ 🌙 plan — no file written"
  echo ""
  echo "   apply it: rhx machine.openhours.optin.set --mode apply"
  exit 0
fi

####################################################################
# the write — the dir first, because `~/.config/grove` is this repo's own and
# may not exist on a fresh box
####################################################################
if ! mkdir -p "$(dirname "$GROVE_OPENHOURS_OPTIN")"; then
  echo "   └─ ✋ could not create $(dirname "$GROVE_OPENHOURS_OPTIN")" >&2
  echo "      ⇒ the election has no home, so this box cannot opt in" >&2
  exit 1
fi

if ! printf '%s\n' "$WHY" > "$GROVE_OPENHOURS_OPTIN"; then
  echo "   └─ ✋ could not write $GROVE_OPENHOURS_OPTIN" >&2
  exit 1
fi

echo "   ├─ ✔ marker placed"
openhours_optin_converge_hint
exit 0
