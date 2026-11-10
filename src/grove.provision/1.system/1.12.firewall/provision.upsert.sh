#!/usr/bin/env bash
######################################################################
# .what = make `nft` exist on this box — the one binary the unit runs
#
# guarantee:
#   - idempotent: `pkg_install` reads dpkg first, and asks no root where the
#     package is present
#   - declines on every tier but `local@unix` (`_.sh`)
######################################################################

grove_provision_1_12_firewall_provision_upsert() {
  grove_provision_1_12_firewall_applies || return 0
  pkg_install nftables || return 1
}
