#!/usr/bin/env bash
######################################################################
# .what = drive `grove_ssh_platform_findsert` through each verdict a boot can
#         read: SET, KEEP, DIFFERS, a sudo that will not run, and an ssh that
#         cannot connect
#
# .why  = the boot lays `/etc/grove/platform` over ground, and a declaration it
#         did not write must never be overwritten. the verdict word is what the
#         boot prints, and the fault text is what its halt hands the human, so
#         each arm's output is pinned in one transcript snapshot
#
# guarantee:
#   - hermetic: `ssh` and `sudo` are stubs in a mktemp dir; the stub ssh runs the
#     seat's command under `sh`, with the platform path redirected into the fixture
#   - arm 6 is a LIVE read of the boot's own source: it proves the boot reaches
#     this writer and that its halt names the read a human owes
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPS="$HERE/.agent/repo=.this/role=any/skills/git.grove.ssh.operations.sh"
BOOT="$HERE/.agent/repo=.this/role=any/skills/git.grove.provision.boot.sh"
for f in "$OPS" "$BOOT"; do
  [[ -r "$f" ]] || { echo "✋ ConstraintError: the subject $f is absent" >&2; exit 2; }
done

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/state"

failed=0
check() {
  local label="$1"; shift
  if "$@"; then echo "   • $label ✔"; else echo "   💥 MalfunctionError: $label" >&2; failed=1; fi
}
has() { [[ "$1" == *"$2"* ]]; }

transcript=""
record() { transcript+="## $1"$'\n'"${2//$fixture/<fix>}"$'\n'"   (rc $3)"$'\n\n'; }

echo "🌲 prove.platform-findsert-names-each-verdict"

# ssh: `-o X` flags and the seat are dropped; the last arg is the seat's command.
#      a `down` state answers as an ssh that cannot connect
printf '#!/usr/bin/env bash\nS=%q\nF=%q\n[[ -f "$S/down" ]] && { echo "ssh: connect to host <host> port 22: Connection refused" >&2; exit 255; }\ncmd="${!#}"\nexec sh -c "${cmd//\\/etc\\/grove\\/platform/$F}"\n' \
  "$fixture/state" "$fixture/platform" > "$fixture/bin/ssh"
# sudo: `-n` is dropped; a `nosudo` state answers as a seat whose sudo wants a password
printf '#!/usr/bin/env bash\nS=%q\n[[ -f "$S/nosudo" ]] && { echo "sudo: a password is required" >&2; exit 1; }\n[[ "$1" == -n ]] && shift\nexec "$@"\n' \
  "$fixture/state" > "$fixture/bin/sudo"
chmod +x "$fixture/bin/ssh" "$fixture/bin/sudo"

run_findsert() {  # $1 = the platform the boot wants
  (
    export PATH="$fixture/bin:$PATH"
    # shellcheck source=/dev/null
    source "$OPS"
    grove_ssh_platform_findsert "<grove>.ground" "$1"
  )
}

####################################################################
# arm 1 — absent: SET, and the file holds the declared line
####################################################################
out="$(run_findsert hetzner.hetzbot 2>&1)"; rc=$?
record "absent → the boot lays it" "$out" "$rc"
check "absent · rc 0" test "$rc" -eq 0
check "absent · the verdict is the one word SET" test "$out" = SET
check "absent · the file holds the declared platform" test "$(cat "$fixture/platform")" = hetzner.hetzbot

####################################################################
# arm 2 — same: KEEP, and no byte moves
####################################################################
cp "$fixture/platform" "$fixture/state/before"
out="$(run_findsert hetzner.hetzbot 2>&1)"; rc=$?
record "same → the boot keeps it" "$out" "$rc"
check "same · rc 0" test "$rc" -eq 0
check "same · the verdict is the one word KEEP" test "$out" = KEEP
check "same · no byte moved" cmp -s "$fixture/platform" "$fixture/state/before"

####################################################################
# arm 3 — another platform declared: DIFFERS, rc 3, never overwritten
####################################################################
printf 'aws.ec2\n' > "$fixture/platform"
out="$(run_findsert hetzner.hetzbot 2>&1)"; rc=$?
record "another platform declared → the boot refuses" "$out" "$rc"
check "differs · rc 3" test "$rc" -eq 3
check "differs · it names what the box holds" test "$out" = "DIFFERS aws.ec2"
check "differs · the declaration it did not write stands" test "$(cat "$fixture/platform")" = aws.ec2
rm -f "$fixture/platform"

####################################################################
# arm 4 — absent, and the seat's sudo wants a password: the fault is relayed
####################################################################
touch "$fixture/state/nosudo"
out="$(run_findsert hetzner.hetzbot 2>&1)"; rc=$?
record "absent, the seat's sudo wants a password" "$out" "$rc"
check "nosudo · a non-zero exit" test "$rc" -ne 0
check "nosudo · sudo's own reason is relayed" has "$out" "sudo: a password is required"
check "nosudo · never reads as SET" bash -c '[[ "$1" != *SET* ]]' _ "$out"
check "nosudo · no file was laid" test ! -e "$fixture/platform"
rm -f "$fixture/state/nosudo"

####################################################################
# arm 5 — the seat is unreachable: ssh's own fault is relayed
####################################################################
touch "$fixture/state/down"
out="$(run_findsert hetzner.hetzbot 2>&1)"; rc=$?
record "the seat is unreachable" "$out" "$rc"
check "down · rc 255, ssh's own" test "$rc" -eq 255
check "down · ssh's own reason is relayed" has "$out" "Connection refused"
rm -f "$fixture/state/down"

####################################################################
# arm 6 — the boot is wired to this writer; its rendered lines live in
#   `prove.boot-steps-name-each-verdict`, which drives the step itself
####################################################################
boot="$(cat "$BOOT")"
check "boot · sources the ssh operations" has "$boot" 'source "$(dirname "${BASH_SOURCE[0]}")/git.grove.ssh.operations.sh"'
check "boot · sources the step operations" has "$boot" 'source "$(dirname "${BASH_SOURCE[0]}")/git.grove.provision.boot.operations.sh"'
check "boot · step 1 declares the platform through the step" has "$boot" 'boot_platform_declare'
check "boot · no second copy of the writer remains" bash -c '[[ "$1" != *"_platform_findsert_at"* ]]' _ "$boot"

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.platform-findsert-names-each-verdict.snap" name=transcript actual="$transcript" || failed=1

echo ""
if [[ $failed -ne 0 ]]; then
  echo "💥 MalfunctionError: prove.platform-findsert-names-each-verdict: a claim did not hold" >&2
  exit 1
fi
echo "🌲 all claims held ✔"
