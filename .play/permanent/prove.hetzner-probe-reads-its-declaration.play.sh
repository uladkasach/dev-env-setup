#!/usr/bin/env bash
######################################################################
# .what = drive the hetzner platform probe, and its rung in the ladder,
#         against a fixture declaration
#
# .why
#   - the probe is what keeps a hetzner grove off the laptop's member join
#   - its live box sits behind the tailnet, so no laptop run can reach it
#   - the LOGIC needs no box: a fixture file stands in for /etc/grove/platform
#   - the play redefines `grove_env_platform_file`, so no root and no
#     runtime override is involved
#
# guarantee:
#   - READ-ONLY outside its own mktemp dir, removed on exit
#   - each derive runs in a subshell, so no stub leaks between arms
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$HERE/src/grove.env.sh"

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
grove_env_platform_file() { printf '%s' "$fixture/platform"; }

failed=0
pass() { echo "   • $1 ✔"; }
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }

echo "🌲 prove.hetzner-probe-reads-its-declaration"

####################################################################
# the probe alone — the declaration's value decides, never its presence
####################################################################
expect_probe() {
  local label="$1" want="$2" rc
  grove_env_probe_hetzner_hetzbot && rc=0 || rc=$?
  [[ "$rc" == "$want" ]] && pass "probe · ${label} → rc=${rc}"
  [[ "$rc" != "$want" ]] && fail "probe · ${label} → rc=${rc}, expected rc=${want}"
  return 0
}

rm -f "$fixture/platform"
expect_probe "no declaration" 1

printf 'aws.ec2\n' > "$fixture/platform"
expect_probe "another platform's declaration" 1

: > "$fixture/platform"
expect_probe "an empty declaration (presence alone)" 1

printf 'hetzner.hetzbot\n' > "$fixture/platform"
expect_probe "the hetzner declaration" 0

printf 'hetzner.hetzbot\nsome later line\n' > "$fixture/platform"
expect_probe "the hetzner declaration, first line only" 0

# a dir at the path is present and readable, yet declares naught — a fault, rc 2
rm -f "$fixture/platform"
mkdir "$fixture/platform"
expect_probe "a dir at the declaration path (a fault, not a decline)" 2
rmdir "$fixture/platform"

# an unreadable declaration is a FAULT, rc 2 — never rc 1, which reads "not hetzner"
# root reads a mode-000 file, so the unreadable rows cannot be built under root.
#   the play then DECLINES, out loud and by its exit code — a silent pass proves naught
declined=0
unreadable_ok=1
if [[ "$(id -u)" -eq 0 ]]; then
  echo "   ✋ ConstraintError: the unreadable-declaration rows cannot be built as root — run this play as a user" >&2
  declined=1
  unreadable_ok=0
fi
if [[ "$unreadable_ok" -eq 1 ]]; then
  printf 'hetzner.hetzbot\n' > "$fixture/platform"
  chmod 000 "$fixture/platform"
  expect_probe "an unreadable declaration (a fault, not a decline)" 2
  chmod 644 "$fixture/platform"
fi

####################################################################
# the rung in the ladder — each derive in its own subshell, with the
#   other probes stubbed, so the ORDER is what is proven
####################################################################
derive_with() {
  # $1 = ec2 probe answer, $2 = declaration (or 'absent'), $3 = DISPLAY,
  # $4 = SSH_CONNECTION (optional), $5 = 'unreadable' to chmod the declaration 000
  #   — the real file, the real probe, the real halt; built only off root (see above)
  (
    ec2_answer="$1"
    unset GROVE_ENV_SERVER WAYLAND_DISPLAY XDG_SESSION_TYPE SSH_CONNECTION SSH_TTY
    export DISPLAY="$3"
    [[ -z "$3" ]] && unset DISPLAY
    [[ -n "${4:-}" ]] && export SSH_CONNECTION="$4"
    rm -f "$fixture/platform"
    [[ "$2" != "absent" ]] && printf '%s\n' "$2" > "$fixture/platform"
    [[ "${5:-}" == unreadable ]] && chmod 000 "$fixture/platform"
    # the stub reads the arm's answer from the subshell, never its own $1
    grove_env_probe_aws_ec2()      { [[ "$ec2_answer" == "yes" ]]; }
    grove_env_probe_aws_ec2_imds() { return 1; }
    grove_env_derive >/dev/null 2>"$fixture/err" || { echo "rc=$?"; return 0; }
    echo "$GROVE_ENV_SERVER"
  )
}

got="$(derive_with yes hetzner.hetzbot '')"
[[ "$got" == "cloud@aws.ec2" ]] && pass "ladder · ec2 answers first, even beside a declaration → ${got}"
[[ "$got" != "cloud@aws.ec2" ]] && fail "ladder · ec2 + declaration → '${got}', expected cloud@aws.ec2"

got="$(derive_with no hetzner.hetzbot ':0')"
[[ "$got" == "cloud@hetzner.hetzbot" ]] && pass "ladder · the declaration outranks a forwarded display → ${got}"
[[ "$got" != "cloud@hetzner.hetzbot" ]] && fail "ladder · declaration + DISPLAY → '${got}', expected cloud@hetzner.hetzbot"

got="$(derive_with no absent ':0')"
[[ "$got" == "local@unix" ]] && pass "ladder · a laptop with no declaration is untouched → ${got}"
[[ "$got" != "local@unix" ]] && fail "ladder · no declaration + DISPLAY → '${got}', expected local@unix"

got="$(derive_with no absent '')"
[[ "$got" == "rc=2" ]] && pass "ladder · a headless box with no declaration is refused → ${got}"
[[ "$got" != "rc=2" ]] && fail "ladder · headless, no declaration → '${got}', expected rc=2"
grep -qsF "$fixture/platform" "$fixture/err" && pass "ladder · the refusal names the file the probe read"
grep -qsF "$fixture/platform" "$fixture/err" || fail "ladder · the refusal does not name the file the probe read"
refusal_text="$(sed "s#$fixture#<fixture>#g" "$fixture/err")"

# an unreadable declaration HALTS the ladder — a display beside it must not answer
#   local@unix. a real mode-000 file, so the halt text snapped below is the real one
halt_text=""
if [[ "$unreadable_ok" -eq 1 ]]; then
  got="$(derive_with no hetzner.hetzbot ':0' '' unreadable)"
  [[ "$got" == "rc=2" ]] && pass "ladder · an unreadable declaration halts, even beside a display → ${got}"
  [[ "$got" != "rc=2" ]] && fail "ladder · unreadable declaration + DISPLAY → '${got}', expected rc=2 (never local@unix)"
  grep -qsF "is not a readable file" "$fixture/err" && pass "ladder · the halt names the permission fault"
  grep -qsF "is not a readable file" "$fixture/err" || fail "ladder · the halt does not name the permission fault"
  halt_text="$(sed "s#$fixture#<fixture>#g" "$fixture/err")"

  # the ec2 dmi rung reads hardware, so it still answers first — as it does beside
  #   a READABLE declaration. only the rungs after it are halted
  got="$(derive_with yes hetzner.hetzbot ':0' '' unreadable)"
  [[ "$got" == "cloud@aws.ec2" ]] && pass "ladder · ec2 answers first, even beside an unreadable declaration → ${got}"
  [[ "$got" != "cloud@aws.ec2" ]] && fail "ladder · ec2 + unreadable declaration → '${got}', expected cloud@aws.ec2"
  chmod 644 "$fixture/platform"
fi

# a set-but-malformed server value refuses, and names the three the probes detect
got="$( ( GROVE_ENV_SERVER=notatier; export GROVE_ENV_SERVER
          grove_env_derive >/dev/null 2>"$fixture/err" || echo "rc=$?" ) )"
[[ "$got" == "rc=2" ]] && pass "ladder · a malformed server value is refused → ${got}"
[[ "$got" != "rc=2" ]] && fail "ladder · GROVE_ENV_SERVER=notatier → '${got}', expected rc=2"
malformed_text="$(cat "$fixture/err")"

got="$(derive_with no absent 'localhost:10.0' '192.0.2.1 50000 192.0.2.2 22')"
[[ "$got" == "rc=2" ]] && pass "ladder · a forwarded display over ssh, no declaration, is refused → ${got}"
[[ "$got" != "rc=2" ]] && fail "ladder · ssh -X, no declaration → '${got}', expected rc=2 (never local@unix)"

####################################################################
# the member join's own guard — independent of the tier
####################################################################
# shellcheck source=/dev/null
source "$HERE/src/grove.provision/5.devtools/5.23.tailscale/configure.upsert.sh"

why_with() {
  # $1 = SSH_CONNECTION, $2 = SSH_TTY, $3 = declaration (or 'absent')
  (
    unset SSH_CONNECTION SSH_TTY
    [[ -n "$1" ]] && export SSH_CONNECTION="$1"
    [[ -n "$2" ]] && export SSH_TTY="$2"
    rm -f "$fixture/platform"
    [[ "$3" != "absent" ]] && printf '%s\n' "$3" > "$fixture/platform"
    grove_provision_5_23_tailscale_seat_remote_why
  )
}

got="$(why_with '' '' absent)"
[[ -z "$got" ]] && pass "join guard · a local seat with no declaration reads local"
[[ -n "$got" ]] && fail "join guard · local seat → '${got}', expected empty"

got="$(why_with '192.0.2.1 50000 192.0.2.2 22' '' absent)"
[[ "$got" == *SSH_CONNECTION* ]] && pass "join guard · an ssh seat reads remote"
[[ "$got" != *SSH_CONNECTION* ]] && fail "join guard · ssh seat → '${got}', expected SSH_CONNECTION named"

got="$(why_with '' '/dev/pts/3' absent)"
[[ "$got" == *SSH_TTY* ]] && pass "join guard · an ssh tty reads remote"
[[ "$got" != *SSH_TTY* ]] && fail "join guard · ssh tty → '${got}', expected SSH_TTY named"

got="$(why_with '' '' 'some.platform')"
[[ "$got" == *declares* ]] && pass "join guard · any platform declaration reads remote"
[[ "$got" != *declares* ]] && fail "join guard · declaration → '${got}', expected the file named"

####################################################################
# the three texts a human reads when the derivation stops — every byte snapped
####################################################################
# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
snapdir="$HERE/.play/permanent/prove.hetzner-probe-reads-its-declaration.snap"
play_snap_verify dir="$snapdir" name=derive.refusal actual="$refusal_text" || failed=1
play_snap_verify dir="$snapdir" name=derive.malformed actual="$malformed_text" || failed=1
[[ "$unreadable_ok" -eq 1 ]] && { play_snap_verify dir="$snapdir" name=derive.unreadable-halt actual="$halt_text" || failed=1; }

[[ "$failed" -ne 0 ]] && exit 1
if [[ "$declined" -ne 0 ]]; then
  echo "🌙 declined: one row could not be built on this seat — see the ✋ above" >&2
  exit 2
fi
echo "🌲 all claims held ✔"
exit 0
