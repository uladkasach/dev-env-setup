#!/usr/bin/env bash
######################################################################
# .what = join a laptop to the tailnet ONCE, as a member
#
#   `local@unix` → a MEMBER join: `sudo tailscale up`, no key, no tags. the
#                  daemon mints a login url; this prints it and RETURNS. the
#                  sign-in is the human's act, in his browser, as himself
#   `cloud@*`    → no join here. its provisioner joins it as `tag:camp` at
#                  machine build (`rule.require.the-provisioner-joins-the-tailnet`);
#                  `configure.verify` proves it
#   any other    → no join; there is no kind for that tier
#
# .why the daemon is read FIRST — see `_.sh`. `Running` ends the phase
#
# 🛑 .why the member path never waits on the browser
#   - `rhx` hands the skill a piped stdin, and a run that blocked on a login
#     would hold a terminal — or a duct — until a human clicked
#   - ⇒ the client is bounded by `timeout`; the DAEMON keeps the login offer,
#     and `tailscale status --json` hands back its `AuthURL`. the next apply
#     reads `Running` and does no work (fulcrum F008: measured on first apply)
#
# guarantee:
#   - a joined node is never sent a second `up`
#   - a seat with no root declines, and mints no url
#   - a cloud grove is never sent an `up`, and no key is read on any tier
#   - a joined laptop leaves with shields up: it refuses all inbound tailnet traffic
######################################################################

grove_provision_5_23_tailscale_configure_upsert() {
  ####################################################################
  # 0. no client, no join — `provision.verify` already reports why
  ####################################################################
  if ! command -v tailscale >/dev/null 2>&1; then
    echo "   🌙 tailscale is absent, so there is no node to join — see provision above"
    return 0
  fi

  ####################################################################
  # 1. the daemon first. a joined node takes no `up`, whatever its tier
  ####################################################################
  local state
  state="$(grove_provision_5_23_tailscale_state)"
  case "$state" in
    Running)
      echo "   • this node already joined the tailnet — no join owed"
      [[ "${GROVE_ENV_SERVER:-}" == local@unix ]] || return 0
      grove_provision_5_23_tailscale_shields_set
      return $? ;;
    Stopped)
      echo "   🌙 this node is joined and was taken down on purpose — left as it is"
      echo "      ⇒ to restore it: $(grove_provision_5_23_tailscale_restore_say)"
      return 0 ;;
    Starting)
      # a joined node, mid-boot or mid-resume. it takes no `up`; the verify
      #   below reads it again and names a rerun if it has not settled
      echo "   🌙 the daemon has not settled yet — no join owed; the verify below rereads it"
      return 0 ;;
    InUseOtherUser)
      echo "   ✋ ConstraintError: another login on this machine holds tailscale" >&2
      echo "      ⇒ tailscale serves one OS user at a time; that user must log it out" >&2
      echo "      read why: tailscale status" >&2
      return 1 ;;
    NeedsMachineAuth)
      echo "   ✋ ConstraintError: this node is joined and waits on a tailnet admin to approve it" >&2
      echo "      ⇒ approve it in the tailscale admin console, then rerun" >&2
      return 1 ;;
    NeedsLogin|NoState) ;;
    *)
      echo "   💥 MalfunctionError: could not read the tailscale daemon's state (got '${state}')" >&2
      echo "      ⇒ an unread state is never treated as 'not joined' — a second \`up\`" >&2
      echo "        on a joined node rewrites it" >&2
      echo "      read why: systemctl status tailscaled; tailscale status" >&2
      return 1 ;;
  esac

  ####################################################################
  # 2. the join kind, from the tier alone
  ####################################################################
  case "${GROVE_ENV_SERVER:-}" in
    local@unix) grove_provision_5_23_tailscale_join_member ;;
    cloud@*)
      echo "   🌙 a grove is joined by its provisioner, never here — the verify below checks it"
      return 0 ;;
    *)
      echo "   🌙 '${GROVE_ENV_SERVER:-unset}' has no join kind — a member join needs a"
      echo "      human at a laptop"
      return 0 ;;
  esac
}

######################################################################
# .what = the member join — print the login url, and return
######################################################################
grove_provision_5_23_tailscale_join_member() {
  # 🛑 a member join puts the human's own login on this node. the tier alone
  #   decides it, so a mis-tiered grove would mint a url that reads like a
  #   laptop's. refuse on any sign the shell is remote, before any url exists
  local remote
  remote="$(grove_provision_5_23_tailscale_seat_remote_why)"
  if [[ -n "$remote" ]]; then
    echo "   ✋ ConstraintError: a member join is a laptop's own sign-in, and this seat reads as remote" >&2
    echo "      ⇒ ${remote}" >&2
    echo "      ⇒ on a grove: its tier is wrong, so no url was minted. check /etc/grove/platform" >&2
    echo "      ⇒ on your laptop: run it at the laptop's own keyboard, not over ssh" >&2
    return 1
  fi

  bundle.root.owns "the tailnet sign-in" "this laptop is not on the tailnet yet" || return 0

  # a node that already waits for a login holds its url; ask before any `up`
  local url said=""
  url="$(grove_provision_5_23_tailscale_status | jq -r '.AuthURL // empty' 2>/dev/null)"

  if [[ -z "$url" ]]; then
    # .why the exit code is not read: the client WAITS for the browser, so
    #   `timeout` ends it by design (124). success is read from the daemon below
    #   — a url present, or a node already joined — never from this exit code
    # .why its words are KEPT, never sunk: where no url appears, the client's
    #   own reason is the one clue left. a member join carries no secret to leak
    # `--shields-up` from the first `up`: the node refuses inbound before it
    #   ever holds a tailnet address
    said="$(sudo timeout 20 tailscale up --shields-up 2>&1)"
    if [[ "$(grove_provision_5_23_tailscale_state)" == "Running" ]]; then
      echo "   • joined as a member"
      grove_provision_5_23_tailscale_shields_set
      return $?
    fi
    url="$(grove_provision_5_23_tailscale_status | jq -r '.AuthURL // empty' 2>/dev/null)"
  fi

  if [[ -z "$url" ]]; then
    echo "   💥 MalfunctionError: tailscale offered no login url" >&2
    echo "      ⇒ the daemon reads '$(grove_provision_5_23_tailscale_state)' and holds no AuthURL" >&2
    if [[ -n "$said" ]]; then
      echo "      ⇒ the client said:" >&2
      printf '%s\n' "$said" | sed 's/^/        /' >&2
    fi
    echo "      read why: systemctl status tailscaled; tailscale status" >&2
    return 1
  fi

  echo "   🙋 sign in — open this url in your browser, as yourself:"
  echo "      ${url}"
  echo "      then rerun: $(grove_provision_5_23_tailscale_rerun)"
  return 0
}

######################################################################
# .what = set shields-up on a laptop — it refuses every inbound tailnet
#         connection, and its own outbound reach (ssh to a grove) is unchanged
# .why  = a laptop needs no inbound. the tailnet's acl is one fence; this is a
#         second, on the node itself, so a wrong acl or a stray listener on the
#         laptop is never reachable from the tailnet
######################################################################
grove_provision_5_23_tailscale_shields_set() {
  local shields
  shields="$(grove_provision_5_23_tailscale_shields)"
  if [[ "$shields" == up ]]; then
    echo "   • shields up — this laptop refuses inbound tailnet traffic ✔"
    return 0
  fi

  bundle.root.owns "the laptop's inbound shield" "this laptop accepts inbound tailnet traffic" || return 0

  if ! sudo timeout 10 tailscale set --shields-up; then
    echo "   💥 MalfunctionError: \`tailscale set --shields-up\` failed; this laptop may accept inbound tailnet traffic" >&2
    echo "      read why: systemctl status tailscaled; tailscale status" >&2
    return 1
  fi
  if [[ "$(grove_provision_5_23_tailscale_shields)" != up ]]; then
    echo "   💥 MalfunctionError: shields-up was set, but the daemon does not report it" >&2
    echo "      ⇒ check by hand: tailscale debug prefs | jq .ShieldsUp" >&2
    return 1
  fi
  echo "   • shields up — inbound tailnet traffic now refused ✔"
}

######################################################################
# .what = why this seat reads as remote — empty when it reads as local
# .why  = facts independent of the tier: an ssh session, or a platform
#         declaration, which only a grove's bootstrap writes
######################################################################
grove_provision_5_23_tailscale_seat_remote_why() {
  [[ -n "${SSH_CONNECTION:-}" ]] && { printf 'SSH_CONNECTION is set: this shell came in over ssh'; return 0; }
  [[ -n "${SSH_TTY:-}" ]] && { printf 'SSH_TTY is set: this shell came in over ssh'; return 0; }
  [[ -e "$(grove_env_platform_file)" ]] && { printf '%s declares a grove platform' "$(grove_env_platform_file)"; return 0; }
  return 0
}
