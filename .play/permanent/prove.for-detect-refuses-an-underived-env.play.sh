#!/usr/bin/env bash
######################################################################
# .what = drive `grove_for_detect` through all three of its arms, each cloud
#         platform through the cloud arm, and the UNDERIVED case through a
#         derivation that halts
#
# 🛑 .why the `*)` arm needs a clamp no real box can give it
#   - a real box answers `cloud@*` or `local@*`, so it never reaches `*)`
#   - a wrong default is invisible on every box this repo runs on
#   - it surfaces only where a play sources `grove.for.sh` alone
#   - that is the rarest path, and the one with the least attention on it
#
# 📜 2026-09-03: the arm read `echo "local"`, with the comment *"the same
#    last resort the derivation takes"* — `grove_env_derive` takes no last
#    resort at all, it halts. the comment cited a deleted mechanism, and the
#    code beneath it was the failhide that deletion existed to remove.
#
# guarantee:
#   - READ-ONLY. it sources one file and sets a variable in its own shell
#   - each arm's answer joins a transcript, snapped beside this play
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# the subject must be present, or every refusal arm would pass on an absent function
[[ -r "$HERE/src/grove.for.sh" ]] || {
  echo "✋ ConstraintError: the subject src/grove.for.sh is absent from $HERE" >&2
  exit 2
}
# shellcheck source=/dev/null
source "$HERE/src/grove.for.sh"
declare -F grove_for_detect grove_for_valid >/dev/null || {
  echo "💥 MalfunctionError: src/grove.for.sh defines no grove_for_detect or grove_for_valid" >&2
  exit 1
}

failed=0
transcript=""

# every line this play prints goes through say (stdout) or cry (stderr), and
#   joins the transcript — so a reworded verdict or error surfaces as a snap diff
say() { echo "$1"; transcript+="$1"$'\n'; }
cry() { echo "$1" >&2; transcript+="$1"$'\n'; }

say "🌲 prove.for-detect-refuses-an-underived-env"

# one arm — detect under a server value, compare the answer, record it
# $1 = GROVE_ENV_SERVER ('' = unset) · $2 = answer wanted ('' = refused)
#   · $3 = what `grove_env_derive` does when the server is unset (halt|<server>)
# every line opens with the same two padded inputs, so the `→` column aligns and
#   the snap reads as a table: what went in, what came out
arm() {
  local got rc derive_to="${3:-}" label
  label="$(printf 'server=%-22s derive=%-22s' "${1:-(unset)}" "${derive_to:--}")"
  got="$(
    unset GROVE_ENV_SERVER
    [[ -n "$1" ]] && export GROVE_ENV_SERVER="$1"
    # the derivation is stubbed: on THIS laptop the real one answers local@unix.
    #   the stub reads derive_to as data, never as code
    if [[ "$derive_to" == halt ]]; then
      grove_env_derive() { return 2; }
    elif [[ -n "$derive_to" ]]; then
      grove_env_derive() { export GROVE_ENV_SERVER="$derive_to"; }
    fi
    grove_for_detect
  )" && rc=0 || rc=$?

  # a wanted answer must come back with rc=0; a refusal must come back empty, non-zero
  if [[ -n "$2" && "$got" == "$2" && "$rc" -eq 0 ]]; then
    say "   • $label → '$got', rc=0 ✔"
    return 0
  fi
  if [[ -z "$2" && -z "$got" && "$rc" -ne 0 ]]; then
    say "   • $label → '', rc=$rc ✔"
    return 0
  fi
  cry "   💥 MalfunctionError: $label → '$got', rc=$rc — expected '${2}'"
  [[ -z "$2" ]] && cry "      ⇒ a guess here is rule.forbid.failhide: the run reports success"
  [[ -z "$2" ]] && cry "        and hands back the tier that means 'a human is at a keyboard'"
  failed=1
  return 1
}

# arms 1 and 1b — each cloud platform. a hetzner grove that read 'local' would
#   take the MEMBER join meant for a human's laptop (`5.23.tailscale`, #174)
arm "cloud@aws.ec2"          cloud
arm "cloud@hetzner.hetzbot"  cloud

# arm 2 — a local tier
arm "local@unix"             local

####################################################################
# .what = arm 3 — the one this probe exists for
#
# 🛑 .why an UNDERIVED environment must answer EMPTY, never 'local'
#   - `grove_env_derive` refuses to guess a platform; it halts instead
#   - a guess here would reinstate the very default it refuses
#   - 'local' is the dangerous half: every gate reads it as "a human is here"
#
# .two shapes reach the `*)` arm
#   - a malformed value, on any box
#   - an unset value whose derivation halts — stubbed, since the real one
#     answers `local@unix` on this laptop
####################################################################
arm "notatier"  ""     ""                       # a malformed value
arm ""          ""     halt                     # unset, and the derivation halts
arm ""          cloud  cloud@hetzner.hetzbot    # unset, and the derivation names hetzner

# and the caller's own gate must reject that empty answer — called once, and its
#   line takes the arms' shape: input, arrow, answer, rc
valid_rc=0
valid_out="$(grove_for_valid "" 2>&1)" || valid_rc=$?
valid_label="$(printf 'grove_for_valid %-43s' "''")"
# the gate's own words join the transcript, so a reworded rejection is a snap diff
[[ -n "$valid_out" ]] && while IFS= read -r line; do say "     $line"; done <<< "$valid_out"
[[ "$valid_rc" -ne 0 ]] && say "   • $valid_label → rejected, rc=$valid_rc ✔"
[[ "$valid_rc" -eq 0 ]] && { cry "   💥 MalfunctionError: $valid_label → accepted, rc=0 — expected rejected"; failed=1; }

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.for-detect-refuses-an-underived-env.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"
