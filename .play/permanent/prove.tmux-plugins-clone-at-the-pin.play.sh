#!/usr/bin/env bash
######################################################################
# .what = prove the real `git_clone` lands tpm and tmux-resurrect at the commits
#         `2.8.tmux` pins, and refuses a commit the remote does not hold
#
# .why this play exists
#   - every other play that drives the tpm and plugin installs stubs `git_clone`,
#     so the stubs agree with themselves and the github contract goes unproven
#   - this play calls the real clone, over the real wire, at the declared pins
#
# .the arms — each clone lands in a private temp dir, never the box's own ~/.tmux
#   - C1. tpm at its pin            → HEAD names the pin
#   - C2. tmux-resurrect at its pin → HEAD names the pin
#   - C3. tpm at a commit the remote lacks → git_clone fails, and no partial clone stays
#
# usage:
#   rhx play.run --play prove.tmux-plugins-clone-at-the-pin
#
# exit:
#   0 = every arm holds
#   1 = an arm failed
#   2 = no checkout, a source failed, or github is unreachable — so no claim was graded
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
# git's own words land in the snaps, so they read alike on every box, whatever its locale
export LC_ALL=C

echo "🔎 prove.tmux-plugins-clone-at-the-pin"
echo "   └─ root: $_root"
echo ""

# shellcheck source=/dev/null
source "$GROVE_SRC/grove.web.sh" || { echo "   ✋ ConstraintError: could not source grove.web.sh" >&2; exit 2; }
# shellcheck source=/dev/null
source "$GROVE_SRC/grove.provision/2.shell/2.8.tmux/_.sh" || { echo "   ✋ ConstraintError: could not source 2.8.tmux/_.sh" >&2; exit 2; }
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"

TPM_URL="https://github.com/tmux-plugins/tpm"
ABSENT_AT="0000000000000000000000000000000000000000"

# the wire first: a remote that does not answer grades no claim, so it declines rather than fails
GIT_TERMINAL_PROMPT=0 timeout -k 5 60 git ls-remote "$TPM_URL" HEAD </dev/null >/dev/null 2>&1 || {
  echo "   ✋ ConstraintError: github did not answer a bounded ls-remote — no claim graded" >&2
  exit 2
}

FIX="$(web_tempdir prove-clone)" || { echo "   ✋ ConstraintError: no temp dir for the clones — no claim graded" >&2; exit 2; }
trap 'rm -rf "$FIX"' EXIT

failed=0

# .what = clone one repo at its pin, then grade that HEAD names the pin
_arm_pinned() {
  local label="$1" url="$2" at="$3" dir="$FIX/$4"
  local out rc head
  out="$( git_clone "$url" "$dir" --at "$at" 2>&1 )"; rc=$?
  head="$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo absent)"
  if [[ "$rc" -eq 0 && "$head" == "$at" ]]; then
    play_snap_assert arm="${label%%.*}" rendered="$(printf '%s\n' "$out" "   • HEAD is the pin, $at ✔")" mask="$FIX" || return 1
    echo "   ├─ $label ✔"
    return 0
  fi
  echo "   ├─ $label: rc=$rc, HEAD=$head, want $at" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  return 1
}

_arm_pinned "C1. tpm lands at its pin" "$TPM_URL" "$GROVE_UPGRADE_2_8_TMUX_TPM_AT" tpm \
  || failed=$(( failed + 1 ))
_arm_pinned "C2. tmux-resurrect lands at its pin" "$(grove_provision_2_8_tmux_plugin_url tmux-resurrect)" \
  "$(grove_provision_2_8_tmux_plugin_at tmux-resurrect)" tmux-resurrect \
  || failed=$(( failed + 1 ))

# C3. a commit the remote lacks: the clone refuses, and the boundary removes what it fetched
out="$( git_clone "$TPM_URL" "$FIX/tpm-absent" --at "$ABSENT_AT" 2>&1 )"; rc=$?
if [[ "$rc" -ne 0 && ! -e "$FIX/tpm-absent" && "$out" == *"the pinned commit is absent"* ]]; then
  # git's own `fatal:` line is masked, as a pid or a temp path is: its words vary by git
  #   version (this seat's git says `reference is not a tree`, a CI runner's `unable to read
  #   tree`), and the claim is the ✋ beneath it, which this repo writes
  play_snap_assert arm=C3 rendered="$(printf '%s\n' "$out" | sed "s/^fatal: .*/fatal: <git's own words>/")" mask="$FIX" \
    && echo "   ├─ C3. a commit the remote lacks is refused, and no partial clone stays ✔" \
    || failed=$(( failed + 1 ))
else
  echo "   ├─ C3. rc=$rc, partial clone: $([[ -e "$FIX/tpm-absent" ]] && echo stays || echo gone)" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  failed=$(( failed + 1 ))
fi

echo ""
[[ "$failed" -eq 0 ]] || { echo "   💥 MalfunctionError: $failed arm(s) failed" >&2; exit 1; }
echo "🌲 the real clone lands each plugin at its pin, and refuses a commit the remote lacks"
