#!/usr/bin/env bash
# .what = install claude-code, rhachet, and codex globally via pnpm
# .ref  = https://github.com/anthropics/claude-code
# .ref  = https://github.com/openai/codex
# .why
#   - `--allow-build=@anthropic-ai/claude-code` — pnpm 10+ refuses a
#     dependency's build scripts unless approved; WITH A TTY it asks and
#     hangs the run, so it eats the NEXT command sent down the duct
#     (rule.forbid.tty-as-a-proxy-for-a-human: a duct HAS a tty)
#   - it names pnpm's absence rather than let the installs fail, since pnpm
#     arrives with `5.1.node` (rule.require.errors-name-the-fix)
#   - .refs = gotcha.5-3-brains-peers.demo=optional-peer-outages
#
#   - it also converges the CANDIDATE claude, via `_.sh` (define.5-3-brains.candidate-claude)
#
# guarantee:
#   - `pnpm install -g` converges on an already-installed package
#   - it returns ITS OWN status and does not reach for the configure phase

# the pins live in this bundle's `_.sh` (GROVE_BRAIN_{CLAUDE,CODEX}_PIN) —
# both halves read them: the installs below and the verify's probes

_grove_provision_5_3_brains_prune_npm_shadows() {
  ##################################################################
  # .what = uninstall each named package from every fnm node version's
  #         npm global, so only the pnpm global copy is left on PATH
  # .why  = `fnm env --use-on-cd` puts fnm's bin ahead of $PNPM_HOME on
  #   some shells, and the $PNPM_HOME prepend is order-sensitive
  #   (`5.1.node/configure.upsert.sh`). so a stray `npm install -g <pkg>`
  #   can outrank the pnpm copy this bundle converges on, with no other
  #   check to notice the swap. a re-apply that never removes the shadow
  #   would redden forever, or worse, report ✔ on a pnpm copy nobody runs
  #   (`rule.require.one-command-provision`, the re-apply-loops-forever shape)
  #   - claude-code: a stray npm install, or claude's own native-installer migration
  #   - rhachet: 📜 2026-11-23, `rhx upgrade --self --which global` raised
  #     pnpm's rhachet to 1.54.1 while the bare `rhx` resolved to an
  #     fnm npm-global 1.51.0 — the upgrade exited 0 and reached no shell
  ##################################################################
  local fnm_home="${FNM_DIR:-$HOME/.local/share/fnm}"
  local pkg

  for pkg in "$@"; do
    _grove_provision_5_3_brains_prune_npm_shadow "$fnm_home" "$pkg" || return 1
  done
  return 0
}

_grove_provision_5_3_brains_prune_npm_shadow() {
  local fnm_home="$1" pkg="$2"
  local nodedir pkg_parent pkg_base

  for nodedir in "$fnm_home"/node-versions/*/installation; do
    [[ -d "$nodedir/lib/node_modules/$pkg" ]] || continue
    pkg_parent="$(dirname "$nodedir/lib/node_modules/$pkg")"
    pkg_base="$(basename "$pkg")"

    ################################################################
    # 🛑 clear npm's leftover temp dir FIRST, or the uninstall below
    #    can never succeed on this box again
    #
    # npm uninstalls by a RENAME of the package dir to `.<name>-<hash>`
    # and a delete of that. the hash is derived, not random — so a run
    # cut partway (a ctrl-c, an oom) leaves the temp dir behind, and
    # every later uninstall renames onto it and dies `ENOTEMPTY`
    #   - ⇒ the prune reddens on every apply, with the same fix-text,
    #     and that hand fix fails for the same reason
    #   - that is the very re-apply-loops-forever shape the block above
    #     says this prune exists to prevent (`rule.require.one-command-provision`)
    #
    # 📜 measured 2026-09-13 on this laptop: `.claude-code-h65xko2X`
    #    sat beside `claude-code`, byte-for-byte its twin, and blocked
    #    `5.3.brains` — so the model key this bundle declares could not
    #    reach the box at all
    ################################################################
    local stale
    for stale in "$pkg_parent/.$pkg_base"-*; do
      [[ -d "$stale" ]] || continue
      rm -rf "$stale" || {
        echo "   ✋ could not clear npm's leftover temp dir at $stale" >&2
        echo "      ⇒ npm renames onto this exact path, so the uninstall below" >&2
        echo "        fails ENOTEMPTY until it is gone" >&2
        return 1
      }
      echo "   • cleared npm's leftover temp dir → $(basename "$stale")"
    done

    # invoke npm by absolute path, via its own node — the interactive `npm`
    # shell function routes to pnpm when no package-lock.json is present, so
    # a bare `npm uninstall -g` here would remove the pnpm copy we mean to keep
    "$nodedir/bin/node" "$nodedir/bin/npm" uninstall -g "$pkg" >/dev/null 2>&1 || {
      echo "   ✋ failed to prune npm-global $pkg shadow at $nodedir" >&2
      echo "      fix: '$nodedir/bin/node' '$nodedir/bin/npm' uninstall -g $pkg" >&2
      return 1
    }
    echo "   • pruned npm-global $pkg shadow at $(basename "$(dirname "$nodedir")")"
  done
  return 0
}

grove_provision_5_3_brains_provision_upsert() {
  if ! command -v pnpm >/dev/null 2>&1; then
    echo "   ✋ pnpm is absent — the robot brains cannot install" >&2
    echo "      ⇒ pnpm comes from 5.1.node, so the cause is one bundle above" >&2
    echo "        this one rather than a fact about the brains themselves" >&2
    echo "      fix: rhx grove.provision --what 5.1.node --mode apply" >&2
    return 1
  fi

  # jq is a dependency of THIS bundle's configure, which merges claude's
  # settings — the install lands in PROVISION, not configure, since an
  # install below the verify that gates configure would never be seen by it
  # (rule.require.upgrade-entries-verify-themselves)
  if ! command -v jq >/dev/null 2>&1; then
    pkg_install jq || return 1
    echo "   • jq installed — the settings merge needs it"
  fi

  # prune npm-global shadows BEFORE the pnpm installs, so PATH order cannot
  # let a stray copy outrank the one these lines converge on
  _grove_provision_5_3_brains_prune_npm_shadows rhachet @anthropic-ai/claude-code || return 1

  # rhachet is not pinned; the brains ARE — the split is WHO PUBLISHES
  # (`_.sh` states it beside the two pins). `web_pnpm`, never a bare `pnpm`
  # (.refs = gotcha.5-3-brains-peers.demo=optional-peer-outages)
  web_pnpm install -g rhachet || return 1

  # rhachet's PEERS, which a global install does not pull in — three
  # outages traced their absence to failures far from this line, and
  # `declastruct` is a CHAIN link neither is optional without
  # (.refs = gotcha.5-3-brains-peers.demo=optional-peer-outages). the
  # `aws.params` vault these hold is how every grove reads github
  # (rule.require.github-token-at-all-camp)
  web_pnpm install -g declastruct declastruct-aws || return 1

  web_pnpm install -g "@openai/codex@$GROVE_BRAIN_CODEX_PIN" || return 1

  web_pnpm install -g \
    --allow-build=@anthropic-ai/claude-code \
    "@anthropic-ai/claude-code@$GROVE_BRAIN_CLAUDE_PIN" || return 1

  echo "   • robot brains installed ✔ (claude-code@$GROVE_BRAIN_CLAUDE_PIN, codex@$GROVE_BRAIN_CODEX_PIN, rhachet)"
  echo "   • rhachet peers installed ✔ (declastruct, declastruct-aws — the aws.params vault)"

  # the CANDIDATE claude, in its own prefix — LAST, so a candidate that cannot
  # install never delays the pinned default every guardrail here rides on
  grove_provision_5_3_brains_claude_latest_upsert || return 1
}
