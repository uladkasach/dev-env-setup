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
#   - it also converges the CANDIDATE claude — a second, parallel install under
#     `~/.local/opt/claude`, reached as `claude.latest`. the pinned default
#     above is untouched by it; see this bundle's `_.sh` for why both exist
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
    for stale in "$nodedir"/lib/node_modules/@anthropic-ai/.claude-code-*; do
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

_grove_provision_5_3_brains_claude_latest() {
  ##################################################################
  # .what = converge the CANDIDATE claude — its own prefix, the `latest`
  #   pointer, and the `claude.latest` shim. the pinned default is untouched
  #   by every line here.
  #
  # .the declarations live in this bundle's `_.sh`, and BOTH halves read them
  ##################################################################
  local prefix="$GROVE_BRAIN_CLAUDE_LATEST_PREFIX"
  local shim="$GROVE_BRAIN_CLAUDE_LATEST_SHIM"
  local pin="$GROVE_BRAIN_CLAUDE_LATEST_PIN"

  ##################################################################
  # the opt-out leg — it TEARS DOWN, and touches the default not at all
  #
  # .why teardown rather than a skip: a box opted in once and out later would
  #   keep a `claude.latest` no line in the tree declares, pointed at a
  #   version nobody reviewed. the same reason `5.18.openhours` tears down
  ##################################################################
  if [[ -z "$pin" ]]; then
    if [[ -e "$shim" || -d "$prefix" ]]; then
      rm -f "$shim" || return 1
      rm -rf "$prefix" || return 1
      echo "   🌙 claude.latest is opted out — its shim and prefixes removed"
    else
      echo "   🌙 claude.latest is opted out — no candidate installed"
    fi
    echo "      opt in: set GROVE_BRAIN_CLAUDE_LATEST_PIN in this bundle's _.sh"
    return 0
  fi

  ##################################################################
  # 1. the versioned prefix
  #
  # ⚠️ the guard is the shared THREE-valued reader, never `[[ -d ]]` — see
  #   the reader's own header for the shape it exists to refuse
  ##################################################################
  local dir="$prefix/v$pin"
  local state
  state="$(grove_provision_5_3_brains_claude_latest_state)"

  if [[ "$state" == "whole" ]]; then
    echo "   • claude.latest is built at the declared candidate ($pin)"
  else
    mkdir -p "$dir" || return 1

    ##############################################################
    # the package.json is WRITTEN, never `pnpm init`
    #
    # .why written: `pnpm init` is one more registry-era command whose output
    #   shape is pnpm's to change; this text is ours and is the same on every
    #   box (`rule.require.identical-commands-on-every-server`)
    #
    # 🛑 .why `onlyBuiltDependencies` is DECLARED here and not passed as a flag
    #   pnpm 10+ refuses a dependency's build scripts unless approved, and
    #   WITH A TTY it ASKS — which hangs the run and eats the next command
    #   sent down the duct (`rule.forbid.tty-as-a-proxy-for-a-human`: a duct
    #   HAS a tty). the global install above answers that with
    #   `--allow-build=`; a local prefix can answer it in the manifest, which
    #   is better — the approval then lives in the artifact rather than in the
    #   one command line that happened to install it
    ##############################################################
    cat > "$dir/package.json" <<'EOF' || return 1
{
  "name": "claude-latest",
  "private": true,
  "pnpm": {
    "onlyBuiltDependencies": ["@anthropic-ai/claude-code"]
  }
}
EOF

    # `web_pnpm`, never a bare `pnpm` — an unbounded registry call on the
    # provision path does not fail one phase, it holds the duct and every
    # command sent after it (`rule.require.bounded-probes-in-verifies`)
    if ! ( cd "$dir" && web_pnpm add "@anthropic-ai/claude-code@$pin" ); then
      echo "   ✋ could not install the candidate claude@$pin" >&2
      echo "      ⇒ the pinned default is untouched; only the candidate is absent" >&2
      echo "      read why: cd $dir && pnpm add @anthropic-ai/claude-code@$pin" >&2
      return 1
    fi
    echo "   • claude.latest candidate installed ✔ ($pin)"
  fi

  ##################################################################
  # 2. the `latest` pointer
  #
  # ⚠️ `-n` beside `-f`: without it `ln -sf` DEREFERENCES an extant symlink to
  #   a dir and writes the new link INSIDE the old target, so a second bump
  #   would land at `v<old>/v<new>` and the pointer would never move
  ##################################################################
  ln -sfn "v$pin" "$prefix/latest" || {
    echo "   ✋ could not point $prefix/latest at v$pin" >&2
    echo "      ⇒ the shim reads the pointer, so it would run the prior candidate" >&2
    return 1
  }

  ##################################################################
  # 3. REAP every prefix the tree no longer declares
  #
  # 🛑 .why a reap at all: a bundle that only ADDS converges a box to every
  #   version this repo has ever declared rather than the one it declares
  #   today, and no verify on a declared row can see it
  #   (`rule.require.one-command-provision`, defect shape 11). each prefix is
  #   a full node_modules, so the residue is measured in hundreds of MB
  #
  # ⚠️ the declared set is DERIVED from the pin, never a skip-list of retired
  #   versions — a skip-list goes stale the day the next bump lands, silently
  ##################################################################
  local stale reaped=0
  for stale in "$prefix"/v*; do
    [[ -d "$stale" ]] || continue
    [[ "$(basename "$stale")" == "v$pin" ]] && continue
    rm -rf "$stale" || {
      echo "   ✋ could not reap the undeclared candidate prefix $stale" >&2
      return 1
    }
    echo "   • reaped an undeclared candidate prefix → $(basename "$stale")"
    reaped=1
  done
  [[ "$reaped" -eq 1 ]] || true

  ##################################################################
  # 4. the shim — RENDERED from the one declaration, so the verify can diff
  #   a fresh render against what sits on disk and prove it CURRENT
  ##################################################################
  mkdir -p "$(dirname "$shim")" || return 1
  grove_provision_5_3_brains_claude_latest_shim_render > "$shim" || {
    echo "   ✋ could not write the claude.latest shim to $shim" >&2
    return 1
  }
  chmod +x "$shim" || return 1
  echo "   • claude.latest shim declared → $shim"
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

  # the CANDIDATE claude, in its own prefix — LAST, so a candidate that cannot
  # install never delays the pinned default every guardrail here rides on
  _grove_provision_5_3_brains_claude_latest || return 1
}
