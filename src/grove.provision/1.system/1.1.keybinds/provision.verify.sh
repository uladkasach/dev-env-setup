#!/usr/bin/env bash
######################################################################
# .what = prove keyd is INSTALLED and its daemon is up, and that keynav is present
#
# .why the daemon state is a separate claim from the binary
#   - `keyd` is a daemon that must be live for the remap to exist
#   - `systemctl enable --now` can fail on a masked unit or an absent /dev/uinput
#   - ⇒ a present binary with a dead unit is the false success this verify is for
#
# .why `enabled` is asserted too, not just `active`
#   - a unit that is active-but-disabled works today and is gone after the next reboot
#   - ⇒ that is the worst failure shape, because the box passed when it was tested
#
# guarantee:
#   - READ-ONLY. it queries systemd and PATH; repairs no state
#
# exit:
#   0 = keyd is installed, active, and enabled; keynav is present
#   1 = a claim failed, and which is named
######################################################################

grove_provision_1_1_keybinds_provision_verify() {
  local failed=0

  ####################################################################
  # 0. the TRUST ANCHOR — the claim the binary checks below cannot make
  #
  # 🛑 every check below passes on a box whose apt trusts ANY key
  #   - keyd on PATH and its daemon up are silent about the anchor apt verified it against
  #   - ⇒ without this rung the bundle's central claim has no reader
  #   - (rule.require.upgrade-entries-verify-themselves)
  #
  # ⚠️ the LEGACY path is checked FIRST and on its own
  #   - a box that `add-apt-repository` provisioned holds BOTH the scoped key and a blanket copy
  #   - the blanket copy in `/etc/apt/trusted.gpg.d/` is trusted for EVERY repo
  #   - ⇒ it is the one that matters, since it is live until it is deleted
  ####################################################################
  local keydst="/usr/share/keyrings/keyd-team-ppa.asc"
  local legacy
  legacy="$(grep -rls 'Launchpad PPA for keyd' /etc/apt/trusted.gpg.d/ 2>/dev/null | sort -u | head -1 || true)"
  if [[ -n "$legacy" ]]; then
    echo "   ✋ the keyd ppa key still sits in /etc/apt/trusted.gpg.d/" >&2
    echo "      at: $legacy" >&2
    echo "      ⇒ a key there is trusted for EVERY apt source, so this publisher" >&2
    echo "        can vouch for a package that names ANY origin — a replacement" >&2
    echo "        openssh-server included. that is the blast radius signed-by=" >&2
    echo "        exists to bound, and it is unbounded while this file lives" >&2
    echo "      fix: sudo rm '$legacy' && rhx grove.provision --what 1.1.keybinds --mode apply" >&2
    failed=$(( failed + 1 ))
  fi

  if [[ ! -f "$keydst" ]]; then
    echo "   ✋ no pinned keyd ppa key at $keydst" >&2
    echo "      ⇒ apt has no anchor for the keyd source, so its update reports" >&2
    echo "        NO_PUBKEY and no fix keyd's maintainer ships ever reaches here" >&2
    echo "      fix: rhx grove.provision --what 1.1.keybinds --mode apply" >&2
    failed=$(( failed + 1 ))
  elif ! web_verify_gpg_fingerprints --file "$keydst" \
    --fpr "$KEYBINDS_KEYD_PPA_FPR" >/dev/null 2>&1; then
    echo "   ✋ the installed keyd ppa key is NOT the pinned one" >&2
    echo "      at:      $keydst" >&2
    echo "      pinned:  $KEYBINDS_KEYD_PPA_FPR" >&2
    echo "      ⇒ apt verifies every keyd package against this file, so a swapped" >&2
    echo "        anchor is not one bad install — it is every future one, each" >&2
    echo "        with a clean signature check against the wrong key" >&2
    echo "      read it: gpg --show-keys --with-colons $keydst" >&2
    failed=$(( failed + 1 ))
  else
    echo "   • the keyd ppa key is the pinned one, and scoped ✔"
  fi

  ####################################################################
  # 1. the binary, under the documented name
  ####################################################################
  if command -v keyd >/dev/null 2>&1; then
    echo "   • keyd on PATH ✔"
  else
    echo "   ✋ keyd is NOT on PATH" >&2
    echo "      ⇒ either the apt install or the keyd.rvaiya symlink did not take" >&2
    echo "      fix: rhx grove.provision --what 1.1.keybinds --mode apply" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 2. the daemon is up — the claim the binary check cannot make
  ####################################################################
  if systemctl is-active --quiet keyd; then
    echo "   • keyd daemon is active ✔"
  else
    echo "   ✋ the keyd daemon is NOT active" >&2
    echo "      ⇒ the binary can be installed and the remap still absent; keyd" >&2
    echo "        remaps by an open handle on /dev/uinput, held only while it runs" >&2
    echo "      read why: systemctl status keyd" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 3. and it survives a reboot
  ####################################################################
  if systemctl is-enabled --quiet keyd 2>/dev/null; then
    echo "   • keyd is enabled at boot ✔"
  else
    echo "   ✋ keyd is active but NOT enabled at boot" >&2
    echo "      ⇒ the remap holds until the next reboot, then vanishes — and the" >&2
    echo "        box will have passed every check made before that reboot" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 4. keynav
  ####################################################################
  if command -v keynav >/dev/null 2>&1; then
    echo "   • keynav on PATH ✔"
  else
    echo "   ✋ keynav is NOT on PATH" >&2
    failed=$(( failed + 1 ))
  fi

  [[ "$failed" -eq 0 ]] || return 1
}
