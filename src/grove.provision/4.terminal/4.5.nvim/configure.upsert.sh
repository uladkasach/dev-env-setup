#!/usr/bin/env bash
######################################################################
# .what = declare `~/.config/nvim/init.lua` from this run's own checkout
#
# .why
#   - the direction is always repo → machine, since a machine-side edit is lost
#   - (rule.require.repo-as-source-of-truth)
#
# ⚠️ .the source is `$GROVE_SRC`, never a hardcoded path
#   - a literal `$HOME/git/more/dev-env-setup/src/grove.provision/4.terminal/4.5.nvim/init.lua` names MAIN
#   - so a run launched from a WORKTREE would install MAIN's config
#   - a change under test would appear to have no effect, with no message to say why
#   - (howto.install-configs-from-a-worktree)
# .refs = gotcha.4-5-nvim.demo=configure-upsert-keeps-and-pins — every (mN) below
#
# guarantee
#   - idempotent: a copy over an identical file converges
#   - it REFUSES rather than leaves a stale config unreported
######################################################################

####################################################################
# .what = before a `cp` overwrites a machine-side file that DRIFTED from the
#         checkout, keep the machine's copy beside it
# .why
#   - 🛑 a `cp` is a partial write — a 274-line drift was overwritten with no
#     copy kept, and what it held is now unanswerable
#   - it fires on DRIFT only, so a converged apply stays clean
#   - 🛑 DRIFT has two causes `cmp` cannot tell apart, so the message names
#     neither and hands the human the `diff` that does
#   - ⚠️ a failed backup is FATAL — an overwrite would destroy what this keeps
# .refs = gotcha.4-5-nvim.demo=configure-upsert-keeps-and-pins, m1-m2
####################################################################
_nvim_keep_the_copy_about_to_be_overwritten() {
  local dst="$1" src="$2"

  # no file to lose, or identical bytes — a copy would be noise, not evidence
  [[ -f "$dst" ]] || return 0
  cmp -s "$src" "$dst" && return 0

  local bak="$dst.bak.$(date +%Y%m%dT%H%M%S)"
  if ! cp "$dst" "$bak"; then
    echo "   ✋ could not preserve $dst before it is overwritten" >&2
    echo "      ⇒ the machine copy DIFFERS from the checkout, so the overwrite" >&2
    echo "        would destroy bytes no commit holds — this run halts instead" >&2
    echo "      read why: the cp error above — usually a permission or a full disk" >&2
    return 1
  fi

  # 🛑 it states the FACT and names NO cause — `cmp` measured neither of the two
  #    (see the block header, 2026-09-07)
  echo "   ⚠️ $(basename "$dst") DRIFTED from the checkout — kept $bak"
  echo "      ⇒ either the repo moved ahead (the .bak is the old copy, disposable)"
  echo "        or the machine was edited and the repo was never told (port it first)"
  echo "      tell which: diff $bak $src"
  echo "        · only lines this checkout just changed → the repo moved; delete the .bak"
  echo "        · anything else                        → a machine-side edit; move each"
  echo "          part worth a keep INTO the checkout (rule.require.repo-as-source-of-truth)"
  return 0
}

grove_provision_4_5_nvim_configure_upsert() {
  local bundle_dir="$GROVE_SRC/grove.provision/4.terminal/4.5.nvim"
  local src="$bundle_dir/init.lua"
  local dst="$HOME/.config/nvim/init.lua"

  ####################################################################
  # the source must exist
  #   - a `cp` from an absent path leaves the OLD config in place
  #   - without this, the cause never appears in the message a reader gets
  ####################################################################
  if [[ ! -r "$src" ]]; then
    echo "   ✋ the checkout has no init.lua" >&2
    echo "      ⇒ \$GROVE_SRC is this run's own checkout, so an absent file here" >&2
    echo "        means the checkout is incomplete rather than that the path is" >&2
    echo "        wrong (looked in: $src)" >&2
    echo "      ⇒ left alone, nvim keeps whatever config the box already had, and" >&2
    echo "        an edit to this repo's init.lua would appear to do zero" >&2
    return 1
  fi

  if ! mkdir -p "$(dirname "$dst")"; then
    echo "   ✋ could not create $(dirname "$dst")" >&2
    return 1
  fi

  _nvim_keep_the_copy_about_to_be_overwritten "$dst" "$src" || return 1

  if ! cp "$src" "$dst"; then
    echo "   ✋ could not write $dst" >&2
    echo "      read why: the cp error above — usually a permission or a full disk" >&2
    return 1
  fi

  echo "   • nvim config declared → $dst"

  # 🛑 the PLUGIN LOCKFILE — `init.lua` names 13 repos at TIP, and treesitter's
  #    `:TSUpdate` EXECUTES its tip. lazy checks out the lock BEFORE any build,
  #    so this pins what runs — never what is fetched. FATAL if absent (m3)
  #   - to bump: `:Lazy update`, then copy it back over this bundle's `lazy-lock.json`
  local lock_src="$bundle_dir/lazy-lock.json"
  local lock_dst="$HOME/.config/nvim/lazy-lock.json"

  if [[ ! -r "$lock_src" ]]; then
    echo "   ✋ the checkout has no lazy-lock.json" >&2
    echo "      ⇒ \$GROVE_SRC is this run's own checkout, so an absent file here" >&2
    echo "        means nvim takes all 13 plugins at default-branch TIP — and" >&2
    echo "        nvim-treesitter's 'build = :TSUpdate' EXECUTES that tip" >&2
    echo "      ⇒ the config was installed above, so this box is now one nvim" >&2
    echo "        start away from that. do not leave it here" >&2
    echo "      read why: ls -l $lock_src" >&2
    return 1
  fi

  # ⚠️ the SAME keep-the-copy guarantee as init.lua — sharper here, since drift
  #    is the declared bump workflow (m3)
  _nvim_keep_the_copy_about_to_be_overwritten "$lock_dst" "$lock_src" || return 1

  if ! cp "$lock_src" "$lock_dst"; then
    echo "   ✋ could not write $lock_dst" >&2
    echo "      ⇒ lazy reads this exact path; a lockfile anywhere else is a file," >&2
    echo "        not a pin, so the next start clones 13 repos at tip" >&2
    echo "      read why: the cp error above — usually a permission or a full disk" >&2
    return 1
  fi

  echo "   • nvim plugin lockfile declared → $lock_dst"

  # the super+v selector's setup — sourced by kitty's no-tmux overlay
  # (4.3.2.emulator/visual_select.py) AND tmux's popup (2.8.tmux/tmux.conf).
  # this bundle owns it, since it is nvim config and the one bundle on every box
  #   - at the config root, never under lua/ or plugin/: nvim auto-loads neither
  #     path here, so only a `-S` sources it and every other nvim stays untouched
  local sel_src="$bundle_dir/visual_select.lua"
  local sel_dst="$HOME/.config/nvim/visual_select.lua"
  if ! cp "$sel_src" "$sel_dst"; then
    echo "   ✋ could not write $sel_dst" >&2
    echo "      ⇒ super+v opens a plain nvim with no selector keys, in kitty and tmux alike" >&2
    echo "      read why: the cp error above — usually a permission or a full disk" >&2
    return 1
  fi
  echo "   • super+v selector setup declared → $sel_dst"

  grove_provision_4_5_nvim_policy_upsert "$bundle_dir/imagemagick.policy.xml"
}

######################################################################
# .what = fence this bundle's imagemagick rules INTO the policy file the tool reads
#
# .why  = owned since this bundle installs the tool for image.nvim. debian's default
#   declares no coder rule, so a tree `git.grove.pull` wrote can hand an eps to
#   ghostscript. measured 2026-11-15, im6 6.9.12: ONLY rules inlined in
#   `/etc/ImageMagick-6/policy.xml` bite — the seat path, MAGICK_CONFIGURE_PATH, and
#   <include> are all ignored. so this is a BOX-WIDE fact (`bundle.root.declines`):
#   ground sets it on a grove; the laptop's human sets it with `sudo -v &&`
#
# .note = not fatal, as the install is not; `configure.verify` asks that it BITES
######################################################################
# .what = is the seat-path policy the inert copy an earlier version of this bundle
#         wrote? byte-equal to the checkout, so a human's own file never matches
grove_provision_4_5_nvim_policy_seat_is_ours() {
  local seat="$1" src="$2"
  [[ -f "$seat" && -r "$src" ]] && cmp -s "$src" "$seat"
}

grove_provision_4_5_nvim_policy_upsert() {
  local pol_src="$1" pol_dst want

  # the inert seat copy an earlier version of this bundle wrote — removed only when it
  #   is byte-equal to the checkout, so a human's own file is never touched
  local pol_seat="${XDG_CONFIG_HOME:-$HOME/.config}/ImageMagick/policy.xml"
  if grove_provision_4_5_nvim_policy_seat_is_ours "$pol_seat" "$pol_src"; then
    rm -f "$pol_seat" && echo "   • removed the inert seat copy at $pol_seat (imagemagick never read it)"
  fi

  if [[ ! -r "$pol_src" ]]; then
    echo "   🌙 this checkout has no imagemagick.policy.xml, so the coder policy"
    echo "      is left as the box found it (looked in: $pol_src)"
    return 0
  fi
  if ! pol_dst="$(grove_provision_4_5_nvim_policy_path_readable)"; then
    echo "   🌙 imagemagick names no readable policy file, so there is no place for its rules"
    echo "      read why: identify -list policy | grep '^Path:'"
    return 0
  fi

  # 0. read first — root is asked only when the file must change
  want="$(mktemp)" || { echo "   🌙 could not make a temp file; the policy stays as found"; return 0; }
  local rc=0
  grove_provision_4_5_nvim_policy_render "$pol_dst" "$pol_src" > "$want" || rc=$?
  if [[ "$rc" -eq 3 ]]; then
    rm -f "$want"
    echo "   ✋ ConstraintError: $pol_dst holds a broken grove fence (a lone marker, or two fences); left as found" >&2
    echo "      a render would drop '</policymap>', so this bundle writes no byte of it" >&2
    echo "      fix: delete every line from '$GROVE_PROVISION_4_5_NVIM_POLICY_OPEN'" >&2
    echo "           to '$GROVE_PROVISION_4_5_NVIM_POLICY_SHUT' (or the lone one), then:" >&2
    echo "           sudo -v && rhx grove.provision --what 4.5.nvim --mode apply" >&2
    return 1
  fi
  if [[ "$rc" -ne 0 ]]; then
    rm -f "$want"
    echo "   🌙 $pol_dst holds no '<policymap>' line to anchor the rules on; left as found"
    return 0
  fi
  if cmp -s "$want" "$pol_dst"; then
    rm -f "$want"
    echo "   • imagemagick rules already fenced into $pol_dst ✔"
    return 0
  fi

  if ! pkg_can_sudo; then
    rm -f "$want"
    bundle.root.declines "the imagemagick coder policy" "$pol_dst lacks this bundle's current rules"
    return 0
  fi
  pkg_assert_sudo || { rm -f "$want"; return 1; }

  # one atomic swap, mode kept. a dpkg conffile: `1.14.updates` has the UNATTENDED run keep
  #   our copy; a human's own apt asks, and the next apply re-fences whatever they take
  # sudo held one line above, so a refused write here is a fault, never a decline
  if ! bundle.run sudo install -m 644 -o root -g root "$want" "$pol_dst"; then
    rm -f "$want"
    echo "   💥 MalfunctionError: could not write $pol_dst with root held — the policy stays as found" >&2
    bundle.said "      " "$BUNDLE_SAID" >&2
    echo "      read why: ls -l $pol_dst ; df -h $(dirname "$pol_dst")" >&2
    return 1
  fi
  rm -f "$want"
  echo "   • imagemagick rules fenced into $pol_dst"
  echo "     ⇒ box-wide: EPS, PS, PDF, XPS, MVG, MSL, TEXT and the shell delegates now read"
  echo "       'not authorized' for every user; the fence sits between this bundle's markers"
}
