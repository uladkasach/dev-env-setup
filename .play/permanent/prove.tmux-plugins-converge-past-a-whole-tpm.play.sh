#!/usr/bin/env bash
######################################################################
# .what = prove `2.8.tmux`'s upsert converges each pinned plugin even when
#         tpm itself already sits at its pin
#
# .why this play exists
#   - the upsert once answered "tpm already at the declared commit" with a
#     `return 0` that ended the whole phase, so on any box with a whole tpm
#     the plugin pins below it were never read: an absent or adrift plugin
#     stayed that way, and tpm then fetched it UNPINNED at the next server
#
# .the arms — a fixture $HOME; `git_clone` is stubbed, so no network is read
#   - A. tpm whole, plugin absent → the plugin is cloned at its pin
#   - B. tpm whole, plugin whole  → no clone at all
#
# usage:
#   rhx play.run --play prove.tmux-plugins-converge-past-a-whole-tpm
#
# exit:
#   0 = every arm holds
#   1 = an arm failed
#   2 = no checkout found, or the bundle could not be sourced
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
_dir="$GROVE_SRC/grove.provision/2.shell/2.8.tmux"

echo "🔎 prove.tmux-plugins-converge-past-a-whole-tpm"
echo "   └─ root: $_root"
echo ""

for _f in _.sh provision.upsert.sh; do
  # shellcheck source=/dev/null
  source "$_dir/$_f" || { echo "   ✋ ConstraintError: could not source $_dir/$_f" >&2; exit 2; }
done

FIX="$(mktemp -d "${TMPDIR:-/tmp}/prove.tmux-plugins.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT
export HOME="$FIX/home" GROVE_ENV_SERVER="local@unix"

######################################################################
# the stubs — no apt, no network
######################################################################
pkg_install() { return 0; }
git_clone() {
  printf '%s\n' "${2##*/}" >> "$FIX/cloned"
  mkdir -p "$2/.git"
  printf '%s\n' "$4" > "$2/.git/HEAD"
}

# .what = a checkout at the given dir, at the given sha; `tpm` gets its entrypoint
_checkout() {
  mkdir -p "$1/.git"
  printf '%s\n' "$2" > "$1/.git/HEAD"
  [[ "${1##*/}" == tpm ]] && { printf '#!/usr/bin/env bash\n' > "$1/tpm"; chmod +x "$1/tpm"; }
  return 0
}

# .what = a fresh $HOME with tpm whole at its pin
_reset() {
  rm -rf "$HOME" "$FIX/cloned"
  _checkout "$HOME/.tmux/plugins/tpm" "$GROVE_UPGRADE_2_8_TMUX_TPM_AT"
}

failed=0

######################################################################
# A. tpm whole, plugin absent
######################################################################
_arm_absent() {
  _reset
  local out rc
  out="$(grove_provision_2_8_tmux_provision_upsert 2>&1)"; rc=$?
  [[ "$rc" -eq 0 ]] || { echo "   ├─ A: rc=$rc" >&2; printf '%s\n' "$out" | sed 's/^/   │     /' >&2; return 1; }
  [[ "$(cat "$FIX/cloned" 2>/dev/null)" == "tmux-resurrect" ]] && {
    echo "   ├─ A. tpm whole, plugin absent: the plugin is cloned at its pin ✔"
    return 0
  }
  echo "   ├─ A. tpm whole, plugin absent: no plugin clone — the pin was never read" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  return 1
}
_arm_absent || failed=$(( failed + 1 ))

######################################################################
# B. tpm whole, plugin whole
######################################################################
_arm_whole() {
  _reset
  _checkout "$HOME/.tmux/plugins/tmux-resurrect" "$GROVE_UPGRADE_2_8_TMUX_RESURRECT_AT"
  local out rc
  out="$(grove_provision_2_8_tmux_provision_upsert 2>&1)"; rc=$?
  [[ "$rc" -eq 0 && ! -s "$FIX/cloned" && "$out" == *"tmux-resurrect already at the declared commit"* ]] && {
    echo "   └─ B. tpm whole, plugin whole: no clone ✔"
    return 0
  }
  echo "   └─ B. tpm whole, plugin whole: rc=$rc, cloned '$(cat "$FIX/cloned" 2>/dev/null)'" >&2
  printf '%s\n' "$out" | sed 's/^/         /' >&2
  return 1
}
_arm_whole || failed=$(( failed + 1 ))

echo ""
[[ "$failed" -eq 0 ]] || { echo "   💥 MalfunctionError: $failed arm(s) failed" >&2; exit 1; }
echo "   ✔ a whole tpm never stops the plugin pins below it"
