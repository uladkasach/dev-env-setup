#!/usr/bin/env bash
######################################################################
# .what = declare `~/.config/nvim/init.lua` from this run's own checkout
#
# .why
#   - the direction is always repo → machine, since a machine-side edit is lost
#   - (rule.require.repo-as-source-of-truth)
#
# ⚠️ .the source is `$GROVE_SRC`, never a hardcoded path
#   - a literal `$HOME/git/more/dev-env-setup/src/init.lua` names MAIN
#   - so a run launched from a WORKTREE would install MAIN's config
#   - a change under test would appear to have no effect, with no message to say why
#   - (howto.install-configs-from-a-worktree)
#
# guarantee
#   - idempotent: a copy over an identical file converges
#   - it REFUSES rather than leaves a stale config unreported
######################################################################

####################################################################
# 🛑 .keep what this run is about to DESTROY — measured 2026-09-06
#
# .what = before a `cp` overwrites a machine-side file whose content DIFFERS
#         from the checkout, keep the machine's copy beside it.
#
# .why  — a `cp` is a partial write with the widest possible radius
#   `rule.require.repo-as-source-of-truth` says a machine-side edit is LOST, and
#   that is correct as a policy. it is a claim about what SHOULD survive, never a
#   claim that the bytes were worthless.
#
# 📜 .what it cost, on this box
#   `~/.config/nvim/init.lua` had drifted 274 lines from the checkout, in BOTH
#   directions: it held a destructive buffer-wipe present in no commit, AND five
#   improvements the repo lacked (`get_lua_kb`, `count_extmarks`, `count_chans`,
#   log rotation, a stampede guard). the five were read back by hand and shipped.
#
#   ⚠️ and the question "was that ALL of them?" is now **unanswerable**, because
#   this function overwrote the file with no copy kept. the only backup on the
#   box was hand-made, three days stale, and predates the drift.
#
#   ⇒ that is `gotcha.a-partial-write-discards-what-it-never-read`: the fields a
#     writer reads are the only fields it can converge, and this one read none.
#
# ⚠️ .it fires on DRIFT, never on every apply
#   a converged box copies identical bytes, so `cmp` matches and no copy is kept.
#   that keeps the second apply clean (`rule.require.idempotent-install-procedures`).
#
#   ⚠️ the word is DRIFT. `divergence` is a forbidden synonym here — it is latinate
#      and static, so it names the STATE and loses the silence, which is the whole
#      reason the term is load-bear (`term=drift._.choice._.md`). this block said
#      `DIVERGED` in a human-facing message until 2026-09-07.
#
# 🛑 .and DRIFT has TWO causes — this function can tell them apart in NO way
#
#   | the cause | what the `.bak` is worth |
#   |---|---|
#   | the MACHINE was edited, and the repo was never told | evidence — read it, port it |
#   | the REPO moved ahead, and this apply carries it over | disposable — it is the old copy |
#
#   `cmp` answers *"do these differ?"* and says NO part of *why*. so a message that
#   names a cause asserts one it never measured.
#
# 📜 .measured 2026-09-07 — the message did exactly that
#   this block's first cut printed *"a machine-side edit the repo has not been told
#   about"*, and told the human to *"move each part worth a keep INTO the checkout"*.
#   the very next apply fired it against a `.bak` whose whole content was the two
#   lines this checkout had just replaced. there was no machine-side edit and no
#   part worth a keep.
#
#   ⇒ the ACTION was right (keep the copy, always) and the REASON was invented. those
#     two together are the hardest defect to catch, because the verdict looks correct
#     and only the sentence beneath it is false
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4 — a summary that names the
#     wrong subject).
#
#   ⚠️ and it is the CHEAP cause that fires most: every apply after a checkout edit
#     drifts. so a message that cries "somebody edited your machine" on the normal
#     path is a false ✋ on a schedule, which is how a real signal gets ignored.
#
#   ⇒ so the message states the FACT and hands the human the one command that
#     separates the causes. it names neither.
#
# ⚠️ .a failed backup is FATAL, and that is the point
#   the alternative is to overwrite regardless, which destroys the very bytes this
#   exists to preserve — a failure reported by the loss it was meant to prevent
#   (`rule.forbid.failhide`).
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

  ####################################################################
  # 🛑 the PLUGIN LOCKFILE — the pin for 13 repos this config clones
  #
  #   - `init.lua` names 13 repos, and NONE carries a ref, so each is taken at TIP
  #   - `nvim-treesitter` also carries `build = ':TSUpdate'`, so the tip is EXECUTED
  #   - ⇒ a push to any of the 13 was code execution on the next nvim start
  #
  # ⚠️ .a LOCKFILE, not 13 `commit =` fields in init.lua
  #   - 13 hand-maintained pins is 13 declarations of one fact, each free to drift
  #   - `lazy-lock.json` is lazy's OWN single declaration, rewritten on every update
  #   - (rule.require.bundle-as-sole-declaration)
  #
  # ✔ .MEASURED, not assumed — lazy 85c7ff37, read 2026-09-02
  #      a lockfile pins a FIRST install, not only a later `:Lazy restore`:
  #
  #         lua/lazy/core/loader.lua:84   auto-install passes `lockfile = true`
  #         lua/lazy/manage/init.lua:82   pipeline = git.clone
  #                                                → git.checkout{lockfile}
  #                                                → plugin.build
  #         lua/lazy/manage/task/git.lua:329,358  a lock entry OVERRIDES target,
  #                                                and `checkout <lock.commit>`
  #                                                is what runs
  #
  #   - ⇒ the checkout precedes `plugin.build`, so `:TSUpdate` builds the PINNED tree
  #   - and no `config` or `init` of any plugin has run yet
  #
  # ⚠️ .the bound this does NOT hold
  #   - `git.clone` still FETCHES the tip's objects before the checkout rewinds
  #   - it pins what is EXECUTED, never what is transferred; read it no wider
  #   - ⚠️ lazy reads `stdpath('config')/lazy-lock.json` (core/config.lua:24)
  #   - a copy anywhere else is a file, not a pin
  #
  # 🛑 .this is FATAL where the imagemagick policy below is not
  #   - an absent policy degrades an image render
  #   - an absent lockfile means the next nvim start executes 13 repos at tip
  #   - to bump: `:Lazy update`, then copy it back over `src/lazy-lock.json`
  ####################################################################
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

  ####################################################################
  # ⚠️ the SIBLING, and it carries the SAME guarantee on purpose
  #
  #   a guarantee applied to one call and not to its sibling in the same file is
  #   a blocker (`rule.require.one-command-provision`), and the sweep that saw
  #   only the first is the second defect.
  #
  #   here the risk is SHARPER than init.lua's, because drift is the DECLARED
  #   workflow: the block above says "to bump: `:Lazy update`, then copy it back
  #   over `src/lazy-lock.json`". a human who runs the update and reaches for
  #   `grove.provision` before the copy-back loses every new pin, silently.
  ####################################################################
  _nvim_keep_the_copy_about_to_be_overwritten "$lock_dst" "$lock_src" || return 1

  if ! cp "$lock_src" "$lock_dst"; then
    echo "   ✋ could not write $lock_dst" >&2
    echo "      ⇒ lazy reads this exact path; a lockfile anywhere else is a file," >&2
    echo "        not a pin, so the next start clones 13 repos at tip" >&2
    echo "      read why: the cp error above — usually a permission or a full disk" >&2
    return 1
  fi

  echo "   • nvim plugin lockfile declared → $lock_dst"

  ####################################################################
  # 🛑 the imagemagick POLICY, which this bundle owns because it owns the tool
  #
  #   - `provision.upsert` step 6 puts imagemagick on the box
  #   - (rule.require.bundles-own-their-dependencies)
  #   - the debian default calls ITSELF an "open security policy"
  #   - it declares NO coder rule, and an absent rule is a PERMITTED one
  #   - so PS/EPS/PDF/XPS reach ghostscript and MVG/MSL are interpreted
  #   - `src/imagemagick.policy.xml` carries the account and the measurement
  #
  # ⚠️ .a SEAT path, and no root
  #   - 📜 2026-08-31: a policy at `$XDG_CONFIG_HOME/ImageMagick` bites unaided
  #   - 📜 the `$HOME/.config` fallback bites too
  #   - ⇒ the CAMPER can own this for itself, rather than wait on `ground`
  #   - ⚠️ it is not fatal, as step 6 is not, and `configure.verify` asks it bites
  ####################################################################
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
