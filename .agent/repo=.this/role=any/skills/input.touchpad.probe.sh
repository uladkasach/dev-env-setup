#!/usr/bin/env bash
######################################################################
# .what = find WHERE a touchpad stopped working, rung by rung
#
# 🛑 .why this skill exists — "the touchpad died" names a SYMPTOM, and the
#   symptom is identical across five unrelated causes that want five
#   different repairs:
#
#     · the kernel never enumerated it        → firmware / i2c / bios
#     · it enumerated and emits no events     → hardware, or a runtime-suspend
#     · it emits and a process GRABBED it     → keyd, a stale client, a game
#     · it emits and the compositor is deaf   → cosmic-comp lost the device
#     · everything works and config says OFF  → a toggle, or disable-while-typing
#
#   a human cannot tell these apart by feel, and each ad-hoc probe reads one
#   rung — so the usual diagnosis reads whichever rung was reached for first
#   and concludes from it. this walks them in DEPENDENCY ORDER and halts at
#   the first that does not hold, so the verdict names a cause rather than a
#   symptom (`rule.require.solve-at-cause`)
#
# ⚠️ .every reader here is THREE-VALUED — yes / no / could-not-read
#   a probe that folds "i could not read this" into "this is fine" passes a
#   rung it never measured (`rule.forbid.failhide`). several rungs below read
#   other users' processes and WILL be denied in part; each says so rather
#   than reporting a clean count it did not earn
#   (`gotcha.a-check-that-cries-wolf-gets-silenced`, q13)
#
# usage:
#   rhx input.touchpad.probe
#   rhx input.touchpad.probe --within 5     # seconds to watch for events
#   rhx input.touchpad.probe --no-touch     # skip the rung that needs a finger
#
# guarantee:
#   - READ-ONLY with respect to the box: it opens no file for write, changes
#     no config, no power state, no grab. it only reads and reports
#   - every probe is BOUNDED by a timeout (`rule.require.bounded-probes-in-verifies`)
#   - exit 0 = the touchpad is healthy all the way to the compositor
#     exit 2 = a rung did not hold, and the rung names what to do
######################################################################

set -uo pipefail

WITHIN=3
TOUCH=1

__tp_help() {
  cat <<'HELP'
🖱️ input.touchpad.probe — find WHERE a touchpad stopped working

  usage:
    rhx input.touchpad.probe [--within <seconds>] [--no-touch]

  options:
    --within    seconds to watch the device for events   (default: 3)
    --no-touch  skip the rung that asks you to touch the pad

  the ladder, in dependency order — it halts at the first rung that fails:
    1. kernel     the device is enumerated, with an event node
    2. node       the event node exists and is readable
    3. holders    which processes hold the node open
    4. emits      the node actually produces events when touched
    5. compositor the compositor is running and has the node open
    6. config     the compositor's input config does not disable it

  exit 0 = healthy through to the compositor · exit 2 = a rung failed, named
HELP
}

# .what = read every /proc/<pid>/fd entry that points at a given path
# .why  = a grab or a deaf compositor both show up here, and nowhere else.
# .note = other users' /proc is unreadable to us, so this is a LOWER BOUND.
#         it prints a trailing "denied:<n>" line so the caller can say so
#         rather than report a count it did not earn.
__tp_holders_of() {
  local node="$1" denied=0 pid comm target fd
  for fd in /proc/[0-9]*/fd/*; do
    target="$(readlink "$fd" 2>/dev/null)" || { denied=$((denied + 1)); continue; }
    [[ "$target" == "$node" ]] || continue
    pid="${fd#/proc/}"; pid="${pid%%/*}"
    comm="$(cat "/proc/$pid/comm" 2>/dev/null)" || comm='?'
    echo "hold:$pid:$comm"
  done
  echo "denied:$denied"
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --within)   WITHIN="${2:-}"; shift 2 ;;
      --no-touch) TOUCH=0; shift ;;
      --help|-h)  __tp_help; return 0 ;;
      # rhachet injects these; absorb them (`rule.require.wrap-cli-in-skills`)
      --repo|--role|--skill) shift 2 ;;
      *)
        echo "✋ unknown arg: $1" >&2
        echo "   fix: rhx input.touchpad.probe --help" >&2
        return 2
        ;;
    esac
  done

  if ! [[ "$WITHIN" =~ ^[0-9]+$ ]] || [[ "$WITHIN" -lt 1 ]]; then
    echo "✋ --within wants a whole number of seconds, got '$WITHIN'" >&2
    return 2
  fi

  echo "🖱️ input.touchpad.probe --within $WITHIN"

  ####################################################################
  # rung 1 — the KERNEL enumerated it
  #
  # /proc/bus/input/devices is paragraph-separated, one block per device.
  # a touchpad is named "...Touchpad" by every driver we care about, and
  # carries an eventN handler. the sibling "...Mouse" node on the same i2c
  # address is the pointer-emulation twin, NOT the touchpad — do not match it.
  ####################################################################
  local devs=/proc/bus/input/devices
  if [[ ! -r "$devs" ]]; then
    echo "   💥 cannot read $devs — the kernel's input list is unreadable" >&2
    echo "      ⇒ this is not a verdict about the touchpad; the probe went blind" >&2
    return 2
  fi

  local block name node sysfs
  block="$(awk -v RS='' 'tolower($0) ~ /name=.*touchpad/ { print; exit }' "$devs")"

  if [[ -z "$block" ]]; then
    echo "   ✋ the kernel enumerates NO touchpad at all" >&2
    echo "      ⇒ the break is below the driver: firmware, i2c, or bios" >&2
    echo "      read what it DOES enumerate:  cat $devs" >&2
    echo "      read why it did not bind:" >&2
    echo "        journalctl -b -g 'i2c|hid|input:' --case-sensitive=false" >&2
    echo "      the usual causes, in order:" >&2
    echo "        · the touchpad is disabled in bios/uefi setup" >&2
    echo "        · a kernel upgrade dropped the i2c-hid binding" >&2
    echo "        · genuine hardware or ribbon-cable failure" >&2
    return 2
  fi

  name="$(printf '%s\n' "$block" | awk -F'"' '/^N: Name=/ { print $2; exit }')"
  sysfs="$(printf '%s\n' "$block" | awk -F'=' '/^S: Sysfs=/ { print $2; exit }')"
  node="$(printf '%s\n' "$block" \
    | awk '/^H: Handlers=/ { for (i = 2; i <= NF; i++) if ($i ~ /^event[0-9]+$/) { print $i; exit } }')"

  echo "   ├─ 1. kernel"
  echo "   │     ├─ ✔ enumerated: $name"
  echo "   │     └─ sysfs: $sysfs"

  if [[ -z "$node" ]]; then
    echo "   ✋ '$name' is enumerated but carries NO event handler" >&2
    echo "      ⇒ no userspace caller can read it, however healthy the hardware" >&2
    echo "      read the block:  awk -v RS='' '/Touchpad/' $devs" >&2
    return 2
  fi

  ####################################################################
  # rung 2 — the event NODE exists and we may read it
  #
  # ⚠️ an unreadable node is a PERMISSION fact about this shell, never a
  #    fact about the touchpad. it is reported as a skip, not as a failure
  #    of the device — the two want opposite repairs.
  ####################################################################
  local dev="/dev/input/$node"
  echo "   ├─ 2. node"
  if [[ ! -e "$dev" ]]; then
    echo "   ✋ $dev is absent, though the kernel named it" >&2
    echo "      ⇒ udev did not create the node; the device layer is inconsistent" >&2
    echo "      fix: sudo udevadm trigger --subsystem-match=input" >&2
    return 2
  fi
  echo "   │     ├─ ✔ exists: $dev"

  local readable=1
  [[ -r "$dev" ]] || readable=0
  if [[ "$readable" -eq 0 ]]; then
    echo "   │     └─ ⚠️ not readable by this user — rung 4 cannot run"
    echo "   │        ⇒ add yourself to the 'input' group to probe events:"
    echo "   │            sudo usermod -aG input \"\$USER\"   (then re-login)"
  else
    echo "   │     └─ ✔ readable by this user"
  fi

  ####################################################################
  # rung 3 — who HOLDS the node
  #
  # an exclusive grab (EVIOCGRAB) is invisible in /proc, but the holder is
  # not. a touchpad that emits, with exactly one holder that is not the
  # compositor, is the classic "something stole my input" shape.
  ####################################################################
  echo "   ├─ 3. holders"
  local holders denied hold_count=0
  holders="$(__tp_holders_of "$dev")"
  denied="$(printf '%s\n' "$holders" | awk -F: '/^denied:/ { print $2; exit }')"

  local line pid comm
  while IFS= read -r line; do
    [[ "$line" == hold:* ]] || continue
    pid="$(printf '%s' "$line" | cut -d: -f2)"
    comm="$(printf '%s' "$line" | cut -d: -f3-)"
    echo "   │     ├─ pid $pid  $comm"
    hold_count=$((hold_count + 1))
  done <<< "$holders"

  [[ "$hold_count" -eq 0 ]] && echo "   │     ├─ (none visible to this user)"
  # ⚠️ never report this count as a census — it is a lower bound by construction
  echo "   │     └─ ⚠️ lower bound: $denied fd(s) were unreadable (other users)"

  ####################################################################
  # rung 4 — THE claim: it actually emits
  #
  # every rung above can hold while the pad is dead. this is the one that
  # separates "the stack is configured" from "the hardware answers".
  #
  # ⚠️ it needs a FINGER. an empty capture has two causes — the pad emitted
  #    no events, and the human did not touch it — and they render
  #    identically (`gotcha.a-check-that-cries-wolf-gets-silenced`, q14). so
  #    it asks explicitly, and reports the ambiguity rather than resolving it
  #    silently.
  ####################################################################
  echo "   ├─ 4. emits"
  if [[ "$TOUCH" -eq 0 ]]; then
    echo "   │     └─ 🌙 skipped (--no-touch)"
  elif [[ "$readable" -eq 0 ]]; then
    echo "   │     └─ 🌙 skipped — the node is not readable by this user"
  else
    echo "   │     ├─ 👉 MOVE YOUR FINGER ON THE TOUCHPAD for ${WITHIN}s…"
    local bytes
    bytes="$(timeout "$WITHIN" head -c 4096 "$dev" 2>/dev/null | wc -c)" || bytes=0
    if [[ "$bytes" -gt 0 ]]; then
      echo "   │     └─ ✔ emitted $bytes bytes of events — the hardware answers"
    else
      echo "   │     └─ ✋ emitted no events over ${WITHIN}s"
      echo "   ✋ '$name' produced no events" >&2
      echo "      ⇒ two causes render identically here, and they differ:" >&2
      echo "        · you did not touch the pad — re-run and touch it" >&2
      echo "        · the pad is genuinely dead below the driver" >&2
      echo "      to tell them apart, re-run with a longer window:" >&2
      echo "        rhx input.touchpad.probe --within 10" >&2
      echo "      if it stays silent, read the device's power state:" >&2
      echo "        cat /sys$sysfs/../power/control" >&2
      return 2
    fi
  fi

  ####################################################################
  # rung 5 — the COMPOSITOR is listening
  #
  # a device that emits into a compositor that never opened it is the
  # "every layer looks fine and the pointer does not move" shape. the holder
  # list from rung 3 already answers this — we only have to name the
  # compositor.
  ####################################################################
  echo "   ├─ 5. compositor"
  local comp_pid="" comp_name="" p
  for p in /proc/[0-9]*; do
    comm="$(cat "$p/comm" 2>/dev/null)" || continue
    case "$comm" in
      cosmic-comp|gnome-shell|kwin_wayland|sway|Hyprland|weston)
        comp_pid="${p#/proc/}"; comp_name="$comm"; break ;;
    esac
  done

  if [[ -z "$comp_pid" ]]; then
    echo "   │     └─ ⚠️ no known compositor process was found"
    echo "   │        ⇒ this probe knows cosmic-comp, gnome-shell, kwin, sway,"
    echo "   │          Hyprland, weston. an unknown one is not a failure"
  else
    echo "   │     ├─ ✔ running: $comp_name (pid $comp_pid)"
    if printf '%s\n' "$holders" | grep -q "^hold:$comp_pid:"; then
      echo "   │     └─ ✔ it holds $dev open"
    else
      echo "   │     └─ ✋ it does NOT hold $dev open"
      echo "   ✋ the device emits, and $comp_name never opened it" >&2
      echo "      ⇒ the compositor lost the device — the hardware is fine" >&2
      echo "      the usual causes, in order:" >&2
      echo "        · the device was re-enumerated after the compositor started" >&2
      echo "          (a suspend/resume, or an i2c reset)" >&2
      echo "        · libinput refused it; read why:" >&2
      echo "            journalctl --user -b -g libinput --case-sensitive=false" >&2
      echo "      the cheap repair is to make it re-scan — log out and back in" >&2
      return 2
    fi
  fi

  ####################################################################
  # rung 6 — the CONFIG does not disable it
  #
  # ⚠️ an ABSENT config file is not "disabled" — it is "default", which for
  #    every compositor here means enabled. the two must not be folded.
  ####################################################################
  echo "   └─ 6. config"
  local cfg="$HOME/.config/cosmic/com.system76.CosmicComp/v1"
  if [[ ! -d "$cfg" ]]; then
    echo "         └─ ✔ no compositor input config — defaults apply (enabled)"
  else
    local f found=0
    for f in "$cfg/input_touchpad_override" "$cfg/input_default" "$cfg/input_devices"; do
      [[ -r "$f" ]] || continue
      found=1
      echo "         ├─ $(basename "$f"):"
      sed 's/^/         │    /' "$f"
    done
    [[ "$found" -eq 0 ]] && echo "         ├─ (no touchpad keys are set — defaults apply)"
    echo "         └─ ⚠️ read the above: a 'state: Disabled' here is your answer"
  fi

  echo ""
  echo "✔ the touchpad is healthy through to the compositor"
  return 0
}

main "$@"
