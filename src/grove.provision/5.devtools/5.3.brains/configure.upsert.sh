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
# .what = a ROLE HOOK — a hook entry whose `author` begins `repo=`
# .why  = rhachet stamps every hook a role writes with `author: repo=<org>/role=<role>`.
#         such a hook belongs in that repo's own settings; in home it fires in every
#         session on the box, the commander's included. an entry with no author is the
#         commander's own, and is kept
# 🛑 ONE home for the selector, read by the strip, the count, and the verify, so the three
#    cannot disagree on what a role hook is
####################################################################
_GROVE_PROVISION_5_3_BRAINS_ROLE_HOOK='objects | select((.author | type) == "string" and (.author | startswith("repo=")))'

# .what = print one `<author> <count>` line per role that holds a hook in <file>; naught if none
# .why  = the upsert's count and the verify's tree read one census
# guarantee: exits nonzero where jq cannot read <file>, so "none" is never inferred from a failure
_grove_provision_5_3_brains_role_hooks_by_author() {
  jq -r "[.hooks | objects | .[] | arrays | .[] | objects | .hooks | arrays | .[]
    | $_GROVE_PROVISION_5_3_BRAINS_ROLE_HOOK | .author]
    | group_by(.) | map(\"\(.[0]) \(length)\") | .[]" "$1"
}

# .what = 0 if <file> has any write bit (owner, group, or other) · 1 if none · 2 if its mode
#         cannot be read
# .why  = THREE values, never a boolean: a `stat` that fails must not read as "no write bit",
#         or the skip would keep a file it never saw and the verify would print ✔ on it
_grove_provision_5_3_brains_is_writable() {
  local mode
  mode="$(stat -c '%a' "$1")" || return 2
  (( 8#$mode & 8#222 )) && return 0
  return 1
}

####################################################################
# .what = remove <tmp> if the run is interrupted before the swap, then exit as signalled
# .why  = an interrupt must leave the original untouched AND no candidate beside it.
#         the swap clears the guard, since after the rename there is no tmp to remove
####################################################################
_GROVE_PROVISION_5_3_BRAINS_TMP=""
_grove_provision_5_3_brains_tmp_guard() {
  _GROVE_PROVISION_5_3_BRAINS_TMP="$1"
  trap '_grove_provision_5_3_brains_tmp_abort 130' INT
  trap '_grove_provision_5_3_brains_tmp_abort 143' TERM
  trap '_grove_provision_5_3_brains_tmp_abort 129' HUP
}
# .what = the trap's body: remove the candidate, say so, exit with the signal's code
_grove_provision_5_3_brains_tmp_abort() {
  rm -f -- "$_GROVE_PROVISION_5_3_BRAINS_TMP"
  echo "   ✋ interrupted before the swap — the settings file is untouched, the candidate removed" >&2
  echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
  exit "$1"
}
# .note = it removes the guarded path too — after a swap that path is already gone,
#         so one call serves every exit, failed or not
_grove_provision_5_3_brains_tmp_unguard() {
  [[ -n "$_GROVE_PROVISION_5_3_BRAINS_TMP" ]] && rm -f -- "$_GROVE_PROVISION_5_3_BRAINS_TMP"
  _GROVE_PROVISION_5_3_BRAINS_TMP=""
  trap - INT TERM HUP
}

####################################################################
# .what = lock a FILLED tmp and rename it over <target> — the owner's one write path
# .why  = a rename needs the DIR writable, never the file, so the live file is never
#         writable, not for an instant. the tmp lies beside <target>, so the `mv` is an
#         atomic rename (a /tmp tmpfs would make it a cross-device copy)
# guarantee: on any failure the tmp is removed and <target> is untouched
####################################################################
_grove_provision_5_3_brains_settings_swap() {
  local tmp="$1" target="$2"
  if ! chmod 0444 "$tmp"; then
    echo "   ✋ could not lock the candidate $tmp, so $target was left untouched" >&2
    _grove_provision_5_3_brains_tmp_unguard; return 1
  fi
  if ! mv -f "$tmp" "$target"; then
    echo "   ✋ could not rename the locked candidate over $target" >&2
    echo "      ⇒ a rename needs the dir writable: $(dirname "$target")" >&2
    _grove_provision_5_3_brains_tmp_unguard; return 1
  fi
  _grove_provision_5_3_brains_tmp_unguard
}

####################################################################
# .what = the BOOT GATE — after the lock, a real init must leave home byte-equal
# .why  = the measured home writer is a sprout's install step, `npm run prepare:rhachet`.
#         if a lock makes that init HALT, every sprout breaks, which is worse than the leak.
#         so the gate runs the same command in this checkout, through its own arrow
# outcomes:
#   - completes, home byte-equal       → the lock holds
#   - halts on EACCES                  → restore the write bit, keep the strip, halt
#   - home CHANGED                     → a writer renamed past 0444 (F1); halt
#   - halts on aught else              → the gate proves naught; the lock is kept; halt
#   - no checkout, no arrow to home    → 🌙 the gate has no subject; the lock is kept
####################################################################
_grove_provision_5_3_brains_settings_boot_gate() {
  local settings="$1" root before after out code

  # 🛑 the checkout is the parent of the src this run executes (`GROVE_SRC`, which the driver
  #    always exports), never `git rev-parse` — a grove's checkout is PUSHED, carries no .git,
  #    and git answers naught there (defect shape 8)
  root="${GROVE_SRC:+$(dirname "$GROVE_SRC")}"
  if [[ -z "$root" || ! -x "$root/node_modules/.bin/rhachet" ]]; then
    echo "   🌙 boot gate: no rhachet checkout beside this run, so no init to prove the lock against"
    return 0
  fi
  if [[ "$(readlink -f "$root/.claude/settings.json")" != "$settings" ]]; then
    echo "   🌙 boot gate: $root/.claude/settings.json is no arrow to $settings, so an init there never meets the lock"
    return 0
  fi

  before="$(sha256sum < "$settings")"
  out="$(cd "$root" && timeout -k 10 300 npm run --silent prepare:rhachet </dev/null 2>&1)"
  code=$?
  after="$(sha256sum < "$settings")"

  if [[ "$before" != "$after" ]]; then
    echo "   ✋ boot gate: the init CHANGED $settings past its 0444 lock" >&2
    echo "      ⇒ a writer renamed over it, which 0444 cannot stop (F1: lock by mode, not chattr +i)" >&2
    echo "      ⇒ the backup beside it holds the file as it was before this apply" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply, then carry this up" >&2
    return 1
  fi

  if (( code == 0 )); then
    echo "   • boot gate: npm run prepare:rhachet completed, home byte-equal → the lock holds"
    return 0
  fi

  if [[ "$out" == *EACCES* ]]; then
    chmod u+w "$settings" || echo "   ✋ could not restore the write bit on $settings" >&2
    echo "   ✋ boot gate: the lock HALTS rhachet init — it waits for the pair tree" >&2
    echo "      ⇒ the strip stays; the write bit is restored, so no sprout breaks" >&2
    echo "      ⇒ the init's last words:" >&2
    printf '%s\n' "$out" | tail -n 12 | sed 's/^/         /' >&2
    echo "      fix: ship the pair (rhachet.beav.fix-enroll-never-writes-home-scope), then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  echo "   ✋ boot gate: npm run prepare:rhachet failed (exit $code) for a reason other than the lock" >&2
  echo "      ⇒ the lock is kept, but the gate proves naught until the init runs clean" >&2
  printf '%s\n' "$out" | tail -n 12 | sed 's/^/         /' >&2
  echo "      fix: repair the init in $root, then rhx grove.provision --what 5.3.brains --mode apply" >&2
  return 1
}

####################################################################
# .what = the SETTINGS half — `~/.claude/settings.json`
# ⚠️ an ENROLLED claude reads rhachet's role file instead (define.5-3-brains.declared-keys)
#
# 🛑 .the file is LOCKED — mode 0444 — and this half is its one writer
#   - every tree's `.claude/settings.json` is an arrow (two hops) to this file, so a
#     tree's init that writes "its" settings writes HOME, and its hooks then fire in
#     every repo. measured: a sprout's install step (a pre-shield `rhachet init --hooks`)
#   - 0444 makes an `open` for write fail with EACCES. it does NOT stop a `rename`, which
#     needs only the dir — and a rename is how this half writes (`..._settings_swap`)
#   - ⚠️ 0444 stops an open-writer only. a writer that renames past it is caught by the
#     verify, and undone by the next apply
#
# 🛑 .every role-authored hook is STRIPPED (`_GROVE_PROVISION_5_3_BRAINS_ROLE_HOOK`)
#   - every other key — env, model, permissions, statusLine, an unauthored hook — stays
#
# guarantee:
#   - a byte copy beside the file BEFORE any write; a failed copy halts the half
#   - a file that already holds the patch, no role hook, and no write bit is never opened
#   - the boot gate runs after every swap (`..._settings_boot_gate`)
####################################################################
_grove_provision_5_3_brains_settings_upsert() {
  local patch='{"env": {"DISABLE_AUTOUPDATER": "1", "DISABLE_INSTALLATION_CHECKS": "1", "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION": "false", "CLAUDE_CODE_DISABLE_COMMAND_INJECTION_CHECK": "1", "CLAUDE_CODE_ENABLE_TODO_TOOLS": "1", "ANTHROPIC_MODEL": "claude-opus-5-5[1m]", "CLAUDE_CODE_SUBAGENT_MODEL": "claude-sonnet-5-5[1m]", "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50", "CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS": "450000"}, "disableClaudeAiConnectors": true, "permissions": {"defaultMode": "auto"}, "model": "claude-opus-5-5[1m]", "effortLevel": "medium", "cleanupPeriodDays": 36500, "skipAutoPermissionPrompt": true, "tui": "fullscreen", "verbose": false, "feedbackDrafts": "off"}'
  local settings="$HOME/.claude/settings.json" tmp

  if ! mkdir -p "$HOME/.claude"; then
    echo "   ✋ could not create $HOME/.claude" >&2
    return 1
  fi

  # 🛑 a rename over a SYMLINK replaces the link and leaves its target writable,
  #    so the half writes the file the path resolves to
  [[ -L "$settings" ]] && settings="$(readlink -f "$settings")"

  ####################################################################
  # .no extant file, so the patch is written whole — locked, by rename
  ####################################################################
  if [[ ! -f "$settings" ]]; then
    tmp="$(mktemp "$settings.XXXXXX")" || return 1
    _grove_provision_5_3_brains_tmp_guard "$tmp"
    if ! printf '%s\n' "$patch" > "$tmp"; then
      echo "   ✋ could not write $tmp" >&2
      _grove_provision_5_3_brains_tmp_unguard; return 1
    fi
    _grove_provision_5_3_brains_settings_swap "$tmp" "$settings" || return 1
    echo "   • claude settings declared → $settings (0444, swapped in by rename)"
    _grove_provision_5_3_brains_settings_boot_gate "$settings"
    return
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
  #   - 🛑 a `modelSettings.<model>.effortLevel` SHADOWS the declared `effortLevel`
  #     - the cli writes one when a human picks an effort per model, and it wins over the top level
  #     - a deep merge keeps it, so the declared default never reaches that model
  #     - ⇒ the strip removes the effort key alone; an entry it empties is dropped
  ####################################################################
  local reap='del(.env.DISABLE_UPDATES, .env.CLAUDE_CODE_SKIP_UPDATE_CHECK)
    | if (.permissions.deny | type) == "array"
      then .permissions.deny -= ["Agent"]
        | if .permissions.deny == [] then del(.permissions.deny) else . end
      else . end
    | if (.modelSettings | type) == "object"
      then .modelSettings |= with_entries(
          .value |= (if type == "object" then del(.effortLevel) else . end)
          | select(.value != {}))
        | if .modelSettings == {} then del(.modelSettings) else . end
      else . end'

  ####################################################################
  # .the STRIP — drop each role hook, then any matcher block it emptied, then any
  #   event left with no block, then `hooks` itself if empty
  ####################################################################
  local strip="if (.hooks | type) == \"object\"
    then .hooks |= with_entries(
        .value |= (if type == \"array\"
          then map(if (type == \"object\") and ((.hooks | type) == \"array\")
              then .hooks |= map(select([ $_GROVE_PROVISION_5_3_BRAINS_ROLE_HOOK ] == []))
              else . end)
            | map(select((type != \"object\") or ((.hooks | type) != \"array\") or (.hooks != [])))
          else . end)
        | select(.value != []))
      | if .hooks == {} then del(.hooks) else . end
    else . end"
  local converge="$reap | $strip | . * \$patch"

  ####################################################################
  # .the SKIP — a file that already holds the converged content and no write bit is
  #   never opened for write: no backup, no tmp (the guard the global config half uses)
  ####################################################################
  local converged
  if ! converged="$(jq --argjson patch "$patch" "(. as \$was | ($converge) == \$was)" "$settings")"; then
    echo "   ✋ jq could not read $settings" >&2
    echo "      ⇒ the file is likely not valid json, so it was left untouched" >&2
    echo "      read why: jq . $settings" >&2
    return 1
  fi
  # only a read-back "no write bit" (1) may skip; writable (0) and unread (2) both go on to the
  # write, which re-locks the file
  local lock_rc
  _grove_provision_5_3_brains_is_writable "$settings"; lock_rc=$?
  if [[ "$converged" == "true" && "$lock_rc" == 1 ]]; then
    echo "   • claude settings already hold the patch, no role hook, and no write bit → $settings [KEEP]"
    return 0
  fi

  ####################################################################
  # .the BACKUP — a byte copy beside the file, BEFORE any write. a failed copy halts
  ####################################################################
  local backup roles
  backup="$(dirname "$settings")/settings.$(date -u +%Y-%m-%dT%H-%M-%SZ).$$.bak.json"
  if ! cp -p "$settings" "$backup"; then
    echo "   ✋ could not back up $settings → $backup" >&2
    echo "      ⇒ no copy, no write: the file was left untouched" >&2
    echo "      fix: free space or permissions in $(dirname "$settings"), then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  echo "   • backup → $backup"
  roles="$(_grove_provision_5_3_brains_role_hooks_by_author "$settings" | awk '{n += $2} END {print n + 0}')"

  ####################################################################
  # .the MERGE — into a tmp beside the file, then locked and swapped in
  ####################################################################
  tmp="$(mktemp "$settings.XXXXXX")" || return 1
  _grove_provision_5_3_brains_tmp_guard "$tmp"
  if ! jq --argjson patch "$patch" "$converge" "$settings" > "$tmp"; then
    echo "   ✋ jq could not merge the patch into $settings" >&2
    echo "      ⇒ the file is likely not valid json, so it was left untouched" >&2
    echo "      read why: jq . $settings" >&2
    _grove_provision_5_3_brains_tmp_unguard
    return 1
  fi
  _grove_provision_5_3_brains_settings_swap "$tmp" "$settings" || return 1

  echo "   • role hooks stripped → $roles removed; every unauthored hook kept"
  echo "   • claude settings merged → $settings (0444, swapped in by rename)"
  _grove_provision_5_3_brains_settings_boot_gate "$settings"
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

####################################################################
# .what = the KEYBINDINGS half — `~/.claude/keybindings.json`
#
# .why ctrl+enter is the one send-now key, in every window (`rule.require.ctrl-enter-sends-now`)
#   - claude binds `chat:sendNow` to BOTH ctrl+enter and `ctrl+x ctrl+s`, and its hint picks the
#     chord whenever $TMUX is set. on this repo's kitty the chord cannot even be typed: kitty
#     maps ctrl+x to ^C, so the hint advertises a key that interrupts instead
#   - unbind the chord, and ctrl+enter is the one key left bound — so the hint names it in tmux too
#   - the key itself reaches claude through tmux via the kitty map + tmux marker (4.3.2.emulator,
#     2.8.tmux); this half fixes only what the hint SAYS
#
# ⚠️ merged, never overwritten — a human may hold their own keymaps here. the one entry is
#   upserted into the `Chat` block; every other block and key is left as found
# ⚠️ an ENROLLED clone reads `$CLAUDE_CONFIG_DIR/keybindings.json` (the actor dir), not this
#   file, until rhachet links it there the way it links `.credentials.json` (ehmpathy/rhachet#579)
####################################################################
_grove_provision_5_3_brains_keybindings_upsert() {
  local file="$HOME/.claude/keybindings.json" tmp
  local add='{"ctrl+x ctrl+s": null}'
  mkdir -p "$HOME/.claude" || { echo "   ✋ could not create $HOME/.claude" >&2; return 1; }
  [[ -f "$file" ]] || echo '{"bindings": []}' > "$file" || {
    echo "   ✋ could not write $file" >&2; return 1; }
  command -v jq >/dev/null 2>&1 || {
    echo "   ✋ jq is absent, so $file cannot be merged — refused rather than overwrite" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  }
  # 🛑 the same two guards the global config half holds: the tmp lands BESIDE the target, so the
  #    `mv` is an atomic rename; and a file that already holds the unbind is never rewritten
  tmp="$(mktemp "$file.XXXXXX")" || return 1
  if ! jq --argjson add "$add" '
      .bindings = ((.bindings // []) as $b
        | if any($b[]; .context == "Chat")
          then [ $b[] | if .context == "Chat" then .bindings = ((.bindings // {}) + $add) else . end ]
          else $b + [ {context: "Chat", bindings: $add} ]
          end)' "$file" > "$tmp"; then
    echo "   ✋ jq could not merge into $file — not valid json, left untouched" >&2
    rm -f "$tmp"; return 1
  fi
  if [[ "$(jq -S . "$tmp")" == "$(jq -S . "$file")" ]]; then
    rm -f "$tmp"
    echo "   • claude keybindings already unbind the ctrl+x ctrl+s chord → $file [KEEP]"
    return 0
  fi
  mv "$tmp" "$file" || { echo "   ✋ could not write $file" >&2; rm -f "$tmp"; return 1; }
  echo "   • claude keybindings merged → $file (ctrl+enter is the one send-now key)"
}

# .why every half runs — a `&&` would hide the later verdicts (`rule.forbid.failhide`)
grove_provision_5_3_brains_configure_upsert() {
  local failed=0
  _grove_provision_5_3_brains_settings_upsert || failed=1
  _grove_provision_5_3_brains_config_upsert || failed=1
  _grove_provision_5_3_brains_keybindings_upsert || failed=1
  return $failed
}
