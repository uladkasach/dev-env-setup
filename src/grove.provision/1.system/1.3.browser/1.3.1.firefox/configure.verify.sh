#!/usr/bin/env bash
######################################################################
# .what = prove the ctrl+N tab rebind is declared, prove `user.js` declares the
#         prefs that matter, and report which of the three human-click extensions
#         are still owed
#
# .why it asserts three prefs and not all fifteen
#   - a check per pref is a second copy of the upsert's text, and a second copy drifts
#   - so it asserts the three whose absence a human would misdiagnose as another defect:
#
#     signon.rememberSignons          → a credential lands outside 1password
#     widget.gtk.native-emoji-dialog  → ctrl+. opens gtk's picker, 1password never fires
#     ...showSponsored                → the new tab page fills with ads
#
#   - the rest are cosmetic siblings of the third
#   - ⇒ if `user.js` holds those three, it landed from this bundle
#
# .why an absent extension is a 🌙 and NOT a failure
#   - mozilla requires a human hand on the permission prompt
#   - ⇒ an absent extension is work OWED to a human, not work this bundle got wrong
#   - a failure here would fire on every fresh box until the human clicks
#   - that teaches a reader to ignore this roll
#   - (rule.forbid.failhide cuts both ways: a false alarm is its own dishonesty)
#
# guarantee:
#   - READ-ONLY. it reads the systemconfig extension dir, profiles.ini, user.js,
#     and extensions.json. it opens no window, launches no sandbox, repairs no state
#
# exit:
#   0 = the tab rebind is declared AND user.js declares the three load-bear prefs.
#       extensions owed are NAMED
#   1 = the tab rebind is absent or half-declared, or user.js is absent, or a
#       load-bear pref is not declared in it
######################################################################

grove_provision_1_3_1_firefox_configure_verify() {
  local ff_root="$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"
  local failed=0

  ####################################################################
  # 0. the ctrl+N tab rebind — checked FIRST, since it does not live in the profile
  #
  # ⚠️ it is asserted from the HOST files, not from the sandbox
  #   - `firefox.systemconfig.sh status` answers by a `flatpak run --command=cat`
  #   - ⇒ that is a real sandbox launch on every plan
  #   - it probes live state the host files already decide
  #   - (`rule.require.judge-declared-state-not-live-state`)
  #   - and it is unbounded where a verify must be bounded
  #   - (`rule.require.bounded-probes-in-verifies`)
  #   - the two host files ARE the declaration, so if they hold, the mount holds
  ####################################################################
  # ⚠️ this DIFFS rather than greps
  #   - a `grep 'key_selectTab'` proves the token landed once
  #   - it does not prove the live file matches this checkout
  #   - these two files are COPIED, so a stale copy passes a grep
  #   - ⇒ last month's rebind runs silently
  #   - `cmp` is the only check that separates "arrived" from "current"
  local ext_dir="$HOME/.local/share/flatpak/extension/org.mozilla.firefox.systemconfig/x86_64/stable"
  local ff_assets="$GROVE_SRC/grove.provision/1.system/1.3.browser/1.3.1.firefox/firefox"
  local pair
  for pair in \
    "autoconfig.js:$ext_dir/defaults/pref/autoconfig.js" \
    "firefox.cfg:$ext_dir/firefox.cfg"
  do
    local name="${pair%%:*}"
    local dst="${pair#*:}"
    local src="$ff_assets/$name"

    if [[ ! -f "$dst" ]]; then
      echo "   ✋ $name is absent from $dst" >&2
      echo "      ⇒ without BOTH files firefox keeps the linux default alt+N, so" >&2
      echo "        ctrl+2 does not move a tab and reads as a broken keyboard" >&2
      echo "      fix: rhx grove.provision --what 1.3.browser --mode apply" >&2
      failed=$(( failed + 1 ))
    elif [[ ! -f "$src" ]]; then
      echo "   🌙 $name is installed, but this checkout holds no $src"
    elif cmp -s "$src" "$dst"; then
      echo "   • $name matches this checkout ✔"
    else
      echo "   ✋ the installed $name DIFFERS from this checkout" >&2
      echo "      read the drift: diff $src $dst" >&2
      echo "      ⇒ firefox loads the STALE copy, so the rebind that is live is" >&2
      echo "        whichever one an older revision declared" >&2
      echo "      fix: rhx grove.provision --what 1.3.browser --mode apply" >&2
      failed=$(( failed + 1 ))
    fi
  done

  echo "   🌙 unverified — whether a LIVE firefox has read them. autoconfig is"
  echo "      read once at start, so a full quit is what makes the rebind take"

  ####################################################################
  # 1. the profile must exist before its contents can be checked at all
  ####################################################################
  local profile_dir
  profile_dir="$(grep -oP 'Path=\K.*default-release' "$ff_root/profiles.ini" 2>/dev/null)"
  if [[ -z "$profile_dir" ]]; then
    ##################################################################
    # 🛑 "yet" is a claim about the FUTURE, and it is true on one box only
    #   - a profile is born of a GUI launch
    #   - ⇒ a box with no display and no human has no such future
    #   - "no profile yet … open firefox once" names a step no one can take
    #   - it names it on EVERY apply forever
    #   - and it reports owed work on a box that holds all this bundle can give it
    #   - its upsert twin carries the same repair and the full argument
    #
    # ⚠️ a repair applied to one phase of a bundle is not applied to the bundle
    #   - 📜 `5.8.docker` learned that twice, two days apart, over this exact shape
    #   - (`rule.require.one-command-provision`)
    ##################################################################
    if [[ "$GROVE_ENV_SERVER" != "local@unix" ]]; then
      echo "   🌙 no profile here, and none is owed — so its prefs and extensions"
      echo "      are not observable and are not absent. a profile is born of a GUI"
      echo "      launch, and this box has no display and no hand to launch one"
      echo "      ⇒ claim 0 above is the part of this bundle that DOES converge"
      echo "        here, and it stands on its own verdict"
    else
      echo "   🌙 unverified — firefox has no profile yet, so neither its prefs nor"
      echo "      its extensions can be observed. a profile is created at first launch"
      echo "      fix: open firefox once, then re-drive --what 1.3.browser"
    fi
    # ⚠️ the early return must still carry claim 0's verdict
    #   - the rebind lives OUTSIDE the profile, so a never-started firefox is silent about it
    #   - ⇒ a flat `return 0` here would swallow a real failure (rule.forbid.failhide)
    [[ "$failed" -eq 0 ]] || return 1
    return 0
  fi

  local profile="$ff_root/$profile_dir"
  local prefs="$profile/user.js"

  ####################################################################
  # 2. user.js exists — and it is user.js, not prefs.js
  ####################################################################
  if [[ ! -f "$prefs" ]]; then
    echo "   ✋ no user.js at $prefs" >&2
    echo "      ⇒ a value in prefs.js would be REWRITTEN by firefox on its next" >&2
    echo "        clean exit, so user.js is the only place a declaration holds" >&2
    echo "      fix: rhx grove.provision --what 1.3.browser --mode apply" >&2
    return 1
  fi
  echo "   • user.js present ✔"

  ####################################################################
  # 3. the three prefs whose absence costs what a human would misdiagnose
  ####################################################################
  if grep -q 'user_pref("signon.rememberSignons", false)' "$prefs"; then
    echo "   • password save is declared off ✔"
  else
    echo "   ✋ signon.rememberSignons is NOT declared false" >&2
    echo "      ⇒ firefox will offer to save passwords, so a credential lands in" >&2
    echo "        the browser store instead of 1password" >&2
    failed=$(( failed + 1 ))
  fi

  if grep -q 'user_pref("widget.gtk.native-emoji-dialog", false)' "$prefs"; then
    echo "   • the gtk emoji picker is declared off ✔"
  else
    echo "   ✋ widget.gtk.native-emoji-dialog is NOT declared false" >&2
    echo "      ⇒ ctrl+. opens the gtk emoji picker and 1password's shortcut never" >&2
    echo "        fires — which reads as a broken 1password, not a firefox pref" >&2
    failed=$(( failed + 1 ))
  fi

  if grep -q 'user_pref("browser.newtabpage.activity-stream.showSponsored", false)' "$prefs"; then
    echo "   • sponsored new-tab content is declared off ✔"
  else
    echo "   ✋ ...activity-stream.showSponsored is NOT declared false" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 4. the extensions — named when owed, never failed
  ####################################################################
  local addons="$profile/extensions.json" owed=()
  local name
  for name in '1password' 'firefox color' 'vimium'; do
    if [[ -f "$addons" ]] && grep -qiF "$name" "$addons"; then continue; fi
    owed+=("$name")
  done

  if [[ ${#owed[@]} -eq 0 ]]; then
    echo "   • all three extensions are accepted ✔"
  # ⚠️ reachable on a headless box only when a profile arrived by another route
  #   - an ssh -X launch or a restored $HOME is such a route
  #   - the extensions are genuinely absent there and also genuinely UNACCEPTABLE
  #   - the upsert declines to open a tab on this tier
  #   - ⇒ the fix must not name a re-drive, since that would be a cry-wolf
  elif [[ "$GROVE_ENV_SERVER" != "local@unix" ]]; then
    echo "   🌙 ${#owed[@]} extension(s) are unaccepted here, and none is owed: ${owed[*]}"
    echo "      each is accepted through a prompt mozilla shows on a SCREEN, and no"
    echo "      command can accept one — so this box can never hold them"
  else
    echo "   🌙 ${#owed[@]} extension(s) still owed a human click: ${owed[*]}"
    echo "      mozilla requires a hand on the permission prompt, so this is work"
    echo "      owed to a human — not work this bundle got wrong"
    echo "      fix: re-drive --what 1.3.browser and accept the tabs it opens"
  fi

  ####################################################################
  # 5. whether firefox has RE-READ user.js — not observable from here
  ####################################################################
  echo "   🌙 unverified — whether a live firefox has re-read user.js needs that"
  echo "      browser's own view of its prefs (about:config). it re-reads at every"
  echo "      start, so a restart is what makes the above take"

  [[ "$failed" -eq 0 ]] || return 1
}
