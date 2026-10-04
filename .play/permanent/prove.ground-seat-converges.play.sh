#!/usr/bin/env bash
######################################################################
# .what = prove THIS seat holds every power a convergence needs
#
# .why  = a grove image ships two seats, and only one can converge:
#
#           ground — (ALL) NOPASSWD: ALL   → converges the box
#           camper — no sudo, deliberately → runs the agent
#
#         a `grove.provision` run from the camper seat closes almost
#         none of the tree. measured 2026-08-10: 6 of 78 claims, and
#         every claim it missed was a system write.
#
#         🛑 the trap is how that failure READS. a bundle that cannot
#         write /etc reports "the config is absent" — which is exactly
#         what a bundle reports when the config is genuinely absent.
#         so a wrong-seat run and an un-converged box are
#         INDISTINGUISHABLE in the plan. this play is the one question
#         that separates them.
#
# usage:
#   rhx git.grove.send <grove>.ground --reply --play prove.ground-seat-converges
#
# 🛑 .why it reads the TIER before it grades a single power
#
# 📜 measured 2026-09-30, on this laptop's own seat. the play graded `vlad`
#    against a GROVE's ground contract and printed:
#
#      ✋ sudo — absent or password-gated on this seat
#      fix: drive the provision from the seat that holds sudo —
#             rhx git.grove.push <grove>.ground …
#
#    every word of that is true of a ground seat and MIS-SCOPED here. a
#    laptop's human seat is password-gated ON PURPOSE — a human types their
#    password — and the laptop IS the box, so there is no `<grove>.ground`
#    to drive from. the fix-text named a move with no subject.
#
# ⚠️ the verdict was right about the SEAT and wrong about what the seat owes
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4). and a ✋ that
#    cannot ever clear on this box is a red row on m.13's timer.
#
# ⇒ so the tier decides which contract applies, per the repo's own rule that
#   `local@unix` is the one tier with a human at a keyboard. the tier is read
#   from `src/grove.env.sh`, never re-derived here — one fact, one holder
#
# guarantee:
#   - exit 0 = this seat holds all four powers; its verdicts are trustworthy
#   - exit 1 = a power is absent on a seat that OWES it — a cloud grove's
#     ground seat. this seat's "absent" claims are unproven
#   - exit 2 = a power is absent on a LOCAL tier, where the absence is a fact
#     rather than a defect. no claim about a ground seat was proven
#   - READ ONLY — writes no state (rule.forbid.repair-plays)
#
# .note = cited by `git.grove.ready.verify`'s rung-4 fix-text and by
#         `howto.add-a-new-grove.md`. both promised it by name for weeks
#         while it did not exist, so the fix-text named a command that
#         could not run (rule.require.errors-name-the-fix). do not delete
#         it unless those two citations go with it.
######################################################################
set -uo pipefail

SEAT="$(id -un)"
FAILED=0
DECLINED=0

######################################################################
# the TIER, from the repo's own detector — never a second declaration
#
# ⚠️ a decline here, rather than a guess. a play that cannot learn which
#    contract applies cannot grade a seat against one
######################################################################
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ ! -r "$HERE/src/grove.env.sh" ]]; then
  echo "   ✋ no src/grove.env.sh at $HERE — the tier cannot be read" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$HERE/src/grove.env.sh"
if ! grove_env_derive >/dev/null 2>&1; then
  echo "   🌙 the server could not be derived on this box" >&2
  echo "      ⇒ so which contract this seat owes is unknown, and a grade" >&2
  echo "        against either would be a guess" >&2
  echo "      fix: name it — GROVE_ENV_SERVER=local@unix (a laptop) or" >&2
  echo "           cloud@aws.ec2 (a grove), then re-run" >&2
  exit 2
fi
TIER="$(grove_env_server_tier)"

######################################################################
# 🛑 .the grade — ONE holder for "what does an absent power mean here?"
#
#   `local@unix` is the one tier with a human at a keyboard, so a password gate
#   there is the box class's correct posture rather than a defect of the seat.
#   a cloud grove's ground seat OWES every power, so the same absence is a real
#   defect there.
#
# ⚠️ an UNKNOWN tier grades strictly. a tier this function cannot place must
#    never soften into a decline — that would trade a real ✋ for a quiet 🌙 on
#    exactly the box whose class was unreadable (`rule.forbid.failhide`)
######################################################################
_grade_absence() {   # $1 = tier → 'decline' | 'fail'
  case "$1" in
    local) echo "decline" ;;
    *)     echo "fail" ;;
  esac
}

# 🛑 the grade's own fixture. it is the one branch that parts exit 2 from exit
#    1, so a grade seen in only one direction is half proven
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, the corollary)
_grade_ok=1
[[ "$(_grade_absence local)" == "decline" ]] || _grade_ok=0
[[ "$(_grade_absence cloud)" == "fail"    ]] || _grade_ok=0
[[ "$(_grade_absence '')"    == "fail"    ]] || _grade_ok=0
if [[ "$_grade_ok" -ne 1 ]]; then
  echo "   🌙 the tier grade does not cut both ways" >&2
  echo "      ⇒ so no absence below can be scored. this proves no claim" >&2
  exit 2
fi

if [[ "$(_grade_absence "$TIER")" == "decline" ]]; then MARK="·"; else MARK="✋"; fi

# .what = score one absent power against the contract the tier names
_absent() {
  if [[ "$(_grade_absence "$TIER")" == "decline" ]]; then
    DECLINED=$(( DECLINED + 1 ))
  else
    FAILED=$(( FAILED + 1 ))
  fi
}

echo "🔬 prove.ground-seat-converges"
echo "   ├─ seat: $SEAT"
echo "   ├─ tier: $TIER  ($GROVE_ENV_SERVER)"
echo "   └─ the four powers a convergence needs"

# 1. identity — a seat with no name cannot own a file it writes
if [[ -n "$SEAT" ]] && id -u >/dev/null 2>&1; then
  echo "      ├─ ✔ identity    — uid $(id -u), gid $(id -g)"
else
  echo "      ├─ $MARK identity    — this seat has no resolvable uid"
  _absent
fi

# 2. passwordless root — THE discriminator between ground and camper.
#    a password prompt is as fatal as a refusal: a duct is tmux, so an
#    interactive prompt sits on the pane and EATS the next command sent
#    down it (rule.require.one-command-provision)
if sudo -n true 2>/dev/null; then
  echo "      ├─ ✔ sudo        — passwordless, so a system write can land"
else
  echo "      ├─ $MARK sudo        — absent or password-gated on this seat"
  if [[ "$(_grade_absence "$TIER")" == "decline" ]]; then
    echo "      │                  ⇒ correct for a local tier: a human types it"
  else
    echo "      │                  ⇒ every system bundle will claim, and each"
    echo "      │                    claim will read as 'the config is absent'"
  fi
  _absent
fi

# 3. apt — the package manager every provision bundle funnels through.
#    asked UNDER sudo, because that is how a bundle asks it
if sudo -n apt-get --version >/dev/null 2>&1; then
  echo "      ├─ ✔ apt         — reachable under sudo"
else
  echo "      ├─ $MARK apt         — not reachable under sudo on this seat"
  _absent
fi

# 4. systemd — a unit this box enables must have a live target to enable into
SYSTEMD_STATE="$(systemctl is-system-running 2>&1 || true)"
case "$SYSTEMD_STATE" in
  running|degraded)
    echo "      └─ ✔ systemd     — live ($SYSTEMD_STATE)" ;;
  *)
    echo "      └─ $MARK systemd     — not live ($SYSTEMD_STATE)"
    _absent ;;
esac

echo ""
if [[ "$FAILED" -eq 0 && "$DECLINED" -eq 0 ]]; then
  echo "🌲 seat '$SEAT' can converge — its verdicts are trustworthy ✔"
  exit 0
fi

if [[ "$FAILED" -gt 0 ]]; then
  echo "✋ seat '$SEAT' CANNOT converge — do not trust its 'absent' claims"
  echo ""
  echo "  why: a power above is absent on a '$TIER' tier, whose ground seat"
  echo "       OWES it. so every system bundle will claim, for a reason that"
  echo "       has no relation to the box's real state"
  echo "  fix: drive the provision from the seat that holds sudo —"
  echo "         rhx git.grove.push <grove>.ground --from . --into 'git/more/dev-env-setup' --mode apply"
  echo "       ground goes FIRST; the camper's bundles want what ground installs"
  exit 1
fi

######################################################################
# 🛑 a DECLINE — this play's subject is a GROVE's ground seat
#
#   its own usage line says so: `rhx git.grove.send <grove>.ground --play …`.
#   on a local tier the absences above are the box class's correct posture, so
#   there is no ground-seat claim to prove or to refute here
######################################################################
echo "🌙 seat '$SEAT' sits on a '$TIER' tier, so it owes no ground contract"
echo "   ├─ $DECLINED power(s) above are absent, and correctly so — a human"
echo "   │  at this keyboard types their password"
echo "   └─ ⇒ this play grades a GROVE's ground seat. aim it at one:"
echo "        rhx git.grove.send <grove>.ground --reply \\"
echo "          --play prove.ground-seat-converges"
exit 2
