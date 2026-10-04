#!/usr/bin/env bash
######################################################################
# .what = declare claude-code's TWO config files — its settings, and its global config
# .ref  = https://code.claude.com/docs/en/setup
# .ref  = howto.silence-claude-cli-nags
# .refs = define.5-3-brains.declared-keys — every key's why, by heading
#
# 🛑 .claude reads TWO files, and a key belongs to exactly one of them
#   - `~/.claude/settings.json` holds the declared settings; `~/.claude.json` the `/config` toggles
#   - ⚠️ a key the settings schema does not name is stored and read by no caller, silently
#   - ⇒ before you add a key, settle WHICH file claude reads it from
#
# 🛑 .THIS PATCH IS THE SOLE HOME OF EVERY BRAIN KNOB (`rule.require.brain-config-has-one-home`)
#   - the shelf test is the READ SITE, never a guess; a flag with none is deleted
#   - the MODEL is declared twice, `env.ANTHROPIC_MODEL` and `.model`, at ONE value
#   - `permissions.defaultMode` and `.model` were ADOPTED from the live file, never chosen here
#   - ⚠️ when you touch this patch, diff the LIVE keys against the declared set
#
# 🛑 .`cleanupPeriodDays` is 36500 because its 30-day default DELETES transcripts, unreported
# 🛑 .subagents are ALLOWED — no `deny` is declared, and the reap strips a leftover `"Agent"`
#
# ⚠️ `jq '. * $patch'`, never an overwrite — a human edits this file too
#   - it merges objects and REPLACES arrays, so no array is declared
#
# guarantee:
#   - idempotent: a merge of the same patch converges
#   - it PRESERVES every key it does not declare

####################################################################
# .what = the SETTINGS half — `~/.claude/settings.json`
# ⚠️ an ENROLLED claude reads rhachet's role file instead (define.5-3-brains.declared-keys)
####################################################################
_grove_provision_5_3_brains_settings_upsert() {
  local patch='{"env": {"DISABLE_AUTOUPDATER": "1", "DISABLE_INSTALLATION_CHECKS": "1", "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION": "false", "CLAUDE_CODE_DISABLE_COMMAND_INJECTION_CHECK": "1", "CLAUDE_CODE_ENABLE_TODO_TOOLS": "1", "ANTHROPIC_MODEL": "claude-opus-5-5[1m]", "CLAUDE_CODE_SUBAGENT_MODEL": "claude-sonnet-5[1m]", "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50"}, "disableClaudeAiConnectors": true, "permissions": {"defaultMode": "auto"}, "model": "claude-opus-5-5[1m]", "effortLevel": "medium", "cleanupPeriodDays": 36500, "skipAutoPermissionPrompt": true, "tui": "fullscreen", "verbose": true, "feedbackDrafts": "off"}'
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

  # an extant file is MERGED, never overwritten. 🛑 an absent jq is a hard stop —
  # overwrite destroys hooks, skip is a failhide. the fix names THIS bundle,
  # whose provision installs jq (`rule.require.bundles-own-their-dependencies`)
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
  #   - keys are named EXPLICITLY, once proven dead in the pinned cli (define.5-3-brains.declared-keys)
  #   - ⚠️ ONE `del`, since an empty list would render a jq syntax error
  #   - ⚠️ the `Agent` strip removes ONE entry; a list it empties is dropped
  ####################################################################
  local reap='del(.env.DISABLE_UPDATES, .env.CLAUDE_CODE_SKIP_UPDATE_CHECK)
    | if (.permissions.deny | type) == "array"
      then .permissions.deny -= ["Agent"]
        | if .permissions.deny == [] then del(.permissions.deny) else . end
      else . end'

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
# 🛑 `CLAUDE_CONFIG_DIR` is IGNORED here — an apply from an enrolled claude inherits
#   it, and a seat converges its OWN `$HOME` (define.5-3-brains.declared-keys)
####################################################################
_grove_provision_5_3_brains_config_path() {
  local dir="$HOME/.claude"
  [[ -f "$dir/.config.json" ]] && { echo "$dir/.config.json"; return 0; }
  echo "$HOME/.claude.json"
}

####################################################################
# .what = the GLOBAL CONFIG half — the `/config` panel's own toggles
#   - `diffSidebarOpen=false` keeps the diff panel shut; `/diff` still opens it
#   - ⚠️ a key here must have NO claude default, or claude's next save drops it
# 🛑 this file holds the OAUTH SESSION, so the write is guarded twice (define.5-3-brains.declared-keys):
#   1. a SKIP — a file that already holds the value is never opened for write
#   2. an ATOMIC RENAME — a tmp beside the target, `mv`d over
####################################################################
_grove_provision_5_3_brains_config_upsert() {
  local patch='{"diffSidebarOpen": false}'
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
  if [[ "$(jq -c '.diffSidebarOpen' "$config" 2>/dev/null)" == "false" ]]; then
    echo "   • claude global config already holds the diff panel shut → $config [KEEP]"
    return 0
  fi

  # 🛑 guard 2 — the tmp lands BESIDE the target, so the `mv` is an atomic
  #   rename; /tmp is a tmpfs here, and a cross-device `mv` is a copy
  local tmp
  tmp="$(mktemp "$config.XXXXXX")" || return 1
  if ! jq --argjson patch "$patch" '. * $patch' "$config" > "$tmp"; then
    echo "   ✋ jq could not merge the patch into $config" >&2
    echo "      ⇒ the file is likely not valid json, so it was left untouched" >&2
    echo "      read why: jq . $config" >&2
    rm -f "$tmp"
    return 1
  fi

  # ⚠️ this patch never shortens a value, so a smaller result means jq dropped
  #   state — and here that costs a human their session
  local was now
  was="$(wc -c < "$config")"
  now="$(wc -c < "$tmp")"
  if [[ "$now" -lt "$was" ]]; then
    echo "   ✋ the merged global config SHRANK — $was bytes in, $now bytes out" >&2
    echo "      ⇒ this patch never shortens a value, so a smaller result means state" >&2
    echo "        was dropped. the write is refused and $config is untouched" >&2
    echo "      read the candidate before you discard it: jq . $tmp" >&2
    return 1
  fi

  if ! mv "$tmp" "$config"; then
    echo "   ✋ could not write the merged global config back to $config" >&2
    rm -f "$tmp"
    return 1
  fi

  echo "   • claude global config merged → $config (diff panel shut at start)"
}

# .why both halves run — a `&&` would hide the second verdict (`rule.forbid.failhide`)
grove_provision_5_3_brains_configure_upsert() {
  local failed=0
  _grove_provision_5_3_brains_settings_upsert || failed=1
  _grove_provision_5_3_brains_config_upsert || failed=1
  return $failed
}
