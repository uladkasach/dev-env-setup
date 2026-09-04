#!/usr/bin/env bash
######################################################################
# .what = the keyboard remap — capslock as ctrl/escape, vim arrows on the right modifiers
#
# .why
#   - every keybind this repo declares (tmux, nvim, kitty) assumes ctrl under the left pinky
#   - without this leaf those keybinds are reachable only by a contortion
#   - ⇒ the remap is a PRECONDITION of the terminal section, not a preference beside it
#
# .why it applies to EVERY box, headless included
#   - `keyd` installs from apt and runs against `/dev/uinput`
#   - the kernel provides `/dev/uinput` with or without a display
#   - ⇒ a grove HOLDS this bundle fine, it just has no keyboard to remap
#   - so there is NO early return (rule.require.identical-bundle-composition)
#
# usage:
#   rhx grove.provision --what 1.1.keybinds --mode apply
######################################################################

####################################################################
# the keyd ppa's release-key pin — ONE declaration, read by BOTH halves
#
# ⚠️ .why it lives HERE, not in the upsert beside its fetch
#   - the upsert fetches against it and the verify compares against it
#   - a copy in either phase file is one fact with two holders
#   - ⇒ it would drift with no signal (`gotcha.a-check-that-cries-wolf`, m.9)
#
# 🛑 anchor the ppa to THIS key — never by `add-apt-repository`
#   - that command fetches launchpad's key over the wire and trusts it
#   - it names no fingerprint, so whatever key answers becomes a permanent anchor
#   - ⚠️ on an older ubuntu it writes into `/etc/apt/trusted.gpg.d/`
#   - apt trusts that dir for EVERY source
#   - ⇒ a key taken for keyd could vouch for a replacement `openssh-server`
#   - `signed-by=` bounds that blast radius
#
# .the pin, sourced 2026-08-31 from TWO channels that AGREE
#   - launchpad's api names it, and the ubuntu keyserver holds that same
#     fingerprint under uid "Launchpad PPA for keyd" (`gotcha.my-own-note-became-my-evidence`)
#   - re-check: curl -s https://api.launchpad.net/1.0/~keyd-team/+archive/ubuntu/ppa | jq -r .signing_key_fingerprint
####################################################################
KEYBINDS_KEYD_PPA_FPR="67D33FE29A58DA9441D20A9DCD9F79EC6A8AFB2F"

grove_provision_1_1_keybinds() {
  bundle.upgrade 1.1.keybinds.provision.upsert
  bundle.upgrade 1.1.keybinds.provision.verify
  bundle.upgrade 1.1.keybinds.configure.upsert
  bundle.upgrade 1.1.keybinds.configure.verify
}
