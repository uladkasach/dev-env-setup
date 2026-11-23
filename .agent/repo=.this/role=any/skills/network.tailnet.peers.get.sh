#!/usr/bin/env bash
######################################################################
# .what = list the tailnet peers this box sees, by the short name a dial uses,
#         whether each is online, when it was last seen, and its acl tags
#
# .why  = a rebuilt box re-joins the tailnet as a NEW node. while the old node's
#         record survives, tailscale hands the new one a suffixed name (`<name>-1`),
#         so the name a registry dials answers for the DEAD node and a scan of it
#         times out. this read names that state in one call, so a reach failure is
#         sorted into "box down" vs "name moved" before any guess
#         📜 2026-11-18, the first hetzner grove: a rebuild left the key
#         scan at the registry's name silent for 30s
#
# usage:
#   rhx network.tailnet.peers.get                       # every peer
#   rhx network.tailnet.peers.get --match hetzner       # names that hold a fragment
#
# guarantee:
#   - READ-ONLY: it changes no tailscale state
#   - the daemon read is bounded by a timeout
#   - prints names and states only; no tailnet address, no tailnet domain
######################################################################

set -uo pipefail

main() {
  local match=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --match) match="${2:-}"; shift 2 ;;
      --help|-h)
        echo "🛰️ network.tailnet.peers.get — tailnet peers by short name, online state, last seen"
        echo ""
        echo "usage:"
        echo "  rhx network.tailnet.peers.get [--match <fragment>]"
        echo ""
        echo "inputs:"
        echo "  --match  keep peers whose short name holds this fragment (default: all)"
        echo ""
        echo "example:"
        echo "  rhx network.tailnet.peers.get --match hetzner"
        return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      *) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   fix: rhx network.tailnet.peers.get --help" >&2; return 2 ;;
    esac
  done

  if ! command -v tailscale >/dev/null 2>&1; then
    echo "✋ ConstraintError: tailscale is absent — this laptop sees no tailnet" >&2
    echo "   fix: sudo -v && rhx grove.provision --what 5.23.tailscale --mode apply" >&2
    return 2
  fi

  local js
  if ! js="$(timeout -k 2 10 tailscale status --json </dev/null 2>/dev/null)"; then
    echo "💥 MalfunctionError: tailscaled did not answer in 10s" >&2
    echo "   read why: systemctl status tailscaled" >&2
    return 1
  fi

  echo "🛰️ network.tailnet.peers.get${match:+ --match $match}"
  # the short name is the DNSName's first label: the name a dial resolves
  printf '%s' "$js" | jq -r --arg m "$match" '
    [ .Peer // {} | to_entries[] | .value
      | { name: ((.DNSName // "") | split(".")[0]), online: .Online, seen: ((.LastSeen // "-") | .[0:16]),
          tags: ((.Tags // []) | join(",")) }
      | select($m == "" or (.name | contains($m))) ]
    | sort_by(.name)
    | if length == 0 then "   └─ no peer matched"
      else (to_entries | map(
        (if .key == (length - 1) then "   └─ " else "   ├─ " end)
        + .value.name + "  " + (if .value.online then "online ✔" else "offline · last seen " + .value.seen end)
        + (if .value.tags == "" then "" else "  · " + .value.tags end)
      ) | .[])
      end'
}

main "$@"