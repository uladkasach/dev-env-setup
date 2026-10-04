#!/usr/bin/env bash
######################################################################
# prove: no two groves may claim one local port — and a SEAT of one box may
#
# .what = three arms over `git.grove.wake`'s declared-state port guard:
#
#           0. two entries, two exids, ONE port      → the wake must HALT
#           1. two entries, ONE exid,  ONE port      → it must NOT halt
#           2. two entries, two exids, two ports     → it must NOT halt
#
#         arm 0 is the bite. arms 1 and 2 are the two false positives that
#         would make the guard unusable, and each is a real arrangement:
#         arm 1 is `<grove>.ground`, which this repo PRESCRIBES.
#
# 🛑 .why a guard needs a probe at all, and prose will not serve
#
#    `rule.require.seam-claims-have-an-owner` asks for a deliberate break, and
#    `gotcha.a-check-that-cries-wolf-gets-silenced` states the other half: a
#    check proven in one direction only is half proven. a port guard is exactly
#    the shape that decays — it is silent on every healthy box, so the day its
#    reader goes wrong, no run says so.
#
# 🛑 .why the exid exemption is load-bear, and not a convenience
#
#    `howto.add-a-new-grove` (`.register a second seat`) declares that a second
#    seat of one box RIDES ONE TUNNEL. so a guard that discriminated on NAME
#    would halt on the arrangement the repo tells a human to create — a correct
#    reader over the wrong key (`gotcha.a-check-that-cries-wolf-gets-silenced`,
#    m.6). arm 1 is what keeps that key honest.
#
# 📜 .measured 2026-09-27 — the defect this guard was written from
#
#    three registry entries sat on :36901 at once. a wake printed `duct [SET]`,
#    wrote its own Host block, and every later `send` aimed at either of the
#    other two would have landed on THIS box. the extant guard at
#    `git.grove.wake:483` never ran — it reads a LIVE duct's far end, and a
#    claimed-but-idle port reads as free.
#
#    ⇒ so the two guards are PEERS and neither subsumes the other:
#
#      | guard        | reads    | blind to                        |
#      | :483         | LIVE     | a port claimed by an idle entry |
#      | the one here | DECLARED | a duct aimed off-registry       |
#
#      one fact, two stores (`rule.require.judge-declared-state-not-live-state`;
#      `gotcha.a-check-that-cries-wolf-gets-silenced`, q13).
#
# guarantee:
#   - HERMETIC. every arm runs against a `mktemp -d` fixture handed to the skill
#     as `GIT_FOREST_DIR`, so a human's own `~/.git.forest` is never read and
#     never written (`rule.require.hermetic-tests`)
#   - the fixture is removed on a trap, so a cut run leaves no registry behind
#   - NO wire, NO credential, NO box. the guard sits ahead of every aws call by
#     construction — that placement is itself part of what arm 3 proves
#   - every probe is BOUNDED and stdin-closed
#     (`rule.require.bounded-probes-in-verifies`)
#
# ⚠️ .what arms 1 and 2 can and cannot claim
#    past the guard, a wake reaches the credential source and halts there, since
#    the fixture names an env no rack declares. so those arms assert the ABSENCE
#    of the port halt, never a successful wake — the later halt IS the evidence
#    the guard let the run through. an arm that demanded exit 0 would need a live
#    box, and a probe that needs a box is a probe nobody runs.
#
# usage:
#   rhx play.run --play prove.grove-ports-are-claimed-once
######################################################################
set -uo pipefail

FAILED=0
_fail() { FAILED=1; }

_self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || _self=""
if   [[ -n "$_self" && -d "$_self/.agent" ]]; then _root="$_self"
elif [[ -d "$PWD/.agent" ]];                  then _root="$PWD"
else                                                _root="$HOME/git/more/dev-env-setup"
fi

_skill="$_root/.agent/repo=.this/role=any/skills/git.grove.wake.sh"

echo ""
echo "🐢 prove: one local port, one grove — a seat of one box excepted"
echo "   └─ root : $_root"
echo ""

if [[ ! -f "$_skill" ]]; then
  echo "   ✋ git.grove.wake.sh is absent at $_skill" >&2
  echo "      ⇒ this play drives the skill itself, so with the skill out of" >&2
  echo "        reach it can grade no claim at all" >&2
  echo ""
  echo "🐚 prove: 1 blocker (the skill is out of reach)"
  exit 1
fi

######################################################################
# the fixture — a registry of our own, handed over as GIT_FOREST_DIR
#
# ⚠️ a fixture per ARM, never one reused: an arm that inherits a neighbour's
#    entries grades a world nobody declared
#    (`gotcha.a-check-that-cries-wolf-gets-silenced`, q5)
######################################################################
_fixture_root="$(mktemp -d)"
trap 'rm -rf "$_fixture_root"' EXIT

# writes one grove entry. every field the skill reads is named, so no arm
# leans on a default this play cannot see
_entry_set() {
  local dir="$1" name="$2" port="$3" exid="$4"
  mkdir -p "$dir/groves"
  cat > "$dir/groves/$name.json" <<JSON
{
  "name": "$name",
  "sshAlias": "$name",
  "user": "camper",
  "host": "localhost",
  "port": $port,
  "exid": "$exid",
  "env": "prove-no-such-env",
  "account": "000000000000",
  "nat": null,
  "type": "ec2",
  "status": "active",
  "addedAt": 1790531014
}
JSON
}

# drives the skill against one fixture and echoes both streams together.
# BOUNDED and stdin-closed: a wake that reached a prompt would otherwise hold
# this run, and a play that hangs is a play that gets silenced
_wake_says() {
  local dir="$1" grove="$2"
  GIT_FOREST_DIR="$dir" timeout -k 5 60 bash "$_skill" "$grove" </dev/null 2>&1
}

# the one sentence arm 0 must produce and arms 1 and 2 must not
_HALT='is already claimed by another grove'

######################################################################
echo "   arm 0 — two exids on one port: the wake HALTS"
#
# the bite. two boxes, one port. a wake here would bind the tunnel and write
# this grove's ssh alias over the other's, so every later send aimed at the
# neighbour lands on this box
######################################################################
_d0="$_fixture_root/arm0"
_entry_set "$_d0" "prove-grove-alpha" 36901 "prove-grove-alpha"
_entry_set "$_d0" "prove-grove-beta"  36901 "prove-grove-beta"

_out0="$(_wake_says "$_d0" "prove-grove-beta")"
_rc0=$?

if [[ "$_rc0" -eq 2 ]] && grep -q "$_HALT" <<< "$_out0"; then
  echo "      ✔ halted (exit 2) and named the claimant"
  if grep -q 'prove-grove-alpha' <<< "$_out0"; then
    echo "      ✔ the halt names WHICH grove holds the port"
  else
    echo "      ✋ the halt fired and did not name the claimant" >&2
    echo "         ⇒ a human cannot act on 'some other grove has it'; the" >&2
    echo "           whole remedy is to know which entry to re-port" >&2
    _fail
  fi
elif [[ "$_rc0" -eq 2 ]]; then
  echo "      ✋ exited 2 for some OTHER reason — the port halt never fired" >&2
  echo "         ⇒ the guard is blind to a declared collision, which is the" >&2
  echo "           one state it exists to catch" >&2
  echo "         got: $_out0" >&2
  _fail
else
  echo "      ✋ did NOT halt (exit $_rc0)" >&2
  echo "         ⇒ two groves may claim one port, so a send aimed at one" >&2
  echo "           lands on the other, silently" >&2
  echo "         got: $_out0" >&2
  _fail
fi
echo ""

######################################################################
echo "   arm 1 — ONE exid on one port: a SEAT, so it does NOT halt"
#
# `<grove>.ground` is the arrangement `howto.add-a-new-grove` prescribes: a
# second seat of one box, which rides the one tunnel. a guard keyed on NAME
# halts here, and a guard keyed on EXID does not
######################################################################
_d1="$_fixture_root/arm1"
_entry_set "$_d1" "prove-grove-alpha"        36901 "prove-grove-alpha"
_entry_set "$_d1" "prove-grove-alpha.ground" 36901 "prove-grove-alpha"

_out1="$(_wake_says "$_d1" "prove-grove-alpha.ground")"

if grep -q "$_HALT" <<< "$_out1"; then
  echo "      ✋ halted on a SEAT of the same box" >&2
  echo "         ⇒ the guard reads the NAME where it must read the exid, so it" >&2
  echo "           refuses the second-seat arrangement this repo prescribes" >&2
  echo "         got: $_out1" >&2
  _fail
else
  echo "      ✔ no port halt — a shared exid rides one tunnel"
fi
echo ""

######################################################################
echo "   arm 2 — two exids, two ports: no collision, so no halt"
#
# the ordinary healthy shape. a guard that only ever met arm 0 could be served
# by one that halts unconditionally
######################################################################
_d2="$_fixture_root/arm2"
_entry_set "$_d2" "prove-grove-alpha" 36901 "prove-grove-alpha"
_entry_set "$_d2" "prove-grove-beta"  36911 "prove-grove-beta"

_out2="$(_wake_says "$_d2" "prove-grove-beta")"

if grep -q "$_HALT" <<< "$_out2"; then
  echo "      ✋ halted where the two ports DIFFER" >&2
  echo "         ⇒ the guard halts unconditionally, so it refuses every wake" >&2
  echo "           on any box that holds a second grove" >&2
  echo "         got: $_out2" >&2
  _fail
else
  echo "      ✔ no port halt — distinct ports, distinct claims"
fi
echo ""

######################################################################
echo "   arm 3 — the halt lands BEFORE any aws call"
#
# 🛑 the placement claim, and it is a real one rather than tidiness: a halt
#    printed after the box read has already resumed an instance a human pays
#    for by the hour, and then declined to use it. arm 0's own output is the
#    evidence — the wake's header and its `account:` row sit downstream of the
#    guard, so neither may appear
######################################################################
_leaked=""
grep -q 'heres the wave' <<< "$_out0" && _leaked="the wake header"
grep -q 'account:'       <<< "$_out0" && _leaked="${_leaked:+$_leaked, }the account read"

if [[ -z "$_leaked" ]]; then
  echo "      ✔ the halt printed no downstream row — it fired ahead of them"
else
  echo "      ✋ the halt fired AFTER: $_leaked" >&2
  echo "         ⇒ the guard sits below work it means to decline, so a human" >&2
  echo "           pays for a resumed box the same run then refuses" >&2
  _fail
fi
echo ""

######################################################################
# the verdict
######################################################################
if [[ "$FAILED" == 0 ]]; then
  echo "🌲 one local port, one grove — and a seat of one box is exempt ✔"
  exit 0
fi
echo "✋ the port claim is not held" >&2
echo "   ⇒ two groves on one port means a send, push, or provision aimed at" >&2
echo "     one of them lands on the other, while every row stays green" >&2
exit 1
