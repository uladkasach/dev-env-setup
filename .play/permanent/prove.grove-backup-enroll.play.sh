#!/usr/bin/env bash
######################################################################
# .what = the backup bundle enrolls a camp grove, declines every other box, and its
#         verify reads each arm of the status it renders
#
# .why  the enroll is the critipath every backup rides on (case=4, e1–e3), and its
#   only proof was a boot on a live grove. this drives the REAL upsert and verify
#   against a fixture root: `systemctl` and `sudo` are stubs, every file act is real
#
# .the cases
#   1. the unit files say what the design says (user, priority, bound, schedule)
#   2. off `cloud@*`, both phases decline and write naught
#   3. the camper seat, unconverged, declines to the seat with root in the runtime's own
#      words (snapped); writes naught
#   4. ground's apply installs the four files, reloads, then enables the timer
#   5. a second apply on a converged box asks no root and writes naught
#   6. the verify: enrolled and in its grace · ✓ · ✗ FAILED · ⏳ past the grace · drift ·
#      NOT ENROLLED (timer off) · NOT ENROLLED (a file absent)
######################################################################
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REAL="$HERE/src/grove.provision/5.devtools/5.26.backup"

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

failed=0
pass() { echo "   • $1 ✔"; }
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }
claim() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }

echo "🌲 prove.grove-backup-enroll"

######################################################################
# 1. the unit files, as written
######################################################################
has_line() { grep -qxF -- "$2" "$REAL/$1"; }
claim "service · runs as camper, once per fire" bash -c 'grep -qxF User=camper "$1" && grep -qxF Type=oneshot "$1"' _ "$REAL/grove-backup.service"
claim "service · runs the installed agent" has_line grove-backup.service ExecStart=/usr/local/lib/grove-backup/grove-backup
claim "service · takes the box's spare cycles only" \
  bash -c 'for l in Nice=10 CPUWeight=10 IOWeight=10 IOSchedulingClass=idle; do grep -qxF "$l" "$1" || exit 1; done' _ "$REAL/grove-backup.service"
claim "service · no start bound: each aws call carries its own" has_line grove-backup.service TimeoutStartSec=infinity
claim "service · its state dir is world-readable, for infra's stats" has_line grove-backup.service StateDirectoryMode=0755
claim "timer · fires every 15 minutes, and a missed fire runs on wake" \
  bash -c 'grep -qxF "OnCalendar=*:0/15" "$1" && grep -qxF Persistent=true "$1" && grep -qxF WantedBy=timers.target "$1"' _ "$REAL/grove-backup.timer"
claim "timer · systemd reads its calendar" systemd-analyze calendar '*:0/15' >/dev/null

######################################################################
# the fixture: a checkout of the bundle whose library reads a fixture state dir,
#   a root the four files install into, and stubs for systemctl and sudo
######################################################################
GROVE_SRC="$fixture/src"
mkdir -p "$GROVE_SRC/grove.provision/5.devtools"
cp -a "$REAL" "$GROVE_SRC/grove.provision/5.devtools/"
STATE="$fixture/state"; mkdir -p "$STATE"
printf '\ngrove_backup_state_dir() { printf %%s %q; }\n' "$STATE" \
  >>"$GROVE_SRC/grove.provision/5.devtools/5.26.backup/grove.backup.operations.sh"
ROOT="$fixture/root"

# shellcheck source=/dev/null
source "$GROVE_SRC/grove.provision/5.devtools/5.26.backup/_.sh"
# shellcheck source=/dev/null
source "$GROVE_SRC/grove.provision/5.devtools/5.26.backup/provision.upsert.sh"
# shellcheck source=/dev/null
source "$GROVE_SRC/grove.provision/5.devtools/5.26.backup/provision.verify.sh"
eval "$(declare -f grove_provision_5_26_backup_files | sed '1s/grove_provision_5_26_backup_files/real_files/')"
grove_provision_5_26_backup_files() { real_files | awk -F'\t' -v r="$ROOT" 'BEGIN { OFS = "\t" } { $2 = r $2; print }'; }

LOG="$fixture/calls.log"; : >"$LOG"
CAN_SUDO=1 TIMER_ENABLED=disabled TIMER_ACTIVE=inactive SERVICE_STATE=inactive TIMER_SINCE=now
FAIL_INSTALL=0 FAIL_RELOAD=0 FAIL_ENABLE=0
pkg_can_sudo()    { [[ "$CAN_SUDO" -eq 1 ]]; }
pkg_assert_sudo() { [[ "$CAN_SUDO" -eq 1 ]]; }
# the decline a camper reads is the RUNTIME's own, never a stub: lifted from bundle.upgrade.sh
eval "$(sed -n '/^bundle\.root\.declines() {/,/^}/p' "$HERE/src/bundle.upgrade.sh")"
declare -F bundle.root.declines >/dev/null || { echo "💥 MalfunctionError: bundle.root.declines not found in src/bundle.upgrade.sh" >&2; exit 1; }
# sudo runs its command as this seat: `install` drops the root owner it cannot set
sudo() {
  echo "sudo $*" >>"$LOG"
  local -a args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in -o|-g) shift 2 ;; *) args+=("$1"); shift ;; esac
  done
  [[ "${args[0]}" == install && "$FAIL_INSTALL" -eq 1 ]] && { echo "install: cannot create regular file: Permission denied" >&2; return 1; }
  "${args[@]}"
}
systemctl() {
  echo "systemctl $*" >>"$LOG"
  case "$*" in
    "is-enabled grove-backup.timer") echo "$TIMER_ENABLED"; [[ "$TIMER_ENABLED" == enabled ]] ;;
    "is-active grove-backup.timer")  echo "$TIMER_ACTIVE";  [[ "$TIMER_ACTIVE" == active ]] ;;
    daemon-reload) [[ "$FAIL_RELOAD" -eq 0 ]] ;;
    "enable --now grove-backup.timer") [[ "$FAIL_ENABLE" -eq 0 ]] || return 1; TIMER_ENABLED=enabled TIMER_ACTIVE=active; return 0 ;;
    "show grove-backup.timer -p NextElapseUSecRealtime --value") date -u -d '+10 min' '+%a %Y-%m-%d %H:%M:%S UTC' ;;
    "show grove-backup.timer -p ActiveEnterTimestamp --value") date -u -d "$TIMER_SINCE" '+%a %Y-%m-%d %H:%M:%S UTC' ;;
    "show -p ActiveState --value grove-backup.service") echo "$SERVICE_STATE" ;;
    *) return 1 ;;
  esac
}
installed() { local f; for f in /usr/local/lib/grove-backup/grove-backup /usr/local/lib/grove-backup/grove.backup.operations.sh /etc/systemd/system/grove-backup.service /etc/systemd/system/grove-backup.timer; do [[ -f "$ROOT$f" ]] || return 1; done; }
none_installed() { [[ -z "$(find "$ROOT" -type f 2>/dev/null)" ]]; }

######################################################################
# 2. off cloud@*, both phases decline
######################################################################
GROVE_ENV_SERVER=local@unix
out="$(grove_provision_5_26_backup_provision_upsert 2>&1)"; rc=$?
claim "decline · a laptop's upsert declines, rc 0, and names why" \
  bash -c '[[ "$1" -eq 0 && "$2" == *"🌙 a local@unix box holds no camp aws identity"* ]]' _ "$rc" "$out"
snap_decline="# upsert, local@unix (exit $rc)"$'\n'"$out"$'\n\n'
out="$(grove_provision_5_26_backup_provision_verify 2>&1)"; rc=$?
claim "decline · a laptop's verify declines, rc 0" test "$rc" -eq 0 -a -n "$out"
snap_decline+="# verify, local@unix (exit $rc)"$'\n'"$out"$'\n'
claim "decline · naught is installed off cloud@*" none_installed

######################################################################
# 3. the camper seat, with no root, declines to the seat that has it
######################################################################
GROVE_ENV_SERVER=cloud@hetzner.hetzbot CAN_SUDO=0
out="$(grove_provision_5_26_backup_provision_upsert 2>&1)"; rc=$?
claim "camper · an unconverged seat with no root declines, rc 0" \
  bash -c '[[ "$1" -eq 0 && "$2" == *"🌙 the grove backup agent is a BOX-WIDE fact, and this seat has no root"* ]]' _ "$rc" "$out"
claim "camper · the decline names what it saw, and that no step is owed" \
  bash -c '[[ "$1" == *"⇒ grove-backup.timer is inactive"* && "$1" == *"no step is owed by this seat, and none by a human"* ]]' _ "$out"
snap_camper="# upsert, cloud@hetzner.hetzbot, the camper seat (exit $rc)"$'\n'"$out"$'\n'
claim "camper · naught is installed, and no root is asked" bash -c '! grep -q "^sudo" "$1"' _ "$LOG"
claim "camper · naught is installed" none_installed

######################################################################
# 4. ground's apply
######################################################################
CAN_SUDO=1
grove_provision_5_26_backup_provision_upsert >"$fixture/apply.out" 2>&1; rc=$?
claim "ground · the apply exits 0" test "$rc" -eq 0
claim "ground · the four files land" installed
claim "ground · the agent is executable, the rest are not" \
  test "$(stat -c %a "$ROOT/usr/local/lib/grove-backup/grove-backup")" == 755 \
    -a "$(stat -c %a "$ROOT/etc/systemd/system/grove-backup.timer")" == 644
claim "ground · systemd reloads BEFORE the timer is enabled" \
  bash -c 'r="$(grep -n "systemctl daemon-reload" "$1" | head -n 1 | cut -d: -f1)"; e="$(grep -n "systemctl enable --now grove-backup.timer" "$1" | head -n 1 | cut -d: -f1)"; [[ -n "$r" && -n "$e" && "$r" -lt "$e" ]]' _ "$LOG"
claim "ground · the timer is enabled and started" test "$TIMER_ENABLED $TIMER_ACTIVE" == "enabled active"

######################################################################
# 5. the second apply writes naught
######################################################################
: >"$LOG"
out="$(grove_provision_5_26_backup_provision_upsert 2>&1)"; rc=$?
claim "converged · the second apply reads ✔ and exits 0" \
  bash -c '[[ "$1" -eq 0 && "$2" == *"match this checkout, and the timer is enabled ✔"* ]]' _ "$rc" "$out"
claim "converged · it asks no root" bash -c '! grep -q "^sudo" "$1"' _ "$LOG"
snap_converged="$out"

# the camper seat on a box ground already converged: the common state at boot. it verifies
#   alone, never a decline that reads as a failure, and asks no root
CAN_SUDO=0; : >"$LOG"
out="$(grove_provision_5_26_backup_provision_upsert 2>&1)"; rc=$?
claim "camper, converged · reads ✔ and exits 0, with no root" \
  bash -c '[[ "$1" -eq 0 && "$2" == *"match this checkout, and the timer is enabled ✔"* ]]' _ "$rc" "$out"
claim "camper, converged · never a 🌙 decline" bash -c '[[ "$1" != *"🌙"* ]]' _ "$out"
claim "camper, converged · asks no root" bash -c '! grep -q "^sudo" "$1"' _ "$LOG"
snap_camper+=$'\n'"# upsert, cloud@hetzner.hetzbot, the camper seat, the box converged (exit $rc)"$'\n'"$out"$'\n'
CAN_SUDO=1

######################################################################
# 7. the installed agent, EXECUTED: its command line, as the box and a human run it
######################################################################
AGENT="$ROOT/usr/local/lib/grove-backup/grove-backup"
cli() { local label="$1"; shift; local o rc; o="$("$AGENT" "$@" 2>&1)"; rc=$?; snap_cli+="\$ grove-backup $* (exit $rc)"$'\n'"$o"$'\n\n'; CLI_RC=$rc; CLI_OUT="$o"; }
snap_cli=""
cli help --help
claim "agent · --help prints its usage, exit 0, and starts no pass" \
  bash -c '[[ "$1" -eq 0 && "$2" == *"usage:"* && ! -e "$3/status.json" ]]' _ "$CLI_RC" "$CLI_OUT" "$STATE"
cli bogus --bogus
claim "agent · an unknown word is refused, exit 2, and starts no pass" \
  bash -c '[[ "$1" -eq 2 && "$2" == *"unknown argument"* && ! -e "$3/status.json" ]]' _ "$CLI_RC" "$CLI_OUT" "$STATE"
cli lineextra --line extra
claim "agent · --line with another word is refused, exit 2" test "$CLI_RC" -eq 2
# a fresh ok status: the ✓ arm reads no live systemd, so the snap holds on any box
printf '{"verdict":"ok","at":"%s","last_ok":"%s","put":2,"skipped":5,"failures":[]}\n' \
  "$(date -u +%Y-%m-%dT%H:%MZ)" "$(date -u +%Y-%m-%dT%H:%MZ)" >"$STATE/status.json"
cli line --line
claim "agent · --line prints the one status line, exit 0" \
  bash -c '[[ "$1" -eq 0 && "$2" == "✓ "*" ago · 2 put · 5 skipped" ]]' _ "$CLI_RC" "$CLI_OUT"
rm -f "$STATE/status.json"
cli adopt --adopt
claim "agent · --adopt claims the prefix, exit 0" test "$CLI_RC" -eq 0 -a -f "$STATE/prefix.claimed"
rm -f "$STATE/prefix.claimed"
out="$( source "$AGENT"; id() { echo 0; }; grove_backup_main 2>&1 )"; rc=$?
snap_cli+="\$ sudo grove-backup (exit $rc)"$'\n'"$out"$'\n'
claim "agent · a pass as root is refused, exit 2, and writes no status" \
  bash -c '[[ "$1" -eq 2 && "$2" == *"never as root"* && ! -e "$3/status.json" ]]' _ "$rc" "$out" "$STATE"

######################################################################
# 6. the verify, one arm at a time
######################################################################
snap_verify=""
verify() {
  grove_provision_5_26_backup_provision_verify >"$fixture/verify.out" 2>&1
  local rc=$?
  snap_verify+="# verify (exit $rc)"$'\n'"$(cat "$fixture/verify.out")"$'\n\n'
  return "$rc"
}
verify; rc=$?
claim "verify · enrolled, no run yet, in its grace · ✔" \
  test "$rc" -eq 0 -a "$(grep -c 'grove backup · enrolled · next run in' "$fixture/verify.out")" -eq 1

now_iso() { date -u +%Y-%m-%dT%H:%MZ; }
printf '{"verdict":"ok","at":"%s","last_ok":"%s","put":2,"skipped":5,"failures":[]}\n' "$(now_iso)" "$(now_iso)" >"$STATE/status.json"
verify; rc=$?
# the stamp holds the minute, so a run under load that crosses one reads `1m ago`: any age
#   under the stale bound is the claim, never a minute-exact one
claim "verify · the last run ok · ✓, rc 0" test "$rc" -eq 0 -a "$(grep -cE '✓ [0-9]+m ago · 2 put · 5 skipped' "$fixture/verify.out")" -eq 1

printf '{"verdict":"failed","cause":"1 of 7 units did not land","fix":"free space on the disk","at":"%s","last_ok":"%s","failures":[{"unit":"user=c/org=a/repo=w/tree=w","why":"disk · 3 MiB free"}]}\n' \
  "$(now_iso)" "$(date -u -d '-5 days' +%Y-%m-%dT%H:%MZ)" >"$STATE/status.json"
verify; rc=$?
claim "verify · the last run failed · rc 1, 💥, and when it last succeeded" \
  test "$rc" -eq 1 -a "$(grep -c '💥 MalfunctionError: grove backup · FAILED · 1 of 7 units did not land · 0m · last ok 5d ago' "$fixture/verify.out")" -eq 1
claim "verify · it names the fix, and each failed unit with its why" \
  test "$(grep -c -e '├─ free space on the disk' -e '├─ user=c/org=a/repo=w/tree=w: disk · 3 MiB free' "$fixture/verify.out")" -eq 2

rm -f "$STATE/status.json"
TIMER_SINCE='-3 hours' SERVICE_STATE=activating
verify; rc=$?
claim "verify · a first run still at work past the grace · ⏳, never a ✗" \
  test "$rc" -eq 0 -a "$(grep -c '⏳ the first run is at work' "$fixture/verify.out")" -eq 1
SERVICE_STATE=inactive
verify; rc=$?
claim "verify · enrolled past its grace with no run · ✗ STALE · never" \
  test "$rc" -eq 1 -a "$(grep -c 'STALE · never' "$fixture/verify.out")" -eq 1

old_iso="$(date -u -d '-3 hours' +%Y-%m-%dT%H:%MZ)"
printf '{"verdict":"ok","at":"%s","last_ok":"%s","put":1,"skipped":1,"failures":[]}\n' "$old_iso" "$old_iso" >"$STATE/status.json"
SERVICE_STATE=activating
verify
claim "verify · a long pass at work over an older ok · ⏳, never ✗ STALE" \
  test "$(grep -c '⏳ a pass is at work · last ok 3h ago' "$fixture/verify.out")" -eq 1
SERVICE_STATE=inactive
verify
claim "verify · the same status with no pass at work · ✗ STALE" \
  test "$(grep -c 'STALE · last ok 3h ago' "$fixture/verify.out")" -eq 1
rm -f "$STATE/status.json"

printf '\n# drift\n' >>"$ROOT/etc/systemd/system/grove-backup.timer"
verify; rc=$?
claim "verify · an installed file that drifts from the checkout · ✋, named, rc 1" \
  test "$rc" -eq 1 -a "$(grep -c 'grove-backup.timer DIFFERS from this checkout' "$fixture/verify.out")" -eq 1

# the files match, but the timer is off: a half-enrolled box, both timer states named
cp "$REAL/grove-backup.timer" "$ROOT/etc/systemd/system/grove-backup.timer"
TIMER_ACTIVE=inactive TIMER_ENABLED=disabled
verify; rc=$?
claim "verify · the files match but the timer is off · ✋ NOT ENROLLED, both states named, rc 1" \
  test "$rc" -eq 1 -a "$(grep -cxF '   ✋ ConstraintError: grove backup · NOT ENROLLED · timer is inactive, disabled' "$fixture/verify.out")" -eq 1
claim "verify · the timer arm names the apply as its fix" \
  test "$(grep -cxF '      └─ fix: rhx grove.provision --what 5.26.backup --mode apply' "$fixture/verify.out")" -eq 1

# an installed file is absent: the box was never enrolled, or lost a file since
mv "$ROOT/etc/systemd/system/grove-backup.service" "$fixture/service.aside"
verify; rc=$?
claim "verify · an installed file is absent · ✋ NOT ENROLLED, rc 1" \
  test "$rc" -eq 1 -a "$(grep -cxF '   ✋ ConstraintError: grove backup · NOT ENROLLED' "$fixture/verify.out")" -eq 1
claim "verify · the absent arm names the apply as its fix, and reads no timer" \
  bash -c '[[ "$(grep -cxF "      └─ fix: rhx grove.provision --what 5.26.backup --mode apply" "$1")" -eq 1 && "$(grep -c "timer is" "$1")" -eq 0 ]]' _ "$fixture/verify.out"

######################################################################
# the apply's failure arms — each names what stays live, and never prints the ✔ row
#   each runs on a fresh root, so a prior arm's files never read as converged
######################################################################
snap_fail=""
fail_arm() {
  local label="$1" rc
  ROOT="$fixture/root.fail"; rm -rf "$ROOT"; TIMER_ENABLED=disabled TIMER_ACTIVE=inactive; : >"$LOG"
  grove_provision_5_26_backup_provision_upsert >"$fixture/fail.out" 2>&1; rc=$?
  snap_fail+="# $label (exit $rc)"$'\n'"$(cat "$fixture/fail.out")"$'\n\n'
  return "$rc"
}

FAIL_INSTALL=1; fail_arm "upsert, a file the install refuses"; rc=$?; FAIL_INSTALL=0
claim "fail · install refused · rc 1, named, the prior agent kept" \
  bash -c '[[ "$1" -eq 1 ]] && grep -qF "💥 MalfunctionError: could not install" "$2" && grep -qF "the agent stays at its prior version" "$2"' _ "$rc" "$fixture/fail.out"
claim "fail · install refused · the timer is never touched" bash -c '! grep -q "systemctl daemon-reload\|enable --now" "$1"' _ "$LOG"

FAIL_RELOAD=1; fail_arm "upsert, a daemon-reload that fails"; rc=$?; FAIL_RELOAD=0
claim "fail · reload · rc 1, and names that the old units stay live" \
  bash -c '[[ "$1" -eq 1 ]] && grep -qF "💥 MalfunctionError: systemctl daemon-reload failed" "$2" && grep -qF "the OLD definitions stay live" "$2"' _ "$rc" "$fixture/fail.out"
claim "fail · reload · the timer is never enabled over stale units" bash -c '! grep -q "enable --now" "$1"' _ "$LOG"

FAIL_ENABLE=1; fail_arm "upsert, a timer that will not enable"; rc=$?; FAIL_ENABLE=0
claim "fail · enable · rc 1, and names that the work has one copy" \
  bash -c '[[ "$1" -eq 1 ]] && grep -qF "💥 MalfunctionError: could not enable grove-backup.timer" "$2" && grep -qF "unpushed work has one copy" "$2"' _ "$rc" "$fixture/fail.out"
claim "fail · enable · never the started row" bash -c '! grep -qF "enabled and started" "$1"' _ "$fixture/fail.out"

# the checkout lacks a source: the runtime's own files list, one row pointed at naught
eval "$(declare -f grove_provision_5_26_backup_files | sed '1s/grove_provision_5_26_backup_files/files_whole/')"
grove_provision_5_26_backup_files() { files_whole | awk -F'\t' -v a="$fixture/absent" 'BEGIN { OFS = "\t" } NR == 1 { $1 = a "/grove-backup" } { print }'; }
fail_arm "upsert, a checkout that lacks the agent"; rc=$?
eval "$(declare -f files_whole | sed '1s/files_whole/grove_provision_5_26_backup_files/')"
claim "fail · absent source · rc 1, named as an incomplete checkout" \
  bash -c '[[ "$1" -eq 1 ]] && grep -qF "💥 MalfunctionError: no grove-backup at" "$2" && grep -qF "own checkout is incomplete" "$2"' _ "$rc" "$fixture/fail.out"
claim "fail · absent source · naught is installed" bash -c '! grep -q "^sudo install" "$1"' _ "$LOG"

# a box with no jq: the apply installs it first, and says so
command() { [[ "$1" == -v && "$2" == jq ]] && return 1; builtin command "$@"; }
pkg_install() { echo "pkg_install $*" >>"$LOG"; }
fail_arm "upsert, a box with no jq"; rc=$?
unset -f command
claim "jq · absent · it lands first, its row printed, and the apply goes on" \
  bash -c '[[ "$1" -eq 0 ]] && grep -qF "• jq installed — the backup status is json" "$2" && grep -q "^pkg_install jq" "$3"' _ "$rc" "$fixture/fail.out" "$LOG"
ROOT="$fixture/root"

######################################################################
# the texts ground reads on every boot, and a human at the agent — every byte snapped
#   masked: the fixture dir, each age, each clock time
######################################################################
# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
snapdir="$HERE/.play/permanent/prove.grove-backup-enroll.snap"
mask() {
  sed -e "s#$fixture#<fixture>#g" -e 's#\b[0-9]\+[smhd] ago#<age> ago#g' -e 's#in [0-9]\+[smhd]\b#in <age>#g' \
      -e 's#· [0-9]\+[smhd] · #· <age> · #g' -e 's#[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}[T ][0-9:]\+Z\?#<time>#g'
}
play_snap_verify dir="$snapdir" name=upsert.apply     actual="$(mask <"$fixture/apply.out")" || failed=1
play_snap_verify dir="$snapdir" name=upsert.converged actual="$(mask <<<"$snap_converged")"  || failed=1
play_snap_verify dir="$snapdir" name=verify.arms      actual="$(mask <<<"$snap_verify")"     || failed=1
play_snap_verify dir="$snapdir" name=agent.cli        actual="$(mask <<<"$snap_cli")"        || failed=1
play_snap_verify dir="$snapdir" name=decline.off-cloud actual="$(mask <<<"$snap_decline")"   || failed=1
play_snap_verify dir="$snapdir" name=decline.camper   actual="$(mask <<<"$snap_camper")"     || failed=1
play_snap_verify dir="$snapdir" name=upsert.fails     actual="$(mask <<<"$snap_fail")"       || failed=1

if [[ "$failed" -ne 0 ]]; then
  # every verify arm, each under its own header: verify.out alone holds only the LAST arm,
  #   which would show the drift arm's own planted drift beside an unrelated failed claim
  sed 's/^/      │ /' "$fixture/apply.out" <(printf '%s' "$snap_verify") "$LOG" >&2
  echo "💥 MalfunctionError: a claim failed" >&2
  exit 1
fi
echo ""
echo "🌲 all claims held ✔"
