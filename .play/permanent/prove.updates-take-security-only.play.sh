#!/usr/bin/env bash
######################################################################
# .what = drive `1.14.updates` through every variant a human can read: each of
#         its four phases, with root and without, over a box that holds the
#         policy, lacks it, or holds one a later drop-in overrides
#
# .why  = the bundle's ✋ / 💥 / 🌙 lines are its contract with the human at the
#         apply. a fix-text that drifts is caught only where its bytes are pinned,
#         so every arm's output lands in one transcript snapshot
#
# guarantee:
#   - hermetic: dpkg, apt, sudo, systemctl, and apt-config are stubs in a mktemp
#     dir; the live drop-in path is redirected into it. no root, no apt
#   - the root decline is the REAL runtime's (`bundle.root.declines`), so the
#     snapshot holds the fix-text a laptop's human actually reads
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
B="$HERE/src/grove.provision/1.system/1.14.updates"
for f in _.sh provision.upsert.sh provision.verify.sh configure.upsert.sh configure.verify.sh; do
  [[ -r "$B/$f" ]] || { echo "✋ ConstraintError: the subject $B/$f is absent" >&2; exit 2; }
done

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/state" "$fixture/live"

failed=0
check() {
  local label="$1"; shift
  if "$@"; then echo "   • $label ✔"; else echo "   💥 MalfunctionError: $label" >&2; failed=1; fi
}
has() { [[ "$1" == *"$2"* ]]; }

transcript=""
record() {
  local text="${2//$fixture/<fix>}"
  transcript+="## $1"$'\n'"${text//$HERE/<root>}"$'\n\n'
}

echo "🌲 prove.updates-take-security-only"

# systemctl: `is-enabled` reads the state file; `enable` writes it, unless masked;
#   `show -p Environment` answers as systemd would once it has read the live unit drop-in
{
  printf '#!/usr/bin/env bash\nS=%q\nL=%q\n' "$fixture/state" "$fixture/live"
  cat <<'STUB'
case "$1" in
  is-enabled) [[ -f "$S/timer-masked" ]] && { echo masked; exit 1; }; cat "$S/timer" 2>/dev/null || echo disabled ;;
  unmask) touch "$S/unmask-called" ;;
  enable) [[ -f "$S/timer-masked" ]] && { echo "Failed to enable unit: Unit file is masked." >&2; exit 1; }
          [[ -f "$S/enable-refused" ]] && { echo "Failed to enable unit: Access denied" >&2; exit 1; }
          echo enabled > "$S/timer" ;;
  daemon-reload) [[ -f "$S/reload-fails" ]] && { echo "Failed to reload daemon: Access denied" >&2; exit 1; }; touch "$S/reloaded" ;;
  show) if [[ -f "$L/unit.d/52grove-keep-conffiles.conf" ]]; then
          echo "Environment=APT_CONFIG=$L/grove-unattended-keep-conffiles.conf"
        else echo "Environment="; fi ;;
esac
STUB
} > "$fixture/bin/systemctl"
# apt-config: prints the dump the arm laid, or fails as a broken apt would. under an
#   APT_CONFIG that names a readable file, it adds that file's Dpkg::Options, as apt does
{
  printf '#!/usr/bin/env bash\nS=%q\n' "$fixture/state"
  cat <<'STUB'
[[ -f "$S/aptconfig-fails" ]] && { echo "E: stub apt-config could not parse its config" >&2; exit 100; }
cat "$S/dump"
if [[ -n "${APT_CONFIG:-}" && -r "$APT_CONFIG" ]] && grep -q force-confold "$APT_CONFIG"; then
  echo 'DPkg::Options "";'
  echo 'DPkg::Options:: "--force-confdef";'
  echo 'DPkg::Options:: "--force-confold";'
fi
STUB
} > "$fixture/bin/apt-config"
# sudo: a binary, since `timeout` execs it; runs as this user, minus the owner flags only root may pass
printf '#!/usr/bin/env bash\na=(); skip=0\nfor x in "$@"; do (( skip )) && { skip=0; continue; }; case "$x" in -o|-g) skip=1 ;; *) a+=("$x") ;; esac; done\nexec "${a[@]}"\n' \
  > "$fixture/bin/sudo"
# apt-cache: `policy` prints the archive lines the arm laid (the box's apt sources)
{
  printf '#!/usr/bin/env bash\nS=%q\n' "$fixture/state"
  cat <<'STUB'
[[ "$1" == policy ]] && cat "$S/policy" 2>/dev/null
exit 0
STUB
} > "$fixture/bin/apt-cache"
chmod +x "$fixture/bin/systemctl" "$fixture/bin/apt-config" "$fixture/bin/sudo" "$fixture/bin/apt-cache"

# a pop!_os box: its own VERSION_CODENAME, ubuntu's in UBUNTU_CODENAME, as the laptop reads
printf 'ID=pop\nVERSION_CODENAME=noble\nUBUNTU_CODENAME=noble\n' > "$fixture/state/os-release"
export GROVE_PROVISION_1_14_OS_RELEASE="$fixture/state/os-release"
# the archive lines `apt-cache policy` prints on that laptop (measured 2026-11-17)
policy_good() {
  printf '%s\n' \
    ' 500 http://us.archive.ubuntu.com/ubuntu noble-security/main amd64 Packages' \
    '     release v=24.04,o=Ubuntu,a=noble-security,n=noble,l=Ubuntu,c=main,b=amd64'
}
policy_good > "$fixture/state/policy"

# a merged config as apt would print it with the bundle's drop-in in force
dump_good() {
  cat <<'DUMP'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
Unattended-Upgrade::Origins-Pattern:: "origin=Ubuntu,archive=${distro_codename}-security";
Unattended-Upgrade::Origins-Pattern:: "origin=UbuntuESMApps,archive=${distro_codename}-apps-security";
Unattended-Upgrade::Automatic-Reboot "false";
DUMP
}

# $1 = phase (provision.upsert|provision.verify|configure.upsert|configure.verify)
# $2 = root here (yes|no) · $3 = server tag
run_phase() {
  (
    export PATH="$fixture/bin:$PATH" GROVE_SRC="$HERE/src" GROVE_ENV_SERVER="$3"
    # shellcheck source=/dev/null
    source "$HERE/src/bundle.upgrade.sh"
    if [[ "$2" == yes ]]; then pkg_can_sudo() { return 0; }; else pkg_can_sudo() { return 1; }; fi
    slug="1.14.updates.$1"
    pkg_assert_sudo() { return 0; }
    pkg_present() { [[ -f "$fixture/state/pkg" ]]; }
    pkg_install() {
      [[ -f "$fixture/state/install-fails" ]] && { echo "E: stub apt refused the install" >&2; return 100; }
      touch "$fixture/state/pkg"
    }
    # shellcheck source=/dev/null
    source "$B/_.sh"
    grove_provision_1_14_updates_dropin() { printf '%s' "$fixture/live/52grove-unattended-upgrades"; }
    grove_provision_1_14_updates_keepconf() { printf '%s' "$fixture/live/grove-unattended-keep-conffiles.conf"; }
    grove_provision_1_14_updates_unitdropin() { printf '%s' "$fixture/live/unit.d/52grove-keep-conffiles.conf"; }
    # a partial checkout: one declared file is not on disk
    [[ -f "$fixture/state/declared-absent" ]] && grove_provision_1_14_updates_files() {
      printf '%s\t%s\n' "$fixture/checkout/52grove-unattended-upgrades" "$fixture/live/52grove-unattended-upgrades"
    }
    # shellcheck source=/dev/null
    source "$B/$1.sh"
    "grove_provision_1_14_updates_${1//./_}"
  )
}

####################################################################
# arm 1 — provision: the package
####################################################################
out="$(run_phase provision.verify yes cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "provision.verify, the package absent" "$out"
check "verify · absent package is a ✋ (rc 1)" test "$rc" -eq 1
check "verify · names the sudo -v fix" has "$out" "sudo -v && rhx grove.provision --what 1.14.updates --mode apply"

out="$(run_phase provision.upsert no local@unix 2>&1)"; rc=$?
record "provision.upsert, absent, a laptop seat with no root" "$out"
check "upsert · no root declines (rc 0)" test "$rc" -eq 0
check "upsert · the decline hands the laptop its sudo -v line" has "$out" "sudo -v && rhx grove.provision --what 1.14.updates --mode apply"
check "upsert · no root installs no package" test ! -f "$fixture/state/pkg"

touch "$fixture/state/install-fails"
out="$(run_phase provision.upsert yes cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "provision.upsert, absent, root here, apt refuses" "$out"
check "upsert · a failed install is a 💥 (rc 1)" test "$rc" -eq 1
check "upsert · the failure names itself" has "$out" "MalfunctionError: unattended-upgrades did not install"
rm -f "$fixture/state/install-fails"

out="$(run_phase provision.upsert yes cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "provision.upsert, absent, root here" "$out"
check "upsert · root installs (rc 0)" test "$rc" -eq 0
check "upsert · the package is present after" test -f "$fixture/state/pkg"
check "upsert · the install reports what it changed" has "$out" "unattended-upgrades installed"

out="$(run_phase provision.upsert yes cloud@hetzner.hetzbot 2>&1)"
record "provision.upsert, present" "$out"
check "upsert · a held package asks for no install" has "$out" "already installed"

out="$(run_phase provision.verify yes cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "provision.verify, present" "$out"
check "verify · present package ✔ (rc 0)" test "$rc" -eq 0

####################################################################
# arm 2 — configure.upsert: the drop-in and the timer
####################################################################
out="$(run_phase configure.upsert no cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.upsert, no drop-in, a grove seat with no root" "$out"
check "configure · no root declines (rc 0)" test "$rc" -eq 0
check "configure · no root writes no drop-in" test ! -e "$fixture/live/52grove-unattended-upgrades"

# a MASKED timer is an admin's refusal: the apply never lifts it, fails loud (rc 2),
#   and names the unmask — so the verify's fix (this apply) still has an exit
touch "$fixture/state/timer-masked"
out="$(run_phase configure.upsert yes cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.upsert, root here, the timer masked" "$out"
check "configure · a masked timer is a ✋ (rc 2), never overridden" \
  bash -c '[[ "$1" -eq 2 && ! -e "$2" && -e "$3" ]]' _ "$rc" "$fixture/state/unmask-called" "$fixture/state/timer-masked"
check "configure · the ✋ names the unmask, then the re-apply" \
  has "$out" $'sudo systemctl unmask apt-daily.timer apt-daily-upgrade.timer\n        rhx grove.provision --what 1.14.updates --mode apply'
check "configure · the drop-in still landed" cmp -s "$B/52grove-unattended-upgrades" "$fixture/live/52grove-unattended-upgrades"
rm -rf "$fixture/state/timer-masked" "$fixture/state/timer" "$fixture/state/reloaded" "$fixture/live/"*

# the enable itself refused: the one road left is a 💥 that names the read
touch "$fixture/state/enable-refused"
out="$(run_phase configure.upsert yes cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.upsert, root here, the enable refused" "$out"
check "configure · a refused enable is a 💥 (rc 1)" test "$rc" -eq 1
check "configure · the 💥 names how to read why" has "$out" "read why: systemctl status apt-daily.timer apt-daily-upgrade.timer"
rm -rf "$fixture/state/enable-refused" "$fixture/state/timer" "$fixture/state/reloaded" "$fixture/live/"*

chmod 0555 "$fixture/live"
out="$(run_phase configure.upsert yes cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.upsert, root here, the apt dir unwritable" "$out"
check "configure · a failed write is a 💥 (rc 1)" test "$rc" -eq 1
check "configure · the 💥 nests install's own words under it" has "$out" "      ⇒ it said: install: cannot create regular file"
check "configure · the 💥 names the read" has "$out" "      read why: ls -ld "
chmod 0755 "$fixture/live"

# a partial checkout: the declared file is absent, so the apply halts before any root ask
touch "$fixture/state/declared-absent"
out="$(run_phase configure.upsert yes cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.upsert, a declared file absent from the checkout" "$out"
check "configure · an absent declared file is a 💥 (rc 1)" test "$rc" -eq 1
check "configure · it names the partial checkout" has "$out" "the declared file is absent at $fixture/checkout/52grove-unattended-upgrades"
check "configure · it writes no byte" test ! -e "$fixture/live/52grove-unattended-upgrades"
rm -f "$fixture/state/declared-absent"

# the unit drop-in lands and systemd refuses the reload: the run is not done
touch "$fixture/state/reload-fails"
out="$(run_phase configure.upsert yes cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.upsert, root here, the daemon-reload refused" "$out"
check "configure · a refused reload is a 💥 (rc 1)" test "$rc" -eq 1
check "configure · it says the file is on disk and unread" has "$out" "52grove-keep-conffiles.conf is on disk and systemd did not reload it"
rm -rf "$fixture/state/reload-fails" "$fixture/state/timer" "$fixture/live/"*

out="$(run_phase configure.upsert yes cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.upsert, root here, first apply" "$out"
check "configure · root writes and enables (rc 0)" test "$rc" -eq 0
check "configure · the drop-in equals the declared one" cmp -s "$B/52grove-unattended-upgrades" "$fixture/live/52grove-unattended-upgrades"
check "configure · the timer is enabled" test "$(cat "$fixture/state/timer")" = enabled
check "configure · the keepconf file equals the declared one" cmp -s "$B/grove-unattended-keep-conffiles.conf" "$fixture/live/grove-unattended-keep-conffiles.conf"
check "configure · the unit drop-in equals the declared one" cmp -s "$B/apt-daily-upgrade.keep-conffiles.conf" "$fixture/live/unit.d/52grove-keep-conffiles.conf"
check "configure · systemd was reloaded for the unit drop-in" test -f "$fixture/state/reloaded"
check "configure · the global drop-in sets no Dpkg::Options" bash -c '! grep -q "^Dpkg::Options" "$1"' _ "$B/52grove-unattended-upgrades"

cp "$fixture/live/52grove-unattended-upgrades" "$fixture/state/after1"
rm -f "$fixture/state/reloaded"
out="$(run_phase configure.upsert no cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.upsert, current, no root" "$out"
check "configure · a current box asks for no root" has "$out" "both apt timers current ✔"
check "configure · a re-run writes no byte" cmp -s "$fixture/state/after1" "$fixture/live/52grove-unattended-upgrades"
check "configure · a re-run reloads no unit" test ! -f "$fixture/state/reloaded"

####################################################################
# arm 3 — configure.verify: apt's MERGED config, not only our file
####################################################################
dump_good > "$fixture/state/dump"
out="$(run_phase configure.verify no cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.verify, all in force" "$out"
check "verify · every claim ✔ (rc 0)" test "$rc" -eq 0
check "verify · each of the three owned files is compared" test "$(grep -c 'matches the declared policy ✔' <<<"$out")" -eq 3
check "verify · no phase calls a function its file lacks" bash -c '[[ "$1" != *"command not found"* ]]' _ "$out"

dump_good | grep -v 'Periodic::Unattended-Upgrade' > "$fixture/state/dump"
out="$(run_phase configure.verify no cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.verify, a later drop-in turns off the daily run" "$out"
check "verify · no daily run is a ✋ (rc 1)" test "$rc" -eq 1

dump_good | sed 's/Automatic-Reboot "false"/Automatic-Reboot "true"/' > "$fixture/state/dump"
out="$(run_phase configure.verify no cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.verify, a later drop-in allows a reboot" "$out"
check "verify · a reboot allowed is a ✋ (rc 1)" test "$rc" -eq 1

{ dump_good; echo 'Unattended-Upgrade::Allowed-Origins:: "${distro_id}:${distro_codename}-updates";'; } > "$fixture/state/dump"
out="$(run_phase configure.verify no cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.verify, a non-security origin allowed" "$out"
check "verify · a non-security origin is a ✋ (rc 1)" test "$rc" -eq 1
check "verify · it names where to read the origin" has "$out" "read it: grep -rn 'Origins' /etc/apt/apt.conf.d/"

dump_good > "$fixture/state/dump"; echo disabled > "$fixture/state/timer"
out="$(run_phase configure.verify no cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.verify, the timer disabled" "$out"
check "verify · a disabled timer is a ✋ (rc 1)" test "$rc" -eq 1
echo enabled > "$fixture/state/timer"

####################################################################
# arm 4 — the conffile choice is the unattended run's ALONE
####################################################################
mv "$fixture/live/unit.d/52grove-keep-conffiles.conf" "$fixture/state/unit.bak"
out="$(run_phase configure.verify no cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.verify, the unit hands the run no APT_CONFIG" "$out"
check "keepconf · an unwired unit is a ✋ (rc 1)" test "$rc" -eq 1
check "keepconf · it names the skipped imagemagick update" has "$out" "skips any upgrade that would prompt over an edited conffile"
mv "$fixture/state/unit.bak" "$fixture/live/unit.d/52grove-keep-conffiles.conf"

{ dump_good; echo 'DPkg::Options:: "--force-confdef";'; echo 'DPkg::Options:: "--force-confold";'; } > "$fixture/state/dump"
out="$(run_phase configure.verify no cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.verify, a global drop-in keeps every conffile" "$out"
check "keepconf · a global choice is a ✋ (rc 1)" test "$rc" -eq 1
check "keepconf · it names the human's own run" has "$out" "EVERY apt run keeps a local conffile silently, a human's included"
dump_good > "$fixture/state/dump"

touch "$fixture/state/aptconfig-fails"
out="$(run_phase configure.verify no cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "configure.verify, apt-config itself fails" "$out"
check "verify · a broken apt-config is a 💥, never a policy ✋ (rc 1)" test "$rc" -eq 1
check "verify · the 💥 keeps apt-config's own reason" has "$out" "stub apt-config could not parse"
check "verify · it is never read as 'not daily'" bash -c '[[ "$1" != *"does not run unattended-upgrade daily"* ]]' _ "$out"
rm -f "$fixture/state/aptconfig-fails"

####################################################################
# arm 5 — the allowed origin must be an archive this box's apt serves
#   📜 2026-11-17: `${distro_id}:…-security` read `Pop:noble-security` on pop!_os,
#   which no archive carries — claim 2c was green and the run upgraded naught
####################################################################
check "policy · the declared drop-in keys on the archive Origin, never \${distro_id}" \
  bash -c '! grep -v "^//" "$1" | grep -q "distro_id" && grep -q "origin=Ubuntu,archive=\${distro_codename}-security" "$1"' _ "$B/52grove-unattended-upgrades"

printf '%s\n' ' 500 http://apt.pop-os.org/release noble/main amd64 Packages' \
  '     release v=24.04,o=pop-os-release,a=noble,n=noble,l=pop-os-release,c=main,b=amd64' > "$fixture/state/policy"
out="$(run_phase configure.verify no local@unix 2>&1)"; rc=$?
record "configure.verify, no apt source serves the security archive" "$out"
check "archive · an unserved security archive is a ✋ (rc 1)" test "$rc" -eq 1
check "archive · it names the archive it looked for" has "$out" "no apt source here serves o=Ubuntu,a=noble-security"
check "archive · it names how to read the sources" has "$out" "apt-cache policy"
policy_good > "$fixture/state/policy"

out="$(run_phase configure.verify no local@unix 2>&1)"; rc=$?
record "configure.verify, a pop!_os laptop that serves ubuntu's security archive" "$out"
check "archive · pop!_os reads ubuntu's codename and its archive ✔ (rc 0)" test "$rc" -eq 0
check "archive · the ✔ names the archive" has "$out" "(o=Ubuntu,a=noble-security)"

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.updates-take-security-only.snap" name=transcript actual="$transcript" || failed=1

echo ""
if [[ $failed -ne 0 ]]; then
  echo "💥 MalfunctionError: prove.updates-take-security-only: a claim did not hold" >&2
  exit 1
fi
echo "🌲 all claims held ✔"
