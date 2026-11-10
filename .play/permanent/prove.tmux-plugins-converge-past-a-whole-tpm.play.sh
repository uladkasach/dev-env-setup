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
#   - C / H / X. plugin adrift, a cut clone, its clone fails → each line snapped
#   - T1..T7. tpm absent, adrift, a cut clone, unmovable, its clone fails, git absent,
#     and a laptop's distro tmux that does not install → each line snapped
#   - F1 / F2. a grove with no tmux whose pin did not land: the distro floor lays, or
#     fails too → each line snapped
#   - J1..J4. the verify's judge reads each plugin's STATE, never its dir: whole,
#     adrift, a cut clone, and a conf plugin with no pin
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

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"

FIX="$(mktemp -d "${TMPDIR:-/tmp}/prove.tmux-plugins.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT
export HOME="$FIX/home" GROVE_ENV_SERVER="local@unix"

######################################################################
# the stubs — no apt, no network, a fixed clock (so an `.aside.<stamp>` snaps alike)
######################################################################
pkg_install() { [[ "${PKG_FAILS:-}" == yes ]] && return 1; return 0; }
date() { printf '20261023T000000Z'; }
mv() { [[ "${MV_FAILS:-}" == yes ]] && return 1; builtin command mv "$@"; }
# git absent is the one `command -v` answer a fixture must forge; every other lookup is real
command() { [[ "${GIT_ABSENT:-}" == yes && "${1:-}" == -v && "${2:-}" == git ]] && return 1; builtin command "$@"; }
git_clone() {
  [[ "${CLONE_FAILS:-}" == yes ]] && return 1
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
    play_snap_assert arm=A rendered="$out" mask="$FIX" || return 1
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
    play_snap_assert arm=B rendered="$out" mask="$FIX" || return 1
    echo "   ├─ B. tpm whole, plugin whole: no clone ✔"
    return 0
  }
  echo "   └─ B. tpm whole, plugin whole: rc=$rc, cloned '$(cat "$FIX/cloned" 2>/dev/null)'" >&2
  printf '%s\n' "$out" | sed 's/^/         /' >&2
  return 1
}
_arm_whole || failed=$(( failed + 1 ))

######################################################################
# C / H / X. the plugin is adrift, a cut clone, or its clone fails — each line snapped
######################################################################
# .what = run the upsert over one prepared plugin state; grade a phrase and the rc, then snap
_arm_plugin() {
  local arm="$1" want_rc="$2" phrase="$3" out rc
  out="$(grove_provision_2_8_tmux_provision_upsert 2>&1)"; rc=$?
  [[ "$rc" -eq "$want_rc" && "$out" == *"$phrase"* ]] && {
    # a snap that differs fails the arm, so a drift in the rendered message never passes green
    play_snap_assert arm="${arm%%.*}" rendered="$out" mask="$FIX" || return 1
    echo "   ├─ $arm ✔"
    return 0
  }
  echo "   ├─ $arm: rc=$rc (want $want_rc), no '$phrase'" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  return 1
}

_reset
_checkout "$HOME/.tmux/plugins/tmux-resurrect" "0000000000000000000000000000000000000000"
_arm_plugin "C. an adrift plugin: moved aside, re-cloned at its pin" 0 "tmux-resurrect was 'adrift'; moved aside" \
  || failed=$(( failed + 1 ))

_reset
mkdir -p "$HOME/.tmux/plugins/tmux-resurrect"
_arm_plugin "H. a cut clone: moved aside, re-cloned at its pin" 0 "tmux-resurrect was 'half'; moved aside" \
  || failed=$(( failed + 1 ))

_reset
CLONE_FAILS=yes _arm_plugin "X. the clone fails: ✋, and tpm is told not to cover" 1 "could not clone tmux-resurrect" \
  || failed=$(( failed + 1 ))

######################################################################
# T1..T7. tpm itself is not whole, or the phase's own install fails — each line snapped
######################################################################
_reset; rm -rf "$HOME/.tmux/plugins/tpm"
_arm_plugin "T1. tpm absent: cloned at its pin" 0 "tpm installed at the declared commit" \
  || failed=$(( failed + 1 ))

_reset; rm -rf "$HOME/.tmux/plugins/tpm"; _checkout "$HOME/.tmux/plugins/tpm" "0000000000000000000000000000000000000000"
_arm_plugin "T2. tpm adrift: moved aside, re-cloned at its pin" 0 "tpm was 'adrift'; moved aside, re-clone follows" \
  || failed=$(( failed + 1 ))

_reset; rm -rf "$HOME/.tmux/plugins/tpm"; mkdir -p "$HOME/.tmux/plugins/tpm"
_arm_plugin "T3. tpm a cut clone: moved aside, re-cloned at its pin" 0 "tpm was 'half'; moved aside, re-clone follows" \
  || failed=$(( failed + 1 ))

_reset; rm -rf "$HOME/.tmux/plugins/tpm"; mkdir -p "$HOME/.tmux/plugins/tpm"
MV_FAILS=yes _arm_plugin "T4. tpm cannot be moved aside: ✋, no clone over it" 1 "holds a tpm this bundle cannot use (half)" \
  || failed=$(( failed + 1 ))

_reset; rm -rf "$HOME/.tmux/plugins/tpm"
CLONE_FAILS=yes _arm_plugin "T5. tpm's clone fails: ✋, the conf's path is named" 1 "could not clone tpm to" \
  || failed=$(( failed + 1 ))

_reset; rm -rf "$HOME/.tmux/plugins/tpm"
GIT_ABSENT=yes _arm_plugin "T6. git absent: installed, then tpm cloned" 0 "git installed — this box shipped without it" \
  || failed=$(( failed + 1 ))

_reset
PKG_FAILS=yes _arm_plugin "T7. a laptop's distro tmux does not install: ✋" 1 "tmux did not install" \
  || failed=$(( failed + 1 ))

######################################################################
# F1 / F2. a grove whose pin did not land, with no tmux at all: the distro floor
######################################################################
# .what = run the floor over a grove that holds no tmux and no placed pin; grade a phrase and snap
_arm_floor() {
  local arm="$1" want_rc="$2" phrase="$3" out rc
  grove_provision_2_8_tmux_binary_state() { printf 'absent'; }
  grove_provision_2_8_tmux_pin_dst_version() { printf ''; }
  out="$(grove_provision_2_8_tmux_pin_floor 2>&1)"; rc=$?
  [[ "$rc" -eq "$want_rc" && "$out" == *"$phrase"* ]] && {
    play_snap_assert arm="${arm%%.*}" rendered="$out" mask="$FIX" || return 1
    echo "   ├─ $arm ✔"
    return 0
  }
  echo "   ├─ $arm: rc=$rc (want $want_rc), no '$phrase'" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  return 1
}
_arm_floor "F1. the floor lays the distro tmux: 🌙, the pin still owed" 0 "the distro tmux is laid as a floor" \
  || failed=$(( failed + 1 ))
PKG_FAILS=yes _arm_floor "F2. the floor does not install either: ✋, no duct can reach the box" 1 "the distro tmux floor did not install either" \
  || failed=$(( failed + 1 ))

######################################################################
# J1..J4. the verify's judge — the same `plugin_state` the upsert asks, never a `-d` test
######################################################################
# .what = grade one judged plugin: the line the judge must print for it
_judged() {
  local label="$1" want="$2"; shift 2
  local got; got="$(grove_provision_2_8_tmux_plugins_judged "$HOME/.tmux/plugins" "$@" | tr '\n' ' ')"
  [[ "$got" == *"$want"* ]] && { echo "   ├─ $label ✔"; return 0; }
  echo "   ├─ $label: judged '$got', want '$want'" >&2
  return 1
}

_reset
_checkout "$HOME/.tmux/plugins/tmux-resurrect" "$GROVE_UPGRADE_2_8_TMUX_RESURRECT_AT"
_judged "J1. a plugin at its pin is whole" "tmux-resurrect=whole" tpm tmux-resurrect \
  || failed=$(( failed + 1 ))

_reset
_checkout "$HOME/.tmux/plugins/tmux-resurrect" "0000000000000000000000000000000000000000"
_judged "J2. a plugin at another commit is adrift, though its dir is there" "tmux-resurrect=adrift" tmux-resurrect \
  || failed=$(( failed + 1 ))

_reset
mkdir -p "$HOME/.tmux/plugins/tmux-resurrect"
_judged "J3. a cut clone (a dir, no .git) is half, though its dir is there" "tmux-resurrect=half" tmux-resurrect \
  || failed=$(( failed + 1 ))

_reset
mkdir -p "$HOME/.tmux/plugins/tmux-sensible"
_judged "J4. a conf plugin this repo pins no commit for is unpinned" "tmux-sensible=unpinned" tmux-sensible \
  || failed=$(( failed + 1 ))

echo ""
[[ "$failed" -eq 0 ]] || { echo "   💥 MalfunctionError: $failed arm(s) failed" >&2; exit 1; }
echo "   ✔ a whole tpm never stops the plugin pins below it, and the verify judges each at its pin"
