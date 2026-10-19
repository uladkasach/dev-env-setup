#!/usr/bin/env bash
######################################################################
# .what = the system libraries a playwright chromium needs to launch —
#         what `npx playwright install-deps chromium` installs, declared here
#
# .why it is a bundle
#   - a repo's e2e suite downloads its own browser build per playwright
#     version, into `~/.cache/ms-playwright`. that half is the repo's
#   - the browser then dlopens ~30 box-wide libs (nss, gbm, atk, cups, x11…)
#     and fonts. those want root, so no repo can place them on a grove seat
#     that holds no sudo — ⇒ a box-wide fact, owned by a bundle
#
# .why the list is DECLARED, never `playwright install-deps` at apply time
#   - install-deps calls `sudo apt-get` itself, so it skips this tree's apt
#     funnel: no wait on the dpkg lock, no noninteractive env — the needrestart
#     prompt that once held a grove's duct for 57 minutes (`grove.pkg.sh`)
#   - its preview mode lists every package apt would TOUCH, upgrades included,
#     so its output is not the declaration either
#
# .why keyed by os release
#   - 24.04 renamed half these packages (`libasound2` → `libasound2t64`), so
#     one list cannot serve two releases. a release with no row here DECLINES
#     loudly, rather than install a list written for another
#
# .refs = playwright v1.64.0, packages/playwright-core/src/server/registry/
#         nativeDeps.ts — `deps['ubuntu22.04-x64']` and `deps['ubuntu24.04-x64']`,
#         each its `tools` + `chromium`
#
# usage:
#   sudo -v && rhx grove.provision --what 5.21.playwright --mode apply
######################################################################

# .what = the os release this box runs, as playwright keys it — `ubuntu24.04`, or empty
# .why pop-os reports ID=pop with ID_LIKE=ubuntu, and ships ubuntu's package names
grove_provision_5_21_playwright_release() {
  local id="" like="" ver=""
  [[ -r /etc/os-release ]] || return 0
  id="$(. /etc/os-release && echo "${ID:-}")"
  like="$(. /etc/os-release && echo "${ID_LIKE:-}")"
  ver="$(. /etc/os-release && echo "${VERSION_ID:-}")"
  [[ "$id" == ubuntu || " $like " == *" ubuntu "* ]] && echo "ubuntu$ver"
}

# .what = the packages for this box's release, one per line — empty where none is declared
grove_provision_5_21_playwright_packages() {
  local release
  release="$(grove_provision_5_21_playwright_release)"
  case "$release" in
    ubuntu22.04|ubuntu24.04) ;;
    *) return 0 ;;
  esac

  # tools — a virtual display, and the fonts a page renders with. one list on both releases
  printf '%s\n' xvfb fonts-noto-color-emoji fonts-unifont libfontconfig1 \
    libfreetype6 xfonts-cyrillic xfonts-scalable fonts-liberation \
    fonts-ipafont-gothic fonts-wqy-zenhei fonts-tlwg-loma-otf fonts-freefont-ttf

  # chromium — the libs the browser binary dlopens. 24.04 renamed half of them to `*t64`
  case "$release" in
    ubuntu22.04)
      printf '%s\n' libasound2 libatk-bridge2.0-0 libatk1.0-0 \
        libatspi2.0-0 libcairo2 libcups2 libdbus-1-3 libdrm2 libgbm1 \
        libglib2.0-0 libnspr4 libnss3 libpango-1.0-0 libwayland-client0 libx11-6 libxcb1 \
        libxcomposite1 libxdamage1 libxext6 libxfixes3 libxkbcommon0 libxrandr2
      ;;
    ubuntu24.04)
      printf '%s\n' libasound2t64 libatk-bridge2.0-0t64 libatk1.0-0t64 \
        libatspi2.0-0t64 libcairo2 libcups2t64 libdbus-1-3 libdrm2 libgbm1 \
        libglib2.0-0t64 libnspr4 libnss3 libpango-1.0-0 libx11-6 libxcb1 \
        libxcomposite1 libxdamage1 libxext6 libxfixes3 libxkbcommon0 libxrandr2
      ;;
  esac
}

grove_provision_5_21_playwright() {
  bundle.upgrade 5.21.playwright.provision.upsert
  bundle.upgrade 5.21.playwright.provision.verify
}
