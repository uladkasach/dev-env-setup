#!/usr/bin/env bash
######################################################################
# .what = prove `2.8.tmux`'s configure.verify renders each claim it owns, ✔ and ✋ alike,
#         and snap every variant a human reads in `--mode plan`
#
# .why this play exists
#   - the phase grades the conf, its shadows, its plugins at their pins, and its
#     default-terminal; no other play drives it, so a drift in any row shipped unseen
#
# .the arms — a fixture $HOME and checkout; a fake `tmux` on PATH answers the shadow probe
#   - V0. no conf · V1. all claims hold · V2. the conf differs from the checkout
#   - V3 / V4 / V5. a plugin absent / adrift / with no pin
#   - V6 / V7. no default-terminal / one terminfo lacks · V8. no server to name tpm's root
#   - S1 / S2 / S3. a server loads only ours / a shadow on disk / a shadow already retired
#   - S4. a tmux too old to name its confs, with an XDG conf on disk
#   - the live server claims (`_verify_live_servers`) are another play's subject
#
# usage:
#   rhx play.run --play prove.tmux-configure-verify-renders-each-claim
#
# exit:
#   0 = every arm holds | 1 = an arm failed | 2 = no checkout, or the bundle could not be sourced
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

_dir="$_root/src/grove.provision/2.shell/2.8.tmux"

echo "🔎 prove.tmux-configure-verify-renders-each-claim"
echo "   └─ root: $_root"
echo ""

export GROVE_SRC="$_root/src"
for _f in _.sh configure.verify.sh; do
  # shellcheck source=/dev/null
  source "$_dir/$_f" || { echo "   ✋ ConstraintError: could not source $_dir/$_f" >&2; exit 2; }
done

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"

FIX="$(mktemp -d "${TMPDIR:-/tmp}/prove.tmux-configure-verify.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

# the verify reads the checkout's conf from `$GROVE_SRC`, so the fixture checkout stands in now
export GROVE_SRC="$FIX/src" HOME="$FIX/home" XDG_CONFIG_HOME="$FIX/home/.config"
CONF_SRC="$GROVE_SRC/grove.provision/2.shell/2.8.tmux/tmux.conf"

######################################################################
# the stubs — no live server, no real terminfo, a fake tmux for the shadow probe
######################################################################
grove_provision_2_8_tmux_live_sockets() { [[ -n "${SOCK:-}" ]] && printf '%s\n' "$SOCK"; return 0; }
grove_provision_2_8_tmux_plugin_root() { [[ "${NO_ROOT:-}" == yes ]] && return 1; printf '%s' "$HOME/.tmux/plugins"; }
grove_provision_2_8_tmux_verify_live_servers() { return 0; }
infocmp() { [[ "$1" == tmux-256color ]]; }

# .what = a fake tmux: `-V` names an old build; `display-message` answers the sentinel with `$CONF_FILES`
mkdir -p "$FIX/bin"
printf '#!/usr/bin/env bash\n[[ "${1:-}" == -V ]] && { echo "tmux 3.2a"; exit 0; }\nprintf "A%%sZ\\n" "${CONF_FILES:-}"\n' > "$FIX/bin/tmux"
chmod +x "$FIX/bin/tmux"
export PATH="$FIX/bin:$PATH"

# .what = a conf that holds every claim; an arm edits a copy of it
_conf() {
  printf "set -g default-terminal '%s'\n" "${TERM_DECLARED-tmux-256color}"
  printf "set -g @plugin 'tmux-plugins/tpm'\n"
  printf "set -g @plugin 'tmux-plugins/tmux-resurrect'\n"
  [[ -n "${EXTRA_PLUGIN:-}" ]] && printf "set -g @plugin 'tmux-plugins/%s'\n" "$EXTRA_PLUGIN"
  printf "run '~/.tmux/plugins/tpm/tpm'\n"
}

# .what = a checkout at the given dir, at the given sha
_checkout() { mkdir -p "$1/.git"; printf '%s\n' "$2" > "$1/.git/HEAD"; }

# .what = a fresh world per arm: the conf live and in the checkout, tpm and the plugin at their pins
_reset() {
  rm -rf "$HOME" "$FIX/src"
  mkdir -p "$HOME" "$(dirname "$CONF_SRC")"
  _conf > "$CONF_SRC"
  cp "$CONF_SRC" "$HOME/.tmux.conf"
  _checkout "$HOME/.tmux/plugins/tpm" "$GROVE_UPGRADE_2_8_TMUX_TPM_AT"
  _checkout "$HOME/.tmux/plugins/tmux-resurrect" "$GROVE_UPGRADE_2_8_TMUX_RESURRECT_AT"
}

failed=0

# .what = run the verify; grade its rc and a phrase, then snap the whole message
_arm() {
  local label="$1" want_rc="$2" phrase="$3" out rc
  out="$(grove_provision_2_8_tmux_configure_verify 2>&1)"; rc=$?
  [[ "$rc" -eq "$want_rc" && "$out" == *"$phrase"* ]] && {
    # a snap that differs fails the arm, so a drift in the rendered message never passes green
    play_snap_assert arm="${label%%.*}" rendered="$out" mask="$FIX" || return 1
    echo "   ├─ $label ✔"
    return 0
  }
  echo "   ├─ $label: rc=$rc (want $want_rc), no '$phrase'" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  return 1
}

_reset; rm -f "$HOME/.tmux.conf"
_arm "V0. no conf: ✋ names the stock defaults" 1 "no ~/.tmux.conf on this box" || failed=$(( failed + 1 ))

_reset
# the plugin count is the repo conf's, pinned by the snap; the phrase grades the claim alone
_arm "V1. every claim holds" 0 "declared tmux plugins present, each at its pin ✔" || failed=$(( failed + 1 ))

_reset; printf '# a hand edit\n' >> "$HOME/.tmux.conf"
_arm "V2. the conf differs: ✋ names the diff" 1 "~/.tmux.conf DIFFERS from the checkout" || failed=$(( failed + 1 ))

_reset; rm -rf "$HOME/.tmux/plugins/tmux-resurrect"
_arm "V3. a plugin absent: ✋ names it" 1 "is ABSENT, or a cut clone" || failed=$(( failed + 1 ))

_reset; _checkout "$HOME/.tmux/plugins/tmux-resurrect" "0000000000000000000000000000000000000000"
_arm "V4. a plugin adrift: ✋ names it" 1 "present but NOT at its pinned commit: tmux-resurrect" || failed=$(( failed + 1 ))

EXTRA_PLUGIN=tmux-sensible _reset; mkdir -p "$HOME/.tmux/plugins/tmux-sensible"
_arm "V5. a plugin with no pin: ✋ names it" 1 "pins no commit for: tmux-sensible" || failed=$(( failed + 1 ))

TERM_DECLARED="" _reset
_arm "V6. no default-terminal: ✋ names the 8-colour fallback" 1 "the conf declares no default-terminal" || failed=$(( failed + 1 ))

TERM_DECLARED=grove-no-such-term _reset
_arm "V7. a default-terminal terminfo lacks: ✋" 1 "which terminfo does NOT hold" || failed=$(( failed + 1 ))

_reset
NO_ROOT=yes _arm "V8. no server to name tpm's root: 🌙, unproven not disproven" 0 "the plugin claim is unproven" || failed=$(( failed + 1 ))

_reset
SOCK=fake CONF_FILES="$HOME/.tmux.conf" _arm "S1. a server loads only ours: ✔" 0 "is the only conf tmux loads ✔" || failed=$(( failed + 1 ))

_reset; mkdir -p "$XDG_CONFIG_HOME/tmux"; printf 'set -g mouse off\n' > "$XDG_CONFIG_HOME/tmux/tmux.conf"
SOCK=fake CONF_FILES="$HOME/.tmux.conf,$XDG_CONFIG_HOME/tmux/tmux.conf" \
  _arm "S2. a shadow on disk: ✋ names it" 1 "tmux loads ANOTHER conf besides ~/.tmux.conf" || failed=$(( failed + 1 ))

_reset
SOCK=fake CONF_FILES="$HOME/.tmux.conf,$XDG_CONFIG_HOME/tmux/tmux.conf" \
  _arm "S3. a shadow already retired: ✔, and the 🌙 says the server still names it" 0 "the live server still NAMES it" || failed=$(( failed + 1 ))

_reset; mkdir -p "$XDG_CONFIG_HOME/tmux"; printf 'set -g mouse off\n' > "$XDG_CONFIG_HOME/tmux/tmux.conf"
SOCK=fake CONF_FILES="" \
  _arm "S4. an old tmux and an XDG conf: ✋ by a file test, and says so" 1 "read by a FILE test, not by tmux" || failed=$(( failed + 1 ))

echo ""
[[ "$failed" -eq 0 ]] || { echo "   💥 MalfunctionError: $failed arm(s) failed" >&2; exit 1; }
echo "   ✔ the configure.verify renders each claim it owns, ✔ and ✋ alike"
