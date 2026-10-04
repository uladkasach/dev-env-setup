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

  # 🛑 the imagemagick POLICY — owned since this bundle installs the tool. the
  #    debian default permits every coder. a SEAT path that bites with no root;
  #    not fatal, and `configure.verify` asks that it bites (m4)
  local pol_src="$bundle_dir/imagemagick.policy.xml"
  local pol_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ImageMagick"
  local pol_dst="$pol_dir/policy.xml"

  if [[ ! -r "$pol_src" ]]; then
    echo "   🌙 this checkout has no imagemagick.policy.xml, so the coder policy"
    echo "      is left as the box found it (looked in: $pol_src)"
  elif ! mkdir -p "$pol_dir"; then
    echo "   🌙 could not create $pol_dir — the imagemagick coder policy stays"
    echo "      as the box found it, which on debian is the vendor's OPEN default"
  elif ! cp "$pol_src" "$pol_dst"; then
    echo "   🌙 could not write $pol_dst — the imagemagick coder policy stays"
    echo "      as the box found it, which on debian is the vendor's OPEN default"
  else
    echo "   • imagemagick coder policy declared → $pol_dst"
  fi
}
