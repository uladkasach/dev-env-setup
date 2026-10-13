#!/usr/bin/env bash
######################################################################
# .what = read the wifi link watchdog: one record-only probe pass, its unit
#         state, and every stall it has recorded
#
# .why  = `1.11.wifi` runs `machine_wifi_link_watchdog` to catch the silent
#         stall — associated, gateway silent — and to write the link, driver,
#         and firmware state at that moment. this is how a human or an agent
#         reads that record, and proves the probe without a reconnect
#
# usage:
#   rhx network.wifi.watchdog.get
#   rhx network.wifi.watchdog.get --since -7d
#   rhx network.wifi.watchdog.get --since -7d --evidence  # the full record per stall
#   rhx network.wifi.watchdog.get --gateway 192.0.2.1    # a planted stall
#
# guarantee:
#   - READ-ONLY: the pass runs under --mode plan, so it never reconnects
#   - the pass runs THIS checkout's executable, so a change is provable pre-apply
#   - every read is bounded by a timeout
######################################################################

set -uo pipefail

UNIT='wifi-link-watchdog.service'
SINCE='-48h'
GATEWAY=""
EVIDENCE=0

__watchdog_help() {
  cat <<'HELP'
📶 network.wifi.watchdog.get — the wifi stall watchdog: a probe pass, its unit, its records

  usage:
    rhx network.wifi.watchdog.get [--since <journalctl time>] [--gateway <ip>]

  options:
    --since     how far back to read the watchdog's records   (default: -48h)
    --evidence  also print the full record the unit wrote at each stall
    --gateway   probe this address in place of the real gateway — an
                unreachable one (192.0.2.1) plants a stall, to prove the record

  the pass is record-only (--mode plan): it never reconnects
HELP
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --since)   SINCE="${2:-}"; shift 2 ;;
      --gateway) GATEWAY="${2:-}"; shift 2 ;;
      --evidence) EVIDENCE=1; shift ;;
      --help|-h) __watchdog_help; return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      *) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   fix: rhx network.wifi.watchdog.get --help" >&2; return 2 ;;
    esac
  done

  local root bin
  root="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null)"
  bin="$root/src/machine/machine_wifi_link_watchdog"
  if [[ ! -f "$bin" ]]; then
    echo "💥 MalfunctionError: this checkout lacks $bin" >&2
    return 1
  fi

  echo "📶 network.wifi.watchdog.get --since $SINCE${GATEWAY:+ --gateway $GATEWAY}"

  # 1. one pass, now, record-only
  echo ""
  echo "── 1. one probe pass (record-only)"
  local args=(--once --mode plan) out rc=0
  [[ -n "$GATEWAY" ]] && args+=(--gateway "$GATEWAY")
  out="$(timeout 120 bash "$bin" "${args[@]}" 2>&1)" || rc=$?
  printf '%s\n' "$out" | sed 's/^/      /'
  case "$rc" in
    0) echo "      ⇒ every connected wifi link answers ✔" ;;
    3) echo "      ⇒ a STALL was seen — the record above is what the unit writes before it reconnects" ;;
    *) echo "      ⚠️ the pass exited $rc — no verdict" ;;
  esac

  # 2. the unit
  echo ""
  echo "── 2. unit $UNIT"
  # is-enabled / is-active print their answer AND exit non-zero on a no, so the print is the answer
  local enabled active
  enabled="$(timeout 5 systemctl is-enabled "$UNIT" 2>/dev/null)"
  active="$(timeout 5 systemctl is-active "$UNIT" 2>/dev/null)"
  echo "      enabled: ${enabled:-unread}"
  echo "      active:  ${active:-unread}"
  [[ "$enabled" == enabled ]] || echo "      fix: sudo -v && rhx grove.provision --what 1.11.wifi --mode apply"

  # 3. what it has recorded
  echo ""
  echo "── 3. stalls recorded (since $SINCE)"
  local records
  records="$(timeout 10 journalctl -u "$UNIT" --since "$SINCE" --no-pager -o short-iso 2>/dev/null \
    | grep -E 'wifi-watchdog: (STALL|RECONNECT|RESTORED|NOT RESTORED|COOLDOWN|watch begins)')"
  if [[ -n "$records" ]]; then
    printf '%s\n' "$records" | sed 's/^/      /'
    [[ "$EVIDENCE" -eq 1 ]] || echo "      ⇒ the full record per stall: rhx network.wifi.watchdog.get --since $SINCE --evidence"
  else
    echo "      · none"
  fi

  # 4. the full record the unit wrote at each stall — only on ask, it runs long
  if [[ "$EVIDENCE" -eq 1 ]]; then
    echo ""
    echo "── 4. the record written at each stall (since $SINCE)"
    local evidence
    evidence="$(timeout 10 journalctl -u "$UNIT" --since "$SINCE" --no-pager -o short-iso 2>/dev/null \
      | grep -E 'wifi-watchdog: (STALL|  |RECONNECT|RESTORED|NOT RESTORED)')"
    [[ -n "$evidence" ]] && printf '%s\n' "$evidence" | sed 's/^/      /' || echo "      · none"
  fi

  echo ""
  echo "🌲 done"
  [[ "$rc" -eq 0 || "$rc" -eq 3 ]] || return 1
  return 0
}

main "$@"
