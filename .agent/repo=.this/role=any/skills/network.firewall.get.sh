#!/usr/bin/env bash
######################################################################
# .what = read this box's host firewall: the declared ruleset, the unit that
#         loads it, the live table where this seat may read it, and every
#         socket that listens — what a hole in the firewall would expose
#
# .why  = "is this laptop reachable from the network it sits on?" has three
#         answers that are easy to fold: what is DECLARED to load at boot, what
#         is LOADED now, and what LISTENS behind it. a listener behind a loaded
#         drop is harmless; the same listener with no firewall is a target.
#         `1.12.firewall` converges the first two; this reads all three
#
# usage:
#   rhx network.firewall.get
#
# guarantee:
#   - READ-ONLY: it writes no file, unit, or rule
#   - the live table is read only where `sudo -n` passes — it never prompts
#   - every read is bounded by a timeout
######################################################################

set -uo pipefail

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        echo "🧱 network.firewall.get — the host firewall: declared, loaded, and what listens behind it"
        echo ""
        echo "usage:"
        echo "  rhx network.firewall.get"
        return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      *) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   fix: rhx network.firewall.get --help" >&2; return 2 ;;
    esac
  done

  local unit="grove-firewall" ruleset="/etc/grove/firewall.nft"

  # .why its own read: `systemctl is-enabled` PRINTS `not-found` and EXITS non-zero
  #   for an absent unit, so a bare `|| echo` appends a second answer on a new line
  __unit_state() {
    local out
    out="$(timeout 5 systemctl "$1" "$unit" 2>/dev/null)"
    printf '%s' "${out:-?}"
  }

  echo "🧱 network.firewall.get"
  echo "   tier: ${GROVE_ENV_SERVER:-<unset>} · kernel: $(uname -r)"

  # 1. the declaration — what loads at every boot
  echo ""
  echo "── 1. declared (survives a reboot)"
  if command -v nft >/dev/null 2>&1; then
    echo "      nft: $(timeout 5 nft --version 2>/dev/null || echo '?')"
  else
    echo "      nft: absent"
  fi
  if [[ -r "$ruleset" ]]; then
    echo "      ruleset: $ruleset ($(wc -l <"$ruleset") lines)"
  else
    echo "      ruleset: $ruleset absent"
  fi
  echo "      $unit.service: enabled=$(__unit_state is-enabled)"
  echo "      ufw: $( { [[ -r /etc/ufw/ufw.conf ]] && grep -E '^ENABLED=' /etc/ufw/ufw.conf; } || echo 'absent')"

  # 2. the live table — transient, and readable only with root
  echo ""
  echo "── 2. loaded (this boot — transient)"
  echo "      $unit.service: active=$(__unit_state is-active)"
  echo "      ssh.service: enabled=$(unit=ssh __unit_state is-enabled) active=$(unit=ssh __unit_state is-active)"
  if timeout 5 sudo -n true 2>/dev/null; then
    local live
    live="$(timeout 5 sudo -n nft list table inet grove_firewall 2>&1)"
    printf '%s\n' "$live" | sed 's/^/        /'
  else
    echo "      · live table unread — this seat holds no cached sudo (run 'sudo -v' first to see it)"
  fi

  # 3. what listens — the surface an absent firewall would expose
  echo ""
  echo "── 3. listeners (what a hole would expose — transient)"
  local listen
  listen="$(timeout 5 ss -Htuln 2>/dev/null | awk '{print "        " $1 "  " $5}' | sort -u)"
  [[ -n "$listen" ]] && printf '%s\n' "$listen" || echo "        · no listener"
  echo "      ⇒ 127.0.0.1 / [::1] listeners are local-only; any other address faces the network"

  echo ""
  echo "🌲 done — rung 1 is the verdict; rungs 2 and 3 are this boot only"
}

main "$@"
