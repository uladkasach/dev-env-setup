#!/usr/bin/env bash
######################################################################
# .what = prove the real npm registry serves the role packages `5.18.openhours`
#         pins, at the declared versions, and refuses a version it lacks
#
# .why this play exists
#   - `prove.openhours-renders-each-claim` stubs `web_pnpm`, so its arms agree with
#     themselves and the registry contract goes unproven: a yanked or renamed pin
#     would fail every opted-in apply while the suite stayed green
#   - this play calls the real `web_pnpm add`, over the real wire, at the declared pins
#
# .the arms — each install lands in a private temp cwd, never the box's own openhours cwd
#   - R1. every pinned package installs, and each node_modules/<name> reads its declared version
#   - R2. a version the registry lacks fails loud, and leaves no node_modules/<name> for it
#
# .the snaps — pnpm's own progress lines vary by run (durations, counts, cache hits), so
#   each arm snaps the verdict it grades: the name, the declared and installed version,
#   and for R2 the refusal and the absent dir — never pnpm's error code, which pnpm owns
#   and may rename while the refusal still holds
#
# usage:
#   rhx play.run --play prove.openhours-role-packages-install-at-the-pin
#
# exit:
#   0 = every arm holds
#   1 = an arm failed
#   2 = no checkout, a source failed, no pnpm, or the registry is unreachable — no claim graded
######################################################################

set -uo pipefail

# .what = the checkout under proof — `PROVE_ROOT` (the red half), this play's own, or the cwd
_root_of() {
  [[ -n "${PROVE_ROOT:-}" ]] && { printf '%s' "$PROVE_ROOT"; return 0; }
  local self; self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
  [[ -n "$self" && -f "$self/src/grove.provision._.sh" ]] && { printf '%s' "$self"; return 0; }
  [[ -f "$PWD/src/grove.provision._.sh" ]] && { printf '%s' "$PWD"; return 0; }
  return 1
}
_root="$(_root_of)" || { echo "   ✋ ConstraintError: no checkout found" >&2; exit 2; }

export GROVE_SRC="$_root/src"

echo "🔎 prove.openhours-role-packages-install-at-the-pin"
echo "   └─ root: $_root"
echo ""

# shellcheck source=/dev/null
source "$GROVE_SRC/grove.web.sh" || { echo "   ✋ ConstraintError: could not source grove.web.sh" >&2; exit 2; }
# shellcheck source=/dev/null
source "$GROVE_SRC/grove.provision/5.devtools/5.18.openhours/_.sh" \
  || { echo "   ✋ ConstraintError: could not source 5.18.openhours/_.sh" >&2; exit 2; }
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"

# the pins are the bundle's own declaration, never a copy here
[[ "${#GROVE_OPENHOURS_ROLE_PKGS[@]}" -gt 0 ]] \
  || { echo "   💥 MalfunctionError: 5.18.openhours declares no role packages — no pin to grade" >&2; exit 1; }

command -v pnpm >/dev/null 2>&1 || {
  echo "   ✋ ConstraintError: no pnpm on this box, so the registry cannot be asked — no claim graded" >&2
  echo "      fix: rhx grove.provision --what 5.1.node --mode apply" >&2
  exit 2
}
command -v jq >/dev/null 2>&1 || {
  echo "   ✋ ConstraintError: no jq on this box, so no installed version can be read — no claim graded" >&2
  exit 2
}

FIX="$(web_tempdir prove-openhours-pkgs)" || { echo "   ✋ ConstraintError: no temp dir for the installs — no claim graded" >&2; exit 2; }
trap 'rm -rf "$FIX"' EXIT

# the wire first: a registry that does not answer grades no claim, so it declines rather than fails
_first="${GROVE_OPENHOURS_ROLE_PKGS[0]%@*}"
timeout -k 5 60 pnpm view "$_first" name </dev/null >/dev/null 2>&1 || {
  echo "   ✋ ConstraintError: the npm registry did not answer a bounded \`pnpm view $_first\` — no claim graded" >&2
  exit 2
}

# .what = a throwaway cwd with its own package.json, so `pnpm add` never walks up to a parent
_cwd() {
  mkdir -p "$1" || return 1
  printf '{\n  "name": "prove-openhours-pkgs",\n  "private": true\n}\n' > "$1/package.json"
}

failed=0

######################################################################
# R1. every pinned package installs at its declared version
######################################################################
_arm_install() {
  local dir="$FIX/r1" out rc spec name want have rendered="" bad=0
  _cwd "$dir" || { echo "   ├─ R1: could not make $dir" >&2; return 1; }
  out="$( cd "$dir" && web_pnpm add "${GROVE_OPENHOURS_ROLE_PKGS[@]}" 2>&1 )"; rc=$?
  for spec in "${GROVE_OPENHOURS_ROLE_PKGS[@]}"; do
    name="${spec%@*}"
    want="${spec##*@}"
    have="$(jq -r '.version // empty' "$dir/node_modules/$name/package.json" 2>/dev/null)"
    [[ "$have" == "$want" ]] || bad=1
    # the snap names each package and its verdict, never the version: a routine bump changes no claim
    rendered+="   • $name: installed at its declared version ✔"$'\n'
  done
  if [[ "$rc" -eq 0 && "$bad" -eq 0 ]]; then
    play_snap_assert arm=R1 rendered="${rendered%$'\n'}" mask="$FIX" || return 1
    echo "   ├─ R1. every pinned role package installs at its declared version ✔"
    return 0
  fi
  echo "   ├─ R1: rc=$rc" >&2
  for spec in "${GROVE_OPENHOURS_ROLE_PKGS[@]}"; do
    name="${spec%@*}"
    echo "   │  • $name: declared ${spec##*@}, installed $(jq -r '.version // "absent"' "$dir/node_modules/$name/package.json" 2>/dev/null || echo absent)" >&2
  done
  printf '%s\n' "$out" | tail -n 20 | sed 's/^/   │     /' >&2
  return 1
}
_arm_install || failed=$(( failed + 1 ))

######################################################################
# R2. a version the registry lacks fails loud, and installs no stand-in
######################################################################
_arm_absent() {
  local dir="$FIX/r2" name="$_first" out rc
  local spec="$name@0.0.0-prove-absent"
  _cwd "$dir" || { echo "   ├─ R2: could not make $dir" >&2; return 1; }
  out="$( cd "$dir" && web_pnpm add "$spec" 2>&1 )"; rc=$?
  if [[ "$rc" -ne 0 && ! -e "$dir/node_modules/$name" ]]; then
    echo "   ├─ R2. a version the registry lacks fails loud, and installs no stand-in ✔"
    play_snap_assert arm=R2 rendered="$(printf '%s\n' \
      "   • asked: $spec" \
      "   • refused: rc nonzero ✔" \
      "   • node_modules/$name: absent ✔")" mask="$FIX" || return 1
    return 0
  fi
  echo "   ├─ R2: rc=$rc, node_modules/$name: $([[ -e "$dir/node_modules/$name" ]] && echo present || echo absent)" >&2
  printf '%s\n' "$out" | tail -n 20 | sed 's/^/   │     /' >&2
  return 1
}
_arm_absent || failed=$(( failed + 1 ))

echo ""
[[ "$failed" -eq 0 ]] || { echo "   💥 MalfunctionError: $failed arm(s) failed" >&2; exit 1; }
echo "🌲 the registry serves each openhours role package at its pin, and refuses a version it lacks"
