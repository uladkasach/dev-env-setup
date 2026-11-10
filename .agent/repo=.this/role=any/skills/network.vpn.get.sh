#!/usr/bin/env bash
######################################################################
# .what = read which exit node this laptop routes through — if any — and every
#         exit node it may choose
#
# .why  = "am i on the vpn right now?" must be answered by the route itself,
#         never by memory of a `set`. an exit node that went offline leaves the
#         pref in place and the traffic nowhere, so its status is read too
#
# usage:
#   rhx network.vpn.get
#
# guarantee:
#   - READ-ONLY: it changes no tailscale pref
#   - every read is bounded by a timeout
######################################################################

set -uo pipefail

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        echo "🛰️ network.vpn.get — the exit node in use, and every one this laptop may choose"
        echo ""
        echo "usage:"
        echo "  rhx network.vpn.get"
        return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      *) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   fix: rhx network.vpn.get --help" >&2; return 2 ;;
    esac
  done

  if ! command -v tailscale >/dev/null 2>&1; then
    echo "✋ ConstraintError: tailscale is absent — there is no exit node to read" >&2
    echo "   fix: sudo -v && rhx grove.provision --what 5.23.tailscale --mode apply" >&2
    return 2
  fi

  local js
  if ! js="$(timeout 10 tailscale status --json 2>/dev/null)"; then
    echo "💥 MalfunctionError: tailscaled did not answer" >&2
    echo "   read why: systemctl status tailscaled" >&2
    return 1
  fi

  echo "🛰️ network.vpn.get"

  # 1. the route in use — read from the daemon, never from a remembered `set`
  echo ""
  echo "── 1. route (now)"
  printf '%s' "$js" | jq -r '
    (.Peer // {} | to_entries | map(.value) | map(select(.ExitNode == true)) | first) as $x
    | if $x == null then "      direct — no exit node; traffic leaves by this network"
      else "      via \($x.HostName) · \($x.Location.Country // "tailnet") · online=\($x.Online)"
      end'

  # 2. what this laptop may choose
  echo ""
  echo "── 2. exit nodes this laptop may use"
  # tailnet nodes by name (a house grove); mullvad by country, since it offers hundreds
  local opts
  opts="$(printf '%s' "$js" | jq -r '
    .Peer // {} | to_entries | map(.value) | map(select(.ExitNodeOption == true))
    | (map(select(((.DNSName // "") | test("mullvad\\.ts\\.net\\.?$")) | not))
       | .[] | "      \(.HostName)  (tailnet)  online=\(.Online)"),
      (map(select((.DNSName // "") | test("mullvad\\.ts\\.net\\.?$")))
       | if length == 0 then empty else
           "      mullvad: \(length) nodes, \(map(select(.Online)) | length) online — by country (--country <cc>):",
           (group_by(.Location.CountryCode // "?")
            | map("\(.[0].Location.CountryCode // "?" | ascii_downcase) \(length)")
            | _nwise(10) | "        " + join(" · "))
         end)')"
  if [[ -n "$opts" ]]; then
    printf '%s\n' "$opts"
  else
    echo "      · none — no exit node is shared with this laptop yet"
    echo "      ⇒ mullvad: buy the add-on in the tailscale admin console, then grant this device"
    echo "      ⇒ house grove: it advertises itself as an exit node; approve it in the console"
  fi

  # 3. the panel shield (`5.24.vpntray`) — is it declared, and is it up?
  echo ""
  echo "── 3. panel shield"
  local bin="$HOME/.local/bin/grove-vpntray" entry="$HOME/.config/autostart/grove-vpntray.desktop" pid
  local fix='rhx grove.provision --what 5.24.vpntray --mode apply'
  echo "      binary: $([[ -x "$bin" ]] && echo "built" || echo "absent — $fix")"
  echo "      autostart: $([[ -e "$entry" ]] && echo "declared" || echo "absent — $fix")"
  pid="$(pgrep -u "$(id -u)" -x grove-vpntray 2>/dev/null | head -n 1)"
  if [[ -n "$pid" ]]; then echo "      up now: yes (pid $pid)"; else echo "      up now: no"; fi

  echo ""
  echo "🌲 done — switch with: rhx network.vpn.set --exit <host|mullvad> · --off"
}

main "$@"
