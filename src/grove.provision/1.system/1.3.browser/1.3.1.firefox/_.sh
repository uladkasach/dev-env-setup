#!/usr/bin/env bash
# .what = firefox — the flatpak build, the `browser` launcher, its prefs, and
#   the three extensions a human must click to accept
# .why
#   - flatpak, never apt: ubuntu's apt firefox is a slow snap wrapper with no
#     `~/.mozilla`, so it is REMOVED (two firefoxes make `xdg-open` guess)
#   - EVERY box, headless too: the flatpak and profile are plain files a grove
#     can hold (rule.require.identical-bundle-composition)
#   - the extension tabs need a human click, so that half runs on `local@unix`
#     only and declines elsewhere (rule.require.one-command-provision)
#   - the ctrl+N tab rebind ships via the flatpak systemconfig extension point,
#     so it converges before firefox ever starts
# .refs = gotcha.1-3-1-firefox.demo=flatpak-user-scope-and-holds-everywhere ·
#   howto.firefox-ctrl-tab-keys
# usage: rhx grove.provision --what 1.3.browser --mode apply

# .what = the declared 1password options, in its storage.local `config` key;
#   the one declaration both phases pass through
# .why inline fill and the save offer ON; "universal sign in" and its autofocus
#   OFF (one combined prompt that grabs focus). labels: the extension's own
#   options page, v8.12.41
# usage: grove_provision_1_3_1_firefox_onepassword_options <profile> plan|apply
grove_provision_1_3_1_firefox_onepassword_options() {
  python3 "$GROVE_SRC/grove.provision/1.system/1.3.browser/1.3.1.firefox/firefox/addon.storage.local.py" \
    --profile "$1" --addon-id '{d634138d-c276-4fc8-924b-40a0ea21d284}' --key config \
    --set inlineEnabled=true \
    --set inlineShowAutomatically=true \
    --set inlineSaveEnabled=true \
    --set autoSaveEnabled=true \
    --set universalSignOnEnabled=false \
    --set universalSignOnAutoFocus=false \
    --mode "$2"
}

grove_provision_1_3_1_firefox() {
  bundle.upgrade 1.3.1.firefox.provision.upsert
  bundle.upgrade 1.3.1.firefox.provision.verify
  bundle.upgrade 1.3.1.firefox.configure.upsert
  bundle.upgrade 1.3.1.firefox.configure.verify
}
