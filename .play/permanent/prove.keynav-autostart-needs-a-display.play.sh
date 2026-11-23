#!/usr/bin/env bash
######################################################################
# .what = prove `1.1.keybinds` writes the keynav autostart on `local@unix` alone,
#         and removes it from ~/.profile on every seat with no display
#
# .why  = measured 2026-11-21: the phase wrote the block on every seat, so each
#         camper login on a hetzner grove began with `Error: Can't open display:`.
#         this clamps the gate and the removal that heals an extant grove
#
# guarantee:
#   - hermetic: a fixture HOME in mktemp; no keynav, no display, no root
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
B="$HERE/src/grove.provision/1.system/1.1.keybinds"

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT

failed=0
check() {
  local label="$1"; shift
  if "$@"; then echo "   • $label ✔"; else echo "   💥 MalfunctionError: $label" >&2; failed=1; fi
}

echo "🌲 prove.keynav-autostart-needs-a-display"

# .what = run the phase's autostart step as a seat of the given server, in the fixture HOME
run_as() {
  (
    export HOME="$fixture/home" GROVE_ENV_SERVER="$1"
    # shellcheck source=/dev/null
    source "$B/configure.upsert.sh"
    grove_provision_1_1_keybinds_keynav_autostart
  )
}
marker="# grove: keynav autostart at login"
profile="$fixture/home/.profile"
mkdir -p "$fixture/home"
printf '# a human line\nexport FOO=bar\n' > "$profile"
cp "$profile" "$fixture/profile.before"
chmod 0644 "$profile"

####################################################################
# arm 1 — local@unix: the block lands once, a re-run adds no copy
####################################################################
out="$(run_as local@unix 2>&1)"; rc=$?
check "local@unix · exits 0" test "$rc" -eq 0
check "local@unix · the marker lands once" test "$(grep -cxF "$marker" "$profile")" -eq 1
check "local@unix · the human lines stay" grep -qx 'export FOO=bar' "$profile"
run_as local@unix > /dev/null 2>&1
check "local@unix · a re-run adds no copy" test "$(grep -cxF "$marker" "$profile")" -eq 1
cp "$profile" "$fixture/profile.with-block"

####################################################################
# arm 2 — a cloud seat: the block a prior apply wrote is removed, and the
#   profile reads byte for byte as it did before the block
####################################################################
out="$(run_as cloud@hetzner.hetzbot 2>&1)"; rc=$?
check "cloud · exits 0" test "$rc" -eq 0
check "cloud · says it removed the block" bash -c '[[ "$1" == *"removed from ~/.profile"* ]]' _ "$out"
check "cloud · no keynav line is left" bash -c "! grep -q keynav '$profile'"
check "cloud · the profile is byte-equal to before the block" cmp -s "$profile" "$fixture/profile.before"
check "cloud · the profile mode is kept" test "$(stat -c %a "$profile")" = 644
out="$(run_as cloud@hetzner.hetzbot 2>&1)"; rc=$?
check "cloud · a re-run exits 0" test "$rc" -eq 0
check "cloud · a re-run says absent" bash -c '[[ "$1" == *"autostart absent"* ]]' _ "$out"
check "cloud · a re-run keeps the profile byte-equal" cmp -s "$profile" "$fixture/profile.before"

####################################################################
# arm 3 — a pre-marker block's command line is removed too, and a seat
#   with no ~/.profile at all is left without one
####################################################################
printf '# a human line\n(keynav && echo "keynav started" || echo "keynav already up") &\nexport FOO=bar\n' > "$profile"
run_as local@cicd > /dev/null 2>&1; rc=$?
check "legacy · local@cicd exits 0" test "$rc" -eq 0
check "legacy · the pre-marker line is removed" bash -c "! grep -q keynav '$profile'"
check "legacy · the human lines stay" cmp -s "$profile" "$fixture/profile.before"
rm -f "$profile"
run_as cloud@aws.ec2 > /dev/null 2>&1; rc=$?
check "no profile · exits 0" test "$rc" -eq 0
check "no profile · none is made" test ! -e "$profile"

echo
if [[ "$failed" -ne 0 ]]; then echo "💥 prove.keynav-autostart-needs-a-display — a claim missed" >&2; exit 1; fi
echo "✨ prove.keynav-autostart-needs-a-display — every claim held"
