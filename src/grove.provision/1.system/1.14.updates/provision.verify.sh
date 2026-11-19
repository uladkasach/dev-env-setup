#!/usr/bin/env bash
######################################################################
# .what = prove `unattended-upgrades` is installed
#
# guarantee:
#   - READ-ONLY: one dpkg read
######################################################################

grove_provision_1_14_updates_provision_verify() {
  if pkg_present unattended-upgrades; then
    echo "   • unattended-upgrades is installed ✔"
    return 0
  fi

  echo "   ✋ ConstraintError: unattended-upgrades is NOT installed" >&2
  echo "      ⇒ this box takes no security patch until a human applies one" >&2
  echo "      fix: from a seat with sudo (ground on a grove; a laptop's own terminal):" >&2
  echo "        sudo -v && rhx grove.provision --what 1.14.updates --mode apply" >&2
  return 1
}
