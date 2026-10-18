#!/usr/bin/env bash
######################################################################
# .what = prove every declared playwright library is installed
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_5_21_playwright_provision_verify() {
  local release packages name absent=()
  release="$(grove_provision_5_21_playwright_release)"
  mapfile -t packages < <(grove_provision_5_21_playwright_packages)

  if [[ ${#packages[@]} -eq 0 ]]; then
    echo "   🌙 no playwright list declared for '${release:-this os}' — no claim to prove"
    return 0
  fi

  for name in "${packages[@]}"; do
    pkg_present "$name" || absent+=("$name")
  done

  if [[ ${#absent[@]} -eq 0 ]]; then
    echo "   • all ${#packages[@]} playwright chromium libs installed ✔ ($release)"
    return 0
  fi

  echo "   ✋ ${#absent[@]} playwright chromium lib(s) absent: ${absent[*]}" >&2
  echo "      ⇒ a playwright chromium on this box fails to launch, so every e2e suite reds" >&2
  echo "      fix: sudo -v && rhx grove.provision --what 5.21.playwright --mode apply" >&2
  return 1
}
