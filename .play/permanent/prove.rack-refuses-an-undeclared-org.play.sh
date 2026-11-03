#!/usr/bin/env bash
######################################################################
# .what = prove `grove_provision_5_12_rack_declare_org` refuses an org with no
#         declared rack table, loud, and writes no scratch keyrack.yml for it
#
# .why  = the refusal is the clamp on a silent defect: a `for` over the bare
#         `_declared` substitution lost its rc, so an undeclared org wrote
#         `org: <name>` with no envs, and every later read answered empty
#   - four callers lean on it: 5.12 upsert and verify, 5.13 upsert and verify
#   - revert the `if ! envs=…` guard and the undeclared row here goes red
#
# guarantee:
#   - hermetic: a mktemp gitroot, removed on exit; it sources one file
#   - exit 0 = every claim held · exit 1 = a claim failed
#   - exit 2 = the subject could not be read, so no claim was proven
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SUBJECT="$HERE/src/grove.provision/5.devtools/5.12.rack/_.sh"
[[ -r "$SUBJECT" ]] || {
  echo "✋ ConstraintError: the subject 5.12.rack/_.sh is absent from $HERE" >&2
  exit 2
}
# shellcheck source=/dev/null
source "$SUBJECT"
declare -F grove_provision_5_12_rack_declare_org >/dev/null || {
  echo "💥 MalfunctionError: 5.12.rack/_.sh defines no grove_provision_5_12_rack_declare_org" >&2
  exit 1
}

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT

failed=0
transcript=""
say() { echo "$1"; transcript+="$1"$'\n'; }
cry() { echo "$1" >&2; transcript+="$1"$'\n'; }

say "🌲 prove.rack-refuses-an-undeclared-org"

# one row — declare an org under a grove's own org, then read rc, words, and the file
# $1 = label · $2 = GROVE_ORG · $3 = org asked · $4 = rc wanted · $5 = file wanted (yes|no)
row() {
  local label="$1" own="$2" org="$3" want_rc="$4" want_file="$5" gitroot out rc=0 file=no body=""
  gitroot="$fixture/$org"
  out="$(GROVE_ORG="$own" grove_provision_5_12_rack_declare_org "$gitroot" "$org" 2>&1)" || rc=$?
  [[ -f "$gitroot/.agent/keyrack.yml" ]] && { file=yes; body="$(cat "$gitroot/.agent/keyrack.yml")"; }

  # the last row closes the trunk with └─, and its children hang from blank space
  local head="├─" stem="│"
  [[ "${ROW_LAST:-}" == 1 ]] && { head="└─"; stem=" "; }
  say "   $head $label"
  say "   $stem  ├─ GROVE_ORG=${own:-<unset>} · org=$org"
  say "   $stem  ├─ rc=$rc · keyrack.yml written: $file"
  [[ -n "$out" ]] && while IFS= read -r line; do say "   $stem  │  ${line//$fixture/<fixture>}"; done <<< "$out"
  [[ -n "$body" ]] && while IFS= read -r line; do
    [[ "$line" == \#* ]] || say "   $stem  │  yml: $line"
  done <<< "$body"

  if [[ "$rc" -eq "$want_rc" && "$file" == "$want_file" ]]; then
    say "   $stem  └─ ✔"
  else
    cry "   $stem  └─ 💥 MalfunctionError: wanted rc=$want_rc and a written file: $want_file"
    failed=1
  fi
  [[ "${ROW_LAST:-}" == 1 ]] || say "   │"
}

row "an undeclared org, not this grove's own → ✋, no file"  aether  nobody  1 no
row "a declared org → writes org + its envs"                aether  aether  0 yes
ROW_LAST=1 row "this grove's own org, with no table → camp only" newco newco 0 yes

# the undeclared row must name the class and the fix, never print a bare symptom
[[ "$transcript" == *"✋ ConstraintError: org 'nobody' has no declared rack table"* ]] \
  || { cry "   💥 MalfunctionError: the undeclared row never named its ConstraintError"; failed=1; }
[[ "$transcript" == *"fix: declare the org's envs"* ]] \
  || { cry "   💥 MalfunctionError: the undeclared row never named its fix"; failed=1; }

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.rack-refuses-an-undeclared-org.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"
