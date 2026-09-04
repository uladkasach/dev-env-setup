#!/usr/bin/env bash
######################################################################
# .what = prove ONE firefox is installed, that it is the registered default, and
#         that the quiet launcher runs
#
# .why "exactly one" is a claim worth its own check
#   - two firefoxes is not an error state, since both work
#   - the symptom a human sees is "firefox opened with none of my tabs or logins"
#   - `xdg-open` reached the snap build's empty profile
#   - ⇒ that reads as data loss, never as a config defect
#
# .why the launcher is PARSED and not merely stat'd
#   - `~/.local/bin/browser` is a two-line shell file this repo writes
#   - a file test proves the write, not that the file is executable or that it parses
#   - `sh -n` reads it without a browser window
#   - ⇒ that is the most this can check without a tab on the human's screen
#
# guarantee:
#   - READ-ONLY. it queries flatpak, dpkg, and xdg-settings, and parses one file.
#     it opens no window and repairs no state
#
# exit:
#   0 = one firefox, registered default, launcher present and parseable
#   1 = a claim failed, and which is named
######################################################################

grove_provision_1_3_1_firefox_provision_verify() {
  local failed=0

  ####################################################################
  # 1. the flatpak build exists
  ####################################################################
  if flatpak info org.mozilla.firefox >/dev/null 2>&1; then
    echo "   • firefox flatpak present ✔"
  else
    echo "   ✋ the firefox flatpak is NOT installed" >&2
    echo "      fix: rhx grove.provision --what 1.3.browser --mode apply" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 2. and the apt build does NOT — the two-firefox trap
  ####################################################################
  if dpkg -s firefox >/dev/null 2>&1; then
    echo "   ✋ an apt firefox is ALSO installed" >&2
    echo "      ⇒ both work, so this is not an error state — but xdg-open picks by" >&2
    echo "        whichever .desktop the mime db saw last, and the human's session" >&2
    echo "        lands in the snap build's EMPTY profile. it reads as lost tabs" >&2
    echo "        and lost logins, never as a config defect" >&2
    failed=$(( failed + 1 ))
  else
    echo "   • exactly one firefox — no apt build to fight it ✔"
  fi

  ####################################################################
  # 3. it is the registered default
  ####################################################################
  #
  # .why an EMPTY answer is a 🌙 and not a ✋
  #   - `xdg-settings` reads a desktop's mime database
  #   - a headless box has no such database, so it answers empty
  #   - ⇒ that is the box's nature, not a defect this bundle caused
  #   - a ✋ here would fire on every grove run forever
  #   - (rule.require.identical-bundle-composition)
  #   - a WRONG answer is different, since a registry that names another browser disagrees
  #   - ⇒ that still fails
  local default; default="$(xdg-settings get default-web-browser 2>/dev/null)"
  case "$default" in
    org.mozilla.firefox*) echo "   • default browser is the flatpak firefox ✔" ;;
    "")  echo "   🌙 no desktop mime registry here, so the default browser cannot be"
         echo "      observed. the app and its profile are unaffected by it" ;;
    *)   echo "   ✋ the default browser is '$default', not org.mozilla.firefox" >&2
         echo "      ⇒ a registry exists and names another browser, so xdg-open and" >&2
         echo "        'gh --web' reach that one instead" >&2
         echo "      fix: rhx grove.provision --what 1.3.1.firefox --mode apply" >&2
         failed=$(( failed + 1 )) ;;
  esac

  ####################################################################
  # 4. the launcher is present, executable, and parses
  ####################################################################
  local launcher="$HOME/.local/bin/browser"
  if [[ ! -f "$launcher" ]]; then
    echo "   ✋ no browser launcher at $launcher" >&2
    failed=$(( failed + 1 ))
  elif [[ ! -x "$launcher" ]]; then
    echo "   ✋ $launcher exists but is NOT executable" >&2
    echo "      ⇒ every caller gets 'permission denied', which reads as an absent" >&2
    echo "        command rather than a chmod that did not take" >&2
    failed=$(( failed + 1 ))
  # .why `sh -n` is right HERE, where `2.7.aliases` had to abandon it
  #   - the parser must match the SHEBANG
  #   - the upsert writes this launcher as `#!/bin/sh` with pure posix content
  #   - `2.7.aliases` checks dual-shell bash+zsh files, which dash rejects wholesale
  #   - ⇒ do not change this line to match that one by analogy
  elif ! sh -n "$launcher" 2>/dev/null; then
    echo "   ✋ $launcher does not parse as a shell file" >&2
    failed=$(( failed + 1 ))
  else
    echo "   • browser launcher present, executable, parses ✔"
  fi

  [[ "$failed" -eq 0 ]] || return 1
}
