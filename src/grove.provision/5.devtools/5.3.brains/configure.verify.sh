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
#   - ⇒ ONE reader, declared in this bundle's `_.sh`, asked by both halves,
#     so the upsert and the verify cannot read the same box two ways (`define.cry-wolf-measurements`, m.9)
#
# ⚠️ .each claim reads the file at its own moment: a write between two claims makes each true of
#   the instant it read, as a write a second after the plan would. the plan is a survey, and the
#   next one re-reads; the converge, which acts on what it reads, reads ONE backup copy
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state (clamp arm 17h: a hooked, writable home with
#     every claim off is left byte-equal, all three files at their modes)
######################################################################

####################################################################
# .what = the readers this verify asks — declared once, in this bundle's `_.sh`
# .why  = the entrypoint sources `_.sh` with every phase, so they are present on every run. a
#         verify sourced ALONE (a play, a probe) sources that `_.sh` rather than guess a path or
#         skip a claim. absent even so, the verify refuses whole, never a claim at a time
# .note = every reader is named, so a `_.sh` that failed partway cannot pass on the one name it
#         defined first; a missed reader would surface as `command not found`, misnamed as a jq read
####################################################################
_grove_provision_5_3_brains_verify_readers_present() {
  declare -F \
    _grove_provision_5_3_brains_settings_path \
    _grove_provision_5_3_brains_arrow_target \
    _grove_provision_5_3_brains_file_mode \
    _grove_provision_5_3_brains_lock_declared \
    _grove_provision_5_3_brains_mode_declared \
    _grove_provision_5_3_brains_lock_of_mode \
    _grove_provision_5_3_brains_role_hooks_by_author \
    _grove_provision_5_3_brains_foreign_hooks_by_author \
    _grove_provision_5_3_brains_census_total \
    _grove_provision_5_3_brains_census_tree \
    _grove_provision_5_3_brains_config_path \
    _grove_provision_5_3_brains_config_diff_panel \
    _grove_provision_5_3_brains_keybindings_chord >/dev/null 2>&1
}

if ! _grove_provision_5_3_brains_verify_readers_present; then
  _GROVE_PROVISION_5_3_BRAINS_SHARED="$(dirname "${BASH_SOURCE[0]}")/_.sh"
  [[ -r "$_GROVE_PROVISION_5_3_BRAINS_SHARED" ]] && source "$_GROVE_PROVISION_5_3_BRAINS_SHARED"
fi

####################################################################
# .what = print why <path> cannot be read: `absent`, an arrow that cannot be resolved or that
#         points at naught, or `unreadable`
# .why  = `-r` is false for all of them alike, and each wants a different repair — a verdict
#         that names one cause for all sends a human to mend the wrong file
####################################################################
_grove_provision_5_3_brains_unread_cause() {
  [[ -L "$1" ]] && ! _grove_provision_5_3_brains_arrow_target "$1" >/dev/null && { echo "an arrow that cannot be resolved"; return 0; }
  [[ -L "$1" && ! -e "$1" ]] && { echo "an arrow to a file that is absent"; return 0; }
  [[ -e "$1" ]] && { echo unreadable; return 0; }
  echo absent
}

# .what = print the remedy lines for an unread <path>: an arrow is repaired by hand before an apply
#         can reach it; any other cause is the apply's to write
_grove_provision_5_3_brains_unread_fix() {
  if [[ -L "$1" ]]; then
    echo "      read why: readlink -f $1"
    echo "      fix: repair or remove that arrow, then rhx grove.provision --what 5.3.brains --mode apply"
    return 0
  fi
  echo "      fix: rhx grove.provision --what 5.3.brains --mode apply"
}

####################################################################
# .what = the LOCK claims — zero role hooks, no foreign-author hook, and the declared lock
# .why  = a role hook fires in every session on the box; a writable file lets any tree's init
#         write it through its arrow, and a locked one breaks a pre-shield install. the readers
#         and the declaration live in `_.sh`, shared with the upsert, so the two cannot disagree
# guarantee: every claim it cannot observe is a ✋, never a ✔
####################################################################
_grove_provision_5_3_brains_lock_verify() {
  local settings="$HOME/.claude/settings.json" real mode lock want wantmode failed=0
  if ! real="$(_grove_provision_5_3_brains_settings_path)"; then
    echo "   ✋ $settings is an arrow that could not be resolved, so the strip and the lock are unproven" >&2
    echo "      read why: readlink -f $settings" >&2
    echo "      fix: repair or remove that arrow, then rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  if [[ ! -r "$real" ]]; then
    echo "   ✋ $real is $(_grove_provision_5_3_brains_unread_cause "$real"), so the strip and the lock are unproven" >&2
    _grove_provision_5_3_brains_unread_fix "$real" >&2
    return 1
  fi

  _grove_provision_5_3_brains_role_hooks_verify "$real" || failed=1
  _grove_provision_5_3_brains_foreign_hooks_verify "$real" || failed=1

  # the mode is read ONCE, and the verdict renders the value it read
  if ! mode="$(_grove_provision_5_3_brains_file_mode "$real")"; then
    echo "   ✋ the mode of $real could not be observed, so the lock is unproven" >&2
    echo "      ⇒ this is a read that failed, not a box in a known state — an apply cannot clear it" >&2
    echo "      read why: stat -c '%a' $real   (each dir above it must grant this user search)" >&2
    return 1
  fi
  # the lock is judged against the DECLARATION in `_.sh`, which the upsert's swap also reads; each
  # read is guarded, so a failed one is named and never compared as an empty value
  if ! want="$(_grove_provision_5_3_brains_lock_declared)" || ! wantmode="$(_grove_provision_5_3_brains_mode_declared)"; then
    echo "   ✋ the lock declaration reads '$_GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK', neither on nor off, so the lock is unjudged" >&2
    echo "      fix: set _GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK to on or off in 5.3.brains/_.sh, then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  if ! lock="$(_grove_provision_5_3_brains_lock_of_mode "$mode")"; then
    echo "   ✋ the mode of $real reads '$mode', which is not an octal mode, so the lock is unjudged" >&2
    echo "      read why: stat -c '%a' $real" >&2
    return 1
  fi
  _grove_provision_5_3_brains_lock_judge "$real" "$mode" "$lock" "$want" "$wantmode" || failed=1
  return $failed
}

####################################################################
# .what = judge the read <mode> of <real> against the declaration, and print the one verdict
# .why  = the claim is the EXACT declared mode: a write bit alone is not the declaration, since a
#         wider mode lets other users read the commander's `env`. one branch per case, in order
####################################################################
_grove_provision_5_3_brains_lock_judge() {
  local real="$1" mode="$2" lock="$3" want="$4" wantmode="$5"

  # the declared mode, locked → the lock holds
  if [[ "$mode" == "$wantmode" && "$lock" == locked ]]; then
    echo "   • $real is read-only (mode $mode) ✔"
    return 0
  fi
  # the declared mode under `off`: met, but the lock the wish asked for is not — a 🌙, never a ✔,
  # so the debt stays on the page of a clean plan (exit stays 0 — the declaration holds)
  if [[ "$mode" == "$wantmode" ]]; then
    echo "   🌙 $real keeps its write bit (mode $mode), as declared off — the lock is owed, and waits for the pre-shield pins"
    return 0
  fi
  # declared on, found writable
  if [[ "$lock" == writable && "$want" == locked ]]; then
    echo "   ✋ $real is writable (mode $mode), so any tree's init can write it" >&2
    echo "      ⇒ every tree's .claude/settings.json is an arrow to this file" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  # declared off, found locked
  if [[ "$lock" == locked && "$want" == writable ]]; then
    echo "   ✋ $real is read-only (mode $mode), but the lock is declared off" >&2
    echo "      ⇒ a repo pinned below the shielded rhachet fails its install against it" >&2
    echo "      fix: either rhx grove.provision --what 5.3.brains --mode apply   (sets mode $wantmode; the lock lifts)" >&2
    echo "           or set _GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK=on in 5.3.brains/_.sh, then apply (keeps the lock)" >&2
    return 1
  fi
  # the right side of the lock, at a mode other than declared — name the bit that differs: a
  # group or other read bit exposes the commander's `env`; any other bit is a drift, not a leak
  if (( 8#$mode & 8#044 )); then
    echo "   ✋ $real is mode $mode, but the declaration is mode $wantmode — other users may read its env" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  echo "   ✋ $real is mode $mode, but the declaration is mode $wantmode — no other user may read it, yet its bits drift from the declaration" >&2
  echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
  return 1
}

# .what = the ROLE HOOK claim — <real> holds no hook a role authored
_grove_provision_5_3_brains_role_hooks_verify() {
  local real="$1" roles total
  if ! roles="$(_grove_provision_5_3_brains_role_hooks_by_author "$real")"; then
    echo "   ✋ jq could not read $real, so its role hooks are uncounted" >&2
    echo "      read why: jq . $real" >&2
    return 1
  fi
  if [[ -z "$roles" ]]; then
    echo "   • no role-authored hook in $real ✔"
    return 0
  fi
  if ! total="$(_grove_provision_5_3_brains_census_total <<< "$roles")"; then
    echo "   ✋ $real holds role-authored hooks, and the census could not total them" >&2
    echo "      ⇒ the census totals with awk, so awk is absent or failed on this box" >&2
    echo "      read why: command -v awk" >&2
    return 1
  fi
  echo "   ✋ $real holds $total role-authored hooks, which fire in every repo" >&2
  _grove_provision_5_3_brains_census_tree <<< "$roles" >&2
  echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
  return 1
}

# .what = the FOREIGN HOOK claim — a hook stamped in a shape this repo cannot judge is never
#         stripped, so a human must
# .why  = a ✋, never a 🌙: a change to rhachet's stamp shape (a structured author, say) would put
#         every role hook here, and a 🌙 would read that box as clean. a human's own hook carries no
#         `author` key, so it never lands in this census
_grove_provision_5_3_brains_foreign_hooks_verify() {
  local real="$1" foreign total
  if ! foreign="$(_grove_provision_5_3_brains_foreign_hooks_by_author "$real")"; then
    echo "   ✋ jq could not read $real, so its foreign-author hooks are uncounted" >&2
    echo "      read why: jq . $real" >&2
    return 1
  fi
  # no foreign author → no verdict to print
  if [[ -z "$foreign" ]]; then
    return 0
  fi
  if ! total="$(_grove_provision_5_3_brains_census_total <<< "$foreign")"; then
    echo "   ✋ $real holds hooks by an author outside \`repo=…\`, and the census could not total them" >&2
    echo "      ⇒ the census totals with awk, so awk is absent or failed on this box" >&2
    echo "      read why: command -v awk" >&2
    return 1
  fi
  echo "   ✋ $real holds $total hooks by an author outside \`repo=…\`, which the strip cannot judge" >&2
  _grove_provision_5_3_brains_census_tree <<< "$foreign" >&2
  echo "      ⇒ each fires in every session on this box, as a role hook would" >&2
  echo "      fix: judge each author — a role's belongs in its repo, so widen" >&2
  echo "           _GROVE_PROVISION_5_3_BRAINS_ROLE_HOOK to it; a human's own, drop its \`author\`" >&2
  return 1
}

####################################################################
# .what = the KEYBINDINGS claim — `ctrl+x ctrl+s` is UNBOUND in every Chat block that names it
# .why  = then ctrl+enter is the one send-now key claude has, and its hint names ctrl+enter
#         even inside tmux (`rule.require.ctrl-enter-sends-now`). an explicit `null` is the
#         unbind; a key merely ABSENT leaves claude's default chord bound, so absent is a ✋
####################################################################
_grove_provision_5_3_brains_keybindings_verify() {
  local keys="$HOME/.claude/keybindings.json" chord
  if [[ ! -r "$keys" ]]; then
    echo "   ✋ the claude keybindings at $keys are $(_grove_provision_5_3_brains_unread_cause "$keys"), so the ctrl+x ctrl+s chord keeps claude's default bind" >&2
    _grove_provision_5_3_brains_unread_fix "$keys" >&2
    return 1
  fi
  if ! chord="$(_grove_provision_5_3_brains_keybindings_chord "$keys")"; then
    echo "   ✋ jq could not read $keys, so the ctrl+x ctrl+s unbind is unproven" >&2
    echo "      read why: jq . $keys" >&2
    echo "      fix: repair the json by hand, then rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  if [[ "$chord" == unbound ]]; then
    echo "   • ctrl+enter is the one send-now key (the ctrl+x ctrl+s chord is unbound) ✔"
    # the gap is named where the human reads the ✔, never buried in a brief: the cure is upstream
    echo "      ⇒ a bare session reads this file; an ENROLLED clone reads its actor dir's copy until"
    echo "        rhachet links it there (ehmpathy/rhachet#579), so an enrolled hint may still name the chord"
    return 0
  fi
  if [[ "$chord" == misshapen ]]; then
    echo "   ✋ $keys holds no .bindings list, so the ctrl+x ctrl+s unbind cannot be judged" >&2
    echo "      ⇒ the apply refuses to merge into that shape rather than drop your own keymaps" >&2
    echo "      read why: jq .bindings $keys" >&2
    echo "      fix: repair it by hand so .bindings is a list, then rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  echo "   ✋ the ctrl+x ctrl+s chord is still bound to send-now in $keys" >&2
  echo "      ⇒ inside tmux claude's hint names that chord, and kitty maps ctrl+x to ^C," >&2
  echo "        so the hint advertises a key that interrupts the turn instead" >&2
  echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
  return 1
}

####################################################################
# .what = the GLOBAL CONFIG claim — `~/.claude.json`, the `/config` panel's toggles
#
# ⚠️ this is a SECOND FILE, not a second key in the settings. claude reads `diffSidebarOpen`
#   straight off the global config, never through settings — so a check aimed at
#   `settings.json` would go green on an inert declaration
####################################################################
_grove_provision_5_3_brains_config_verify() {
  local config panel
  if ! config="$(_grove_provision_5_3_brains_config_path)"; then
    echo "   ✋ the claude global config is an arrow that could not be resolved, so the diff panel shut-at-start is unproven" >&2
    echo "      read why: readlink -f $HOME/.claude.json $HOME/.claude/.config.json" >&2
    echo "      fix: repair that arrow, then rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  if [[ ! -r "$config" ]]; then
    echo "   ✋ the claude global config at $config is $(_grove_provision_5_3_brains_unread_cause "$config")" >&2
    echo "      ⇒ so the diff panel will auto-open on any wide terminal" >&2
    _grove_provision_5_3_brains_unread_fix "$config" >&2
    return 1
  fi
  if ! panel="$(_grove_provision_5_3_brains_config_diff_panel "$config")"; then
    echo "   ✋ jq could not read $config, so the diff panel shut-at-start is unproven" >&2
    echo "      read why: jq . $config   (then jq -c .diffSidebarOpen $config, which fails where the top is not an object)" >&2
    echo "      fix: repair the json by hand, then rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  if [[ "$panel" == shut ]]; then
    echo "   • the diff panel shut-at-start holds the declared value ✔"
    return 0
  fi
  echo "   ✋ the diff panel is NOT held shut — .diffSidebarOpen reads $(_grove_provision_5_3_brains_settings_value "$config" .diffSidebarOpen) (null = absent), want false" >&2
  echo "      ⇒ absent or true, the fullscreen tui opens the diff panel on its own" >&2
  echo "        whenever the terminal is wide enough" >&2
  echo "      ⇒ a /diff toggle writes this key, so one open flips it to true;" >&2
  echo "        the next apply shuts it again" >&2
  echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
  return 1
}

####################################################################
# .what = print the declared SETTINGS claims, one per line: `<jq path> TAB <want> TAB <label>`
# .why  = a tab never occurs in a path, a value, or a label, so `read` splits each record by
#         name — no colon-packed string for a reader to decode
####################################################################
_grove_provision_5_3_brains_settings_claims() {
  printf '%s\t%s\t%s\n' \
    '.env.DISABLE_AUTOUPDATER' '"1"' 'the auto-updater' \
    '.env.DISABLE_INSTALLATION_CHECKS' '"1"' 'the native-installer migration nag' \
    '.env.CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION' '"false"' 'the prompt suggestion' \
    '.env.CLAUDE_CODE_DISABLE_COMMAND_INJECTION_CHECK' '"1"' 'the command injection check' \
    '.env.CLAUDE_CODE_ENABLE_TODO_TOOLS' '"1"' 'the todo and task tools' \
    '.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE' '"50"' 'the auto-compact threshold' \
    '.env.CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS' '"450000"' 'the idle-compaction floor' \
    '.disableClaudeAiConnectors' 'true' 'the claude.ai connector fetch' \
    '.permissions.defaultMode' '"auto"' 'the auto default mode' \
    '(.permissions.deny // []) | index("Agent")' 'null' 'the subagent tool, never denied' \
    '.model' '"claude-opus-5-5[1m]"' 'the default model' \
    '.env.ANTHROPIC_MODEL' '"claude-opus-5-5[1m]"' 'the default model env override' \
    '.env.CLAUDE_CODE_SUBAGENT_MODEL' '"claude-sonnet-5-5[1m]"' 'the subagent model' \
    '.effortLevel' '"medium"' 'the default effort level' \
    '[.modelSettings[]?.effortLevel | select(. != null)] | length' '0' 'the default effort, unshadowed by a per-model override' \
    '.skipAutoPermissionPrompt' 'true' 'the auto-permission prompt skip' \
    '.tui' '"fullscreen"' 'the fullscreen tui' \
    '.verbose' 'false' 'the verbose output default' \
    '.feedbackDrafts' '"off"' 'the claude-drafted feedback queue' \
    '.cleanupPeriodDays' '36500' 'the never-prune transcript retention'
}

# .what = print the compact json value <path> reads from the settings <file>
# guarantee: exits nonzero where jq cannot read <file> or <path> errors on its shape
_grove_provision_5_3_brains_settings_value() {
  local file="$1" path="$2"
  jq -c "$path" "$file"
}

####################################################################
# .what = the SETTINGS VALUE claims — each declared key, read back from <settings>
# 🛑 an unreadable file fails its value claims; the caller still runs every other claim, so one
#    verify run names every claim that is off, never only the first
####################################################################
_grove_provision_5_3_brains_settings_values_verify() {
  local settings="$1" claims path want label live failed=0
  if [[ ! -r "$settings" ]]; then
    echo "   ✋ the claude settings at $settings are $(_grove_provision_5_3_brains_unread_cause "$settings")" >&2
    echo "      ⇒ claude self-updates to a version no checkout declares, and" >&2
    echo "        nags about connectors on every start" >&2
    _grove_provision_5_3_brains_unread_fix "$settings" >&2
    return 1
  fi
  # the claims are read first and guarded, so a list that failed can never read as zero claims
  if ! claims="$(_grove_provision_5_3_brains_settings_claims)" || [[ -z "$claims" ]]; then
    echo "   ✋ the declared settings claims could not be listed, so no value is proven" >&2
    echo "      ⇒ the list is _grove_provision_5_3_brains_settings_claims in configure.verify.sh, so an edit broke it" >&2
    echo "      fix: restore that function from git, then rhx grove.provision --what 5.3.brains --mode plan" >&2
    return 1
  fi

  while IFS=$'\t' read -r path want label; do
    # a read that FAILS is named as one, never reported as the value `absent`
    if ! live="$(_grove_provision_5_3_brains_settings_value "$settings" "$path")"; then
      echo "   ✋ $label is unproven — jq could not read $path from $settings" >&2
      echo "      read why: jq -c '$path' $settings" >&2
      echo "      fix: repair the json by hand, then rhx grove.provision --what 5.3.brains --mode apply" >&2
      failed=1; continue
    fi
    if [[ "$live" == "$want" ]]; then
      echo "   • $label holds the declared value ✔"
      continue
    fi
    echo "   ✋ $label is NOT declared — $path reads $live, want $want" >&2
    echo "      ⇒ a merged file can hold the key at the wrong value, so its" >&2
    echo "        presence alone proves neither the patch nor its effect" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    failed=1
  done <<< "$claims"
  return $failed
}

grove_provision_5_3_brains_configure_verify() {
  if ! _grove_provision_5_3_brains_verify_readers_present; then
    echo "   ✋ the 5.3.brains readers are absent from this run (the bundle's _.sh did not source)" >&2
    echo "      ⇒ the strip, the lock, and the global config path are unproven" >&2
    echo "      ⇒ the bundle driver sources _.sh beside this file, so run it through the driver" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "   ✋ jq is absent, so the settings values, the strip, and the lock are unproven" >&2
    echo "      ⇒ this bundle's provision phase installs jq, so it did not run or could not reach root" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  # every claim runs — a `&&` would hide the later verdicts (`rule.forbid.failhide`)
  local failed=0
  _grove_provision_5_3_brains_settings_values_verify "$HOME/.claude/settings.json" || failed=1
  _grove_provision_5_3_brains_lock_verify || failed=1
  _grove_provision_5_3_brains_keybindings_verify || failed=1
  _grove_provision_5_3_brains_config_verify || failed=1
  return $failed
}
