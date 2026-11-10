#!/usr/bin/env bash
######################################################################
# .what = the host firewall: a local grove takes no inbound connection
#
# .why
#   - a local grove is a laptop with a human at its keyboard. it joins networks
#     it does not own, and it serves no one — so no connection may begin from
#     outside it (`define.invariant.local-grove-is-outbound-only`)
#   - 📜 measured 2026-11-08: one read of this laptop found sshd on 0.0.0.0:22, a
#     dev server on *:3000, and dropbox lan-sync on 0.0.0.0:17500 — each one a
#     target on any shared network. a listener is a matter of chance; a
#     default-drop firewall makes it no matter at all
#
# .why nftables in its OWN table, never ufw
#   - ufw's stock before.rules accept mdns and upnp inbound, so its "deny
#     inbound" default is not outbound-only, and its rules live in package
#     conffiles a second writer would fight
#   - one table, one file, one unit: this bundle is the sole writer of all three
#   - the file replaces `inet grove_firewall` alone, in one atomic transaction,
#     so tailscale's and docker's live tables are never wiped
#
# .why it applies on `local@unix` alone
#   - cloud and house groves are reached INBOUND by design — the duct is ssh —
#     and that reach belongs to their provisioner. a drop written here would
#     cut the duct this repo reaches them by
#   - `local@cicd` is a runner whose network is its host's
#   - ⇒ every other tier declines, with the reason, and makes no write
#
# usage:
#   sudo -v && rhx grove.provision --what 1.12.firewall --mode apply
######################################################################

# .what = where the declaration lives on the box, and its source in the repo
grove_provision_1_12_firewall_ruleset_at() { printf '/etc/grove/firewall.nft'; }
grove_provision_1_12_firewall_unit_at() { printf '/etc/systemd/system/grove-firewall.service'; }
grove_provision_1_12_firewall_dir() { printf '%s' "$GROVE_SRC/grove.provision/1.system/1.12.firewall"; }
grove_provision_1_12_firewall_unit() { printf 'grove-firewall'; }

# .what = the line a human runs to converge this bundle
# .why  = `sudo -v &&` leads — rhx hands a skill a piped stdin, so a bare `rhx`
#   cannot reach root on a laptop (`gotcha.rhx-runs-a-skill-with-no-tty`)
grove_provision_1_12_firewall_rerun() {
  printf 'sudo -v && rhx grove.provision --what 1.12.firewall --mode apply'
}

# .what = does this tier hold the firewall? — and if not, say why and decline
# .why  = one gate, read by all four phases, so no phase can drift from it
grove_provision_1_12_firewall_applies() {
  [[ "${GROVE_ENV_SERVER:-}" == local@unix ]] && return 0
  case "${GROVE_ENV_SERVER:-}" in
    cloud@*)    echo "   🌙 declined — a cloud grove is reached inbound by its duct; that reach is its provisioner's" ;;
    local@cicd) echo "   🌙 declined — a ci runner's network is its host's, and no human sits at it" ;;
    *)          echo "   🌙 declined — tier '${GROVE_ENV_SERVER:-<unset>}' is not one this bundle knows; it fails closed and writes naught" ;;
  esac
  return 1
}

# .what = the systemd answer for one query, or `?` — never two answers
# .why  = `systemctl is-enabled` PRINTS `not-found` AND exits non-zero for an
#   absent unit, so a bare `|| echo` reports both
grove_provision_1_12_firewall_unit_state() {
  local out
  out="$(timeout 5 systemctl "$1" "$(grove_provision_1_12_firewall_unit)" 2>/dev/null)"
  printf '%s' "${out:-?}"
}

grove_provision_1_12_firewall() {
  bundle.upgrade 1.12.firewall.provision.upsert
  bundle.upgrade 1.12.firewall.provision.verify
  bundle.upgrade 1.12.firewall.configure.upsert
  bundle.upgrade 1.12.firewall.configure.verify
}
