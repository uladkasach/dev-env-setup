#!/usr/bin/env bash
######################################################################
# .what = declare firefox's prefs via `user.js`, its keybinds via autoconfig, and
#         its three extensions via a force-install policy
#
# .why
#   - `user.js`, never `prefs.js`: firefox rewrites `prefs.js` on every clean exit
#   - the profile dir is READ from `profiles.ini`, since its name is generated
#   - the extensions are a POLICY: `ExtensionSettings` force-installs them at
#     firefox's next start with no prompt, so no tab and no hand step
#   - the ctrl+N rebind and the policy run FIRST: both ride the systemconfig
#     channel, and the profile read returns early on a fresh box
#
# guarantee:
#   - idempotent: `user.js` is overwritten from this file's text
#   - idempotent: the systemconfig channel is copied from the checkout's assets
#   - idempotent: `policies.json` is copied from the checkout's assets
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

  if [[ ! -f "$ff_assets/autoconfig.js" || ! -f "$ff_assets/firefox.cfg" || ! -f "$ff_assets/gtk.css" || ! -f "$ff_assets/policies.json" ]]; then
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
    echo "   • firefox ctrl+N tab keys + ctrl+q close-tab declared (fully quit firefox to apply)"
  else
    echo "   ✋ could not write the systemconfig channel into $ext_dir" >&2
    echo "      ⇒ without both files firefox keeps the linux default alt+N, so" >&2
    echo "        ctrl+2 does not move a tab and reads as a broken keyboard" >&2
    return 1
  fi

  ####################################################################
  # 0a. the extensions — force-installed by policy, through the same channel
  #   - flatpak firefox reads `/app/etc/firefox/policies/policies.json`, which
  #     this host dir surfaces; the host's `/etc/firefox/policies` it ignores
  ####################################################################
  if mkdir -p "$ext_dir/policies" && cp "$ff_assets/policies.json" "$ext_dir/policies/policies.json"; then
    echo "   • extension policy declared: 1password, firefox-color, vimium (installed at next firefox start)"
  else
    echo "   ✋ could not write $ext_dir/policies/policies.json" >&2
    echo "      ⇒ without it, the three extensions are never installed on a fresh box" >&2
    return 1
  fi

  ####################################################################
  # 0b. ctrl+w deletes a word in text fields — a gtk keybind scoped to the
  #     flatpak's OWN config dir, so only firefox reads it. it reaches a field
  #     only because firefox.cfg above frees ctrl+w from close-tab
  ####################################################################
  local gtk_dir="$HOME/.var/app/org.mozilla.firefox/config/gtk-3.0"
  if mkdir -p "$gtk_dir" && cp "$ff_assets/gtk.css" "$gtk_dir/gtk.css"; then
    echo "   • firefox ctrl+w delete-word declared in its gtk.css (fully quit firefox to apply)"
  else
    echo "   ✋ could not write firefox's gtk.css into $gtk_dir" >&2
    echo "      ⇒ ctrl+w in a text field does naught, rather than delete a word" >&2
    return 1
  fi

  ####################################################################
  # 0c. the fleet board — a READ-ONLY grant of ONE dir into the sandbox
  #     the flatpak sees none of $HOME by default, so a file:// url to
  #     ~/.rhachet/fleet/fleet.board.html opens as "file not found"
  # 🛑 the grant is `~/.rhachet/fleet:ro`, never `~/.rhachet`: its siblings
  #    hold keyrack state, and a browser is the widest attack surface on the
  #    box (rule.require.narrowest-terminal-grant)
  # ⚠️ an override is read at sandbox START — a live firefox must fully quit
  ####################################################################
  local fleet_grant='~/.rhachet/fleet:ro'
  if flatpak override --user --filesystem="$fleet_grant" org.mozilla.firefox 2>/dev/null; then
    echo "   • firefox may read the fleet board: $fleet_grant (fully quit firefox to apply)"
  else
    echo "   ✋ could not grant firefox $fleet_grant" >&2
    echo "      ⇒ file:///…/.rhachet/fleet/fleet.board.html reads as absent in firefox" >&2
    return 1
  fi

  ####################################################################
  # 1. find the profile — it is generated, so it must be read
  ####################################################################
  local profile_dir
  profile_dir="$(grove_provision_1_3_1_firefox_profile_dir)"
  if [[ -z "$profile_dir" ]]; then
    # 🛑 an absent profile is owed work only where a human can launch the GUI —
    #    elsewhere it can never be met, and a "fix" would loop forever
    #    (rule.require.one-command-provision). the flatpak and ctrl+N above converge
    if [[ "$GROVE_ENV_SERVER" != "local@unix" ]]; then
      echo "   🌙 no firefox profile here, and none is owed"
      echo "      ⇒ a profile is born of a GUI launch, and the prefs below live"
      echo "        inside one. this box has no display to launch into"
      echo "      ⇒ what this bundle converges here is already done above: the"
      echo "        flatpak itself, the ctrl+N channel, and the extension policy"
      return 0
    fi

    echo "   🌙 no firefox profile yet at $ff_root"
    echo "      ⇒ a fresh install creates no profile until firefox is STARTED once."
    echo "        the prefs live in the profile, so they are owed; the extensions"
    echo "        arrive by policy at that same first start."
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
  # 2b. 1password's options — inline fill + save offer on, universal sign in off
  #     they live in the extension's storage.local, which no pref or policy
  #     reaches, so they are written into that store (firefox/addon.storage.local.py)
  # 🛑 a write needs firefox QUIT: the extension holds its config in memory
  #    and saves it back over any write made under it
  ####################################################################
  local op_out op_code
  op_out="$(grove_provision_1_3_1_firefox_onepassword_options "$profile" apply 2>&1)"
  op_code=$?
  case "$op_code" in
    0) echo "   • 1password options declared: inline fill + save offer on, universal sign in off ✔" ;;
    4) echo "   🌙 1password options owed — firefox is live, and a write under it is lost"
       echo "      fix: quit firefox (☰ → Quit), then rhx grove.provision --what 1.3.1.firefox --mode apply" ;;
    5) echo "   🌙 1password has no storage here yet — its options land once it has run" ;;
    *) echo "   ✋ could not declare the 1password options" >&2
       echo "$op_out" | sed 's/^/      /' >&2
       return 1 ;;
  esac

  ####################################################################
  # 3. the desert palette — the one option NO policy or store write reaches
  #   - firefox color applies a theme from a SHARE url, by a click
  #   - its storage IS readable, so the step is printed only while owed,
  #     and the verify reports it ✔ once done
  ####################################################################
  [[ "$GROVE_ENV_SERVER" == "local@unix" ]] || return 0
  local theme_url='https://color.firefox.com/?theme=XQAAAAIQAQAAAAAAAABBKYhm849SCia2CaaEGccwS-xMDPr_qlXDOMsy5fmNc7qTuOgZgZdB1JimDBY6_wyFhPNbQTHUNdhC5aOH-hbXzzZFdz54UfdCX_Q0U6BYOxbB4cKbN3-x8JbJB-nSYQTDMnJWVFqwFxW6UsMywRqsEjH6xrdahroi3D8vQwbLUkWN2HPFTCEwFJ-BNUTe2qbjSkITKQzctI3TSSXE5trErmv_7LBNAA'
  local theme
  theme="$(grove_provision_1_3_1_firefox_theme_state)"
  if [[ "$theme" == done ]]; then
    echo "   • the desert palette is applied ✔"
    return 0
  fi
  echo "   🌙 owed, once per profile — desert palette: open, then 'Yes, apply theme':"
  echo "        $theme_url"
  return 0
}
