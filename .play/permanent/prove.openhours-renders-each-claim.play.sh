#!/usr/bin/env bash
######################################################################
# .what = prove `5.18.openhours`'s upsert and verify render each claim they own,
#         ✔ and ✋ alike, and snap every variant a human reads in `--mode plan`
#
# .why this play exists
#   - this branch removed the phase's linger rows (`1.6.7.linger` owns that fact), and
#     no other play drives the phase, so a row that vanished or drifted shipped unseen
#
# .the arms — a fixture $HOME, checkout, and reconciler cwd; `systemctl`, `rhx`,
#   `rhachet`, `pnpm`, and `web_pnpm` are stubs, so no real user manager, skill,
#   registry, or gate is touched
#   - V0. opted out, no gate ✔ · V1. opted out, a gate remains: ✋
#   - V2. opted in, every claim holds · V3 / V4. the cwd half / absent: ✋
#   - V5. a gate skill does not answer from the cwd: ✋ · V6. the schedule differs: ✋
#   - V7. the timer neither active nor enabled: ✋
#   - U0. opted out, no gate: 🌙 · U1. opted out over a gate: 🌙, torn down
#   - U2. opted in, converged · U3. a fresh apply builds the cwd · U4. a half cwd is rebuilt
#   - U5. the declared schedule is malformed: ✋, before the marker is read
#
# usage:
#   rhx play.run --play prove.openhours-renders-each-claim
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

_dir="$_root/src/grove.provision/5.devtools/5.18.openhours"

echo "🔎 prove.openhours-renders-each-claim"
echo "   └─ root: $_root"
echo ""

command -v jq >/dev/null 2>&1 || { echo "   ✋ ConstraintError: no jq — the cwd reader needs it" >&2; exit 2; }

FIX="$(mktemp -d "${TMPDIR:-/tmp}/prove.openhours.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

# the bundle bakes its marker, cwd, and schedule paths off `$HOME` at source time,
#   so the fixture home stands in BEFORE the source
export HOME="$FIX/home" GROVE_SRC="$FIX/repo/src"
unset XDG_CONFIG_HOME

for _f in _.sh provision.upsert.sh provision.verify.sh; do
  # shellcheck source=/dev/null
  source "$_dir/$_f" || { echo "   ✋ ConstraintError: could not source $_dir/$_f" >&2; exit 2; }
done

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"

BIN_DIR="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"
NAMES=(machine_openhours_reconcile machine_openhours_reconcile.service machine_openhours_reconcile.timer)

######################################################################
# the stubs — every answer an arm needs is set by an env var
######################################################################
systemctl() {
  case "${2:-}" in
    is-active)     [[ "${ACTIVE:-yes}" == yes ]] && { echo active; return 0; }; echo inactive; return 3 ;;
    is-enabled)    [[ "${ENABLED:-yes}" == yes ]] && { echo enabled; return 0; }; echo disabled; return 1 ;;
    list-timers)   printf 'NEXT LEFT LAST PASSED UNIT ACTIVATES\n<next> <left> <last> <passed> machine_openhours_reconcile.timer machine_openhours_reconcile.service\n' ;;
    daemon-reload) [[ "${RELOAD_FAILS:-}" != yes ]] ;;
    enable)        [[ "${ENABLE_FAILS:-}" != yes ]] ;;
    *)             return 0 ;;
  esac
}

# .what = a gate skill asked from the reconciler's cwd
rhx() {
  [[ "${REACH_FAILS:-}" == yes ]] || { echo "global: open"; return 0; }
  echo "✋ ConstraintError: no skill named '$1' among the linked roles"
  return 2
}

pnpm() { return 0; }

# .what = `web_pnpm add <spec>...` — each package lands at the version its spec pins
web_pnpm() {
  shift
  local spec
  for spec in "$@"; do
    mkdir -p "node_modules/${spec%@*}"
    printf '{ "version": "%s" }\n' "${spec##*@}" > "node_modules/${spec%@*}/package.json"
  done
}

# .what = `rhachet roles link --repo <repo> --role <role>` — places that role's gate skill
rhachet() {
  local skill="$GROVE_OPENHOURS_SKILL_RADIO"
  [[ "${4:-}" == ehmpathy ]] && skill="$GROVE_OPENHOURS_SKILL_COMMIT"
  mkdir -p "$(dirname "$skill")" && printf '#!/usr/bin/env bash\n' > "$skill"
}

######################################################################
# the worlds
######################################################################
# .what = a fixture checkout with the three machine files; the reconciler exits clean
_reset() {
  rm -rf "$HOME" "$FIX/repo"
  mkdir -p "$GROVE_SRC/machine" "$HOME"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$GROVE_SRC/machine/machine_openhours_reconcile"
  printf '[Service]\nExecStart=%%h/.local/bin/machine_openhours_reconcile\n' > "$GROVE_SRC/machine/machine_openhours_reconcile.service"
  printf '[Timer]\nOnCalendar=*:00/30\n' > "$GROVE_SRC/machine/machine_openhours_reconcile.timer"
}

# .what = this box elects the gate
_optin() { mkdir -p "$(dirname "$GROVE_OPENHOURS_OPTIN")" && printf 'elected\n' > "$GROVE_OPENHOURS_OPTIN"; }

# .what = the link stub writes relative paths, so it is asked from inside the cwd — as the upsert does
rhachet_in_cwd() { ( cd "$GROVE_OPENHOURS_CWD" && rhachet "$@" ); }

failed=0

# .what = run one phase; grade its rc and a phrase, then snap the whole message
_arm() {
  local label="$1" phase="$2" want_rc="$3" phrase="$4" out rc
  out="$("grove_provision_5_18_openhours_provision_$phase" 2>&1)"; rc=$?
  [[ "$rc" -eq "$want_rc" && "$out" == *"$phrase"* ]] && {
    # a role-package bump is routine and changes no claim, so each pinned version snaps as `<pin>`
    local spec
    for spec in "${GROVE_OPENHOURS_ROLE_PKGS[@]}"; do out="${out//"$spec"/${spec%@*}@<pin>}"; done
    # a snap that differs fails the arm, so a drift in the rendered message never passes green
    play_snap_assert arm="${label%%.*}" rendered="$out" mask="$FIX" || return 1
    echo "   ├─ $label ✔"
    return 0
  }
  echo "   ├─ $label: rc=$rc (want $want_rc), no '$phrase'" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  return 1
}

# .what = the three files installed, the schedule rendered, the cwd whole at the pin
_installed_at_pin() {
  _installed_files_only
  mkdir -p "$GROVE_OPENHOURS_CWD/.git"
  ( cd "$GROVE_OPENHOURS_CWD" && web_pnpm add "${GROVE_OPENHOURS_ROLE_PKGS[@]}" )
  rhachet_in_cwd roles link --repo ehmpathy --role mechanic
  rhachet_in_cwd roles link --repo bhuild --role dispatcher
}

# .what = the three files and the schedule, with no cwd
_installed_files_only() {
  local name dst
  mkdir -p "$BIN_DIR" "$UNIT_DIR" "$(dirname "$GROVE_OPENHOURS_SCHEDULE")"
  for name in "${NAMES[@]}"; do
    dst="$UNIT_DIR/$name"; [[ "$name" == machine_openhours_reconcile ]] && dst="$BIN_DIR/$name"
    cp "$GROVE_SRC/machine/$name" "$dst"
  done
  chmod +x "$BIN_DIR/machine_openhours_reconcile"
  grove_provision_5_18_openhours_schedule_render > "$GROVE_OPENHOURS_SCHEDULE"
}

######################################################################
# the verify
######################################################################
_reset
ACTIVE=no ENABLED=no _arm "V0. opted out, no gate: ✔" verify 0 "openhours is opted out, and no gate is installed ✔" \
  || failed=$(( failed + 1 ))

_reset; _installed_files_only
_arm "V1. opted out, a gate remains: ✋" verify 1 "openhours is opted out and the box still carries a gate" \
  || failed=$(( failed + 1 ))

_reset; _optin; _installed_at_pin
_arm "V2. opted in, every claim holds" verify 0 "rhx radio.uses answers from that cwd ✔" || failed=$(( failed + 1 ))

_reset; _optin; _installed_at_pin; rm -f "$GROVE_OPENHOURS_CWD/$GROVE_OPENHOURS_SKILL_RADIO"
_arm "V3. the cwd is half: ✋" verify 1 "the reconciler's cwd is built, but not at the pin" || failed=$(( failed + 1 ))

_reset; _optin; _installed_files_only
_arm "V4. the cwd is absent: ✋" verify 1 "the reconciler's cwd was never built" || failed=$(( failed + 1 ))

_reset; _optin; _installed_at_pin
REACH_FAILS=yes _arm "V5. a gate skill does not answer: ✋" verify 1 "rhx git.commit.uses did not answer" \
  || failed=$(( failed + 1 ))

_reset; _optin; _installed_at_pin; printf 'OPENHOURS_TILL=23:00\n' >> "$GROVE_OPENHOURS_SCHEDULE"
_arm "V6. the schedule differs: ✋" verify 1 "the installed schedule DIFFERS" || failed=$(( failed + 1 ))

_reset; _optin; _installed_at_pin
ACTIVE=no ENABLED=no _arm "V7. the timer neither active nor enabled: ✋" verify 1 "not active" || failed=$(( failed + 1 ))

######################################################################
# the upsert
######################################################################
_reset
_arm "U0. opted out, no gate: 🌙" upsert 0 "openhours is opted out — no gate installed" || failed=$(( failed + 1 ))

_reset; _installed_files_only
_arm "U1. opted out over a gate: 🌙, torn down" upsert 0 "the timer is stopped and its files removed" \
  || failed=$(( failed + 1 ))
[[ ! -e "$UNIT_DIR/machine_openhours_reconcile.timer" && ! -e "$BIN_DIR/machine_openhours_reconcile" ]] \
  || { echo "   ├─ U1: a gate file remains after the teardown" >&2; failed=$(( failed + 1 )); }

_reset; _optin; _installed_at_pin
_arm "U2. opted in, converged" upsert 0 "the reconciler's cwd is built and at the pin" || failed=$(( failed + 1 ))

_reset; _optin
_arm "U3. a fresh apply builds the cwd" upsert 0 "the reconciler's cwd built and linked" || failed=$(( failed + 1 ))
[[ "$(grove_provision_5_18_openhours_cwd_state)" == whole ]] \
  || { echo "   ├─ U3: the cwd reads '$(grove_provision_5_18_openhours_cwd_state)' after the apply" >&2; failed=$(( failed + 1 )); }

_reset; _optin; _installed_at_pin; rm -rf "$GROVE_OPENHOURS_CWD/node_modules"
_arm "U4. a half cwd is rebuilt" upsert 0 "the reconciler's cwd built and linked" || failed=$(( failed + 1 ))

_reset; _optin
GROVE_OPENHOURS_DAYS="5-1" _arm "U5. a malformed schedule: ✋, before the marker is read" upsert 1 "the declared schedule is malformed" \
  || failed=$(( failed + 1 ))

echo ""
[[ "$failed" -eq 0 ]] || { echo "   💥 MalfunctionError: $failed arm(s) failed" >&2; exit 1; }
echo "   ✔ the openhours upsert and verify render each claim they own, ✔ and ✋ alike"
