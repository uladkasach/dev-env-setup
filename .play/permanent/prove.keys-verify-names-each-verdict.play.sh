#!/usr/bin/env bash
######################################################################
# .what = prove `5.16.keys`'s verify names each verdict a human reads: a key
#         held, a key the boot places next, and an empty key on and off camp
#
# .why  = the boot runs this verify one step BEFORE `git.grove.auth.keys.set`
#         places the keys, so on every first boot the ✋ halted the boot one step
#         short of its own repair. the deferral line (GROVE_BOOT_PLACES_KEYS=1) is
#         the fix; this clamps it beside the two ✋ texts it must never replace
#
# guarantee:
#   - hermetic: a fixture $HOME, stub `rhx` and `aws` on PATH; all in mktemp.
#     the one account id is a dox.verify dummy
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
B="$HERE/src/grove.provision/5.devtools/5.16.keys"

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT

failed=0
check() {
  local label="$1"; shift
  if "$@"; then echo "   • $label ✔"; else echo "   💥 MalfunctionError: $label" >&2; failed=1; fi
}

transcript=""
record() { transcript+="## $1"$'\n'"${2//$fixture/<fix>}"$'\n\n'; }

echo "🌲 prove.keys-verify-names-each-verdict"

mkdir -p "$fixture/home/.local/state/keyrack.gitroot" "$fixture/bin" "$fixture/state"

# rhx: the AWS_PROFILE row answers 'ambient'; the key answers the state file, or empty
cat > "$fixture/bin/rhx" <<STUB
#!/usr/bin/env bash
[[ " \$* " == *" --key AWS_PROFILE "* ]] && { printf ambient; exit 0; }
[[ -f "$fixture/state/value" ]] && cat "$fixture/state/value"
exit 0
STUB
printf '#!/usr/bin/env bash\nprintf 123456789012\n' > "$fixture/bin/aws"
chmod +x "$fixture/bin/rhx" "$fixture/bin/aws"

# $1 = server tag · $2 = boot places keys (1|0)
run_verify() {
  (
    export PATH="$fixture/bin:$PATH" HOME="$fixture/home" GROVE_ENV_SERVER="$1" GROVE_ORG=ahbode
    [[ "$2" == 1 ]] && export GROVE_BOOT_PLACES_KEYS=1
    # shellcheck source=/dev/null
    source "$HERE/src/grove.provision/5.devtools/5.12.rack/_.sh"
    # shellcheck source=/dev/null
    source "$B/_.sh"
    # shellcheck source=/dev/null
    source "$B/configure.verify.sh"
    grove_env_seat_is_admin() { return 1; }
    grove_provision_5_16_keys_required() { printf '%s\n' "${KEYS_ROWS:-ahbode:prep:VENDOR_KEY}"; }
    grove_provision_5_16_keys_declare() { return 0; }
    grove_provision_5_16_keys_configure_verify
  )
}

####################################################################
# arm 1 — the key is held
####################################################################
printf 'a-dummy-value' > "$fixture/state/value"
out="$(run_verify cloud@hetzner.hetzbot 0 2>&1)"; rc=$?
record "held, on camp" "$out"
check "held · ✔ names the slug" bash -c "[[ \"\$1\" == *'✔ ahbode.prep.VENDOR_KEY — the rack hands over a value'* ]]" _ "$out"
check "held · rc 0" test "$rc" -eq 0
check "held · the value never reaches the page" bash -c "[[ \"\$1\" != *'a-dummy-value'* ]]" _ "$out"
rm -f "$fixture/state/value"

####################################################################
# arm 2 — empty inside a boot: the boot's next step owns it
####################################################################
out="$(run_verify cloud@hetzner.hetzbot 1 2>&1)"; rc=$?
record "empty, inside a boot that places keys next" "$out"
check "boot · 🌙 names the step that places it" bash -c "[[ \"\$1\" == *'🌙 ahbode.prep.VENDOR_KEY — not yet placed; the boot places it next and reads it back'* ]]" _ "$out"
check "boot · rc 0, so the boot reaches the step that clears it" test "$rc" -eq 0
check "boot · no ✋ beside the deferral" bash -c "[[ \"\$1\" != *'✋'* ]]" _ "$out"

####################################################################
# arm 3 — empty outside a boot, on a camp grove: the five states
####################################################################
out="$(run_verify cloud@hetzner.hetzbot 0 2>&1)"; rc=$?
record "empty, on camp, outside a boot" "$out"
check "camp · ✋ names the empty key" bash -c "[[ \"\$1\" == *'✋ ConstraintError: ahbode.prep.VENDOR_KEY — the rack hands over an EMPTY value'* ]]" _ "$out"
check "camp · the account verdict reads = ambient, never an id" bash -c "[[ \"\$1\" == *\"profile 'ambient' = this box's ambient account\"* && \"\$1\" != *123456789012* ]]" _ "$out"
check "camp · the five states are named" bash -c "[[ \"\$1\" == *'EMPTY collapses five states'* ]]" _ "$out"
check "camp · rc 1" test "$rc" -eq 1

####################################################################
# arm 4 — empty off camp: os.secure, and never aws.params
####################################################################
out="$(run_verify local@unix 0 2>&1)"; rc=$?
record "empty, off camp (a laptop)" "$out"
check "off camp · names os.secure as the vault" bash -c "[[ \"\$1\" == *'--vault os.secure'* ]]" _ "$out"
check "off camp · warns off aws.params" bash -c "[[ \"\$1\" == *'never --vault aws.params on this box'* ]]" _ "$out"
check "off camp · rc 1" test "$rc" -eq 1

####################################################################
# arm 5 — a required row that is not <org>:<env>:<key>: refused by name
####################################################################
printf 'a-dummy-value' > "$fixture/state/value"
out="$(KEYS_ROWS='ahbode:VENDOR_KEY' run_verify cloud@hetzner.hetzbot 0 2>&1)"; rc=$?
record "a malformed required row" "$out"
check "malformed · ✋ names the row and the shape it owes" \
  bash -c "[[ \"\$1\" == *\"✋ ConstraintError: the required row 'ahbode:VENDOR_KEY' is not '<org>:<env>:<key>'\"* ]]" _ "$out"
check "malformed · rc 1" test "$rc" -eq 1
check "malformed · the value never reaches the page" bash -c "[[ \"\$1\" != *'a-dummy-value'* ]]" _ "$out"
rm -f "$fixture/state/value"

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.keys-verify-names-each-verdict.snap" name=transcript actual="$transcript" || failed=1

echo ""
if [[ $failed -ne 0 ]]; then
  echo "💥 MalfunctionError: prove.keys-verify-names-each-verdict: a claim did not hold" >&2
  exit 1
fi
echo "🌲 all claims held ✔"
