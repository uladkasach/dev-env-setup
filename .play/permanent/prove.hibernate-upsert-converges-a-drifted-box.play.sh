#!/usr/bin/env bash
######################################################################
# prove.hibernate-upsert-converges-a-drifted-box — `1.15.hibernate`'s upsert
# heals every gap the drift reader names, in the order systemd needs, says what
# it undid, leaves a converged box untouched, and declines on a seat with no root
#
# .what = sources the bundle's `_.sh` and `configure.upsert.sh`, points the
#         declared paths into a temp dir, and puts stubs on PATH:
#           - `sudo` runs its command as this seat (it drops `-o`/`-g`, which
#             only root may pass)
#           - `systemctl` holds unit state in files, and logs every call
#         `pkg_can_sudo` and `bundle.root.declines` are stood in for here, so
#         the arm sets which seat ran the apply
#
# .the arms
#   retirenote the stopgap's retire     → one `⇒` line: a box now holds on activity, never presence
#   drifted    old bytes, a reload owed, a drop-in, the stopgap, a masked and
#              stopped timer → drift empty after; reload logged before unmask and
#              enable; drop-in and its emptied `.d` dir gone; the apply names the
#              unmask and the re-arm
#   again      the same box, applied a second time → "match", no write logged
#   reload     bytes match, a reload owed → the reload runs, drift empty after
#   unloaded   a drop-in written with no reload → retired in the SAME apply
#   retimer    an active timer whose file changed → `try-restart`, named
#   restart    an active timer, only a reload owed → `try-restart` still runs
#   mode       matched bytes at mode 644 → held at 755, named, drift empty
#   absent     no declared file on the box → all three written, drift empty
#   nosource   this checkout lacks a declared file → ✋ exit 2 with git.repo.pull, box unchanged
#   staleresult / unhealthy   a last result from before the apply / from a converged box
#   *fails     unmask, enable, restart, mktemp, install, chown, rm (drop-in, stopgap), rmdir
#              each fail → 💥 exit 1, with its fix
#   resetfirst the last result is cleared before the timer arms
#   resetfails a reset that fails is loud, and the apply still passes, so its verify runs
#   symlink    a dst linked to a seat's file with the right bytes → named, replaced, target untouched
#   alone      each gap by itself on a converged box heals in one apply
#   camper     a drifted box, a seat with no root → 🌙, no write logged, box unchanged
#   laptop     the runtime's decline on `local@unix`, for a provision-phase slug → `sudo -v && rhx`, the bundle named
#   offec2     the dispatch on `local@unix` → 🌙 declined, no phase runs
#   onec2      the dispatch on `cloud@aws.ec2` → upsert, then verify
#   dispatch.plan   the REAL `bundle.upgrade`, `--mode plan`, on a drifted box → the upsert "would run",
#                   the verify still runs and names the drift, no write, exit 1
#   dispatch.apply  the same, `--mode apply` → the upsert runs, the verify proves the box converged, exit 0
#
# .the write — `rule.forbid.repair-plays` exception 2: a temp dir, removed by a trap
#
# ⚠️ .what it does NOT prove — the real `install -o root`, the real systemd, and
#   a real ground seat. the ground apply on an ec2 grove reads those
#
# usage:
#   rhx play.run --play prove.hibernate-upsert-converges-a-drifted-box
######################################################################
set -uo pipefail

# the checkout is this file's own, never the cwd: rhx guarantees no cwd
REPO="${GROVE_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src}"
BUNDLE="$REPO/grove.provision/1.system/1.15.hibernate"
FIX=""
# the restore reports whether it took: a fixture that survives fails the play (`rule.forbid.repair-plays`, condition 4)
trap '[[ -n "$FIX" ]] && rm -rf "$FIX"; [[ -n "$FIX" && -e "$FIX" ]] && { echo "   ✋ residue SURVIVED — $FIX"; exit 1; }' EXIT
FAILED=0

[[ -f "$BUNDLE/configure.upsert.sh" ]] || { echo "✋ ConstraintError: no bundle at $BUNDLE"; exit 2; }
export GROVE_SRC="$REPO"
# shellcheck source=/dev/null
source "$BUNDLE/_.sh"
# shellcheck source=/dev/null
source "$BUNDLE/configure.upsert.sh"
# shellcheck source=/dev/null
source "$BUNDLE/configure.verify.sh"

FIX="$(mktemp -d)"
SD="$FIX/sd"
mkdir -p "$FIX/bin"

# a sudo that runs as this seat — `install -o root -g root` would need real root
#   it logs each call, so an arm can prove a converged box asked for no root
cat > "$FIX/bin/sudo" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$SUDO_LOG"
[[ "$1" == "-n" ]] && exit 0
# an arm arms one command to fail by a flag file beside the log: $SUDO_LOG.fail.<cmd>
[[ -e "$SUDO_LOG.fail.$1" ]] && { echo "sudo: $1: an injected fault" >&2; exit 1; }
if [[ "$1" == install ]]; then
  args=(); skip=0
  for a in "$@"; do
    [[ $skip -eq 1 ]] && { skip=0; continue; }
    [[ "$a" == -o || "$a" == -g ]] && { skip=1; continue; }
    args+=("$a")
  done
  exec "${args[@]}"
fi
exec "$@"
STUB

# a systemctl that holds unit state in files under $SD — the one model both bundle plays share.
# a failed source must halt: the play would then drive the box's real systemctl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/prove.hibernate.systemctl.fixture" \
  || { echo "✋ ConstraintError: the systemctl fixture would not load beside this play"; exit 2; }
hibernate_systemctl_stub "$FIX/bin" "$SD"
chmod +x "$FIX/bin/sudo"
export PATH="$FIX/bin:$PATH"

# the seat this arm stands in: CAN=0 holds root, CAN=1 is a camper
CAN=0
pkg_can_sudo() { return "$CAN"; }
pkg_assert_sudo() { return "$CAN"; }
# the runtime's own decline pair, lifted by name from src/bundle.upgrade.sh, so the camper
# arm reads the text a camper reads — never a stub that drops its lines
RUNTIME_ROOT="$(awk '/^bundle\.root\.(declines|owns)\(\) \{$/,/^\}$/' "$REPO/bundle.upgrade.sh")"
[[ "$RUNTIME_ROOT" == *"bundle.root.declines() {"*"bundle.root.owns() {"* ]] \
  || { echo "✋ ConstraintError: bundle.root.declines and bundle.root.owns were not found in $REPO/bundle.upgrade.sh"; exit 2; }
eval "$RUNTIME_ROOT"

DROPIN_DIR="$FIX/box/etc/idle-hibernate.service.d"

# .what = a box with every gap: old bytes, reload owed, a drop-in, the stopgap, a masked stopped timer
drifted() {
  rm -rf "$FIX/box" "$SD"; mkdir -p "$FIX/box/bin" "$FIX/box/etc" "$DROPIN_DIR" "$SD"
  GROVE_PROVISION_1_15_HIBERNATE_PAIRS=(
    "$FIX/box/bin/idle-hibernate.sh:755"
    "$FIX/box/etc/idle-hibernate.service:644"
    "$FIX/box/etc/idle-hibernate.timer:644"
  )
  # this seat stands in for root: the files it writes are this seat's
  GROVE_PROVISION_1_15_HIBERNATE_OWNER="$(id -u):$(id -g)"
  GROVE_PROVISION_1_15_HIBERNATE_STOPGAP="$FIX/box/bin/idle-hibernate-holds.sh"
  GROVE_PROVISION_1_15_HIBERNATE_UNIT_ROOTS=("$FIX/box/etc")
  # the records too: a grove that runs this play holds a real /run/idle-hibernate.last, and a
  # verify that read it would snap that box's state rather than the fixture's
  GROVE_PROVISION_1_15_HIBERNATE_RECORD="$FIX/box/idle-hibernate.last"
  GROVE_PROVISION_1_15_HIBERNATE_SLEEP_RECORD="$FIX/box/idle-hibernate.last-sleep"
  rm -f "$SUDO_LOG".fail.*
  echo "# old check" > "$FIX/box/bin/idle-hibernate.sh"
  cp "$BUNDLE/idle-hibernate.service" "$BUNDLE/idle-hibernate.timer" "$FIX/box/etc/"
  chmod 644 "$FIX/box/etc/idle-hibernate.service" "$FIX/box/etc/idle-hibernate.timer"
  echo "[Service]" > "$DROPIN_DIR/stopgap-crews.conf"
  echo "$DROPIN_DIR/stopgap-crews.conf" > "$SD/dropins.idle-hibernate.service"
  touch "$FIX/box/bin/idle-hibernate-holds.sh" "$SD/needreload.idle-hibernate.service"
  echo masked > "$SD/enabled"; echo inactive > "$SD/active"
  : > "$SD/log"; : > "$SUDO_LOG"
}
export SUDO_LOG="$FIX/sudo.log"

OUT=""; URUNS=0
# .what = run the upsert; keep stdout and stderr APART for the snap, and joined for the patterns
apply() {
  USTDOUT="$(grove_provision_1_15_hibernate_configure_upsert 2>"$FIX/uerr")"; RC=$?
  USTDERR="$(cat "$FIX/uerr")"
  OUT="$USTDOUT"$'\n'"$USTDERR"
  URUNS=$((URUNS + 1))
}
# .what = the apply transcript snap: EVERY run's stdout, stderr, and systemctl writes, masked
# .why every run: each is one box a ground seat can meet, and a pattern proves a phrase, never
#   the line around it. `arm` keeps each run once, under the first arm that judges it
USNAP=""; UKEPT=0
# the fixture's owner is this seat's uid:gid, so it is masked: the snap holds on any seat, root included
upmask() { printf '%s' "$1" | sed -E -e "s#$FIX#<fix>#g" -e "s# $(id -u):$(id -g)\b# <uid>:<gid>#g" -e 's/\.grove-provision\.[A-Za-z0-9]+/.grove-provision.<tmp>/g'; }
ukeep() {
  [[ "$URUNS" -gt "$UKEPT" ]] || return 0
  UKEPT=$URUNS
  USNAP+="## $1 (exit $RC)"$'\n'"### stdout"$'\n'"$(upmask "$USTDOUT")"$'\n'"### stderr"$'\n'"$(upmask "$USTDERR")"$'\n'
  USNAP+="### systemctl"$'\n'"$(upmask "$(cat "$SD/log")")"$'\n\n'
}
# .what = name an arm, and keep the run it judges
arm() { echo "   ├─ arm '$1'"; ukeep "$1"; }
quote() {
  echo "   │     │ exit=$RC"
  printf '%s\n' "$OUT" | sed 's/^/   │     │ out: /'
  sed 's/^/   │     │ systemctl /' "$SD/log"
  printf '%s\n' "$(grove_provision_1_15_hibernate_drift)" | sed 's/^/   │     │ drift: /'
}
# .what = the line number of the first logged systemctl call that starts with $1
at() { grep -n -m1 "^$1" "$SD/log" | cut -d: -f1; }
writes() { grep -cE '^(daemon-reload|unmask|enable|try-restart)' "$SD/log"; }

echo "🔭 does the upsert heal each gap, in order, and say what it undid?"

drifted; apply
arm drifted
WHY=""
[[ $RC -eq 0 ]] || WHY="the apply failed"
[[ -z "$WHY" && -n "$(grove_provision_1_15_hibernate_drift)" ]] && WHY="drift remains after the apply"
[[ -z "$WHY" && ( -z "$(at daemon-reload)" || -z "$(at unmask)" || "$(at daemon-reload)" -gt "$(at unmask)" || "$(at unmask)" -gt "$(at enable)" ) ]] \
  && WHY="the reload did not precede the unmask, or the unmask did not precede the enable"
[[ -z "$WHY" && ( -e "$DROPIN_DIR" || -e "$FIX/box/bin/idle-hibernate-holds.sh" ) ]] && WHY="a drop-in, its dir, or the stopgap survived"
[[ -z "$WHY" && ( "$OUT" != *"unmasked"*"hand hold is undone"* || "$OUT" != *"re-armed"*"hand stop is undone"* ) ]] && WHY="the apply did not name the hand hold it undid"
[[ -z "$WHY" && "$(stat -c %a "$FIX/box/bin/idle-hibernate.sh")" != 755 ]] && WHY="the check landed without mode 0755"
if [[ -n "$WHY" ]]; then echo "   │  ✋ $WHY"; quote; FAILED=1
else echo "   │  ✔ converged: reload → unmask → enable, drop-in and stopgap retired, each undo named"; fi

# the retire changes what holds a box — from presence to activity — and the apply says so then
arm retirenote
if [[ "$OUT" != *"retired the stopgap pre-check"*"⇒ a box now holds on activity, never on presence"*"for 3h sleeps — keep one pane that prints"* ]]; then
  echo "   │  ✋ the stopgap was retired with no word that a quiet crew now sleeps"; quote; FAILED=1
else echo "   │  ✔ the retire names the shift: activity, never presence, and the 3h a quiet crew has"; fi

: > "$SD/log"; : > "$SUDO_LOG"; apply
arm again
if [[ "$OUT" != *"match this checkout"* || "$(writes)" -ne 0 || -s "$SUDO_LOG" ]]; then
  echo "   │  ✋ a converged box was written again, or asked for root"; quote; sed 's/^/   │     │ sudo /' "$SUDO_LOG"; FAILED=1
else echo "   │  ✔ untouched — no write and no sudo on a converged box"; fi

drifted
cp "$BUNDLE/idle-hibernate.sh" "$FIX/box/bin/"; chmod 755 "$FIX/box/bin/idle-hibernate.sh"
rm -f "$DROPIN_DIR/stopgap-crews.conf" "$FIX/box/bin/idle-hibernate-holds.sh"
echo enabled > "$SD/enabled"; echo active > "$SD/active"
apply
arm reload
if [[ -z "$(at daemon-reload)" || -n "$(grove_provision_1_15_hibernate_drift)" ]]; then echo "   │  ✋ a reload owed went unrun"; quote; FAILED=1
else echo "   │  ✔ a reload owed on matched bytes runs, and the drift clears"; fi

drifted
echo "[Service]" > "$DROPIN_DIR/hand-hold.conf"
echo "$DROPIN_DIR/hand-hold.conf" > "$SD/queued.idle-hibernate.service"
apply
arm unloaded
if [[ $RC -ne 0 || -e "$DROPIN_DIR/hand-hold.conf" || -n "$(grove_provision_1_15_hibernate_drift)" ]]; then
  echo "   │  ✋ a drop-in written with no reload survived one apply"; quote; FAILED=1
else echo "   │  ✔ a drop-in systemd had not loaded yet is retired in the same apply"; fi

drifted
cp "$BUNDLE/idle-hibernate.sh" "$FIX/box/bin/"; chmod 0755 "$FIX/box/bin/idle-hibernate.sh"
rm -f "$DROPIN_DIR/stopgap-crews.conf" "$FIX/box/bin/idle-hibernate-holds.sh" "$SD/needreload.idle-hibernate.service"
echo "# old schedule" > "$FIX/box/etc/idle-hibernate.timer"
echo enabled > "$SD/enabled"; echo active > "$SD/active"
apply
arm retimer
if [[ -z "$(at try-restart)" || "$OUT" != *"restarted on its declared schedule"* ]]; then
  echo "   │  ✋ an active timer whose file was rewritten kept its old schedule"; quote; FAILED=1
else echo "   │  ✔ a rewritten timer is restarted on its declared schedule"; fi

# a run that died after the rename left the bytes right and the old schedule live;
# the next apply finds only a reload owed, and must still restart the timer
drifted
cp "$BUNDLE/idle-hibernate.sh" "$FIX/box/bin/"; chmod 755 "$FIX/box/bin/idle-hibernate.sh"
rm -f "$DROPIN_DIR/stopgap-crews.conf" "$FIX/box/bin/idle-hibernate-holds.sh"
touch "$SD/needreload.idle-hibernate.timer"
echo enabled > "$SD/enabled"; echo active > "$SD/active"
apply
arm restart
if [[ -z "$(at try-restart)" || -n "$(grove_provision_1_15_hibernate_drift)" ]]; then
  echo "   │  ✋ an active timer was left on whatever schedule it last loaded"; quote; FAILED=1
else echo "   │  ✔ an active timer is restarted on every apply, not only when this run rewrote it"; fi

# matched bytes at the wrong mode: a 644 check never runs, and the apply must hold 755
drifted
cp "$BUNDLE/idle-hibernate.sh" "$FIX/box/bin/"; chmod 644 "$FIX/box/bin/idle-hibernate.sh"
rm -f "$DROPIN_DIR/stopgap-crews.conf" "$FIX/box/bin/idle-hibernate-holds.sh" "$SD/needreload.idle-hibernate.service"
echo enabled > "$SD/enabled"; echo active > "$SD/active"
apply
arm mode
if [[ "$(stat -c %a "$FIX/box/bin/idle-hibernate.sh")" != 755 || "$OUT" != *"held at 755"* || -n "$(grove_provision_1_15_hibernate_drift)" ]]; then
  echo "   │  ✋ matched bytes at mode 644 were left unrunnable"; quote; FAILED=1
else echo "   │  ✔ matched bytes at the wrong mode are held at 755, and named"; fi

# a box where the first boot died before it wrote a file: every declared file absent
drifted
rm -f "$FIX/box/bin/idle-hibernate.sh" "$FIX/box/etc/idle-hibernate.service" "$FIX/box/etc/idle-hibernate.timer"
apply
arm absent
if [[ $RC -ne 0 || ! -x "$FIX/box/bin/idle-hibernate.sh" || ! -f "$FIX/box/etc/idle-hibernate.timer" || -n "$(grove_provision_1_15_hibernate_drift)" ]]; then
  echo "   │  ✋ a box with no declared file did not converge"; quote; FAILED=1
else echo "   │  ✔ a box with no declared file gets all three, and converges"; fi

# a drop-in on the TIMER is retired too, and a `.d` dir that holds a file no glob reads stays
drifted
TIMER_DROPIN_DIR="$FIX/box/etc/idle-hibernate.timer.d"
mkdir -p "$TIMER_DROPIN_DIR"
echo "[Timer]" > "$TIMER_DROPIN_DIR/hold.conf"; echo "note" > "$TIMER_DROPIN_DIR/readme.txt"
echo "$TIMER_DROPIN_DIR/hold.conf" > "$SD/dropins.idle-hibernate.timer"
apply
arm timerdropin
if [[ $RC -ne 0 || -e "$TIMER_DROPIN_DIR/hold.conf" || ! -e "$TIMER_DROPIN_DIR/readme.txt" \
  || "$OUT" != *"holds a file systemd does not read; left in place"*"⇒ it holds: readme.txt"*"sudo rm -r $TIMER_DROPIN_DIR"* \
  || -n "$(grove_provision_1_15_hibernate_drift)" ]]; then
  echo "   │  ✋ a timer drop-in survived, or its dir's unread file was lost unnamed"; quote; FAILED=1
else echo "   │  ✔ the timer's drop-in is retired; a file no glob reads stays, named, with the step that clears it"; fi

# a systemd that cannot list drop-ins halts the apply loud, before the timer arms
drifted; touch "$SD/fail.dropins"; apply; rm -f "$SD/fail.dropins"
arm dropinsunread
if [[ $RC -eq 0 || "$OUT" != *"💥 MalfunctionError: could not list the units' drop-ins"* || -n "$(at enable)" ]]; then
  echo "   │  ✋ an unanswered drop-in read was taken as none, or the timer armed past it"; quote; FAILED=1
else echo "   │  ✔ an unanswered drop-in read halts the apply loud, before the timer arms"; fi

# a daemon-reload that fails halts the apply loud, and names what stays live
drifted; touch "$SD/fail.reload"; apply; rm -f "$SD/fail.reload"
arm reloadfails
if [[ $RC -eq 0 || "$OUT" != *"💥 MalfunctionError: systemctl daemon-reload failed"* || "$OUT" != *"OLD definitions stay live"* || -n "$(at enable)" ]]; then
  echo "   │  ✋ a failed reload was not loud, or the timer armed on old units"; quote; FAILED=1
else echo "   │  ✔ a failed reload halts the apply loud, and names the old units as live"; fi

# a wedged manager ends at the write bound, loud and named — the apply never hangs its duct
WRITE_BOUND_REAL="$GROVE_PROVISION_1_15_HIBERNATE_WRITE_BOUND"
drifted; touch "$SD/hang.daemon-reload"; GROVE_PROVISION_1_15_HIBERNATE_WRITE_BOUND=1; apply
GROVE_PROVISION_1_15_HIBERNATE_WRITE_BOUND="$WRITE_BOUND_REAL"; rm -f "$SD/hang.daemon-reload"
arm reloadhangs
if [[ $RC -eq 0 || "$OUT" != *"sudo systemctl daemon-reload did not answer within 1s"* || "$OUT" != *"💥 MalfunctionError: systemctl daemon-reload failed"* || -n "$(at enable)" ]]; then
  echo "   │  ✋ a reload that never returned was not ended by the bound, named, and halted before the arm"; quote; FAILED=1
else echo "   │  ✔ a reload that never returns ends at the bound, named, and the timer never arms on old units"; fi

# a checkout that lacks a declared file halts with the fix, and writes no box file
drifted; REAL_SRC="$GROVE_SRC"; GROVE_SRC="$FIX/empty.src"; apply; GROVE_SRC="$REAL_SRC"
arm nosource
if [[ $RC -ne 2 || "$OUT" != *"✋ ConstraintError"* || "$OUT" != *"git.repo.pull"* || "$(cat "$FIX/box/bin/idle-hibernate.sh")" != "# old check" ]]; then
  echo "   │  ✋ an incomplete checkout was not refused with exit 2 and its fix, or the box was written"; quote; FAILED=1
else echo "   │  ✔ an incomplete checkout is refused with exit 2 and its fix; the box is untouched"; fi

# the stopgap's last run left Result=exec-condition; the apply that retires it must
# leave the same pass's verify clean, not red on a fault the apply just removed
drifted; echo exec-condition > "$SD/result"; apply
VOUT="$(grove_provision_1_15_hibernate_configure_verify 2>&1)"; VRC=$?
arm staleresult
if [[ $RC -ne 0 || $VRC -ne 0 || -z "$(at reset-failed)" ]]; then
  echo "   │  ✋ the verify after a full apply read a result from before it (verify exit $VRC)"; quote
  printf '%s\n' "$VOUT" | sed 's/^/   │     │ verify: /'; FAILED=1
else echo "   │  ✔ the apply resets the last result, so its own verify reads clean"; fi

# converged config, bad last run: the apply cannot clear it, so it asks no root and writes naught
drifted
cp "$BUNDLE/idle-hibernate.sh" "$FIX/box/bin/"; chmod 755 "$FIX/box/bin/idle-hibernate.sh"
rm -f "$DROPIN_DIR/stopgap-crews.conf" "$FIX/box/bin/idle-hibernate-holds.sh" "$SD/needreload.idle-hibernate.service"
echo enabled > "$SD/enabled"; echo active > "$SD/active"; echo exit-code > "$SD/result"
: > "$SD/log"; : > "$SUDO_LOG"; apply
arm unhealthy
if [[ $RC -ne 0 || "$(writes)" -ne 0 || -n "$(at reset-failed)" || -s "$SUDO_LOG" ]]; then
  echo "   │  ✋ a run fault on a converged box gated an apply, or asked root"; quote; FAILED=1
else echo "   │  ✔ a converged box with a bad last run is left alone — no root, no write"; fi

# .what = judge an apply that must halt loud on one box fault: exit 1, its 💥 line, and the fix
# .usage = timerfails <arm> <💥 text> [inline] — inline: the tool's error rides on the 💥 line, so the fix points there
timerfails() {
  local where="the error above"
  [[ "${3:-}" == inline ]] && where="the error on the 💥 line"
  arm "$1"
  if [[ $RC -ne 1 || "$OUT" != *"💥 MalfunctionError: $2"* || "$OUT" != *"└─ fix: read $where, then re-run from the ground seat"* ]]; then
    echo "   │  ✋ a $1 fault was not loud, named no fix, or the apply passed"; quote; FAILED=1
  else echo "   │  ✔ halts loud, with its fix — $2"; fi
}
drifted; touch "$SD/fail.unmask"; apply; timerfails unmaskfails "could not unmask idle-hibernate.timer"
drifted; touch "$SD/fail.enable"; apply; timerfails enablefails "could not enable and start idle-hibernate.timer"
[[ "$OUT" == *"bills by the hour"* ]] || { echo "   │  ✋ the enable fault did not name its cost"; FAILED=1; }
drifted; touch "$SD/fail.restart"; apply; timerfails restartfails "could not restart idle-hibernate.timer on its declared schedule"

# the root writes a seat-less stub cannot fail: each armed by a flag, each loud with its fix
drifted; touch "$SUDO_LOG.fail.mktemp"; apply; timerfails stagefails "could not stage $FIX/box/bin/idle-hibernate.sh"
drifted; touch "$SUDO_LOG.fail.install"; apply; timerfails installfails "could not install $FIX/box/bin/idle-hibernate.sh"
[[ -z "$(find "$FIX/box/bin" -name '*.grove-provision.*')" ]] || { echo "   │  ✋ a failed install left its staged file"; FAILED=1; }
drifted; touch "$SUDO_LOG.fail.rm"; apply; timerfails rmfails "could not remove the drop-in $DROPIN_DIR/stopgap-crews.conf"
drifted; touch "$SUDO_LOG.fail.rmdir"; apply; timerfails rmdirfails "could not remove the emptied $DROPIN_DIR: " inline
# matched bytes at the wrong mode, and a chown that fails
drifted; cp "$BUNDLE/idle-hibernate.sh" "$FIX/box/bin/"; chmod 644 "$FIX/box/bin/idle-hibernate.sh"
touch "$SUDO_LOG.fail.chown"; apply
timerfails chownfails "could not set $FIX/box/bin/idle-hibernate.sh to 755 $GROVE_PROVISION_1_15_HIBERNATE_OWNER"
# no drop-in left to retire, so the first rm that runs is the stopgap's
drifted; rm -f "$DROPIN_DIR/stopgap-crews.conf" "$SD/dropins.idle-hibernate.service"; touch "$SUDO_LOG.fail.rm"; apply
timerfails stopgapfails "could not remove $FIX/box/bin/idle-hibernate-holds.sh"

# the last result is cleared BEFORE the timer arms, so a tick the arm fires stays on record
drifted; apply
arm resetfirst
if [[ -z "$(at reset-failed)" || -z "$(at enable)" || "$(at reset-failed)" -gt "$(at enable)" ]]; then
  echo "   │  ✋ the reset ran after the timer armed, so it could erase a real first tick"; quote; FAILED=1
else echo "   │  ✔ reset-failed precedes enable"; fi

# a reset that fails is loud, and leaves the apply passed, so its verify still runs
drifted; touch "$SD/fail.reset"; apply; rm -f "$SD/fail.reset"
arm resetfails
if [[ $RC -ne 0 || "$OUT" != *"💥 MalfunctionError: could not reset the last result"*"└─ fix:"* || -n "$(grove_provision_1_15_hibernate_drift)" ]]; then
  echo "   │  ✋ a failed reset failed the apply (so its verify would be skipped), or went unnamed"; quote; FAILED=1
else echo "   │  ✔ a failed reset is loud; the apply passes, so the verify runs and names any stale fault"; fi

# a dst that is a symlink to a seat's file with the right bytes is replaced, never followed
drifted
cp "$BUNDLE/idle-hibernate.sh" "$FIX/seat.sh"; chmod 644 "$FIX/seat.sh"
rm -f "$FIX/box/bin/idle-hibernate.sh"; ln -s "$FIX/seat.sh" "$FIX/box/bin/idle-hibernate.sh"
SYMDRIFT="$(grove_provision_1_15_hibernate_drift)"; apply
arm symlink
if [[ "$SYMDRIFT" != *"$FIX/box/bin/idle-hibernate.sh is a symlink"* ]]; then
  echo "   │  ✋ a symlinked dst read as converged"; printf '%s\n' "$SYMDRIFT" | sed 's/^/   │     │ drift: /'; FAILED=1
elif [[ -L "$FIX/box/bin/idle-hibernate.sh" || "$(stat -c %a "$FIX/seat.sh")" != 644 || -n "$(grove_provision_1_15_hibernate_drift)" ]]; then
  echo "   │  ✋ the apply followed the link into the seat's file, or left the link"; quote; FAILED=1
else echo "   │  ✔ the link is named, replaced by the declared file, and the seat's file is untouched"; fi

# each gap alone heals: one repair can never stand in for another's
converged() { drifted; apply; : > "$SD/log"; : > "$SUDO_LOG"; }
alone() {
  apply
  ukeep "alone.$1"
  if [[ $RC -ne 0 || -n "$(grove_provision_1_15_hibernate_drift)" ]]; then
    echo "   │  ✋ the gap '$1' alone did not heal"; quote; FAILED=1; return
  fi
  echo "   │  ✔ $1"
}
echo "   ├─ arm 'alone'"
converged; echo "# drift" >> "$FIX/box/bin/idle-hibernate.sh"; alone bytes
converged; chmod 644 "$FIX/box/bin/idle-hibernate.sh"; alone mode
converged; touch "$SD/needreload.idle-hibernate.timer"; alone reload
converged; mkdir -p "$DROPIN_DIR"; echo "[Service]" > "$DROPIN_DIR/one.conf"; alone dropin
converged; touch "$FIX/box/bin/idle-hibernate-holds.sh"; alone stopgap
converged; echo masked > "$SD/enabled"; alone masked
converged; echo disabled > "$SD/enabled"; echo inactive > "$SD/active"; alone unarmed

# `slug` is the phase `bundle.upgrade` binds as a local; the decline reads it to name the bundle
drifted; CAN=1; slug=1.15.hibernate.configure.upsert GROVE_ENV_SERVER=cloud@aws.ec2 apply; CAN=0
arm camper
if [[ "$OUT" != *"🌙 the idle check, with its units, is a BOX-WIDE fact, and this seat has no root"*"⇒ $FIX/box/bin/idle-hibernate.sh differs"*"no step is owed by this seat; the seat with sudo owes one apply:"*"rhx grove.provision --what 1.15.hibernate --mode apply"* || "$OUT" == *"none by a human"* ]]; then
  echo "   │  ✋ a seat with no root did not decline in the runtime's words, with the first drift"; quote; FAILED=1
elif [[ "$(writes)" -ne 0 || "$(cat "$FIX/box/bin/idle-hibernate.sh")" != "# old check" ]]; then
  echo "   │  ✋ a seat with no root wrote to the box"; quote; FAILED=1
else echo "   │  ✔ 🌙 declined in the runtime's words, the first drift named — no write, the box unchanged"; fi

# .what = the runtime's decline on a LAPTOP, and its strip of a provision-phase slug
# .why  twelve bundles share this decline. this bundle's platform gate declines first on a
#   laptop, so the decline is called by name: its laptop text and its strip are its own contract
USTDOUT="$(slug=1.15.hibernate.provision.upsert GROVE_ENV_SERVER=local@unix \
  bundle.root.declines "the idle check, with its units," "$FIX/box/bin/idle-hibernate.sh differs from this checkout's idle-hibernate.sh" 2>"$FIX/uerr")"; RC=$?
USTDERR="$(cat "$FIX/uerr")"; OUT="$USTDOUT"$'\n'"$USTDERR"; URUNS=$((URUNS + 1))
arm laptop
if [[ "$OUT" != *"⇒ on a laptop the seat with root is its human"*"sudo -v && rhx grove.provision --what 1.15.hibernate --mode apply"* \
  || "$OUT" == *"provision.upsert --mode"* || "$OUT" == *"the seat with sudo owes"* ]]; then
  echo "   │  ✋ on a laptop the decline did not hand the human sudo -v && rhx, for the bundle"; quote; FAILED=1
else echo "   │  ✔ 🌙 on a laptop: sudo -v && rhx … for the bundle, the phase name stripped"; fi

# the platform gate sits at dispatch, so it is driven through the dispatch
: > "$FIX/upgrades"
bundle.upgrade() { echo "$1" >> "$FIX/upgrades"; }
BUNDLE_DEPTH=1
drifted
USTDOUT="$(GROVE_ENV_SERVER=local@unix grove_provision_1_15_hibernate 2>"$FIX/uerr")"; RC=$?
USTDERR="$(cat "$FIX/uerr")"; OUT="$USTDOUT"$'\n'"$USTDERR"; URUNS=$((URUNS + 1))
arm offec2
if [[ "$OUT" != *"🌙 declined"*"no ec2 identity"* || -s "$FIX/upgrades" || "$(writes)" -ne 0 ]]; then
  echo "   │  ✋ a box with no ec2 identity ran a phase, or did not decline"; RC=-; quote; FAILED=1
else echo "   │  ✔ 🌙 declined off ec2 — no phase ran, no write"; fi

: > "$FIX/upgrades"; : > "$SD/log"
USTDOUT="$(GROVE_ENV_SERVER=cloud@aws.ec2 grove_provision_1_15_hibernate 2>"$FIX/uerr")"; RC=$?
USTDERR="$(cat "$FIX/uerr")"; OUT="$USTDOUT"$'\n'"$USTDERR"; URUNS=$((URUNS + 1))
echo "   ├─ arm 'onec2'"; ukeep onec2
# the phases are stubbed here (each is proven above), so what the dispatch shows is its ORDER
USNAP+="### phases dispatched"$'\n'"$(cat "$FIX/upgrades")"$'\n\n'
if [[ "$(cat "$FIX/upgrades")" != $'1.15.hibernate.configure.upsert\n1.15.hibernate.configure.verify' ]]; then
  echo "   │  ✋ an ec2 box did not run upsert then verify"; sed 's/^/   │  │ ran: /' "$FIX/upgrades"; FAILED=1
else echo "   │  ✔ on ec2 the dispatch runs upsert, then verify"; fi

# .what = drive the bundle through the REAL runtime, `src/bundle.upgrade.sh`, in a subshell
# .why the mode gate lives in the runtime, never in the bundle: `--mode plan` skips the upsert by
#   its slug and still runs the verify. only the real `bundle.upgrade` shows that, so the stub above
#   is left behind in this shell and the runtime is sourced fresh beside the fixture
dispatch() {
  # the redirect sits INSIDE the substitution: on a bare assignment it would land after the expansion
  USTDOUT="$( (GROVE_MODE="$1"; GROVE_ENV_SERVER=cloud@aws.ec2; WHAT=()
    # shellcheck source=/dev/null
    source "$REPO/bundle.upgrade.sh" || exit 97
    bundle.upgrade 1.15.hibernate; exit "${BUNDLE_FAILED:-0}") 2>"$FIX/uerr")"; RC=$?
  USTDERR="$(cat "$FIX/uerr")"; OUT="$USTDOUT"$'\n'"$USTDERR"; URUNS=$((URUNS + 1))
}
drifted; dispatch plan
arm dispatch.plan
if [[ "$RC" -ne 1 || "$OUT" != *"1.15.hibernate.configure.upsert — would run (plan)"* \
  || "$OUT" != *"✋ $FIX/box/bin/idle-hibernate.sh differs from this checkout's idle-hibernate.sh"* \
  || "$(writes)" -ne 0 || "$(cat "$FIX/box/bin/idle-hibernate.sh")" != "# old check" ]]; then
  echo "   │  ✋ a plan through the runtime wrote, skipped the verify, or ran the upsert"; quote; FAILED=1
else echo "   │  ✔ --mode plan: the upsert would run, the verify names the drift, no write, exit 1"; fi

# a camper seat through the real runtime: the decline reads `$slug` by dynamic scope from the
#   real `bundle.upgrade`, never from a hand-set slug, and the verify after it names the same apply
drifted; CAN=1; dispatch apply; CAN=0
arm dispatch.camper
OWED="rhx grove.provision --what 1.15.hibernate --mode apply"
if [[ "$RC" -ne 1 || "$OUT" != *"🌙 the idle check, with its units, is a BOX-WIDE fact, and this seat has no root"*"the seat with sudo owes one apply:"*"$OWED"* \
  || "$OUT" != *"✋ $FIX/box/bin/idle-hibernate.sh differs"*"⇒ fix, from the ground seat: $OWED"* \
  || "$OUT" == *"<this bundle>"* || "$(writes)" -ne 0 || "$(cat "$FIX/box/bin/idle-hibernate.sh")" != "# old check" ]]; then
  echo "   │  ✋ a camper through the runtime did not decline and verify toward one owed apply, or it wrote"; quote; FAILED=1
else echo "   │  ✔ a camper: 🌙 declined by the real runtime, the verify ✋ after it, both name one apply — no write"; fi

drifted; dispatch apply
echo "   └─ arm 'dispatch.apply'"; ukeep dispatch.apply
if [[ "$RC" -ne 0 || "$OUT" != *"├─ 1.15.hibernate.configure.upsert"* || "$OUT" != *"├─ 1.15.hibernate.configure.verify"* \
  || "$OUT" != *"the idle check and its units match this checkout ✔"* || -n "$(grove_provision_1_15_hibernate_drift)" ]]; then
  echo "      ✋ an apply through the runtime did not converge the box and prove it"; quote; FAILED=1
else echo "      ✔ --mode apply: the upsert runs, then the verify proves the box converged, exit 0"; fi

# the apply transcript, held by the shared snap — a reworded line shows in review, not in silence
# shellcheck source=/dev/null
source "$HERE/play.snap.operations.sh" || { echo "   💥 MalfunctionError: play.snap.operations.sh would not load"; exit 1; }
play_snap_verify dir="$HERE/prove.hibernate-upsert-converges-a-drifted-box.snap" name=transcript actual="$USNAP" || FAILED=1

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 the upsert heals each gap in order, names what it undid, and writes a converged box never"
else
  echo "✋ the contract did NOT hold — read the arms above"
fi
exit "$FAILED"
