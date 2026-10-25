#!/usr/bin/env bash
######################################################################
# .what = make a bluetooth device paired, bonded, trusted, and connected
#         to THIS machine — the move that "takes" it from another host
#
# .why  = a one-shot `bluetoothctl pair <mac>` registers no agent that
#         can answer, so a device that asks for a passkey — a keyboard —
#         is never shown its code. it connects, waits, and the pair ends
#         in a timeout or `AuthenticationCanceled`. a trackpad pairs that
#         way only because it asks for no code at all.
#
#         this skill drives ONE interactive bluetoothctl session instead:
#         it registers itself as the default agent, scans, pairs, and
#         prints the passkey the moment the device asks for it — on
#         stdout and as a desktop notification, since the human must
#         type it on the device while the pair is still open.
#
# ⚠️ .a device holds ONE host at a time
#   apple magic devices keep a bond with the last host that paired them.
#   to take one here leaves the other host's bond stale: that host must
#   pair again to take it back. there is no multi-host switch on the
#   device. see `howto.fix-apple-magic-device-bluetooth`, `.move a device
#   between two machines`.
#
# usage:
#   rhx bluetooth.device.set --name 'Magic Keyboard'                # plan
#   rhx bluetooth.device.set --name 'Magic Keyboard' --mode apply   # take it
#   rhx bluetooth.device.set --mac B0:BE:83:F0:41:3D --mode apply
#
# guarantee:
#   - plan mode is the default; the pair takes a deliberate --mode apply
#   - idempotent: a device already bonded here is only (re)connected; a
#     stale bond is removed and re-paired
#   - every wait is bounded (`rule.require.bounded-probes-in-verifies`)
#   - it VERIFIES `Bonded: yes` + `Connected: yes` at the end, and fails
#     loud otherwise — `Paired: yes` alone is the cosmic trap where input
#     never registers
#   - exit 0 = set, 1 = malfunction, 2 = constraint (bad input, device not
#     discoverable, pair refused)
######################################################################

set -uo pipefail

NAME=""
MAC=""
MODE=plan
SCAN_SECS=30
PAIR_SECS=90

__bt_help() {
  cat <<'HELP'
🔵 bluetooth.device.set — pair, bond, trust, and connect a device to this machine

  usage:
    rhx bluetooth.device.set --name '<device name>' [--mode plan|apply]
    rhx bluetooth.device.set --mac <AA:BB:CC:DD:EE:FF> [--mode plan|apply]

  options:
    --name NAME    the device's advertised name, exactly (e.g. 'Magic Trackpad')
    --mac MAC      the device's address, if known
    --mode plan    show the device's state here and what apply would do (default)
    --mode apply   scan, pair (passkey shown live), trust, connect, verify

  before apply, put the device in pair mode:
    - on the OTHER machine, turn bluetooth off (it will grab the device back otherwise)
    - power-cycle the device; its light blinks while it waits to pair

  if a passkey appears, type it ON THE DEVICE and press enter.
HELP
}

# .what = drop color codes, carriage returns, and the shell prompt from one line
__bt_strip() {
  local s="$1"
  s="${s//$'\r'/}"
  s="$(printf '%s' "$s" | sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/^\[[^]]*\]# ?//')"
  printf '%s' "$s"
}

# .what = send one command line into the bluetoothctl session
__bt_send() { printf '%s\n' "$1" >&"${BT[1]}"; }

# .what = surface a passkey to the human, on every channel that reaches them
__bt_show_code() {
  local code="$1"
  # a keyboard re-announces its passkey once per digit typed; show it once
  [[ "$code" == "${__BT_LAST_CODE:-}" ]] && return 0
  __BT_LAST_CODE="$code"
  echo "   │"
  echo "   ├─ 🔑 passkey: $code"
  echo "   │     ⇒ type $code ON THE DEVICE, then press enter"
  echo "   │"
  command -v notify-send >/dev/null 2>&1 &&
    timeout 5 notify-send -u critical "bluetooth passkey: $code" \
      "type $code on the device, then press enter" >/dev/null 2>&1
  return 0
}

# .what = answer the agent prompts bluetoothctl prints while a pair is open
# .why  = the passkey is the whole reason this skill exists; the confirm and
#         authorize prompts would otherwise stall the pair until it times out
__bt_react() {
  local line="$1" code
  if [[ "$line" =~ Passkey:\ ([0-9]{6}) ]]; then
    __bt_show_code "${BASH_REMATCH[1]}"
  elif [[ "$line" =~ PIN\ code:\ ([0-9]+) ]]; then
    __bt_show_code "${BASH_REMATCH[1]}"
  elif [[ "$line" =~ Confirm\ passkey\ ([0-9]{6}) ]]; then
    __bt_show_code "${BASH_REMATCH[1]}"
    __bt_send "yes"
  elif [[ "$line" =~ Enter\ PIN\ code ]]; then
    code="$(printf '%06d' $(( RANDOM % 1000000 )))"
    __bt_send "$code"
    __bt_show_code "$code"
  elif [[ "$line" =~ Authorize\ service ]]; then
    __bt_send "yes"
  fi
}

# .what = read session output until a line matches $1, or $2 seconds pass
# .why  = one bounded reader, so every wait in the pair flow shares the
#         same timeout discipline and the same prompt reactions
# .note = optional $3 is a command re-sent every 3s while it waits
__bt_await() {
  local pattern="$1" secs="$2" repeat="${3:-}" line rc
  local deadline=$(( SECONDS + secs )) next=$(( SECONDS + 3 ))
  __BT_MATCH=""
  while (( SECONDS < deadline )); do
    if [[ -n "$repeat" ]] && (( SECONDS >= next )); then __bt_send "$repeat"; next=$(( SECONDS + 3 )); fi
    IFS= read -r -t 1 line <&"${BT[0]}"; rc=$?
    (( rc > 128 )) && continue
    (( rc != 0 )) && return 1   # the session ended
    line="$(__bt_strip "$line")"
    __bt_react "$line"
    if [[ "$line" =~ $pattern ]]; then __BT_MATCH="$line"; return 0; fi
  done
  return 1
}

# .what = one read of a field from `bluetoothctl info`, outside the session
__bt_field() {
  timeout 10 bluetoothctl info "$1" 2>/dev/null | awk -v k="$2:" '$1 == k { print $2; exit }'
}

__bt_close() {
  [[ -n "${BT_PID:-}" ]] || return 0
  __bt_send "scan off" 2>/dev/null
  __bt_send "quit" 2>/dev/null
  timeout 5 tail --pid="$BT_PID" -f /dev/null 2>/dev/null || kill "$BT_PID" 2>/dev/null
  BT_PID=""
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)    NAME="${2:-}"; shift 2 ;;
      --mac)     MAC="${2:-}"; shift 2 ;;
      --mode)    MODE="${2:-}"; shift 2 ;;
      --help|-h) __bt_help; return 0 ;;
      --repo|--role|--skill) shift 2 ;;   # rhachet injects these
      *)
        echo "✋ ConstraintError: unknown arg: $1" >&2
        echo "   fix: rhx bluetooth.device.set --help" >&2
        return 2 ;;
    esac
  done

  case "$MODE" in plan|apply) ;; *)
    echo "✋ ConstraintError: --mode wants 'plan' or 'apply', got '$MODE'" >&2; return 2 ;;
  esac
  if [[ -z "$NAME" && -z "$MAC" ]]; then
    echo "✋ ConstraintError: name the device with --name or --mac" >&2
    echo "   fix: rhx bluetooth.device.set --name 'Magic Keyboard'" >&2
    return 2
  fi
  if [[ -n "$MAC" && ! "$MAC" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
    echo "✋ ConstraintError: --mac is not an address: '$MAC'" >&2; return 2
  fi
  MAC="${MAC^^}"

  # resolve a name to an address this machine already knows, if it does
  if [[ -z "$MAC" ]]; then
    MAC="$(timeout 10 bluetoothctl devices 2>/dev/null |
      awk -v n="$NAME" '{ m=$2; $1=""; $2=""; sub(/^  /, ""); if ($0 == n) { print m; exit } }')"
  fi

  echo "🔵 bluetooth.device.set --mode $MODE"
  echo "   ├─ device: ${NAME:-?} ${MAC:+($MAC)}"

  local bonded="" connected=""
  if [[ -n "$MAC" ]]; then
    bonded="$(__bt_field "$MAC" Bonded)"; connected="$(__bt_field "$MAC" Connected)"
    echo "   ├─ here:   bonded=${bonded:-unknown} connected=${connected:-unknown}"
  else
    echo "   ├─ here:   not known to this machine yet"
  fi

  if [[ "$bonded" == yes && "$connected" == yes ]]; then
    echo "   └─ ✔ already bonded and connected here — naught to do"
    return 0
  fi

  if [[ "$MODE" == plan ]]; then
    echo "   └─ 🌙 plan — apply would:"
    if [[ "$bonded" == yes ]]; then
      echo "         connect it; if the device refuses (its bond moved to another host),"
      echo "         remove it and re-pair"
    else
      echo "         scan for it, pair it (a passkey is shown if it asks), trust, connect"
    fi
    echo ""
    echo "   first: turn bluetooth off on the other machine, power-cycle the device"
    echo "   run it: rhx bluetooth.device.set ${NAME:+--name '$NAME'}${MAC:+ --mac $MAC} --mode apply"
    return 0
  fi

  # one interactive session; stdbuf so its output reaches us line by line
  coproc BT { stdbuf -oL -eL bluetoothctl 2>&1; }
  trap __bt_close EXIT

  __bt_send "agent KeyboardDisplay"
  __bt_send "default-agent"
  # bluetoothctl confirms the agent in words that vary by version, and the
  # passkey reached this session on 2026-10-25 with no match here — so a
  # miss is no evidence of failure, and it stays silent (no cry-wolf warn)
  __bt_await 'Agent registered|Default agent|already registered' 5

  # 1. a bond that already exists here — a connect may be all it needs
  local need_pair=yes
  if [[ "$bonded" == yes ]]; then
    echo "   ├─ • connects (already bonded here)…"
    __bt_send "connect $MAC"
    if __bt_await 'Connection successful|Failed to connect' 20 && [[ "$__BT_MATCH" == *successful* ]]; then
      need_pair=no
    else
      echo "   │  the device refused — its bond lives on another host now. re-pairs."
      __bt_send "remove $MAC"; __bt_await 'Device has been removed|not available' 10
    fi
  fi

  # 2. find it, then pair it
  if [[ "$need_pair" == yes ]]; then
    echo "   ├─ • scans up to ${SCAN_SECS}s — the device must be in pair mode…"
    __bt_send "scan on"
    local want
    if [[ -n "$NAME" ]]; then want="Device ([0-9A-F:]{17}) ${NAME}\$"; else want="Device ${MAC}( |\$)"; fi
    if ! __bt_await "$want" "$SCAN_SECS" "devices"; then
      echo "   └─ ✋ not seen in ${SCAN_SECS}s" >&2
      echo "" >&2
      echo "✋ ConstraintError: the device is not discoverable" >&2
      echo "   ⇒ it is asleep, or still bound to the other host" >&2
      echo "   fix: turn bluetooth off on the other machine, power-cycle the device, retry" >&2
      return 2
    fi
    [[ "$__BT_MATCH" =~ Device\ ([0-9A-F:]{17}) ]] && MAC="${BASH_REMATCH[1]}"
    __bt_send "scan off"
    echo "   ├─ • found $MAC — pairs (up to ${PAIR_SECS}s)…"

    # bluetoothctl reports the outcome as "Pair<-ing> successful" / "Failed to pair"
    __bt_send "pair $MAC"
    if ! __bt_await 'Pair[[:alpha:]]* successful|Failed to pair' "$PAIR_SECS" || [[ "$__BT_MATCH" != *successful* ]]; then
      echo "   └─ ✋ ${__BT_MATCH:-the pair timed out}" >&2
      echo "" >&2
      echo "✋ ConstraintError: the pair did not complete" >&2
      echo "   ⇒ a passkey not typed in time, or the device left pair mode" >&2
      echo "   fix: power-cycle the device and retry; type the passkey on the device, then enter" >&2
      return 2
    fi
    __bt_send "trust $MAC";   __bt_await 'trust succeeded' 10
    __bt_send "connect $MAC"; __bt_await 'Connection successful|Failed to connect' 20
  fi

  __bt_close
  trap - EXIT

  # 3. VERIFY — bonded AND connected; `Paired: yes` alone is not enough
  bonded="$(__bt_field "$MAC" Bonded)"; connected="$(__bt_field "$MAC" Connected)"
  local trusted; trusted="$(__bt_field "$MAC" Trusted)"
  if [[ "$bonded" != yes || "$connected" != yes ]]; then
    echo "   └─ ✋ bonded=${bonded:-?} trusted=${trusted:-?} connected=${connected:-?}" >&2
    echo "" >&2
    echo "✋ ConstraintError: the device is not bonded and connected here" >&2
    echo "   ⇒ an unbonded HID device connects but its input never registers" >&2
    echo "   fix: bluetoothctl remove $MAC, power-cycle the device, retry" >&2
    return 2
  fi
  echo "   └─ ✔ bonded=yes trusted=${trusted:-?} connected=yes"
  echo ""
  echo "✔ set — the device is this machine's now. use it to confirm input registers"
  return 0
}

main "$@"
