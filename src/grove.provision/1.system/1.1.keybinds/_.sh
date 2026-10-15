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

####################################################################
# the pinned anchor + source paths, and the LEGACY ones they replace
#
# .why the legacy readers live here
#   - the upsert's skip check, its cleanup, and the verify all read them
#   - one reader each would be three holders of one fact
#
# 🛑 .why a legacy source must be REMOVED, never left beside the pinned one
#   - `add-apt-repository` writes `keyd-team-ubuntu-ppa-<series>.sources` (deb822,
#     key inline) or `.list` (key in /etc/apt/trusted.gpg.d/)
#   - the pinned `.list` names the SAME uri + suite with a DIFFERENT `signed-by`
#   - apt then refuses the pair — two Signed-By values for one source is an error
#   - ⇒ and that error fails `apt update` for EVERY source on the box, not just keyd
#   - 📜 2026-10-14: the upsert skipped on a box with the legacy `.sources`, because
#     its skip check read only "keyd installed + daemon up" — so the verify's
#     "no pinned key" ✋ could never be repaired by the apply it named
####################################################################
KEYBINDS_KEYD_KEY_PATH="/usr/share/keyrings/keyd-team-ppa.asc"
KEYBINDS_KEYD_LIST_PATH="/etc/apt/sources.list.d/keyd-team-ppa.list"

# .what = every keyd apt source file on the box that is NOT the pinned one
keybinds_keyd_sources_legacy() {
  local f
  for f in /etc/apt/sources.list.d/*keyd*; do
    [[ -e "$f" ]] || continue
    [[ "$f" == "$KEYBINDS_KEYD_LIST_PATH" ]] && continue
    echo "$f"
  done
}

# .what = every blanket keyd key in /etc/apt/trusted.gpg.d/ (trusted for EVERY source)
keybinds_keyd_keys_legacy() {
  grep -rls 'Launchpad PPA for keyd' /etc/apt/trusted.gpg.d/ 2>/dev/null | sort -u || true
}

# .what = is the pinned anchor + source in place, with no legacy one beside it?
keybinds_keyd_anchor_holds() {
  [[ -f "$KEYBINDS_KEYD_KEY_PATH" ]] || return 1
  web_verify_gpg_fingerprints --file "$KEYBINDS_KEYD_KEY_PATH" \
    --fpr "$KEYBINDS_KEYD_PPA_FPR" >/dev/null 2>&1 || return 1
  grep -qF "signed-by=$KEYBINDS_KEYD_KEY_PATH" "$KEYBINDS_KEYD_LIST_PATH" 2>/dev/null || return 1
  [[ -z "$(keybinds_keyd_sources_legacy)" ]] || return 1
  [[ -z "$(keybinds_keyd_keys_legacy)" ]] || return 1
}

####################################################################
# the apple keyboard ids — ONE declaration, read by both confs and both phases
#
# .why both buses
#   - a magic keyboard reports 004c:029c over bluetooth (measured 2026-10-14)
#   - and 05ac:029c when wired over usb-c — apple's usb vendor id
#
# .to add a board
#   - plug it in, then `rhx input.keyboard.ids` names its `vendor:product`
#   - an apple-layout board goes here; a pc-layout board needs no entry
#   - ⇒ the criteria: criteria `keyboard.alt-super-per-board`
####################################################################
KEYBINDS_APPLE_IDS=(004c:029c 05ac:029c)

####################################################################
# .what = render one keyd conf: the shared remap, plus the per-board ids and swap
#
# .why one renderer for both confs
#   - keyd applies exactly ONE conf per device, so each file carries the full remap
#   - two hand-written copies would drift; one renderer cannot
#   - the upsert writes its output; the verify compares the live file against it
#
# usage:
#   keybinds_keyd_conf --for builtin   # every board but apple; swaps alt/super
#   keybinds_keyd_conf --for apple     # apple boards only; no swap
####################################################################
keybinds_keyd_conf() {
  local board=""
  [[ "${1:-}" == "--for" ]] && board="${2:-}"

  # the ids section — the one place the two confs part on WHICH devices
  local id
  case "$board" in
    builtin)
      echo "[ids]"
      echo "*"
      for id in "${KEYBINDS_APPLE_IDS[@]}"; do echo "-$id"; done
      ;;
    apple)
      echo "[ids]"
      for id in "${KEYBINDS_APPLE_IDS[@]}"; do echo "$id"; done
      ;;
    *)
      echo "keybinds_keyd_conf: --for must be builtin|apple, got '$board'" >&2
      return 1
      ;;
  esac

  cat <<'EOF'

[global]
# if capslock held > 200ms, skip the escape tap (helps with ctrl+click)
overload_tap_timeout = 200

[main]
# capslock = control (held) / escape (tapped)
capslock = overload(control, esc)

# disable disruptive keys
coffee  = noop
sleep   = noop
suspend = noop
power   = noop

# vim-style arrows with right alt, right ctrl, or right meta (magic keyboard)
rightalt = layer(vimarrows)
rightcontrol = layer(vimarrows)
rightmeta = layer(vimarrows)
EOF

  # the per-board swap — the key beside the spacebar is super on every board
  if [[ "$board" == "builtin" ]]; then
    cat <<'EOF'

# swap left alt and left super, so the key beside the spacebar is super (as on apple)
leftalt = leftmeta
leftmeta = leftalt
EOF
  fi

  cat <<'EOF'

[vimarrows]
h = left
j = down
k = up
l = right
EOF
}

grove_provision_1_1_keybinds() {
  bundle.upgrade 1.1.keybinds.provision.upsert
  bundle.upgrade 1.1.keybinds.provision.verify
  bundle.upgrade 1.1.keybinds.configure.upsert
  bundle.upgrade 1.1.keybinds.configure.verify
}
