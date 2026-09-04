#!/usr/bin/env bash
######################################################################
# .what = prove each declared key is LIVE in ~/.claude/settings.json
#
# .it reads each key back with jq, and never greps the file
#   - the write is a deep MERGE
#   - ⇒ a key can be present in the file and still hold the wrong value
#   - a human's own edit does that, as does an older patch
#   - a grep for the key NAME would report ✔ on either
#   - ⇒ `jq` reads the VALUE, the only fact that changes what claude does
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
    '.env.DISABLE_UPDATES:"1":every self-update path' \
    '.env.CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION:"false":the prompt suggestion' \
    '.disableClaudeAiConnectors:true:the claude.ai connector fetch'; do
    path="${pair%%:*}"
    want="${pair#*:}"; want="${want%%:*}"
    live="$(jq -c "$path" "$settings" 2>/dev/null)"

    if [[ "$live" == "$want" ]]; then
      echo "   • ${pair##*:} is off ✔"
    else
      echo "   ✋ ${pair##*:} is NOT off — $path reads ${live:-absent}, want $want" >&2
      echo "      ⇒ a merged file can hold the key at the wrong value, so its" >&2
      echo "        presence alone proves neither the patch nor its effect" >&2
      echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
      failed=1
    fi
  done

  return $failed
}
