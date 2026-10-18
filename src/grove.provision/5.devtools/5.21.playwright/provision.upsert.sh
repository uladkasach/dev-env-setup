#!/usr/bin/env bash
######################################################################
# .what = install the libraries a playwright chromium needs to launch
#
# guarantee:
#   - idempotent: `pkg_install` reads dpkg first, so a converged box asks
#     for no sudo — a seat without root passes once ground has installed them
#   - declines on a release this bundle declares no list for
######################################################################

grove_provision_5_21_playwright_provision_upsert() {
  local release packages
  release="$(grove_provision_5_21_playwright_release)"
  mapfile -t packages < <(grove_provision_5_21_playwright_packages)

  if [[ ${#packages[@]} -eq 0 ]]; then
    echo "   🌙 no playwright list declared for '${release:-this os}' — declined"
    echo "      ⇒ add its row from playwright's nativeDeps.ts to 5.21.playwright/_.sh"
    return 0
  fi

  pkg_install "${packages[@]}" || return 1
  echo "   • playwright chromium libs ✔ (${#packages[@]} packages, $release)"
}
