#!/usr/bin/env bash
######################################################################
# .what = the exit-node switch: mullvad on or off with no password, and a
#         pause + resume around a captive portal
#
# .why
#   - the exit node is off by default and switched on for a network the human
#     does not trust (`plan.exit-node`). a switch that asks for a password is
#     one the human skips
#   - an untrusted network is often a captive one: its sign-in page cannot load
#     through the tunnel, so with the vpn on the human is stuck until they turn
#     it off by hand — and then forgets to turn it back on
#
# .the three files, each root's
#   - /usr/local/sbin/grove-exitnode — the switch. it reaches one tailscale pref
#     and checks its own args
#   - /etc/sudoers.d/grove-exitnode — an admin runs `on` and `off` with no
#     password. the whole grant is that one file
#   - /etc/NetworkManager/dispatcher.d/90-grove-exitnode — NetworkManager calls
#     the switch on PORTAL (pause) and on FULL (resume)
#
# .why not `tailscale set --operator=$USER`
#   - the operator may change EVERY pref, shields-up included, from any process
#     of this user — an npm postinstall, an agent. the switch grants one pref
#
# .why the pause is safe enough
#   - it lasts only while NetworkManager reads PORTAL, and the panel shield
#     turns amber (`5.24.vpntray`) for the whole gap
#   - inbound stays dropped throughout (`1.12.firewall`)
#   - ⚠️ what the pause DOES open: outbound traffic leaves direct while it
#     holds. a human who wants zero direct packets signs in with the vpn off
#     and every other app closed
#
# .why `local@unix` alone
#   - a grove's tailscale is its provisioner's
#     (`define.invariant.grove-tailscale-has-one-owner`), and a grove does not
#     roam between networks
#
# usage:
#   sudo -v && rhx grove.provision --what 1.13.exitnode --mode apply
######################################################################

grove_provision_1_13_exitnode_dir() { printf '%s' "$GROVE_SRC/grove.provision/1.system/1.13.exitnode"; }

# .what = each declared file: "<repo name> <box path> <mode>"
#
# .why the sudoers grant is 0444, not the customary 0440
#   - verify reads each file with no root (`rule.require.judge-declared-state-not-live-state`);
#     a 0440 file reads as "not the repo copy" on every run, and the upsert
#     rewrites it every run
#   - sudo demands only root ownership and no group/other WRITE; its text is
#     already public in this repo, so world-read discloses naught
grove_provision_1_13_exitnode_files() {
  printf '%s\n' \
    "grove-exitnode /usr/local/sbin/grove-exitnode 0755" \
    "grove-exitnode.sudoers /etc/sudoers.d/grove-exitnode 0444" \
    "90-grove-exitnode /etc/NetworkManager/dispatcher.d/90-grove-exitnode 0755"
}

# .what = does the box file match the repo copy in content, mode, and root ownership?
grove_provision_1_13_exitnode_matches() {
  local src="$1" dst="$2" mode="$3"
  cmp -s "$src" "$dst" && [[ "$(stat -c '%a %U' "$dst" 2>/dev/null)" == "${mode#0} root" ]]
}

grove_provision_1_13_exitnode_rerun() {
  printf 'sudo -v && rhx grove.provision --what 1.13.exitnode --mode apply'
}

grove_provision_1_13_exitnode_applies() {
  [[ "${GROVE_ENV_SERVER:-}" == local@unix ]] && return 0
  case "${GROVE_ENV_SERVER:-}" in
    cloud@*)    echo "   🌙 declined — a cloud grove's tailscale is its provisioner's" ;;
    local@cicd) echo "   🌙 declined — a ci runner roams no network and routes through no exit node" ;;
    *)          echo "   🌙 declined — tier '${GROVE_ENV_SERVER:-<unset>}' is not one this bundle knows; it fails closed and writes naught" ;;
  esac
  return 1
}

grove_provision_1_13_exitnode() {
  bundle.upgrade 1.13.exitnode.configure.upsert
  bundle.upgrade 1.13.exitnode.configure.verify
}
