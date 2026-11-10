#!/usr/bin/env bash
######################################################################
# .what = route this laptop through a tailscale exit node, or back to direct
#
# .why  = an exit node is a situational choice — on for an untrusted network,
#         off at home — so it lives in a skill, never in a bundle. one command
#         switches it, and the route is read back to prove the switch held
#         (`plan.exit-node` — mullvad when needed, a house grove long term)
#
# usage:
#   rhx network.vpn.set --exit mullvad               # the best online mullvad node
#   rhx network.vpn.set --exit mullvad --country se  # the best mullvad node in one country
#   rhx network.vpn.set --exit <host-or-ip>          # one named exit node (a house grove)
#   rhx network.vpn.set --off                        # direct again
#
# guarantee:
#   - changes exactly one pref, the exit node. shields-up and every other pref
#     stay as they are (`tailscale set`, never `tailscale up`)
#   - lan access through the exit node stays OFF — on a shared network the lan
#     is the threat
#   - where this seat holds no cached sudo, it writes naught and prints the line
#     a human runs (`gotcha.rhx-runs-a-skill-with-no-tty`)
######################################################################

set -uo pipefail

main() {
  local exit_to="" country="" off=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        echo "🛰️ network.vpn.set — route through an exit node, or back to direct"
        echo ""
        echo "usage:"
        echo "  rhx network.vpn.set --exit mullvad [--country <cc>]"
        echo "  rhx network.vpn.set --exit <host-or-ip>"
        echo "  rhx network.vpn.set --off"
        echo ""
        echo "see the choices: rhx network.vpn.get"
        return 0 ;;
      --exit) exit_to="${2:-}"; shift 2 ;;
      --country) country="${2:-}"; shift 2 ;;
      --off) off=1; shift ;;
      --repo|--role|--skill) shift 2 ;;
      *) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   fix: rhx network.vpn.set --help" >&2; return 2 ;;
    esac
  done

  # exactly one intent
  if [[ $off -eq 1 && -n "$exit_to" ]] || [[ $off -eq 0 && -z "$exit_to" ]]; then
    echo "✋ ConstraintError: name one of --exit <target> or --off" >&2
    echo "   fix: rhx network.vpn.set --help" >&2
    return 2
  fi
  if [[ -n "$country" && "$exit_to" != mullvad ]]; then
    echo "✋ ConstraintError: --country narrows --exit mullvad alone" >&2
    return 2
  fi
  # mullvad stays in the home country unless told otherwise — the same default
  # `grove-exitnode` holds (`1.13.exitnode`)
  [[ "$exit_to" == mullvad && -z "$country" ]] && country=us

  local js
  if ! js="$(timeout 10 tailscale status --json 2>/dev/null)"; then
    echo "💥 MalfunctionError: tailscaled did not answer" >&2
    echo "   read why: systemctl status tailscaled" >&2
    return 1
  fi

  # look up the target: one exit node this laptop may use
  local target=""
  if [[ $off -eq 0 && "$exit_to" == mullvad ]]; then
    target="$(printf '%s' "$js" | jq -r --arg cc "${country^^}" '
      .Peer // {} | to_entries | map(.value)
      | map(select(.ExitNodeOption == true and .Online == true
                   and ((.DNSName // "") | test("mullvad\\.ts\\.net\\.?$"))
                   and ($cc == "" or (.Location.CountryCode // "") == $cc)))
      | sort_by(-(.Location.Priority // 0)) | first | .DNSName // empty' | sed 's/\.$//')"
    if [[ -z "$target" ]]; then
      echo "✋ ConstraintError: no online mullvad exit node${country:+ in '$country'} is shared with this laptop" >&2
      echo "   ⇒ the mullvad add-on is bought in the tailscale admin console, and this device" >&2
      echo "     is granted access there — neither is a step this skill can take" >&2
      echo "   read the choices: rhx network.vpn.get" >&2
      return 2
    fi
  elif [[ $off -eq 0 ]]; then
    target="$(printf '%s' "$js" | jq -r --arg t "$exit_to" '
      .Peer // {} | to_entries | map(.value) | map(select(.ExitNodeOption == true))
      | map(select(.HostName == $t or ((.DNSName // "") | sub("\\.$"; "")) == $t
                   or ((.TailscaleIPs // []) | index($t))))
      | first | .DNSName // empty' | sed 's/\.$//')"
    if [[ -z "$target" ]]; then
      echo "✋ ConstraintError: '$exit_to' is not an exit node this laptop may use" >&2
      echo "   read the choices: rhx network.vpn.get" >&2
      return 2
    fi
  fi

  # the one write — root's. two doors, narrowest first:
  #   - mullvad and off go through `grove-exitnode` (`1.13.exitnode`), which
  #     sudoers lets an admin run with no password, and which reaches one pref
  #   - a named node (a house grove) needs cached sudo, never prompted for here
  local switch=/usr/local/sbin/grove-exitnode
  local args=(set "--exit-node=${target}" --exit-node-allow-lan-access=false)
  local rerun="sudo -v && rhx network.vpn.set $([[ $off -eq 1 ]] && echo --off || echo "--exit $exit_to${country:+ --country $country}")"
  if [[ -x "$switch" && ( $off -eq 1 || "$exit_to" == mullvad ) ]]; then
    local how=(on ${country:+"$country"})
    [[ $off -eq 1 ]] && how=(off)
    if ! timeout 20 sudo -n "$switch" "${how[@]}"; then
      echo "💥 MalfunctionError: grove-exitnode ${how[*]} failed — see its line above" >&2
      echo "   read why: journalctl -t grove-exitnode -n 10" >&2
      return 1
    fi
  elif ! timeout 5 sudo -n true 2>/dev/null; then
    echo "🌙 an exit node is a box-wide pref, and this seat holds no cached sudo — no change made"
    echo "   ⇒ run, from your own terminal:"
    echo "     $rerun"
    [[ -x "$switch" ]] || echo "   ⇒ or install the switch once, so mullvad and off need no password: $(printf 'sudo -v && rhx grove.provision --what 1.13.exitnode --mode apply')"
    return 0
  elif ! timeout 15 sudo -n tailscale "${args[@]}"; then
    echo "💥 MalfunctionError: tailscale refused the exit node change" >&2
    echo "   read why: sudo tailscale ${args[*]}" >&2
    return 1
  fi

  # read the route back — the proof that the switch held
  local now
  now="$(timeout 10 tailscale status --json 2>/dev/null | jq -r '
    .Peer // {} | to_entries | map(.value) | map(select(.ExitNode == true)) | first
    | if . == null then "direct" else "\(.HostName) · \(.Location.Country // "tailnet")" end')"

  echo "🛰️ network.vpn.set"
  if [[ $off -eq 1 ]]; then
    [[ "$now" == direct ]] || { echo "💥 MalfunctionError: --off was set, and the route still reads '$now'" >&2; return 1; }
    echo "   └─ direct — traffic leaves by this network ✔"
    return 0
  fi
  [[ "$now" != direct ]] || { echo "💥 MalfunctionError: the exit node was set, and the route still reads direct" >&2; return 1; }
  echo "   ├─ via $now ✔"
  if [[ -x /usr/local/sbin/grove-exitnode ]]; then
    echo "   └─ a captive portal pauses this (amber shield), and sign-in resumes it"
  else
    echo "   └─ ⚠️ on a captive-portal network, sign in BEFORE this — the portal cannot load through the tunnel"
  fi
}

main "$@"
