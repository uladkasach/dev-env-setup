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
  # 0. ctrl+N tab keys — via the flatpak systemconfig channel, so the browser
  #    matches kitty and tmux rather than linux firefox's alt+N
  # 🛑 COPY this bundle's OWN `firefox/` assets — `src/` is the deployable unit,
  #    and this phase is the channel's ONE writer
  # .refs = howto.firefox-ctrl-tab-keys — the measurement and the two-writers case
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
    # 🛑 an absent profile is owed work only where a human can launch the GUI —
    #    elsewhere it can never be met, and a "fix" would loop forever
    #    (rule.require.one-command-provision). the flatpak and ctrl+N above converge
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

// unload inactive tabs once memory runs low.
// .why = OFF by default on linux, ON by default on win/mac. so a linux box with
//        a long-lived window pays for every tab it has ever opened: each one is
//        a full DOM, js heap, jit cache, and gpu buffer, held for as long as the
//        tab exists. measured 2026-09-06: 39 content processes at 8.9G.
user_pref("browser.tabs.unloadOnLowMemory", true);

// trip that unload BEFORE the box is desperate.
// .why = the defaults trip at 200MB free, or 5% of total. on a 31G box 5% is
//        1.5G — by which point this machine is already deep in swap, so the
//        remedy arrives after the harm it exists to prevent.
user_pref("browser.low_commit_space_threshold_mb", 3072);
user_pref("browser.low_commit_space_threshold_percent", 10);

// cap content processes at 4 (the default is 8 on a box with >= 8 cpus).
// .cost = tabs that share a process share its fate: one content crash takes
//         every tab in that process with it. 4 is a deliberate trade, not a
//         knob to lower further — do NOT set 1.
user_pref("dom.ipc.processCount", 4);
EOF
  echo "   • firefox prefs declared in user.js (restart firefox to apply)"

  ####################################################################
  # 3. the three extensions a human must accept
  #
  # each is opened ONLY when `extensions.json` does not already name it
  ####################################################################
  local addons="$profile/extensions.json"
  local opened=0

  # 🛑 a tab opens only where a HUMAN can accept its prompt — gated HERE too, since
  #    a grove can gain a profile (ssh -X, a restored $HOME) and walk past the gate
  #    above. `local@unix`, never `local@*`: `local@cicd` has no screen
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

  # the desert palette — a firefox-color SHARE url, inert until that extension
  # is accepted. ⚠️ whether the THEME is applied lives in extension storage no
  # file exposes, so it is unprovable; the all-accepted branch prints the url
  # rather than claim it (rule.forbid.failhide)
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
