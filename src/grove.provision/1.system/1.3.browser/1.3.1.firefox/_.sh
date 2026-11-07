#!/usr/bin/env bash
# .what = firefox — the flatpak build, the quiet `browser` launcher, its
#   prefs, and the three extensions a human must click to accept
# .why the flatpak build and not the apt one — ubuntu's `firefox` is a
#   snap wrapper that starts slowly and cannot read `~/.mozilla`; the
#   flatpak build keeps a real profile under `~/.var/app/`, where
#   `configure.upsert` writes, and the apt package is REMOVED rather than
#   left beside it, since two firefoxes make `xdg-open` pick one at random
# .why it applies to EVERY box, headless included — "a gui browser needs a
#   display" is true of RUNNING firefox and false of HOLDING this bundle,
#   since the flatpak installs on a grove and the profile is plain files
#   (rule.require.identical-bundle-composition, `.the test`); only
#   `xdg-settings set default-web-browser` genuinely needs a desktop, and
#   THAT line tolerates its own failure and says why
# .why "a grove would never USE it" is not an argument against this — it
#   is the blocker the rule names verbatim, "unused here" instead of
#   "cannot be held here"; `4.3.1.terminfo` proved the same shape wrong once
#   .refs = gotcha.1-3-1-firefox.demo=flatpak-user-scope-and-holds-everywhere
# .why "`gh pr view --web` on a grove is a real use" is NOT the reason
#   either — gh prints the url precisely when NO browser opens, so a bare
#   box delivers that benefit identically
# .why three extensions need a HUMAN CLICK, on a LAPTOP only — mozilla
#   requires a human to accept the permission prompt, so `1password`,
#   `firefox-color`, and `vimium` cannot be installed by any command; the
#   upsert reads `extensions.json` first and opens a tab ONLY for an
#   extension genuinely absent, so a converged box opens no tab
# .why that half is scoped to `local@unix`, off which it DECLINES — its
#   precondition is a human-driven GUI launch, unmeetable with no display
#   and no hand, and a hand-step fix-text would be a fourth step on a box
#   with none to give (rule.require.one-command-provision); the flatpak
#   install and the ctrl+N systemconfig channel still converge unattended
# .why the ctrl+N tab rebind lives here, not in the profile — linux firefox
#   binds tab 1..8 to alt+N, while kitty and tmux use ctrl+N; the rebind
#   ships through the flatpak `org.mozilla.firefox.systemconfig` extension
#   point, a host dir the sandbox mounts read-only, so it converges on a
#   box firefox has never been started on (briefs/desktop/system/howto.firefox-ctrl-tab-keys.md)
#
# usage:
#   rhx grove.provision --what 1.3.browser --mode apply

# .what = the declared 1password extension options, read or written in its
#   storage.local `config` key. the one declaration both phases pass through
# .why — the inline fill and the save offer are the value, so they are declared
#   ON rather than left to chance; "universal sign in" is the noise — one
#   combined prompt that pops and grabs focus — so it and its autofocus are OFF
#   - inlineEnabled            = "offer to fill and save logins and other items in fields"
#   - inlineShowAutomatically  = "show autofill suggestions when a field is selected"
#   - inlineSaveEnabled        = "show a 'save in 1password' button below fields"
#   - autoSaveEnabled          = "offer to save logins"
#   - universalSignOnEnabled   = "use universal sign in for logins" (default on)
#   - universalSignOnAutoFocus = "autofocus 1password sign in prompts when they appear" (default on)
#   labels read from the extension's own options page, v8.12.41
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
