#!/usr/bin/env bash
######################################################################
# .what = call each new skill with a value flag as its LAST word, and fail
#         unless each refuses at once, exit 2, with the flag named
#
# .why  = `shift 2` with one arg left shifts naught and returns non-zero, so a
#         parser loop of `--flag) x="$2"; shift 2 ;;` reads the same flag forever.
#         the call looks valid, prints naught, and never ends. each skill now
#         refuses a bare value flag before its `case`; this proves every one does,
#         and a timeout names a hang as a hang
#
# guarantee:
#   - HERMETIC: a temp HOME and a temp git repo as cwd; no network, no grove
#   - each call is bounded (`timeout -k 2 10`), so a regressed parser fails
#     this play in seconds rather than hold it
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILLS="$HERE/.agent/repo=.this/role=any/skills"

home="$(mktemp -d)"
repo="$(mktemp -d)"
trap 'rm -rf "$home" "$repo"' EXIT
git -C "$repo" init -q
# git.grove.sync runs the INSTALLED aliases: give the temp home this checkout's copy
cp "$HERE/src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh" "$home/.bash_aliases"

failed=0
transcript=""
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }

echo "🌲 prove.value-flags-refuse-when-bare"

# one case — $1 = skill · then its args, the last a value flag with no value
case_bare() {
  local skill="$1" out rc label
  shift
  label="$skill ${*}"
  out="$(cd "$repo" && env HOME="$home" timeout -k 2 10 bash "$SKILLS/$skill.sh" "$@" </dev/null 2>&1)" && rc=0 || rc=$?
  transcript+=$'\n'"## $label"$'\n'"rc=$rc"$'\n'"$out"$'\n'
  if [[ "$rc" -eq 124 || "$rc" -eq 137 ]]; then fail "$label → hung (rc=$rc): the parser loops on a bare flag"; return 1; fi
  if [[ "$rc" -ne 2 ]]; then fail "$label → rc=$rc, expected 2"; return 1; fi
  if [[ "$out" != *"${*: -1}"* ]]; then fail "$label → its refusal does not name ${*: -1}"; return 1; fi
  echo "   • $label → refused, rc=2 ✔"
}

case_bare git.tree.aside        set --tag
case_bare git.tree.aside        set --tag x --path
case_bare file.exec.set         --path
case_bare brains.auth.reset.probe --node
case_bare brains.auth.reset.probe --kind
case_bare brains.auth.reset.probe --from
case_bare grove.backup.get      --from
case_bare grove.backup.get      --skill
case_bare grove.backup.restore  --from
case_bare grove.backup.restore  --from grove-1 --of
case_bare grove.backup.restore  --from grove-1 --of a/b --tree
case_bare grove.backup.restore  --from grove-1 --home
case_bare grove.backup.restore  --from grove-1 --orphan
case_bare grove.backup.restore  --from grove-1 --of a/b --setaside
case_bare grove.backup.restore  --from grove-1 --home .claude --into
case_bare git.grove.play.stop   grove-1 --play
case_bare git.grove.play.stop   grove-1 --play x --scratch
case_bare git.grove.sync        --mode
case_bare aws.reach.set         --org ahbode --env test --gitroot
case_bare aws.reach.del         --org ahbode --env test --gitroot
case_bare play.run              --all --family
case_bare play.run              --within

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.value-flags-refuse-when-bare.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"
