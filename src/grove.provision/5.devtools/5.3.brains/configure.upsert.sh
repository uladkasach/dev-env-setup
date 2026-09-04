#!/usr/bin/env bash
######################################################################
# .what = silence claude-code's self-update and connector nags
# .ref  = https://code.claude.com/docs/en/setup
# .ref  = howto.silence-claude-cli-nags
#
# .DISABLE_AUTOUPDATER + DISABLE_UPDATES block every self-update path
#   - this repo manages claude through pnpm (this bundle's provision)
#   - ⇒ an in-place self-update would put a version on the box no checkout declares
#   - they also silence the "auto-update failed" startup nag
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
# .permissions.defaultMode=acceptEdits starts every session with file edits
#   applied without a prompt (shift+tab still cycles modes live)
#
# ⚠️ the prompt-suggestion flag belongs in `env`, and the installer nag does not
#   - claude reads it mid-session, well after settings load
#   - the installation checks run at BOOT, before settings are read at all
#   - ⇒ only a real shell export can reach those (see the ⚠️ below)
#   - ⇒ the rule is "match the shelf to WHEN the flag is read"
#   - `2.5.zsh` and this file split the two on that line
#
# ⚠️ the "switched to native installer" nag is NOT gated by settings.json
#   - it needs DISABLE_INSTALLATION_CHECKS exported in the SHELL, which `2.shell` owns
#   - ⇒ a reader who still sees it has the right file and the wrong mechanism
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

grove_provision_5_3_brains_configure_upsert() {
  local patch='{"env": {"DISABLE_AUTOUPDATER": "1", "DISABLE_UPDATES": "1", "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION": "false"}, "disableClaudeAiConnectors": true, "permissions": {"defaultMode": "acceptEdits"}}'
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

  local tmp
  tmp="$(mktemp)" || return 1
  if ! jq --argjson patch "$patch" '. * $patch' "$settings" > "$tmp"; then
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
