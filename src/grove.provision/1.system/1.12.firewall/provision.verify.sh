#!/usr/bin/env bash
######################################################################
# .what = prove `nft` is on this box, at the path the unit runs it from
#
# .why the PATH, and not merely the command
#   - the unit names `/usr/sbin/nft` absolutely; systemd does not search PATH
#   - ⇒ an `nft` found elsewhere would pass a `command -v` and fail at boot
#
# guarantee:
#   - READ-ONLY
######################################################################

grove_provision_1_12_firewall_provision_verify() {
  grove_provision_1_12_firewall_applies || return 0

  if [[ ! -x /usr/sbin/nft ]]; then
    echo "   ✋ ConstraintError: /usr/sbin/nft is absent — the firewall unit has no binary to run" >&2
    echo "      ⇒ at boot the unit fails, and the box comes up with no firewall" >&2
    echo "      fix: $(grove_provision_1_12_firewall_rerun)" >&2
    return 1
  fi
  echo "   • nft present ($(timeout 5 /usr/sbin/nft --version 2>/dev/null || echo '?')) ✔"
}
