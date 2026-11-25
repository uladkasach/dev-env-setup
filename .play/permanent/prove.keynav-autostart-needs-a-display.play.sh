#!/usr/bin/env bash
######################################################################
# .what = prove `1.1.keybinds` starts keynav from an xdg autostart entry on
#         `local@unix` alone, and strips every keynav line from ~/.profile on
#         every tier
#
# .why  = ~/.profile runs for every login shell — ssh, `bash -l`, each test
#         harness — and each started a keynav that outlived its shell; on a
#         grove with no display, each camper login began with
#         `Error: Can't open display:`. this clamps the entry, the gate, and
#         the strip that heals an extant box
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
    export HOME="$fixture/home" GROVE_ENV_SERVER="$1" GROVE_SRC="$HERE/src"
    # shellcheck source=/dev/null
    source "$B/_.sh"
    # shellcheck source=/dev/null
    source "$B/configure.upsert.sh"
    grove_provision_1_1_keybinds_keynav_autostart
  )
}
marker="# grove: keynav autostart at login"
legacy='(keynav && echo "keynav started" || echo "keynav already up") &'
profile="$fixture/home/.profile"
entry="$fixture/home/.config/autostart/keynav.desktop"
mkdir -p "$fixture/home"
printf '# a human line\nexport FOO=bar\n' > "$fixture/profile.before"

####################################################################
# arm 1 — local@unix: the marker block is stripped, the entry lands, a re-run
#   rewrites none of it
####################################################################
printf '# a human line\n%s\n%s\nexport FOO=bar\n' "$marker" "$legacy" > "$profile"
chmod 0644 "$profile"
out="$(run_as local@unix 2>&1)"; rc=$?
check "local@unix · exits 0" test "$rc" -eq 0
check "local@unix · no keynav line is left in ~/.profile" bash -c "! grep -q keynav '$profile'"
check "local@unix · the human lines stay byte for byte" cmp -s "$profile" "$fixture/profile.before"
check "local@unix · the profile mode is kept" test "$(stat -c %a "$profile")" = 644
check "local@unix · the entry matches the checkout" cmp -s "$entry" "$B/keynav.desktop"
out="$(run_as local@unix 2>&1)"; rc=$?
check "local@unix · a re-run exits 0" test "$rc" -eq 0
check "local@unix · a re-run says the entry matches" bash -c '[[ "$1" == *"entry matches this checkout"* ]]' _ "$out"
check "local@unix · a re-run says the profile is clean" bash -c '[[ "$1" == *"starts no keynav"* ]]' _ "$out"

####################################################################
# arm 2 — a cloud seat: the strip runs, and no entry is written
####################################################################
rm -rf "$fixture/home/.config"
printf '# a human line\n%s\nexport FOO=bar\n' "$legacy" > "$profile"
out="$(run_as cloud@hetzner.hetzbot 2>&1)"; rc=$?
check "cloud · exits 0" test "$rc" -eq 0
check "cloud · says it removed the start" bash -c '[[ "$1" == *"removed from ~/.profile"* ]]' _ "$out"
check "cloud · the legacy line is removed, the human lines stay" cmp -s "$profile" "$fixture/profile.before"
check "cloud · declines the entry" bash -c '[[ "$1" == *"keynav autostart declined"* ]]' _ "$out"
check "cloud · no entry is written" test ! -e "$entry"

####################################################################
# arm 3 — local@cicd has no graphical session either; a seat with no
#   ~/.profile at all is left without one
####################################################################
rm -f "$profile"
out="$(run_as local@cicd 2>&1)"; rc=$?
check "no profile · local@cicd exits 0" test "$rc" -eq 0
check "no profile · none is made" test ! -e "$profile"
check "no profile · local@cicd writes no entry" test ! -e "$entry"

echo
if [[ "$failed" -ne 0 ]]; then echo "💥 prove.keynav-autostart-needs-a-display — a claim missed" >&2; exit 1; fi
echo "✨ prove.keynav-autostart-needs-a-display — every claim held"
