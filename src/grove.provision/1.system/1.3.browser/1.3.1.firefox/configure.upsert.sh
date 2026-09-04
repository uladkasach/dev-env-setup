#!/usr/bin/env bash
######################################################################
# .what = declare firefox's prefs via `user.js`, and open a tab for each extension
#         that is genuinely absent
#
# .why `user.js` and not `prefs.js`
#   - firefox REWRITES `prefs.js` on every clean exit
#   - ⇒ a value written there survives until the next quit and then reverts
#   - that is the worst failure shape: it works when tested and is gone the next day
#   - `user.js` is read at every start and re-applied over `prefs.js`
#
# .why the profile dir is READ and not assumed
#   - the flatpak profile lives at a generated path like `abc123.default-release`
#   - `profiles.ini` is the only file at a fixed path, so the dir is read out of it
#   - an absent `profiles.ini` means firefox has never been STARTED
#   - ⇒ that case reports what is owed, never a failure
#
# .why an extension tab is opened only when the extension is ABSENT
#   - mozilla requires a human to accept an extension's permission prompt
#   - ⇒ these three cannot be installed by any command
#   - three tabs every run is non-idempotent and obnoxious
#   - `extensions.json` names every accepted addon, so absence is CHECKABLE
#   - ⇒ a converged box opens no tab and a fresh one opens exactly what it owes
#
# .why the ctrl+N rebind runs BEFORE the profile is read
#   - the rebind lives in the flatpak `systemconfig` extension dir, not the profile
#   - that dir exists whether or not firefox has ever been started
#   - the profile lookup below returns early on a never-started firefox
#   - ⇒ a step placed after it is skipped on exactly the fresh box that needs it most
#
# guarantee:
#   - idempotent: `user.js` is overwritten from this file's text
#   - idempotent: the systemconfig channel is copied from the checkout's assets
#   - idempotent: a tab opens only for an extension absent from `extensions.json`
######################################################################

grove_provision_1_3_1_firefox_configure_upsert() {
  local ff_root="$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"

  ####################################################################
  # 0. ctrl+N tab keys — via the flatpak systemconfig channel
  #
  # .why the rebind
  #   - linux firefox binds tab 1..8 to alt+N, while kitty and tmux use ctrl+N
  #   - ⇒ the browser is the one surface where the same intent needs a different hand
  #
  # 🛑 COPY the payload from this bundle's OWN `firefox/`, never reach into `.agent/`
  #   - `src/` is the deployable unit, and `git.grove.push --from src` carries no dir beside it
  #   - ⇒ a bundle that executes a file OUTSIDE `src/` cannot converge on a paved-path box
  #   - 📜 grove 2026-07-31, against a phase that drove `.agent/…/firefox.systemconfig.sh install`:
  #       ✋ firefox.systemconfig.sh is absent or unreadable
  #          looked at: …/dev-env-setup.wip/.agent/…/firefox.systemconfig.sh
  #   - so the two files are declared assets under this bundle's own `firefox/` and this phase copies them
  #   - ⇒ `configure.verify` can `diff` the live files against the checkout and prove CURRENCY
  #
  # ⚠️ this phase is the ONE writer of the channel, and the skill writes none
  #   - two writers on one artifact is forbidden (`rule.forbid.two-writers-on-one-artifact`)
  #   - `firefox.systemconfig.sh` keeps its probe/status/doctor/uninstall verbs
  #   - its `install` verb names this bundle instead
  #
  # see: .agent/repo=.this/role=any/briefs/desktop/system/howto.firefox-ctrl-tab-keys.md
  ####################################################################
  local ext_dir="$HOME/.local/share/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable"
  local ff_assets="$GROVE_SRC/grove.provision/1.system/1.3.browser/1.3.1.firefox/firefox"

  if [[ ! -f "$ff_assets/autoconfig.js" || ! -f "$ff_assets/firefox.cfg" ]]; then
    echo "   ✋ the firefox autoconfig assets are absent from this checkout" >&2
    echo "      looked in: $ff_assets" >&2
    echo "      ⇒ \$GROVE_SRC is this run's OWN src/, so an absent file here is" >&2
    echo "        an incomplete checkout — a repo defect, not a box one" >&2
    return 1
  fi

  if ! mkdir -p "$ext_dir/defaults/pref"; then
    echo "   ✋ could not create the systemconfig extension dir" >&2
    echo "      at: $ext_dir/defaults/pref" >&2
    return 1
  fi

  if cp "$ff_assets/autoconfig.js" "$ext_dir/defaults/pref/autoconfig.js" \
     && cp "$ff_assets/firefox.cfg" "$ext_dir/firefox.cfg"; then
    echo "   • firefox ctrl+N tab keys declared (fully quit firefox to apply)"
  else
    echo "   ✋ could not write the systemconfig channel into $ext_dir" >&2
    echo "      ⇒ without both files firefox keeps the linux default alt+N, so" >&2
    echo "        ctrl+2 does not move a tab and reads as a broken keyboard" >&2
    return 1
  fi

  ####################################################################
  # 1. find the profile — it is generated, so it must be read
  ####################################################################
  local profile_dir
  profile_dir="$(grep -oP 'Path=\K.*default-release' "$ff_root/profiles.ini" 2>/dev/null)"
  if [[ -z "$profile_dir" ]]; then
    ##################################################################
    # 🛑 the SAME absent profile means two things, and only one is owed work
    #   - a profile is created by a GUI LAUNCH
    #   - on a box with a human, "open firefox once" is a step somebody can take
    #   - on every other box there is no display to launch into and no hand
    #   - ⇒ the precondition is not "unmet YET", it cannot be met at all
    #   - to print it anyway is a HAND STEP on the provision path, on every grove
    #   - and it names a SECOND APPLY as its fix, which finds the same absent profile forever
    #   - and it reports owed work on a box that is fully converged
    #   - (rule.require.one-command-provision)
    #
    # ⚠️ this does NOT reopen the "a grove would never USE it" objection
    #   - the flatpak and the ctrl+N channel both converge above this line
    #   - what declines is only the half whose precondition is a human-driven GUI launch
    ##################################################################
    if [[ "$GROVE_ENV_SERVER" != "local@unix" ]]; then
      echo "   🌙 no firefox profile here, and none is owed"
      echo "      ⇒ a profile is born of a GUI launch, and the prefs and the three"
      echo "        extensions below all live inside one. this box has no display"
      echo "        to launch into and no hand to accept an extension prompt"
      echo "      ⇒ what this bundle converges here is already done above: the"
      echo "        flatpak itself, and the ctrl+N systemconfig channel"
      return 0
    fi

    echo "   🌙 no firefox profile yet at $ff_root"
    echo "      ⇒ a fresh install creates no profile until firefox is STARTED once."
    echo "        prefs and extensions both live in the profile, so both are owed."
    echo "      fix: open firefox once, then re-drive:"
    echo "        rhx grove.provision --what 1.3.browser --mode apply"
    return 0
  fi

  local profile="$ff_root/$profile_dir"

  ####################################################################
  # 2. the prefs — declared in user.js, which firefox cannot overwrite
  ####################################################################
  cat > "$profile/user.js" <<'EOF'
// clean new tab page
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.highlights", false);
user_pref("browser.newtabpage.activity-stream.feeds.snippets", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.section.highlights.includePocket", false);
user_pref("browser.newtabpage.activity-stream.discoverystream.enabled", false);

// disable password, address, credit card autofill (use 1password)
user_pref("signon.rememberSignons", false);
user_pref("signon.autofillForms", false);
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);

// disable gtk emoji picker (ctrl+. conflicts with 1password)
user_pref("widget.gtk.native-emoji-dialog", false);
EOF
  echo "   • firefox prefs declared in user.js (restart firefox to apply)"

  ####################################################################
  # 3. the three extensions a human must accept
  #
  # each is opened ONLY when `extensions.json` does not already name it
  ####################################################################
  local addons="$profile/extensions.json"
  local opened=0

  ####################################################################
  # 🛑 a tab is opened only where a HUMAN can accept what it asks
  #   - this section's whole product is a permission prompt on a screen
  #   - mozilla requires a hand on it
  #   - ⇒ on a box with no human the opens below launch a browser into no display
  #   - and they print 🌙 lines that say "accept it by hand" to nobody
  #
  # ⚠️ it is gated HERE, not left to the profile gate above
  #   - today that gate returns first on every headless box, so this is unreachable
  #   - a grove that acquires a profile by any route walks straight past it
  #   - an ssh -X launch or a restored `$HOME` is such a route
  #   - ⇒ a step's precondition belongs at the step (`rule.require.solve-at-cause`)
  #
  # ⚠️ `local@unix` and not `local@*`
  #   - `local@cicd` is a local tier with no screen and no human
  #   - this needs both (`repo.overview.md`)
  ####################################################################
  if [[ "$GROVE_ENV_SERVER" != "local@unix" ]]; then
    echo "   🌙 the three extensions are not offered here, and none is owed"
    echo "      ⇒ each is accepted through a permission prompt mozilla shows on a"
    echo "        SCREEN; no command can accept one. so a tab opened on this box"
    echo "        would ask a question with nobody to answer it"
    return 0
  fi

  __browser_addon_absent() {
    # no extensions.json at all ⇒ no addon is accepted yet
    [[ -f "$addons" ]] || return 0
    grep -qiF "$1" "$addons" && return 1
    return 0
  }

  if __browser_addon_absent '1password'; then
    "$HOME/.local/bin/browser" \
      'https://addons.mozilla.org/en-US/firefox/addon/1password-x-password-manager/'
    echo "   🌙 1password extension is absent — a tab is open; accept it by hand"
    opened=$(( opened + 1 ))
  fi

  ####################################################################
  # the desert palette, to match this repo's kitty/nvim theme
  #   - it is a firefox-color SHARE url, so it applies only once that extension is accepted
  #
  # ⚠️ the url is a variable, and is NAMED again when all three are accepted
  #   - the theme tab must be gated on the EXTENSION's absence
  #   - the share url is inert in a firefox with no firefox-color
  #   - but the extension present does not mean the THEME is applied
  #   - a human who skipped the theme tab or later reset their theme lands past that gate forever
  #   - firefox-color keeps its theme in the extension's own storage, which no file exposes
  #   - ⇒ the claim is unprovable, and this phase must not pretend otherwise (rule.forbid.failhide)
  #   - what it can do is print the remedy, so the all-accepted branch prints the url
  ####################################################################
  local theme_url='https://color.firefox.com/?theme=XQAAAAIQAQAAAAAAAABBKYhm849SCia2CaaEGccwS-xMDPr_qlXDOMsy5fmNc7qTuOgZgZdB1JimDBY6_wyFhPNbQTHUNdhC5aOH-hbXzzZFdz54UfdCX_Q0U6BYOxbB4cKbN3-x8JbJB-nSYQTDMnJWVFqwFxW6UsMywRqsEjH6xrdahroi3D8vQwbLUkWN2HPFTCEwFJ-BNUTe2qbjSkITKQzctI3TSSXE5trErmv_7LBNAA'

  if __browser_addon_absent 'firefox color'; then
    "$HOME/.local/bin/browser" \
      'https://addons.mozilla.org/en-US/firefox/addon/firefox-color/'
    echo "   🌙 firefox-color extension is absent — a tab is open; accept it by hand"
    opened=$(( opened + 1 ))

    "$HOME/.local/bin/browser" "$theme_url"
    echo "      and the desert theme — click 'Yes, apply theme' in that tab"
  fi

  if __browser_addon_absent 'vimium'; then
    "$HOME/.local/bin/browser" \
      'https://addons.mozilla.org/en-US/firefox/addon/vimium-ff/'
    echo "   🌙 vimium extension is absent — a tab is open; accept it by hand"
    opened=$(( opened + 1 ))
  fi

  unset -f __browser_addon_absent

  if [[ "$opened" -eq 0 ]]; then
    echo "   • all three extensions already accepted — no tab opened"
    echo "     if firefox is not in the desert palette, apply it by hand:"
    echo "       $theme_url"
  fi
  return 0
}
