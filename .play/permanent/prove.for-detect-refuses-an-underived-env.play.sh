#!/usr/bin/env bash
######################################################################
# .what = drive `grove_for_detect` through all three of its arms
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
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$HERE/src/grove.for.sh"

failed=0

echo "🌲 prove.for-detect-refuses-an-underived-env"

# arm 1 — a cloud tier
GROVE_ENV_SERVER="cloud@aws.ec2"
got="$(grove_for_detect)" && rc=0 || rc=$?
if [[ "$got" == "cloud" && "$rc" -eq 0 ]]; then
  echo "   • cloud@aws.ec2 → 'cloud', rc=0 ✔"
else
  echo "   ✋ cloud@aws.ec2 → '$got', rc=$rc — expected 'cloud', rc=0" >&2
  failed=1
fi

# arm 2 — a local tier
GROVE_ENV_SERVER="local@unix"
got="$(grove_for_detect)" && rc=0 || rc=$?
if [[ "$got" == "local" && "$rc" -eq 0 ]]; then
  echo "   • local@unix → 'local', rc=0 ✔"
else
  echo "   ✋ local@unix → '$got', rc=$rc — expected 'local', rc=0" >&2
  failed=1
fi

####################################################################
# .what = arm 3 — the one this probe exists for
#
# 🛑 .why an UNDERIVED environment must answer EMPTY, never 'local'
#   - `grove_env_derive` refuses to guess a platform; it halts instead
#   - a guess here would reinstate the very default it refuses
#   - 'local' is the dangerous half: every gate reads it as "a human is here"
#
# .why `GROVE_ENV_SERVER=x` and not empty
#   - an empty value makes `grove_for_detect` call `grove_env_derive`
#   - on THIS laptop that answers `local@unix` correctly
#   - the empty case never reaches the `*)` arm here
#   - a malformed value reaches it on any box
####################################################################
GROVE_ENV_SERVER="notatier"
got="$(grove_for_detect)" && rc=0 || rc=$?
if [[ -z "$got" && "$rc" -ne 0 ]]; then
  echo "   • a malformed server → empty, rc=$rc ✔"
else
  echo "   ✋ a malformed server → '$got', rc=$rc — expected empty and non-zero" >&2
  echo "      ⇒ a guess here is rule.forbid.failhide: the run reports success" >&2
  echo "        and hands back the tier that means 'a human is at a keyboard'" >&2
  failed=1
fi

# and the caller's own gate must reject that empty answer
if grove_for_valid ""; then
  echo "   ✋ grove_for_valid accepted an empty --for" >&2
  failed=1
else
  echo "   • grove_for_valid rejects the empty answer ✔"
fi

[[ "$failed" -eq 0 ]] && echo "🌲 all four claims held ✔"
exit "$failed"
