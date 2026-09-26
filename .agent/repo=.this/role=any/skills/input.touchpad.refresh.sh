#!/usr/bin/env bash
######################################################################
# .what = tear the builtin touchpad's hid device down and re-create it
#
# 🛑 .why this exists — it is the ONE lever that repairs the common case
#   without a reboot. an i2c-hid touchpad that "pauses" mid-session is
#   almost never broken hardware; it is a device the compositor no longer
#   reads, or a driver state machine that wedged. an unbind + bind destroys
#   the evdev node and makes a fresh one, which libinput sees as an unplug
#   + replug — so the compositor re-grabs it from scratch.
#
# ⚠️ .this is a RESET, never a repair
#   if the cause is resource starvation — the compositor too starved to
#   drain a high-rate event stream — this clears the symptom and the pause
#   returns. that outcome is INFORMATION: a refresh that holds is a lost
#   device; a refresh that fades is starvation. the skill says so at the end
#   rather than let a green line imply a cure it did not deliver
#   (`rule.forbid.failhide`)
#
# ⚠️ .the device handle is DISCOVERED, never hardcoded
#   the hid id (`0018:04F3:3242.0001`) and the driver (`hid-multitouch`)
#   differ per machine, and the id can change across a re-enumeration. a
#   literal here would be a magic value that works on one laptop and
#   silently targets the wrong device on the next
#   (`rule.forbid.magic-values`)
#
# ⚠️ .the ESCALATOR is resolved, never assumed to be sudo
#   `sudo` asks for a password on a TERMINAL. a skill invoked by an agent,
#   a hotkey, or a systemd unit has none — sudo then returns 1 and writes
#   not one byte, which is precisely the false ✔ this skill now halts on.
#   `pkexec` asks through the desktop's polkit agent instead, so it needs
#   no tty at all. the right one depends on the CALLER, so it is read at
#   run time rather than baked in (`rule.forbid.tty-as-a-proxy-for-a-human`
#   governs the inverse trap: a tty is not what makes a human present)
#
# usage:
#   rhx input.touchpad.refresh                 # plan — show what would run
#   rhx input.touchpad.refresh --mode apply    # do it
#   rhx input.touchpad.refresh --mode apply --via pkexec   # force the gui ask
#
# guarantee:
#   - plan mode is the default; the write takes a deliberate --mode apply
#     (`rule.require.safe-by-default`)
#   - it VERIFIES the device came back, and fails loud if it did not — a
#     rebind that silently drops the device leaves a laptop with no pointer
#   - every write is bounded by a timeout; a wedged i2c bus can block a
#     sysfs write forever (`rule.require.bounded-probes-in-verifies`)
######################################################################

set -uo pipefail

MODE=plan
VIA=auto

__tp_refresh_help() {
  cat <<'HELP'
🖱️ input.touchpad.refresh — reset the builtin touchpad without a reboot

  usage:
    rhx input.touchpad.refresh [--mode plan|apply]

  options:
    --mode plan    show the device and the commands      (default)
    --mode apply   unbind, rebind, and verify it returned
    --via auto     pick the escalator that can ask here  (default)
    --via sudo     ask on the terminal
    --via pkexec   ask through the desktop's polkit agent (needs no tty)

  what it does:
    destroys the touchpad's hid device and re-creates it. the compositor
    sees an unplug + replug and re-grabs the device from scratch.

  it needs root — the bind handles live under /sys/bus/hid/drivers/.
  --via auto takes password-less sudo, else sudo on a tty, else pkexec.

  read the cause first, if you have not:
    rhx input.touchpad.probe
HELP
}

# .what = name the escalator that can actually ASK on this caller's behalf
# .why  = sudo prompts on a tty. a caller with no tty gets a silent rc=1 and
#         an untouched box, so the escalator is a property of the CALLER and
#         has to be read rather than assumed.
__tp_escalator() {
  [[ "$(id -u)" == 0 ]] && { echo root; return 0; }

  # password-less sudo is the cheapest: it asks no one
  timeout 5 sudo -n true >/dev/null 2>&1 && { echo sudo; return 0; }

  # a terminal means sudo CAN ask, so let it
  [[ -t 0 && -t 1 ]] && { echo sudo; return 0; }

  # no terminal: polkit's agent is the one that can still reach a human
  command -v pkexec >/dev/null 2>&1 && { echo pkexec; return 0; }

  echo none
}

# .what = write $1 into the root-owned path $2, via the resolved escalator
# .why  = one funnel, so the timeout bound and the escalator choice cannot
#         drift between the unbind call and the bind call
#         (`rule.require.bounded-probes-in-verifies`)
__tp_write_as_root() {
  local value="$1" path="$2"
  case "$VIA" in
    root)   echo -n "$value" > "$path" 2>/dev/null ;;
    sudo)   echo -n "$value" | timeout 60 sudo tee "$path" >/dev/null 2>&1 ;;
    pkexec) echo -n "$value" | timeout 90 pkexec tee "$path" >/dev/null 2>&1 ;;
    *)      return 3 ;;
  esac
}

# .what = read the touchpad's sysfs path out of the kernel's input list
# .why  = it is the one place that names the device WITHOUT a guess at the
#         vendor id. the "...Mouse" twin on the same i2c address is the
#         pointer-emulation node, so match on Touchpad alone.
__tp_sysfs_path() {
  awk -v RS='' 'tolower($0) ~ /name=.*touchpad/ {
    for (i = 1; i <= NF; i++)
      if ($i ~ /^Sysfs=/) { sub(/^Sysfs=/, "", $i); print $i; exit }
  }' /proc/bus/input/devices
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)    MODE="${2:-}"; shift 2 ;;
      --via)     VIA="${2:-}"; shift 2 ;;
      --help|-h) __tp_refresh_help; return 0 ;;
      # rhachet injects these; absorb them (`rule.require.wrap-cli-in-skills`)
      --repo|--role|--skill) shift 2 ;;
      *)
        echo "✋ unknown arg: $1" >&2
        echo "   fix: rhx input.touchpad.refresh --help" >&2
        return 2
        ;;
    esac
  done

  case "$MODE" in
    plan|apply) ;;
    *)
      echo "✋ --mode wants 'plan' or 'apply', got '$MODE'" >&2
      return 2
      ;;
  esac

  case "$VIA" in
    auto)   VIA="$(__tp_escalator)" ;;
    sudo|pkexec|root) ;;
    *)
      echo "✋ --via wants 'auto', 'sudo', or 'pkexec', got '$VIA'" >&2
      return 2
      ;;
  esac

  if [[ "$VIA" == none ]]; then
    echo "✋ no way to reach root from here" >&2
    echo "   ⇒ sudo wants a password and this shell has no terminal to ask on," >&2
    echo "     and pkexec is absent, so its graphical ask is unavailable too" >&2
    echo "   fix: run this from a terminal, or install policykit-1" >&2
    return 2
  fi

  echo "🖱️ input.touchpad.refresh --mode $MODE --via $VIA"

  ####################################################################
  # 1. find the device — its sysfs path, its hid id, its driver
  ####################################################################
  local sysfs
  sysfs="$(__tp_sysfs_path)"
  if [[ -z "$sysfs" ]]; then
    echo "   ✋ the kernel enumerates no touchpad — there is none to refresh" >&2
    echo "      ⇒ a refresh re-binds an extant device. an absent one is a" >&2
    echo "        different failure, below the driver" >&2
    echo "      read the ladder:  rhx input.touchpad.probe" >&2
    return 2
  fi

  # the hid device dir is the ancestor named <bus>:<vendor>:<product>.<n>
  local hid="" part
  local IFS_SAVE="$IFS"
  IFS='/'
  for part in $sysfs; do
    [[ "$part" =~ ^[0-9A-Fa-f]{4}:[0-9A-Fa-f]{4}:[0-9A-Fa-f]{4}\.[0-9A-Fa-f]+$ ]] && hid="$part"
  done
  IFS="$IFS_SAVE"

  if [[ -z "$hid" ]]; then
    echo "   ✋ the touchpad is not a hid device — it has no hid handle to rebind" >&2
    echo "      sysfs: $sysfs" >&2
    echo "      ⇒ a ps/2 or serio touchpad resets a different way; this skill" >&2
    echo "        covers i2c-hid and usb-hid only" >&2
    return 2
  fi

  # the driver is whatever sysfs says is bound RIGHT NOW — never assumed
  local drv_link drv
  drv_link="$(readlink "/sys/bus/hid/devices/$hid/driver" 2>/dev/null)" || drv_link=""
  drv="$(basename "$drv_link" 2>/dev/null)"

  if [[ -z "$drv" ]]; then
    echo "   ✋ '$hid' is bound to no driver at all" >&2
    echo "      ⇒ an unbound device cannot be re-bound by this skill; the" >&2
    echo "        driver module may have been unloaded" >&2
    echo "      read it:  ls -l /sys/bus/hid/devices/$hid/" >&2
    return 2
  fi

  echo "   ├─ device: $hid"
  echo "   ├─ driver: $drv"
  echo "   └─ sysfs:  $sysfs"

  local unbind="/sys/bus/hid/drivers/$drv/unbind"
  local bind="/sys/bus/hid/drivers/$drv/bind"

  for part in "$unbind" "$bind"; do
    if [[ ! -e "$part" ]]; then
      echo "   ✋ $part is absent — this driver exposes no bind handle" >&2
      return 2
    fi
  done

  ####################################################################
  # 2. plan — print exactly what apply would run, and stop
  ####################################################################
  if [[ "$MODE" == plan ]]; then
    local shown="$VIA tee"
    [[ "$VIA" == root ]] && shown="tee"

    echo ""
    echo "   🌙 plan — these two commands would run:"
    echo "      echo -n '$hid' | $shown $unbind"
    echo "      echo -n '$hid' | $shown $bind"
    echo ""
    case "$VIA" in
      pkexec) echo "   ⚠️  pkexec asks for your password in a DESKTOP DIALOG."
              echo "      watch the screen; this shell has no terminal to ask on." ;;
      sudo)   echo "   ⚠️  sudo asks for your password on THIS TERMINAL." ;;
    esac
    echo ""
    echo "   ⚠️  the event node will change (event5 → a higher number)."
    echo "      that is normal, not a failure."
    echo ""
    echo "   run it:  rhx input.touchpad.refresh --mode apply"
    return 0
  fi

  ####################################################################
  # 3. apply — unbind, then bind
  #
  # 🛑 .the UNBIND is the gate, and a failed one HALTS
  #   a sudo that cannot reach a terminal returns 1 and writes naught. if
  #   this skill then proceeded to the bind, the device would still be
  #   bound, the verify below would see a live touchpad, and a ✔ would be
  #   printed for a run that touched the box not at all — a textbook false
  #   ✔ (`rule.forbid.failhide`). so an unbind that fails ends the run.
  ####################################################################
  echo ""
  [[ "$VIA" == pkexec ]] && echo "   ├─ 🔐 watch your screen — pkexec asks for your password in a dialog"
  echo "   ├─ • unbinds $hid from $drv…"
  local rc_unbind=0
  __tp_write_as_root "$hid" "$unbind" || rc_unbind=$?

  if [[ "$rc_unbind" -ne 0 ]]; then
    echo "   └─ ✋ the unbind returned $rc_unbind — the device was NOT touched" >&2
    echo "" >&2
    echo "   ✋ $VIA could not write $unbind" >&2
    case "$VIA" in
      sudo)   echo "      ⇒ the likeliest cause is that sudo wanted a password and" >&2
              echo "        this shell has no terminal for it to ask on" >&2
              echo "      try the graphical ask instead:" >&2
              echo "        rhx input.touchpad.refresh --mode apply --via pkexec" >&2 ;;
      pkexec) echo "      ⇒ the dialog was declined, timed out, or no polkit agent" >&2
              echo "        is up to draw it" >&2
              echo "      try it from a terminal instead:" >&2
              echo "        rhx input.touchpad.refresh --mode apply --via sudo" >&2 ;;
      root)   echo "      ⇒ this shell is already root and the write still failed —" >&2
              echo "        the driver may have released the device already" >&2 ;;
    esac
    return 2
  fi

  echo "   ├─ • binds it back…"
  local rc_bind=0
  __tp_write_as_root "$hid" "$bind" || rc_bind=$?

  ####################################################################
  # 4. VERIFY — two claims, and the second is the one that bites
  #
  #   a) a touchpad exists again, with an event node — a rebind that
  #      silently drops the device leaves a laptop with no pointer
  #   b) its sysfs INPUT path MOVED — an unbind destroys the input node
  #      and the bind makes a fresh one, so an unchanged path proves the
  #      device was never torn down, whatever `tee` returned
  ####################################################################
  local after node
  after="$(__tp_sysfs_path)"
  node="$(awk -v RS='' 'tolower($0) ~ /name=.*touchpad/ {
    for (i = 1; i <= NF; i++) if ($i ~ /^event[0-9]+$/) { print $i; exit }
  }' /proc/bus/input/devices)"

  if [[ -z "$after" || -z "$node" ]]; then
    echo "   └─ ✋ the touchpad did NOT come back" >&2
    echo "" >&2
    echo "   ✋ the device was unbound and did not re-bind" >&2
    echo "      ⇒ you have no touchpad until this is repaired" >&2
    echo "      try the bind by hand, to read the error:" >&2
    echo "        echo -n '$hid' | $VIA tee $bind" >&2
    echo "      if that fails, a reboot restores it" >&2
    return 2
  fi

  if [[ "$after" == "$sysfs" ]]; then
    echo "   └─ ✋ the device was never torn down" >&2
    echo "" >&2
    echo "   ✋ the input path is unchanged: $after" >&2
    echo "      ⇒ a real unbind destroys that node and the bind makes a new" >&2
    echo "        one, so an identical path means no reset occurred" >&2
    echo "      bind rc: $rc_bind — run the two writes yourself:" >&2
    echo "        echo -n '$hid' | $VIA tee $unbind" >&2
    echo "        echo -n '$hid' | $VIA tee $bind" >&2
    return 2
  fi

  if [[ "$rc_bind" -ne 0 ]]; then
    echo "   │  ⚠️ the bind returned $rc_bind, and the device is present anyway"
  fi

  echo "   └─ ✔ back on $node"
  echo ""
  echo "✔ refreshed — move a finger to confirm the pointer tracks"
  echo ""
  echo "   ⚠️ this was a RESET, never a repair. if the pause returns, the"
  echo "      cause is upstream — a compositor too starved to drain the"
  echo "      event stream. read the pressure:"
  echo "        rhx machine.diagnose.churn"
  return 0
}

main "$@"
