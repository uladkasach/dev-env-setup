#!/usr/bin/env bash
######################################################################
# .what = install `unattended-upgrades`
#
# guarantee:
#   - reads dpkg first; a box that holds the package asks for no root
#   - a seat with no root declines by name (`bundle.root.owns`)
#   - a failed install names itself, never the next phase's symptom
######################################################################

grove_provision_1_14_updates_provision_upsert() {
  if pkg_present unattended-upgrades; then
    echo "   • unattended-upgrades ✔ (already installed)"
    return 0
  fi

  bundle.root.owns "the unattended-upgrades package" "unattended-upgrades is not installed" || return 0
  if ! bundle.run pkg_install unattended-upgrades; then
    echo "   💥 MalfunctionError: unattended-upgrades did not install" >&2
    bundle.said "      " "$BUNDLE_SAID" >&2
    return 1
  fi
  echo "   • unattended-upgrades installed"
}
