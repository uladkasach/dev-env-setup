#!/usr/bin/env bash
######################################################################
# .what = prove `git.grove.rack.operations` reads a credential for an org
#         this checkout does NOT declare
#
# .why  🛑 keyrack scopes a NAMED-ORG read to the CHECKOUT it runs in
#
#   measured 2026-09-28, from the ahbode checkout:
#
#     ✋ ConstraintError: --org 'aether' does not match manifest org 'ahbode'
#        └─ hint: use an org under 'ahbode', or pass --org @all
#
#   ⇒ and `--org @all` is no substitute: it resolves a DIFFERENT slug
#     (`@all.camp.GITHUB_TOKEN`, never `aether.camp.AWS_PROFILE`)
#
#   the reach skills each read `AWS_PROFILE` for the grove's OWN org, so that
#   refusal is every grove whose org is not this checkout's. the scratch-gitroot
#   read is the way through, and this play is what proves it reaches
#
# 🛑 .why a PLAY and not a unit arm
#   the claim is about a LIVE rack — a manifest entry, an unlocked session, and
#   a vault this box can read. no fixture can hold those, and a fixture that
#   tried would prove obedience to its own author rather than reach
#   (`gotcha.a-check-that-cries-wolf-gets-silenced`, q10)
#
# 🛑 it PRINTS no secret and no account id — this repo is PUBLIC
#   a profile NAME is a name; its value is never echoed
#   (`rule.forbid.dox-in-public-repo`)
#
# ✔ .FIRST RUN: 2026-09-28 — all three arms held
#
#   and the run earned its keep at once: its FIRST roll reported a false ✋ on
#   arm 1, and the pattern was sound the whole time. the cause was arm 0's
#   SCOPE — see the 🛑 block above arm 0
#
#   ⇒ m.13's claim, measured on this very file: a check earns its keep by
#     RUNNING, never by a seat in a directory
#
# guarantee:
#   - exit 0 = the native read and the foreign read both answered
#   - exit 1 = the foreign read came back empty WHILE its session was live, so
#              the pattern does not reach — the one verdict about the subject
#   - exit 2 = no claim was proven, and never a pass (`rule.forbid.failhide`):
#              · no rack, or no native session — the subject is unreadable
#              · no FOREIGN session — this arm measured a lapsed session
#              · the rack holds no foreign-org row to contrast against
######################################################################
set -uo pipefail

echo "🔎 prove.rack-reads-a-foreign-org"
echo "   └─ subject: _rack_get, against an org this checkout does not declare"
echo ""

####################################################################
# 0. find the holder by a FILE IT HOLDS, never by how it ARRIVED
####################################################################
SRC=""
for cand in "$PWD" "$HOME/git/more/dev-env-setup"; do
  if [[ -f "$cand/.agent/repo=.this/role=any/skills/git.grove.rack.operations.sh" ]]; then
    SRC="$cand"
    break
  fi
done

if [[ -z "$SRC" ]]; then
  echo "   🌙 no checkout holds git.grove.rack.operations.sh — no claim to prove" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$SRC/.agent/repo=.this/role=any/skills/git.grove.rack.operations.sh"

####################################################################
# 1. what org does this checkout declare?
####################################################################
NATIVE="$(grep -m1 -E '^org:[[:space:]]*[^[:space:]]' "$SRC/.agent/keyrack.yml" 2>/dev/null \
          | sed -E 's/^org:[[:space:]]*//; s/[[:space:]]+$//')"

if [[ -z "$NATIVE" ]]; then
  echo "   🌙 this checkout's .agent/keyrack.yml declares no org — no contrast to draw" >&2
  exit 2
fi

echo "   ├─ this checkout declares org: $NATIVE"

####################################################################
# 2. pick a FOREIGN org off the live rack — never a hardcoded name
#
# ⚠️ a hardcoded 'aether' goes stale the day that org is retired, and its
#   staleness reads as a defect in the pattern. so the subject is DERIVED:
#   the first `*.camp.AWS_PROFILE` row whose org is not this checkout's
####################################################################
FOREIGN="$(rhx keyrack list --owner ehmpath 2>/dev/null \
           | grep -oE '[a-z0-9-]+\.camp\.AWS_PROFILE' \
           | sed -E 's/\.camp\.AWS_PROFILE//' \
           | grep -vx "$NATIVE" \
           | head -1)"

if [[ -z "$FOREIGN" ]]; then
  echo "   🌙 the rack holds no camp AWS_PROFILE row for a FOREIGN org" >&2
  echo "      ⇒ the contrast this play needs is absent on this box" >&2
  exit 2
fi

echo "   ├─ a foreign org on the rack: $FOREIGN"
echo ""

####################################################################
# 3. the native arm — it must read, and it proves THIS org's session is live
#
# 🛑 this arm is a discriminator for exit 2, and its SCOPE is one org
#   if the native read fails too, the rack is locked or absent and the foreign
#   read's silence says none of what this play asks about the pattern
#
# 🛑 .what it does NOT prove — measured 2026-09-28, on this play's first run
#   every sso session is scoped to ONE org, so a live `ahbode` session says not
#   one word about `aether`. this arm read the NATIVE org and arm 1 depended on
#   the FOREIGN one, so a lapsed aether session rendered:
#
#     ✔ arm 0 — native org 'ahbode' answers, so the session is live
#     ✋ arm 1 — foreign org 'aether' answers EMPTY
#        ⇒ the scratch-gitroot read did NOT reach, and every reach skill
#          aimed at a foreign-org grove will fail the same way
#
#   the pattern was sound the whole time. one `git.grove.rack.unlock --org
#   aether --env camp` later, all three arms held — so that ✋ condemned a
#   capability that served, and named a fix for a defect that did not exist
#   (`gotcha.a-check-that-cries-wolf-gets-silenced`, the false-✋ half)
#
#   ⇒ so arm 1's empty branch is THREE-valued, never two. it asks whether the
#     FOREIGN org's own session is live BEFORE it grades the pattern
####################################################################
FAILED=0

if _rack_get "$NATIVE" camp AWS_PROFILE >/dev/null 2>&1; then
  echo "   ✔ arm 0 — native org '$NATIVE' answers, so the session is live"
else
  echo "   🌙 arm 0 — native org '$NATIVE' answers EMPTY" >&2
  echo "      ⇒ the rack is locked or holds no entry, so the foreign arm below" >&2
  echo "        could not discriminate. no claim proven" >&2
  echo "      ⇒ rhx keyrack unlock --owner ehmpath --env camp --key AWS_PROFILE" >&2
  exit 2
fi

####################################################################
# 4. the foreign arm — THE CLAIM
####################################################################
GOT="$(_rack_get "$FOREIGN" camp AWS_PROFILE 2>/dev/null)"

if [[ -n "$GOT" ]]; then
  echo "   ✔ arm 1 — foreign org '$FOREIGN' answers a profile name"
  echo "      └─ the scratch gitroot carried a read this checkout refuses"
else
  # 🛑 an EMPTY foreign read has TWO causes, and they want opposite verdicts
  #   · the foreign org's own sso session lapsed → no claim proven (exit 2)
  #   · the session is live and the read still came back empty → a real
  #     defect in the pattern (exit 1)
  #
  #   ⇒ arm 0 cannot part them: it read the NATIVE org, and a session is
  #     scoped to one org. so ask the daemon which sessions it actually holds
  #
  # ⚠️ read the status into a VARIABLE and glob it — never `| grep -q`.
  #   `set -o pipefail` is on, and `grep -q` exits early, so the producer
  #   takes SIGPIPE and the pipeline reports non-zero on a MATCH
  #   (`gotcha.pipefail-grep-q`)
  RACK_STATUS="$(rhx keyrack status --owner ehmpath 2>/dev/null || true)"

  if [[ "$RACK_STATUS" != *"$FOREIGN.camp.AWS_PROFILE"* ]]; then
    echo "   🌙 arm 1 — foreign org '$FOREIGN' answers EMPTY, and its session is NOT live" >&2
    echo "      ⇒ the daemon holds no '$FOREIGN.camp.AWS_PROFILE', so this arm" >&2
    echo "        measured a lapsed session rather than the pattern. no claim proven" >&2
    echo "      ⇒ unlock it, then run this play again —" >&2
    echo "        rhx git.grove.rack.unlock --org $FOREIGN --env camp --key AWS_PROFILE" >&2
    exit 2
  fi

  FAILED=1
  echo "   ✋ arm 1 — foreign org '$FOREIGN' answers EMPTY, and its session IS live" >&2
  echo "      ⇒ the daemon holds '$FOREIGN.camp.AWS_PROFILE', so a lapsed session" >&2
  echo "        is ruled out — the scratch-gitroot read did NOT reach" >&2
  echo "      ⇒ every reach skill aimed at a foreign-org grove will fail the same way" >&2
  echo "      ⇒ read the rack before you judge the pattern:" >&2
  echo "        rhx keyrack list --owner ehmpath" >&2
fi

####################################################################
# 5. the plain-read arm — it must REFUSE, or arm 1 proved no new reach
#
# 🛑 a check seen to pass in one direction is half proven. if the PLAIN read
#   of the foreign org also answered, the scratch gitroot bought no capability
#   and this play has been green over a claim nobody needed
#   (`gotcha.a-check-that-cries-wolf-gets-silenced`, the corollary)
####################################################################
PLAIN="$(env -C "$SRC" rhx keyrack get --owner ehmpath \
           --org "$FOREIGN" --env camp --key AWS_PROFILE --value 2>/dev/null)"

if [[ -z "$PLAIN" ]]; then
  echo "   ✔ arm 2 — the PLAIN read of '$FOREIGN' refuses from this checkout"
  echo "      └─ so arm 1's pass is a capability the gitroot bought"
else
  FAILED=1
  echo "   ✋ arm 2 — the PLAIN read of '$FOREIGN' ANSWERED from this checkout" >&2
  echo "      ⇒ keyrack no longer scopes a named-org read to the checkout, so" >&2
  echo "        the scratch gitroot buys no capability and this holder is dead" >&2
  echo "        weight. retire it, and the five bundles that carry the pattern" >&2
  echo "        (term=keyrack.gitroot)" >&2
fi

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 the rack reaches a foreign org, and only through the gitroot ✔"
  exit 0
fi
echo "✋ prove.rack-reads-a-foreign-org found a defect" >&2
exit 1
