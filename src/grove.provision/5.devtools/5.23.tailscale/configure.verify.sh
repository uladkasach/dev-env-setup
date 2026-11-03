#!/usr/bin/env bash
######################################################################
# .what = prove this machine is joined, and joined as the RIGHT kind
#
#   `local@unix` ✔ = joined · no tags · shields up · a camp grove is a peer
#   `cloud@*`    ✔ = joined · tags are exactly `tag:camp`
#
# .why "a camp grove is a peer" needs no grove name
#   - a peer that carries `tag:camp` IS a camp grove, by the tailnet's own acl
#   - ⇒ the check reads `tailscale status --json` and the repo tracks no grove
#     name and no tailnet name (`rule.forbid.dox-in-public-repo`, fulcrum F007)
#
# .why "tagged" stands in for "no user login"
#   - a tagged node belongs to no user; tailscale files it under its tagged
#     identity. so the tag set is the one read, and no login name is printed
#
# 🛑 .a join of the WRONG kind is the invariant breach, never a pass
#   - a laptop with tags, or a grove joined untagged as a user, ✋s — the two
#     invariants of #174, read back off the node itself
#
# guarantee:
#   - READ-ONLY; it prints no login, no address, no key
######################################################################

grove_provision_5_23_tailscale_configure_verify() {
  local js state tags tag peers
  tag="$(grove_provision_5_23_tailscale_tag)"

  if ! command -v tailscale >/dev/null 2>&1; then
    echo "   ✋ ConstraintError: not joined — tailscale is absent (see provision above)" >&2
    return 1
  fi

  case "${GROVE_ENV_SERVER:-}" in
    local@unix|cloud@*) ;;
    *)
      echo "   🌙 '${GROVE_ENV_SERVER:-unset}' has no join kind, so no join is claimed"
      return 0 ;;
  esac

  # every answer below is a jq read. an unparsed answer must never read as an
  #   empty one — "no tags" or "no camp peer" — so the parse is proven first
  if ! command -v jq >/dev/null 2>&1; then
    echo "   ✋ ConstraintError: jq is absent, so the daemon's answer cannot be read (see provision above)" >&2
    return 1
  fi
  js="$(grove_provision_5_23_tailscale_status)"
  if ! printf '%s' "$js" | jq -e 'type == "object"' >/dev/null 2>&1; then
    echo "   💥 MalfunctionError: could not read \`tailscale status --json\` as a json object" >&2
    echo "      ⇒ an unread answer is never reported as 'not joined' or 'no camp peer'" >&2
    echo "      read why: tailscale status --json; systemctl status tailscaled" >&2
    return 1
  fi
  state="$(printf '%s' "$js" | jq -r '.BackendState // "?"')"
  [[ -n "$state" ]] || state='?'

  if [[ "$state" != "Running" ]]; then
    echo "   ✋ ConstraintError: not joined — the daemon reads '${state}'" >&2
    case "${GROVE_ENV_SERVER}:${state}" in
      *:Stopped)
        echo "      ⇒ the node was taken down; restore it: $(grove_provision_5_23_tailscale_restore_say)" >&2
        return 1 ;;
      *:Starting)
        echo "      ⇒ the daemon has not settled (after a boot or a resume); rerun in a moment" >&2
        [[ "${GROVE_ENV_SERVER}" == cloud@* ]] && return 1 ;;
      *:NeedsMachineAuth)
        echo "      ⇒ a tailnet admin must approve this node in the admin console, then rerun" >&2
        return 1 ;;
      *:InUseOtherUser)
        echo "      ⇒ another login on this machine holds tailscale; that user must log it out" >&2
        return 1 ;;
      cloud@*:*)
        grove_provision_5_23_tailscale_provisioner_say >&2
        return 1 ;;
      local@unix:NeedsLogin)
        # the verify reads the url itself: a plan run, or a seat with no root,
        #   never printed one, so "the url above" may name naught
        local url
        url="$(printf '%s' "$js" | jq -r '.AuthURL // empty')"
        if [[ -n "$url" ]]; then
          echo "      ⇒ the sign-in is owed — open this url in your browser, as yourself, then rerun:" >&2
          echo "          ${url}" >&2
        fi
        [[ -n "$url" ]] || echo "      ⇒ the sign-in is owed, and no url is minted yet — the fix below mints one" >&2 ;;
    esac
    echo "      fix: $(grove_provision_5_23_tailscale_rerun)" >&2
    return 1
  fi

  if ! tags="$(printf '%s' "$js" | jq -r '(.Self.Tags // []) | sort | join(",")')"; then
    echo "   💥 MalfunctionError: could not read this node's tags from the daemon's answer" >&2
    return 1
  fi

  if [[ "$GROVE_ENV_SERVER" == cloud@* ]]; then
    if [[ "$tags" == "$tag" ]]; then
      echo "   ✔ joined · tags = ${tag}"
      return 0
    fi
    if [[ -z "$tags" ]]; then
      echo "   ✋ ConstraintError: this grove is joined untagged, as a USER — never as ${tag}" >&2
      echo "      ⇒ the invariant 'a remote grove never joins as a member' is broken" >&2
      echo "      ⇒ log it out (sudo tailscale logout), then its provisioner rejoins it:" >&2
      grove_provision_5_23_tailscale_provisioner_say >&2
      return 1
    fi
    echo "   ✋ ConstraintError: this grove carries tags '${tags}', not exactly '${tag}'" >&2
    echo "      ⇒ the camp's acl names ${tag}; another tag set reaches other doors" >&2
    echo "      ⇒ the provisioner's tailnet policy retags it (ahbode/infrastructure, declastruct)" >&2
    return 1
  fi

  # local@unix — a member, untagged, with a camp grove in sight
  if [[ -n "$tags" ]]; then
    echo "   ✋ ConstraintError: this laptop carries tags '${tags}'" >&2
    echo "      ⇒ the invariant 'a laptop never takes ${tag}' is broken" >&2
    echo "      ⇒ log it out and sign in as yourself:" >&2
    echo "          sudo tailscale logout && $(grove_provision_5_23_tailscale_rerun)" >&2
    return 1
  fi

  local shields
  shields="$(grove_provision_5_23_tailscale_shields)"
  if [[ "$shields" == "?" ]]; then
    echo "   💥 MalfunctionError: could not read whether this laptop's shields are up" >&2
    echo "      ⇒ an unread shield is never reported as up" >&2
    echo "      read why: tailscale debug prefs" >&2
    return 1
  fi
  if [[ "$shields" != up ]]; then
    echo "   ✋ ConstraintError: this laptop accepts inbound tailnet traffic (shields down)" >&2
    echo "      ⇒ a laptop reaches out and is never reached in; any service it listens on is open to the tailnet" >&2
    echo "      fix: $(grove_provision_5_23_tailscale_rerun)" >&2
    return 1
  fi

  if ! peers="$(printf '%s' "$js" | jq -r --arg t "$tag" \
    '[(.Peer // {})[] | select((.Tags // []) | index($t))] | length')" \
     || [[ ! "$peers" =~ ^[0-9]+$ ]]; then
    echo "   💥 MalfunctionError: could not count the camp peers in the daemon's answer (got '${peers:-}')" >&2
    return 1
  fi
  if [[ "$peers" -lt 1 ]]; then
    echo "   ✋ ConstraintError: joined as a member, but no camp grove (${tag}) is a peer" >&2
    echo "      ⇒ three causes: no camp grove is a node of this tailnet yet (none joined" >&2
    echo "        by its provisioner, or each one removed); this laptop signed in to" >&2
    echo "        another tailnet; or the camp's acl does not grant this login a camp grove" >&2
    echo "      ⇒ none joined yet: the provisioner's join is owed (ahbode/infrastructure)" >&2
    echo "      ⇒ another tailnet: sudo tailscale logout, then rerun and sign in to the camp's tailnet:" >&2
    echo "          $(grove_provision_5_23_tailscale_rerun)" >&2
    return 1
  fi

  echo "   ✔ joined as a member · no tags · shields up · a camp grove is a peer"
}
