#!/usr/bin/env bash
######################################################################
# .what = declare claude-code's TWO config files — its settings, and its
#   global config
# .ref  = https://code.claude.com/docs/en/setup
# .ref  = howto.silence-claude-cli-nags
#
# 🛑 .claude reads TWO files, and a key belongs to exactly one of them
#
#   | file | holds | this bundle |
#   |---|---|---|
#   | `~/.claude/settings.json` | the declared settings — env, permissions, model, hooks | merged below |
#   | `~/.claude.json` | the GLOBAL CONFIG — the `/config` panel's own toggles | merged below |
#
#   ⚠️ they are NOT interchangeable, and the failure is silent. `settings.json`
#   is validated against a zod schema, so a key that schema does not name is
#   accepted, stored, and read by no caller. a verify that greps for the key
#   would find it and report ✔ forever.
#   ⇒ before you add a key, settle WHICH file claude reads it from
#
# .why the global config half exists at all — `verbose`
#   - `verbose` is the `/config` panel's "show full command outputs" toggle
#   - it is ABSENT from the settings zod schema (measured, 2.1.87), so a
#     `"verbose": true` in `settings.json` is inert
#   - and `claude config set` is GONE from the cli — the only `config`
#     subcommand left in 2.1.87 sits under `auto-mode`
#   - ⇒ a human's only lever is the TUI toggle, which this repo cannot declare
#     (`rule.require.repo-as-source-of-truth`)
#
# 🛑 .THIS PATCH IS THE SOLE HOME OF EVERY BRAIN KNOB
#   - `rule.require.brain-config-has-one-home`. no peer bundle may declare one
#   - the shelf test is the READ SITE, never a guess: `zd()` assigns this `env`
#     block into `process.env` UNFILTERED at startup, so a flag read after that is
#     reachable from here
#   - ⇒ a flag with NO read site is DEAD, and is deleted rather than rehomed
#
# .the env flags, and what each buys
#   | flag | effect | read at |
#   |---|---|---|
#   | `DISABLE_AUTOUPDATER` | the ONE update kill-switch — cli AND plugins (`ED6()`) | `j96()` |
#   | `DISABLE_INSTALLATION_CHECKS` | the npm→native migration nag (#23683) | `$w6()`, `kFz()` |
#   | `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | auto-compact at 50%, not ~83% — cuts ITPM spikes | `et6()` |
#   | `CLAUDE_CODE_SUBAGENT_MODEL` | subagents on sonnet, never the session's opus | `Ik6()` |
#   - ⚠️ the subagent model is inert while `permissions.deny` holds `Agent`; it is
#     declared so the value is right on the day that ban lifts
#
# .refs = gotcha.5-3-brains.demo=one-home-consolidation.md — the three-bundle split,
#   the silent model drift, what `gk6` gates, the reap, and why `DISABLE_UPDATES` is no knob (m7)
#
# .disableClaudeAiConnectors stops the claude.ai connector auto-fetch
#   - ⇒ it silences "N claude.ai connector needs auth · /mcp" (v2.1.182+)
#
# .CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION turns off the PROMPT SUGGESTION
#   - that is the grey ghost text claude proposes inside its own input box
#   - the `/`-command menu and `@`-file completion are separate and unaffected
#   - ⇒ the term is `prompt suggestion`, never "autocomplete", which names all three
#   - the opt-out shipped in claude 2.0.71 (anthropics/claude-code#13878)
#   - (`term=prompt-suggestion`)
#
# 🛑 .the MODEL is declared TWICE, and the two are not redundant
#
#   the cli picks a model from THREE places, in this order (`Ih()`, 2.1.87):
#     1. the session override — `/model`, or `--model` on the command line
#     2. `env.ANTHROPIC_MODEL`
#     3. `.model`
#
#   - ⇒ `ANTHROPIC_MODEL` OUTRANKS `.model`, so a box that carries only the
#     second runs whatever a stale env var says, quietly
#   - ⇒ and `.model` is the value the `/model` panel reads and writes, so a box
#     that carries only the env var shows a panel that disagrees with its run
#   - ⇒ both are declared, at ONE value, so neither reader is misled
#
#   ⚠️ the env var does NOT pin the session. rung 1 still wins, so `/model`
#   switches live exactly as before — this sets the DEFAULT, never an upper bound
#
#   ✔ `env.ANTHROPIC_MODEL` is a settings key the cli HONORS, not merely an
#     export it happens to read: `zd()` assigns this block into `process.env` at
#     startup, BEFORE the model is picked
#
#   🛑 this line read "`gk6` is the allowlist of env names a settings file may
#      set". that is FALSE: `zd()` applies the block UNFILTERED, and `gk6` gates a
#      TRUST PROMPT, never permission (.refs m3, `define.claude-code-config`)
#   - ⇒ so it reaches every caller — a tui session, `claude -p`, the sdk, and
#     whatever this repo's `claude` shell function or `claude.latest` shim
#     spawns — with no shell export in any rc file
#
# .effortLevel=medium is the default REASONING EFFORT for models that take one
#   - it IS in the settings zod schema — `enum(["low","medium","high"])` — so
#     this key is not the inert-key hazard named at the top of this file
#   - an ABSENT key means `auto`, which the cli picks per model, so the default
#     is a value chosen by no one and free to move under a version bump
#   - `medium` is the cli's own recommended rung, labelled as such in `/effort`
#   - ⚠️ `CLAUDE_CODE_EFFORT_LEVEL` OVERRULES this for a whole session, and the
#     cli says so when it does. this repo exports it from no shelf, so the
#     settings key is the one lever — a box where `/effort` reports an override
#     has that var set by a caller outside this repo
#
# .permissions.defaultMode=auto starts every session in AUTO mode, where the
#   `PermissionRequest` hook decides a suspicious-classified prompt per-segment
#   rather than lift it to the human (shift+tab still cycles modes live)
#
#   ⚠️ `auto` is an INTERNAL mode: the cli's own tip text for an invalid value
#   lists four modes and omits it, because that tip is written against the
#   EXTERNAL set. the validator takes the internal set, which is the external
#   four plus `dontAsk` and `auto` — so a reader who checks the error message
#   rather than the enum concludes, wrongly, that this value is invalid
#
# 🛑 .this key and `.model` were ADOPTED FROM THE LIVE FILE, not chosen here
#   - measured 2026-09-23: the live settings read `auto` and `claude-opus-5-5`
#     where this patch declared `acceptEdits` and `claude-opus-5`
#   - a merge converges a DECLARED key, so the next apply would have reverted
#     both — a human's deliberate choice, undone by a run they asked for a
#     different reason
#   - ⇒ the repo is the source of truth, so the repo learns the live value
#     rather than overwrite it (`rule.require.repo-as-source-of-truth`)
#   - ⚠️ the drift is one-way only for keys this patch DECLARES. `skipAutoPermissionPrompt`,
#     `tui`, and `env.CLAUDE_CODE_DISABLE_COMMAND_INJECTION_CHECK` sat in the live
#     file and in NO bundle: the merge preserved them on this box and a FRESH box
#     got none. ✔ adopted 2026-09-25, at the live values
#   - 🛑 that gap is INVISIBLE to every verify, by construction — a verify reads the
#     rows the repo declares, so a key with no declaration has no row to redden.
#     ⇒ when you touch this patch, diff the LIVE keys against the declared set
#
# 🛑 .cleanupPeriodDays governs the TRANSCRIPTS, and its default DELETES them
#   - claude keeps a session's transcript for N days past its last activity and
#     then removes it. the default N is 30, and it applies whether or not the key
#     appears in the file — so an ABSENT key is not "no prune", it IS the 30-day
#     prune, chosen by default and never stated
#   - ⇒ every `/resume`, every post-compaction re-read of a session `.jsonl`, and
#     every archaeology run against a prior session dies on its 31st day
#   - ⚠️ the loss is UNRECOVERABLE and UNREPORTED. no line says a transcript was
#     pruned, so a human learns of it from a `/resume` that finds naught — which
#     is a failhide in the tool, and the reason this key is declared rather than
#     left to a default nobody sees (`rule.forbid.failhide`)
#   - ⇒ 36500 days is a hundred years, which is `never` said in the one unit the
#     option accepts. claude declares NO sentinel for never, so a reader who
#     greps for that word finds none — and must not read its absence as a gap
#
# .permissions.deny=["Agent"] bans SUBAGENTS outright
#   - a BARE tool name (no parens, no args) removes the tool from claude's own
#     context, so it never sees it — this is not a prompt-at-call-time gate
#   - ⇒ it takes effect on the next tool call, mid-session, with no restart
#   - the cost is real and chosen: research that a subagent would hold in its own
#     context now lands in the main one, and `/batch` (which fans out across
#     worktree agents) no longer runs
#
# 🛑 .`jq '. * $patch'` REPLACES an array; it merges only objects
#   - ⇒ a `deny` list a human adds to this file by hand is DESTROYED by the next
#     apply, silently, because this patch declares that same key
#   - ⇒ a deny entry belongs HERE, in this list, never in the live file alone
#   - (the live file held no `deny` array when this landed, so the first apply
#     destroyed no entry — that is a fact about that day, never a guarantee)
#
# 🛑 .the rule is "match the shelf to WHEN the flag is read" — so FIND THE READ SITE
#   - this file named the wrong shelf TWICE, both times for the installer nag, and
#     neither claim ever cited one. the source contradicts both (.refs m4)
#   - ⇒ a "read too late" comment with no read site beside it is a guess, and these
#     guesses cost a two-writers split across three bundles
#
# ⚠️ `jq '. * $patch'`, never a plain overwrite
#   - `~/.claude/settings.json` is a file a HUMAN also edits, and it holds hooks,
#     model choice, and permissions
#   - ⇒ an overwrite here would silently destroy all of that
#   - ⇒ the deep merge leaves every key it does not declare as it found them
#
# guarantee:
#   - idempotent: a merge of the same patch converges
#   - it PRESERVES every key it does not declare
######################################################################

####################################################################
# .what = the SETTINGS half — `~/.claude/settings.json`
####################################################################
_grove_provision_5_3_brains_settings_upsert() {
  local patch='{"env": {"DISABLE_AUTOUPDATER": "1", "DISABLE_INSTALLATION_CHECKS": "1", "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION": "false", "CLAUDE_CODE_DISABLE_COMMAND_INJECTION_CHECK": "1", "ANTHROPIC_MODEL": "claude-opus-5-5[1m]", "CLAUDE_CODE_SUBAGENT_MODEL": "claude-sonnet-5[1m]", "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50"}, "disableClaudeAiConnectors": true, "permissions": {"defaultMode": "auto", "deny": ["Agent"]}, "model": "claude-opus-5-5[1m]", "effortLevel": "medium", "cleanupPeriodDays": 36500, "skipAutoPermissionPrompt": true, "tui": "fullscreen"}'
  local settings="$HOME/.claude/settings.json"

  if ! mkdir -p "$HOME/.claude"; then
    echo "   ✋ could not create $HOME/.claude" >&2
    return 1
  fi

  ####################################################################
  # .no extant file, so the patch is written whole
  ####################################################################
  if [[ ! -f "$settings" ]]; then
    if ! echo "$patch" > "$settings"; then
      echo "   ✋ could not write $settings" >&2
      return 1
    fi
    echo "   • claude settings declared → $settings"
    return 0
  fi

  ####################################################################
  # .an extant file is MERGED, never overwritten
  #
  # 🛑 an absent jq is a hard stop
  #   - the only ways forward are to overwrite or to skip
  #   - an overwrite destroys a human's hooks, and a silent skip is a failhide
  #   - ⇒ neither is acceptable, so it refuses
  #
  # 📜 this named `--what 2.shell` as its fix, a pointer-shaped error
  #   - it sent the reader to a whole SECTION whose relevance was the numbers
  #   - ⇒ jq is this bundle's own declared dependency, installed by its provision
  #   - ⇒ the fix below names THIS slug, and one apply of it converges
  #   - (`rule.require.bundles-own-their-dependencies`)
  ####################################################################
  if ! command -v jq >/dev/null 2>&1; then
    echo "   ✋ jq is absent, so the extant settings cannot be merged into" >&2
    echo "      ⇒ this file also holds a human's hooks, model, and permissions," >&2
    echo "        so an overwrite would destroy them — refused rather than risk it" >&2
    echo "      ⇒ this bundle's provision phase installs jq, so it did not run" >&2
    echo "        or could not reach root" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  ####################################################################
  # .the REAP — a merge only ADDS, so a RETIRED key outlives its declaration
  #
  # 🛑 without this, HISTORY outranks the tree: the box converges to every key the
  #   repo has EVER declared, never the set it declares today. and no verify can
  #   see it — a verify reads the DECLARED rows, so an undeclared key has no row
  #   to redden (`rule.require.brain-config-has-one-home`, shape 11)
  #
  # ⚠️ it names keys EXPLICITLY, and does NOT reap every undeclared key
  #   - the merge's PRESERVE guarantee is load-bear: it lets the repo ADOPT a value
  #     a human set by hand rather than revert it, and a blanket reap inverts that
  #   - ⇒ a key enters this list only once PROVEN dead — zero read sites in the
  #     pinned cli — which is why a delete here can harm no caller
  #   - a key that is live but merely MOVED is retired by a change of value
  #
  # .refs = gotcha.5-3-brains.demo=one-home-consolidation.md, m5
  ####################################################################
  # ⚠️ ONE `del`, never a loop that builds the filter — an empty list would render
  #    `del() | …`, which is a jq syntax error, so the shape must not depend on count
  local reap='del(.env.DISABLE_UPDATES, .env.CLAUDE_CODE_SKIP_UPDATE_CHECK)'

  local tmp
  tmp="$(mktemp)" || return 1
  if ! jq --argjson patch "$patch" "$reap"' | . * $patch' "$settings" > "$tmp"; then
    echo "   ✋ jq could not merge the patch into $settings" >&2
    echo "      ⇒ the file is likely not valid json, so it was left untouched" >&2
    echo "      read why: jq . $settings" >&2
    rm -f "$tmp"
    return 1
  fi

  if ! mv "$tmp" "$settings"; then
    echo "   ✋ could not write the merged settings back to $settings" >&2
    rm -f "$tmp"
    return 1
  fi

  echo "   • claude settings merged → $settings (updates + connectors + prompt suggestions off)"
}

####################################################################
# .what = where claude's GLOBAL CONFIG lives, as the cli itself resolves it
#
# .why a resolver and not a literal path — the cli takes TWO branches, and a
#   box that sits on the first one would have the second written beside it,
#   read by no caller, while the verify reported ✔ on the file it just wrote
#
# transcribed from `cli.js` (2.1.87):
#   aM = () => exists(join(c1(), ".config.json")) ? join(c1(), ".config.json")
#                                                 : join($CLAUDE_CONFIG_DIR || homedir(), ".claude.json")
#   c1 = () => $CLAUDE_CONFIG_DIR ?? join(homedir(), ".claude")
####################################################################
_grove_provision_5_3_brains_config_path() {
  local dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  [[ -f "$dir/.config.json" ]] && { echo "$dir/.config.json"; return 0; }
  echo "${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"
}

####################################################################
# .what = the GLOBAL CONFIG half — the `/config` panel's own toggles
#
# .verbose=true shows full command outputs rather than a truncated head
#
# 🛑 .this file also holds the OAUTH SESSION, so the write is guarded twice
#
#   claude's own writer carries a refusal for exactly this — `saveConfigWithLock:
#   re-read config is missing auth that cache has; refusing to write to avoid
#   wiping ~/.claude.json. See GH #3117.` — so the hazard is measured upstream,
#   never theorized here.
#
#   ⇒ guard 1, a SKIP: the value is read first, and a file that already holds
#     the declared value is not opened for write at all. so the steady state —
#     every apply after the first — touches the file not at all, and the race
#     window is closed rather than merely narrowed
#   ⇒ guard 2, an ATOMIC RENAME: the merge lands in a tmp on the same
#     filesystem and is `mv`d over. a claude that reads mid-write sees one whole
#     file or the other, never a half
#
#   ⚠️ what remains, stated rather than papered over: a claude that holds the
#   file in memory and writes its own copy back AFTER our rename drops our key.
#   that direction is benign — the next apply re-converges it, and the verify
#   reddens meanwhile. the costly direction (our write dropping ITS auth) needs
#   claude to persist auth inside the millisecond between our read and our
#   rename, and guard 1 removes even that on every apply but the first
#
# .why a MERGE and never an overwrite — the same reason as the settings half,
#   only sharper: this file is ~750KB of a human's per-project state, history,
#   and onboarding flags. it is claude's to own; this bundle declares one key
#   inside it and leaves every other key exactly as it found it
####################################################################
_grove_provision_5_3_brains_config_upsert() {
  local patch='{"verbose": true}'
  local config
  config="$(_grove_provision_5_3_brains_config_path)"

  ####################################################################
  # .no extant file, so the patch is written whole
  #   claude creates this file on its first run and merges its own defaults
  #   over whatever it finds, so a one-key file is a valid seed
  ####################################################################
  if [[ ! -f "$config" ]]; then
    if ! echo "$patch" > "$config"; then
      echo "   ✋ could not write $config" >&2
      return 1
    fi
    echo "   • claude global config declared → $config"
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "   ✋ jq is absent, so the extant global config cannot be merged into" >&2
    echo "      ⇒ this file holds the oauth session and a human's project state," >&2
    echo "        so an overwrite would destroy them — refused rather than risk it" >&2
    echo "      ⇒ this bundle's provision phase installs jq, so it did not run" >&2
    echo "        or could not reach root" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  ####################################################################
  # 🛑 guard 1 — a file that already holds the value is never opened for write
  ####################################################################
  if [[ "$(jq -c '.verbose' "$config" 2>/dev/null)" == "true" ]]; then
    echo "   • claude global config already verbose → $config [KEEP]"
    return 0
  fi

  ####################################################################
  # 🛑 guard 2 — the tmp lands BESIDE the target, so the `mv` is a rename
  #   within one filesystem and therefore atomic. `mktemp` alone would put it
  #   under /tmp, which is a tmpfs here — a cross-device `mv` is a copy, and a
  #   copy has a window in which the file is half written
  ####################################################################
  local tmp
  tmp="$(mktemp "$config.XXXXXX")" || return 1
  if ! jq --argjson patch "$patch" '. * $patch' "$config" > "$tmp"; then
    echo "   ✋ jq could not merge the patch into $config" >&2
    echo "      ⇒ the file is likely not valid json, so it was left untouched" >&2
    echo "      read why: jq . $config" >&2
    rm -f "$tmp"
    return 1
  fi

  ####################################################################
  # ⚠️ a merge that yields a smaller file than it read is a jq that dropped
  #   state, and this is the one file where that costs a human their session.
  #   the patch ADDS one key, so the output can never be shorter than the input
  ####################################################################
  local was now
  was="$(wc -c < "$config")"
  now="$(wc -c < "$tmp")"
  if [[ "$now" -lt "$was" ]]; then
    echo "   ✋ the merged global config SHRANK — $was bytes in, $now bytes out" >&2
    echo "      ⇒ this patch only adds a key, so a smaller result means state" >&2
    echo "        was dropped. the write is refused and $config is untouched" >&2
    echo "      read the candidate before you discard it: jq . $tmp" >&2
    return 1
  fi

  if ! mv "$tmp" "$config"; then
    echo "   ✋ could not write the merged global config back to $config" >&2
    rm -f "$tmp"
    return 1
  fi

  echo "   • claude global config merged → $config (verbose output on)"
}

####################################################################
# .why no phase CALLS the other, and both run
#   - each half owns its own file and its own failure, and a `&&` would let
#     a failed settings merge hide the config merge's verdict entirely
#     (`rule.forbid.failhide`)
#   - ⇒ both run, and the phase reports the worse of the two
####################################################################
grove_provision_5_3_brains_configure_upsert() {
  local failed=0
  _grove_provision_5_3_brains_settings_upsert || failed=1
  _grove_provision_5_3_brains_config_upsert || failed=1
  return $failed
}
