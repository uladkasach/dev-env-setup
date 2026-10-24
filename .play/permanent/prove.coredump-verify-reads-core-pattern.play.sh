#!/usr/bin/env bash
######################################################################
# .what = prove `1.6.8.coredump` reads the kernel's core handler: its verify
#         passes only systemd-coredump, and its upsert re-reads after it installs
#
# .why this play exists
#   - a grove's tmux segfaulted ~110 times and left no core, since no
#     systemd-coredump took them; no verify on the box could see that
#
# .the arms — a fixture core_pattern, never the box's own
#   - V1. `core` (the kernel default)           → ✋ that names the pattern + fix
#   - V2. a pipe to apport                      → ✋ that names apport
#   - V3. a pipe to systemd-coredump            → ✔
#   - V4. a laptop (`local@unix`)               → the same ✋ (parity)
#   - V5. core_pattern unreadable               → ✋ that says `unreadable`
#   - U1. upsert, the kernel already collects   → ✔, no install
#   - U2. upsert, the install sets the pattern  → ✔
#   - U3. upsert, apport keeps the pattern      → ✋ names the other handler
#   - U4. upsert, the install fails             → rc 1
#   - U5. upsert on a laptop                    → the same install (parity)
#   - U6. upsert on a seat with no root         → decline, no install
#   - V6. collects now, apport enabled          → ✋ names the next boot
#   - V7. collects, apport switched off         → ✔
#   - U7. apport enabled                        → `enabled=0`, its comments kept, no install
#   - U8. a switch file with no `enabled=` line → `enabled=0` appended
#   - U9. the switch cannot be written          → ✋, rc 1
#   - U10. a laptop, apport enabled              → the same release (parity, F7)
#
# .what is stubbed
#   - `pkg_install` records its ask; `sudo sysctl --system` writes the fixture
#     pattern the package's drop-in would; `sudo sed`/`sudo tee` run as this seat on
#     a fixture switch file; `bundle.root.owns` grants root
#
# usage:
#   rhx play.run --play prove.coredump-verify-reads-core-pattern
#
# exit:
#   0 = every arm holds
#   1 = an arm failed, or the bundle is absent
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

_dir="$_root/src/grove.provision/1.system/1.6.procs/1.6.8.coredump"

echo "🔎 prove.coredump-verify-reads-core-pattern"
echo "   └─ root: $_root"
echo ""

for _f in _.sh provision.verify.sh provision.upsert.sh; do
  [[ -f "$_dir/$_f" ]] || { echo "   💥 MalfunctionError: no $_dir/$_f — no bundle claims a crash collector" >&2; exit 1; }
  # shellcheck source=/dev/null
  source "$_dir/$_f" || { echo "   ✋ ConstraintError: could not source $_dir/$_f" >&2; exit 2; }
done

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"

FIX="$(mktemp -d "${TMPDIR:-/tmp}/prove.coredump.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT
export GROVE_CORE_PATTERN_PATH="$FIX/core_pattern" GROVE_ENV_SERVER="cloud@aws.ec2"
export GROVE_APPORT_INIT_PATH="$FIX/apport.init" GROVE_APPORT_DEFAULT_PATH="$FIX/apport.default"

P_CORE="core"
P_APPORT="|/usr/share/apport/apport -p%p -s%s -c%c -d%d -P%P -u%u -g%g -- %E"
P_SYSTEMD="|/usr/lib/systemd/systemd-coredump %P %u %g %s %t %c %h"

######################################################################
# the stubs — no apt, no root, no sysctl
######################################################################
pkg_install() { printf '%s\n' "$*" >> "$FIX/installed"; [[ "${INSTALL_FAILS:-}" != yes ]]; }
sudo() {
  case "$1" in
    sysctl)
      [[ "${2:-}" == --system ]] || return 1
      [[ "${APPORT_HOLDS:-}" == yes ]] && return 0
      printf '%s\n' "$P_SYSTEMD" > "$GROVE_CORE_PATTERN_PATH"
      ;;
    sed|tee)
      [[ "${RELEASE_FAILS:-}" == yes ]] && return 1
      "$@"
      ;;
    *) return 1 ;;
  esac
}
bundle.root.owns() { return 0; }

# .what = a fresh world: the given pattern, no install asked, no apport on the box
_pattern() {
  printf '%s\n' "$1" > "$GROVE_CORE_PATTERN_PATH"
  rm -f "$FIX/installed" "$GROVE_APPORT_INIT_PATH" "$GROVE_APPORT_DEFAULT_PATH"
}

# .what = apport on the box: its init entry, and a switch file with the given body
_apport() {
  printf '#!/bin/sh\n' > "$GROVE_APPORT_INIT_PATH"
  printf '%b' "$1" > "$GROVE_APPORT_DEFAULT_PATH"
}

failed=0

# .what = grade one arm: its exit, and a phrase its output must hold
_grade() {
  local label="$1" rc="$2" want="$3" out="$4" phrase="$5"
  local held=yes
  [[ "$rc" -eq "$want" ]] || held="rc=$rc, want $want"
  [[ "$held" == yes && "$out" != *"$phrase"* ]] && held="no '$phrase' in the output"
  # the phrase holds → snap the whole message, keyed by the arm id (`V1`, `U7`, …)
  [[ "$held" == yes ]] && { play_snap_assert arm="${label%%.*}" rendered="$out" mask="$FIX" || return 1; echo "   ├─ $label ✔"; return 0; }
  echo "   ├─ $label: $held" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  return 1
}

# .what = an arm that must ask no install
_uninstalled() {
  [[ ! -s "$FIX/installed" ]] && return 0
  echo "   │  └─ $1: an install was asked, and this arm owed none" >&2
  return 1
}

_verify() { grove_provision_1_6_8_coredump_provision_verify 2>&1; }
_upsert() { grove_provision_1_6_8_coredump_provision_upsert 2>&1; }

######################################################################
# V1..V4. the verify
######################################################################
_pattern "$P_CORE"; out="$(_verify)"; rc=$?
_grade "V1. core: ✋ names the pattern" "$rc" 1 "$out" "core_pattern: core" || failed=$(( failed + 1 ))
_grade "V1. core: ✋ names the fix, with the sudo cache a root step needs" "$rc" 1 "$out" \
  "fix: sudo -v && rhx grove.provision --what 1.6.8.coredump --mode apply" || failed=$(( failed + 1 ))
_grade "V1. core: the fix names the seat that holds sudo" "$rc" 1 "$out" "on a grove: run it on the ground seat" \
  || failed=$(( failed + 1 ))

_pattern "$P_APPORT"; out="$(_verify)"; rc=$?
_grade "V2. apport: ✋ names apport" "$rc" 1 "$out" "apport" || failed=$(( failed + 1 ))

_pattern "$P_SYSTEMD"; out="$(_verify)"; rc=$?
_grade "V3. systemd-coredump: ✔" "$rc" 0 "$out" "pipes each core to systemd-coredump, and no apport claims the boot ✔" || failed=$(( failed + 1 ))

_pattern "$P_CORE"; out="$( GROVE_ENV_SERVER=local@unix _verify )"; rc=$?
_grade "V4. a laptop: the same ✋ (parity)" "$rc" 1 "$out" "core_pattern: core" || failed=$(( failed + 1 ))

rm -f "$GROVE_CORE_PATTERN_PATH"; out="$(_verify)"; rc=$?
_grade "V5. unreadable: ✋ says so" "$rc" 1 "$out" "core_pattern: unreadable" || failed=$(( failed + 1 ))

######################################################################
# U1..U6. the upsert
######################################################################
_pattern "$P_SYSTEMD"; out="$(_upsert)"; rc=$?
_grade "U1. already collects: skip" "$rc" 0 "$out" "already pipes" && _uninstalled U1 || failed=$(( failed + 1 ))

_pattern "$P_APPORT"; out="$(_upsert)"; rc=$?
_grade "U2. the install sets the pattern: ✔" "$rc" 0 "$out" "collects each core" || failed=$(( failed + 1 ))
[[ "$(cat "$FIX/installed" 2>/dev/null)" == "systemd-coredump" ]] \
  || { echo "   │  └─ U2: the install asked for '$(cat "$FIX/installed" 2>/dev/null)', want systemd-coredump" >&2; failed=$(( failed + 1 )); }

_pattern "$P_APPORT"; out="$( APPORT_HOLDS=yes _upsert )"; rc=$?
_grade "U3. apport keeps the pattern: ✋" "$rc" 1 "$out" "still pipes cores elsewhere" || failed=$(( failed + 1 ))

_pattern "$P_APPORT"; out="$( INSTALL_FAILS=yes _upsert )"; rc=$?
_grade "U4. the install fails: ✋ names the package" "$rc" 1 "$out" "systemd-coredump did not install" || failed=$(( failed + 1 ))

_pattern "$P_APPORT"; out="$( GROVE_ENV_SERVER=local@unix _upsert )"; rc=$?
_grade "U5. a laptop: the same install (parity)" "$rc" 0 "$out" "collects each core" || failed=$(( failed + 1 ))

# U6. the REAL decline a crew seat meets — the runtime's own `bundle.root.owns`, with sudo denied
_pattern "$P_APPORT"
out="$(
  # shellcheck source=/dev/null
  source "$_root/src/bundle.upgrade.sh"
  pkg_can_sudo() { return 1; }
  _upsert
)"; rc=$?
_grade "U6. no root: decline" "$rc" 0 "$out" "this seat has no root" && _uninstalled U6 || failed=$(( failed + 1 ))
_grade "U6. the decline points at the verify for the run still owed" "$rc" 0 "$out" \
  "bundle's verify names the run" || failed=$(( failed + 1 ))
[[ "$out" != *"none by a human"* ]] \
  || { echo "   │  └─ U6: the decline says no human owes a step — it cannot read that" >&2; failed=$(( failed + 1 )); }

######################################################################
# V6, V7, U7..U9. apport's boot claim — its init rewrites core_pattern each boot
######################################################################
_pattern "$P_SYSTEMD"; _apport '# set this to 0 to disable apport\nenabled=1\n'
out="$(_verify)"; rc=$?
_grade "V6. collects now, apport enabled: ✋ names the next boot" "$rc" 1 "$out" \
  "apport takes it back at the next boot" || failed=$(( failed + 1 ))
_grade "V6. apport enabled: ✋ names the fix, with the sudo cache" "$rc" 1 "$out" \
  "fix: sudo -v && rhx grove.provision --what 1.6.8.coredump --mode apply" || failed=$(( failed + 1 ))

_pattern "$P_SYSTEMD"; _apport 'enabled=0\n'
out="$(_verify)"; rc=$?
_grade "V7. collects, apport off: ✔" "$rc" 0 "$out" "no apport claims the boot ✔" || failed=$(( failed + 1 ))

_pattern "$P_SYSTEMD"; _apport '# set this to 0 to disable apport\nenabled=1\n'
out="$(_upsert)"; rc=$?
_grade "U7. apport enabled: its boot claim is turned off" "$rc" 0 "$out" "boot claim on core_pattern is off" \
  && _uninstalled U7 || failed=$(( failed + 1 ))
[[ "$(cat "$GROVE_APPORT_DEFAULT_PATH")" == $'# set this to 0 to disable apport\nenabled=0' ]] \
  || { echo "   │  └─ U7: the switch file reads '$(cat "$GROVE_APPORT_DEFAULT_PATH")', want its comment kept and enabled=0" >&2; failed=$(( failed + 1 )); }

_grade "U7. the release names what is lost and the undo" "$rc" 0 "$out" "undo: set enabled=1" \
  || failed=$(( failed + 1 ))

_pattern "$P_SYSTEMD"; _apport 'enabled=1\n'
out="$( GROVE_ENV_SERVER=local@unix _upsert )"; rc=$?
_grade "U10. a laptop: the same release (parity, F7)" "$rc" 0 "$out" "boot claim on core_pattern is off" \
  || failed=$(( failed + 1 ))
[[ "$(cat "$GROVE_APPORT_DEFAULT_PATH")" == "enabled=0" ]] \
  || { echo "   │  └─ U10: the switch file reads '$(cat "$GROVE_APPORT_DEFAULT_PATH")', want enabled=0" >&2; failed=$(( failed + 1 )); }

_pattern "$P_SYSTEMD"; _apport '# no switch line\n'
out="$(_upsert)"; rc=$?
_grade "U8. a switch file with no enabled= line (the init's default is 1): set to 0" "$rc" 0 "$out" \
  "boot claim on core_pattern is off" || failed=$(( failed + 1 ))

_pattern "$P_SYSTEMD"; _apport 'enabled=1\n'
out="$( RELEASE_FAILS=yes _upsert )"; rc=$?
_grade "U9. the switch cannot be written: ✋" "$rc" 1 "$out" "apport still claims core_pattern at the next boot" \
  || failed=$(( failed + 1 ))

echo ""
[[ "$failed" -eq 0 ]] || { echo "   💥 MalfunctionError: $failed arm(s) failed" >&2; exit 1; }
echo "   ✔ the coredump bundle reads core_pattern, and passes only systemd-coredump"
