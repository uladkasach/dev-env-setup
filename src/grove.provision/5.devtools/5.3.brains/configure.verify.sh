#!/usr/bin/env bash
######################################################################
# .what = prove each declared key is LIVE — in BOTH files the upsert writes
#
# .it reads each key back with jq, and never greps the file
#   - the write is a deep MERGE
#   - ⇒ a key can be present in the file and still hold the wrong value
#   - a human's own edit does that, as does an older patch
#   - a grep for the key NAME would report ✔ on either
#   - ⇒ `jq` reads the VALUE, the only fact that changes what claude does
#
# 🛑 .it finds the GLOBAL CONFIG through the cli's OWN two-branch lookup
#   - that lookup takes two branches, and a verify that hardcoded one would
#     report `absent` forever on a box that sat on the other — a false ✋, which
#     decays into a silenced check (`gotcha.a-check-that-cries-wolf`)
#   - ⇒ ONE reader, declared in `configure.upsert.sh`, asked by both halves,
#     so the upsert and the verify cannot read the same box two ways (m.9)
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_5_3_brains_configure_verify() {
  local settings="$HOME/.claude/settings.json"

  if [[ ! -r "$settings" ]]; then
    echo "   ✋ no claude settings at $settings" >&2
    echo "      ⇒ claude self-updates to a version no checkout declares, and" >&2
    echo "        nags about connectors on every start" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "   🌙 jq is absent, so the settings values cannot be observed."
    echo "      the file exists; what it holds is unproven"
    return 0
  fi

  local failed=0 pair path want live

  for pair in \
    '.env.DISABLE_AUTOUPDATER:"1":the auto-updater' \
    '.env.DISABLE_INSTALLATION_CHECKS:"1":the native-installer migration nag' \
    '.env.CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION:"false":the prompt suggestion' \
    '.env.CLAUDE_CODE_DISABLE_COMMAND_INJECTION_CHECK:"1":the command injection check' \
    '.env.CLAUDE_CODE_ENABLE_TODO_TOOLS:"1":the todo and task tools' \
    '.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:"50":the auto-compact threshold' \
    '.disableClaudeAiConnectors:true:the claude.ai connector fetch' \
    '.permissions.defaultMode:"auto":the auto default mode' \
    '.permissions.deny:["Agent"]:the subagent ban' \
    '.model:"claude-opus-5-5[1m]":the default model' \
    '.env.ANTHROPIC_MODEL:"claude-opus-5-5[1m]":the default model env override' \
    '.env.CLAUDE_CODE_SUBAGENT_MODEL:"claude-sonnet-5[1m]":the subagent model' \
    '.effortLevel:"medium":the default effort level' \
    '.skipAutoPermissionPrompt:true:the auto-permission prompt skip' \
    '.tui:"fullscreen":the fullscreen tui' \
    '.verbose:true:the verbose output default' \
    '.cleanupPeriodDays:36500:the never-prune transcript retention'; do
    path="${pair%%:*}"
    want="${pair#*:}"; want="${want%%:*}"
    live="$(jq -c "$path" "$settings" 2>/dev/null)"

    if [[ "$live" == "$want" ]]; then
      echo "   • ${pair##*:} holds the declared value ✔"
    else
      echo "   ✋ ${pair##*:} is NOT declared — $path reads ${live:-absent}, want $want" >&2
      echo "      ⇒ a merged file can hold the key at the wrong value, so its" >&2
      echo "        presence alone proves neither the patch nor its effect" >&2
      echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
      failed=1
    fi
  done

  ####################################################################
  # .the GLOBAL CONFIG half — `~/.claude.json`, the `/config` panel's toggles
  #
  # ⚠️ this is a SECOND FILE, not a second key in the one above. claude reads
  #   `diffSidebarOpen` straight off the global config, never through settings —
  #   so a check aimed at `settings.json` would go green on an inert declaration
  ####################################################################
  local config
  if declare -F _grove_provision_5_3_brains_config_path >/dev/null 2>&1; then
    config="$(_grove_provision_5_3_brains_config_path)"
  else
    ####################################################################
    # 🌙 the upsert half is the one reader, and it is absent from this run
    #   - a verify may run with no upsert sourced beside it
    #   - ⇒ it says so rather than guess a path, because a guessed path that
    #     misses reads `absent` and reports a ✋ against a box that is fine
    ####################################################################
    echo "   🌙 the global config path reader is absent, so the diff panel default is unproven"
    return $failed
  fi

  if [[ ! -r "$config" ]]; then
    echo "   ✋ no claude global config at $config" >&2
    echo "      ⇒ so the diff panel will auto-open on any wide terminal" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  live="$(jq -c '.diffSidebarOpen' "$config" 2>/dev/null)"
  if [[ "$live" == "false" ]]; then
    echo "   • the diff panel shut-at-start holds the declared value ✔"
  else
    echo "   ✋ the diff panel is NOT held shut — .diffSidebarOpen reads ${live:-absent}, want false" >&2
    echo "      ⇒ absent or true, the fullscreen tui opens the diff panel on its own" >&2
    echo "        whenever the terminal is wide enough" >&2
    echo "      ⇒ a /diff toggle writes this key, so one open flips it to true;" >&2
    echo "        the next apply shuts it again" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    failed=1
  fi

  return $failed
}
