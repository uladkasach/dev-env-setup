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
# guarantee:
#   - `pnpm install -g` converges on an already-installed package
#   - it returns ITS OWN status and does not reach for the configure phase

# the pins live in this bundle's `_.sh` (GROVE_BRAIN_{CLAUDE,CODEX}_PIN) —
# both halves read them: the installs below and the verify's probes

_grove_provision_5_3_brains_prune_claude_shadows() {
  ##################################################################
  # .what = uninstall @anthropic-ai/claude-code from every fnm node version
  # .why  = `fnm env --use-on-cd` puts fnm's multishell bin ahead of
  #   $PNPM_HOME on some shells, and the $PNPM_HOME prepend is order-
  #   sensitive (`5.1.node/configure.upsert.sh`). so a stray
  #   `npm install -g @anthropic-ai/claude-code` — or claude's own
  #   native-installer migration — can outrank the pinned pnpm copy on
  #   PATH, with no other check to notice the swap. the verify CAN detect
  #   the resulting drift (it asks the live binary), but a re-apply that
  #   never removes the shadow would redden forever
  #   (`rule.require.one-command-provision`, the re-apply-loops-forever shape)
  ##################################################################
  local fnm_home="${FNM_DIR:-$HOME/.local/share/fnm}"
  local nodedir pruned=0

  for nodedir in "$fnm_home"/node-versions/*/installation; do
    [[ -d "$nodedir/lib/node_modules/@anthropic-ai/claude-code" ]] || continue

    # invoke npm by absolute path, via its own node — the interactive `npm`
    # shell function routes to pnpm when no package-lock.json is present, so
    # a bare `npm uninstall -g` here would remove the pnpm copy we mean to keep
    "$nodedir/bin/node" "$nodedir/bin/npm" uninstall -g @anthropic-ai/claude-code >/dev/null 2>&1 || {
      echo "   ✋ failed to prune npm-global claude-code shadow at $nodedir" >&2
      echo "      fix: '$nodedir/bin/node' '$nodedir/bin/npm' uninstall -g @anthropic-ai/claude-code" >&2
      return 1
    }
    echo "   • pruned npm-global claude-code shadow at $(basename "$(dirname "$nodedir")")"
    pruned=1
  done

  [[ "$pruned" -eq 1 ]] || true
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

  # prune a shadow BEFORE the pinned install, so PATH order cannot leave a
  # stray npm-global copy outranking the pnpm one this line converges on
  _grove_provision_5_3_brains_prune_claude_shadows || return 1

  web_pnpm install -g \
    --allow-build=@anthropic-ai/claude-code \
    "@anthropic-ai/claude-code@$GROVE_BRAIN_CLAUDE_PIN" || return 1

  echo "   • robot brains installed ✔ (claude-code@$GROVE_BRAIN_CLAUDE_PIN, codex@$GROVE_BRAIN_CODEX_PIN, rhachet)"
  echo "   • rhachet peers installed ✔ (declastruct, declastruct-aws — the aws.params vault)"
}
