#!/usr/bin/env bash
######################################################################
# .what = make `keyd` and `keynav` EXIST on this box, with keyd's daemon up
#
# .why keyd comes from a ppa, not the archive
#   - ubuntu's archive carries no keyd at all
#   - the source is DECLARED whole below, so a re-run rewrites one line rather than appends
#
# .why the `keyd.rvaiya` symlink
#   - the ppa installs under its maintainer's name to dodge an unrelated `keyd`
#   - every doc, brief, and diagnosis in this repo says `keyd`
#   - ⇒ the link puts the documented name on PATH
#   - `ln -sf` re-points rather than fails on a re-run
#
# .why `enable --now` and not `start`
#   - `--now` starts it AND enables it at boot
#   - a start alone gives a remap that vanishes on the next reboot
#   - ⇒ that is the worst shape, because the box worked when it was tested
#
# .why every failure is NAMED rather than a bare `|| return 1`
#   - this run has no `set -e`, so an unguarded function returns its LAST status
#   - ⇒ propagation is required, but it is only half the job
#   - the reader also needs which claim broke and what its absence costs
#   - (rule.require.failloud, rule.require.errors-name-the-fix)
#
# guarantee:
#   - idempotent: apt install of a present package is a no-op
#   - idempotent: the symlink re-points
#   - idempotent: `enable --now` on a live unit reports it is already active
######################################################################

# .the release-key pin is `KEYBINDS_KEYD_PPA_FPR`, declared in this bundle's `_.sh`
#   - both halves read it: the fetch below, and the verify's rung 0
#   - `_.sh` carries where the value came from and how to re-check it

grove_provision_1_1_keybinds_provision_upsert() {
  ####################################################################
  # 0. what is ALREADY true — read before any privilege is asked for
  #
  # 🛑 the FREE reads come first, and root is asserted only after they miss
  #   - a grove's camper seat holds no sudo by design (`term=seat`)
  #   - 📜 a root assert at the top failed every camper apply and skipped three later phases
  #   - those were facts `ground` had already set box-wide with this same bundle
  #   - its ✋ named two HAND STEPS, each a blocker under `rule.require.one-command-provision`
  #   - all four reads below are FREE: dpkg, readlink, and systemctl's query verbs need no root
  #   - `pkg_install` uses this same order, and this is that order for a DIRECT sudo
  ####################################################################
  local keyd_link; keyd_link="$(readlink -f /usr/bin/keyd 2>/dev/null || true)"
  if pkg_present keyd \
    && pkg_present keynav \
    && [[ "$keyd_link" == "/usr/bin/keyd.rvaiya" ]] \
    && systemctl is-enabled keyd >/dev/null 2>&1 \
    && systemctl is-active keyd >/dev/null 2>&1; then
    echo "   • keyd + keynav installed, linked, and the daemon is up ✔"
    return 0
  fi

  # it does not hold, and this seat cannot set it — ground owns every write below
  if ! pkg_can_sudo; then
    bundle.root.declines "the keyd remap" \
      "keyd=$(pkg_present keyd && echo present || echo absent), link=${keyd_link:-（none）}, unit=$(systemctl is-active keyd 2>/dev/null || echo inactive)"
    return 0
  fi

  # ⚠️ every write below is root's, and `sudo` reads a password from a TERMINAL
  #   - with none attached it prompts anyway
  #   - a duct is tmux, so the question sits on the pane and eats the next command sent
  #   - `pkg_install` asserts this already, but a bundle that reaches root DIRECTLY must ask itself
  #   - reached only when this seat CAN sudo, since the gate above returned otherwise
  #   - kept as the belt to that braces, because a credential can lapse between the lines
  pkg_assert_sudo || return 1

  ####################################################################
  # 1. the ppa — the only apt source that carries keyd
  #
  # ⚠️ the pinned-key path below never calls `add-apt-repository`
  #   - so this bundle owns no `software-properties-common`
  #   - 📜 2026-08-13: a box that holds that package holds it by grace of its base image
  #   - ⇒ a bundle that leans on it passes on LUCK (`rule.require.bundles-own-their-dependencies`)
  #   - `4.5.nvim` is its ONE consumer, and it installs it itself
  ####################################################################
  local keydst="/usr/share/keyrings/keyd-team-ppa.asc"
  local keytmp
  keytmp="$(web_tempdir keydkey)" || return 1

  if ! web_fetch "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${KEYBINDS_KEYD_PPA_FPR}" \
    --into "$keytmp/keyd.asc"; then
    echo "   ✋ could not fetch the keyd ppa's release key" >&2
    echo "      ⇒ apt would then report the ppa as unsigned, and its error reads" >&2
    echo "        as 'NO_PUBKEY' rather than 'the key was never fetched'" >&2
    rm -rf "$keytmp"
    return 1
  fi

  if ! web_verify_gpg_fingerprints --file "$keytmp/keyd.asc" \
    --fpr "$KEYBINDS_KEYD_PPA_FPR"; then
    echo "      ⇒ keyd is NOT installed, and the ppa is NOT declared. that is the" >&2
    echo "        safe outcome — a box with no keyd beats a box whose apt trusts" >&2
    echo "        an anchor nobody vouched for" >&2
    rm -rf "$keytmp"
    return 1
  fi

  if ! sudo dd if="$keytmp/keyd.asc" of="$keydst" status=none; then
    echo "   ✋ could not install the keyd ppa's release key to $keydst" >&2
    rm -rf "$keytmp"
    return 1
  fi
  rm -rf "$keytmp"

  # apt fetches as the `_apt` user, not root, so a root-only key reads as unsigned
  sudo chmod go+r "$keydst" || return 1
  echo "   • the keyd ppa's release key verified against its pinned fingerprint ✔"

  ####################################################################
  # the source, bound to exactly that key
  #
  # .`signed-by=$keydst` is ONE variable
  #   - ⇒ the path the key lands at and the path apt trusts cannot drift apart
  #
  # ⚠️ `UBUNTU_CODENAME` first, `VERSION_CODENAME` second
  #   - a ppa publishes per UBUNTU series, and on a derivative the two fields differ
  #   - pop!_os sets both today
  #   - a derivative that sets only `VERSION_CODENAME` would name a series launchpad never published
  #   - ⇒ apt reddens on a source that is correct upstream
  ####################################################################
  local arch codename
  arch="$(dpkg --print-architecture)"
  codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"

  if ! echo "deb [arch=$arch signed-by=$keydst] https://ppa.launchpadcontent.net/keyd-team/ppa/ubuntu $codename main" \
    | sudo tee /etc/apt/sources.list.d/keyd-team-ppa.list >/dev/null; then
    echo "   ✋ could not declare the keyd apt source" >&2
    echo "      ⇒ ubuntu's archive has NO keyd, so without this source the install" >&2
    echo "        below cannot find the package at all" >&2
    return 1
  fi

  pkg_refresh

  if ! pkg_install keyd; then
    echo "   ✋ keyd did not install" >&2
    echo "      ⇒ without it, capslock stays capslock and every tmux/nvim/kitty" >&2
    echo "        keybind this repo declares is a contortion to reach" >&2
    echo "      read why: sudo apt-get install keyd" >&2
    return 1
  fi

  ####################################################################
  # 2. make the documented name the one a shell finds on PATH
  ####################################################################
  if ! sudo ln -sf /usr/bin/keyd.rvaiya /usr/bin/keyd; then
    echo "   ✋ could not link /usr/bin/keyd -> keyd.rvaiya" >&2
    echo "      ⇒ the ppa installs under its maintainer's name, and every brief," >&2
    echo "        doc, and diagnosis in this repo says 'keyd'. without the link" >&2
    echo "        each of those reads as an absent command" >&2
    return 1
  fi

  ####################################################################
  # 3. the daemon, now AND at boot
  ####################################################################
  if ! sudo systemctl enable --now keyd; then
    echo "   ✋ the keyd daemon would not start" >&2
    echo "      ⇒ keyd remaps through an open handle on /dev/uinput, held only" >&2
    echo "        while it runs. so an installed binary with a dead unit gives NO" >&2
    echo "        remap at all — and a 'command -v keyd' check would pass" >&2
    echo "      read why: systemctl status keyd" >&2
    return 1
  fi

  ####################################################################
  # 4. keynav — click and move by keyboard, without a mouse
  #
  # ref: https://www.semicomplete.com/projects/keynav/
  #   ctrl + ;          begin a selection
  #   h / j / k / l     narrow to that quarter of the screen
  #   shift + h/j/k/l   move the last selection instead of a narrow
  #   space             click the selection
  #   semicolon         move the pointer to the selection
  ####################################################################
  if ! pkg_install keynav; then
    echo "   ✋ keynav did not install" >&2
    echo "      ⇒ the keyboard-only pointer is absent. keyd's remap above is" >&2
    echo "        unaffected, so this is the smaller half of the bundle" >&2
    echo "      read why: sudo apt-get install keynav" >&2
    return 1
  fi
}
