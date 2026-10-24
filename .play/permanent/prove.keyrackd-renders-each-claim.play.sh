#!/usr/bin/env bash
######################################################################
# .what = prove `1.6.4.keyrackd`'s upsert and verify render each claim they own,
#         ✔ and ✋ alike, and snap every variant a human reads in `--mode plan`
#
# .why this play exists
#   - every failure row of the phase opens `✋ ConstraintError:`, and no other
#     play drives it, so a drift in any row shipped unseen
#
# .the arms — a fixture $HOME, checkout, and skill; `systemctl` is a stub, so no
#   real user manager is touched
#   - V1. every claim holds · V2 / V3. the service / the timer differs
#   - V4 / V5. the timer not enabled / not armed · V0. no skill: 🌙, no claim
#   - U1. converged: skip · U2. a fresh apply declares and enables both units
#   - U3. the checkout lacks the timer · U4. the service write fails
#   - U5. daemon-reload fails · U6. enable fails · U0. no skill: 🌙, no write
#
# usage:
#   rhx play.run --play prove.keyrackd-renders-each-claim
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

_dir="$_root/src/grove.provision/1.system/1.6.procs/1.6.4.keyrackd"
TIMER_REAL="$_root/src/machine/keyrack_daemon_prune.timer"

echo "🔎 prove.keyrackd-renders-each-claim"
echo "   └─ root: $_root"
echo ""

export GROVE_SRC="$_root/src"
for _f in _.sh provision.upsert.sh provision.verify.sh; do
  # shellcheck source=/dev/null
  source "$_dir/$_f" || { echo "   ✋ ConstraintError: could not source $_dir/$_f" >&2; exit 2; }
done
[[ -f "$TIMER_REAL" ]] || { echo "   ✋ ConstraintError: no timer asset at $TIMER_REAL" >&2; exit 2; }

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"

FIX="$(mktemp -d "${TMPDIR:-/tmp}/prove.keyrackd.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

# the phase reads its skill and timer off `$GROVE_SRC`, so the fixture checkout stands in now
export GROVE_SRC="$FIX/repo/src" HOME="$FIX/home"
SKILL="$(grove_provision_1_6_4_keyrackd_skill)"
UNIT_DIR="$(grove_provision_1_6_4_keyrackd_unit_dir)"
SERVICE="$UNIT_DIR/$(grove_provision_1_6_4_keyrackd_service_name)"
TIMER="$UNIT_DIR/$(grove_provision_1_6_4_keyrackd_timer_name)"

######################################################################
# the stub — a user manager whose every answer an arm sets
######################################################################
systemctl() {
  case "${2:-}" in
    is-enabled)    [[ "${ENABLED:-yes}" == yes ]] ;;
    is-active)     [[ "${ACTIVE:-yes}" == yes ]] ;;
    daemon-reload) [[ "${RELOAD_FAILS:-}" != yes ]] ;;
    enable)        [[ "${ENABLE_FAILS:-}" != yes ]] ;;
    *)             return 0 ;;
  esac
}

# .what = a fresh world per arm: the skill, the checkout's timer, and both units as declared
_reset() {
  rm -rf "$FIX/repo" "$HOME"
  mkdir -p "$(dirname "$SKILL")" "$GROVE_SRC/machine" "$UNIT_DIR"
  printf '#!/usr/bin/env bash\n' > "$SKILL"; chmod +x "$SKILL"
  cp "$TIMER_REAL" "$GROVE_SRC/machine/"
  cp "$TIMER_REAL" "$TIMER"
  grove_provision_1_6_4_keyrackd_service_text > "$SERVICE"
}

failed=0

# .what = run one phase; grade its rc and a phrase, then snap the whole message
_arm() {
  local label="$1" phase="$2" want_rc="$3" phrase="$4" out rc
  out="$("grove_provision_1_6_4_keyrackd_provision_$phase" 2>&1)"; rc=$?
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

######################################################################
# the verify
######################################################################
_reset
_arm "V1. every claim holds" verify 0 "is armed on this boot ✔" || failed=$(( failed + 1 ))

_reset; printf '# a hand edit\n' >> "$SERVICE"
_arm "V2. the service differs: ✋" verify 1 "does NOT match this checkout" || failed=$(( failed + 1 ))

_reset; printf '# a hand edit\n' >> "$TIMER"
_arm "V3. the timer differs: ✋" verify 1 "does NOT match $GROVE_SRC/machine" || failed=$(( failed + 1 ))

_reset
ENABLED=no _arm "V4. the timer not enabled: ✋" verify 1 "is not enabled" || failed=$(( failed + 1 ))

_reset
ACTIVE=no _arm "V5. the timer not armed: ✋" verify 1 "is not armed" || failed=$(( failed + 1 ))

_reset; rm -f "$SKILL"
_arm "V0. no skill: 🌙, no timer claimed" verify 0 "no prune skill on this box" || failed=$(( failed + 1 ))

######################################################################
# the upsert
######################################################################
_reset
_arm "U1. converged: skip" upsert 0 "both units match this checkout, and the timer is armed ✔" || failed=$(( failed + 1 ))

_reset; rm -rf "$UNIT_DIR"
ENABLED=no ACTIVE=no _arm "U2. a fresh apply: both units declared, the timer enabled" upsert 0 "enabled and started" \
  || failed=$(( failed + 1 ))
[[ -f "$SERVICE" && -f "$TIMER" ]] \
  || { echo "   ├─ U2: a unit file is absent after the apply" >&2; failed=$(( failed + 1 )); }

_reset; rm -f "$GROVE_SRC/machine/keyrack_daemon_prune.timer"
_arm "U3. the checkout lacks the timer: ✋" upsert 1 "this run's own checkout is incomplete" || failed=$(( failed + 1 ))

# a directory where the service file must go makes the write fail, as a full or read-only dir would
_reset; rm -f "$SERVICE"; mkdir -p "$SERVICE"
ACTIVE=no _arm "U4. the service write fails: ✋" upsert 1 "could not write $SERVICE" || failed=$(( failed + 1 ))

_reset; printf '# a hand edit\n' >> "$SERVICE"
RELOAD_FAILS=yes _arm "U5. daemon-reload fails: ✋" upsert 1 "daemon-reload failed" || failed=$(( failed + 1 ))

_reset
ACTIVE=no ENABLE_FAILS=yes _arm "U6. enable fails: ✋" upsert 1 "could not enable" || failed=$(( failed + 1 ))

_reset; rm -f "$SKILL"; rm -rf "$UNIT_DIR"
_arm "U0. no skill: 🌙, no unit written" upsert 0 "no keyrack.daemon.prune skill" || failed=$(( failed + 1 ))
[[ ! -e "$SERVICE" ]] \
  || { echo "   ├─ U0: a service was written though no skill is there to run" >&2; failed=$(( failed + 1 )); }

echo ""
[[ "$failed" -eq 0 ]] || { echo "   💥 MalfunctionError: $failed arm(s) failed" >&2; exit 1; }
echo "   ✔ the keyrackd upsert and verify render each claim they own, ✔ and ✋ alike"
