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
#
# 🛑 .the READERS it shares with the verify — the role and foreign selectors, the census, the
#   mode and the lock declaration, the arrow resolver, the two paths — live in this bundle's `_.sh`

# .what = print whether the two json files hold one document, key order aside: `same` or `differs`
# .why  = TWO words and an exit, never a boolean: a read that fails must not read as "differs",
#         or the caller would rename its candidate over a file it never saw
# guarantee: exits nonzero where either cannot be read — an unreadable pair is neither
_grove_provision_5_3_brains_json_equivalence() {
  local a b
  a="$(jq -S . "$1")" || return 1
  b="$(jq -S . "$2")" || return 1
  [[ "$a" == "$b" ]] && { echo same; return 0; }
  echo differs
}

# .what = print the global config MERGE jq program: `$patch` laid over the extant document
_grove_provision_5_3_brains_config_merge_filter() {
  echo '. * $patch'
}

####################################################################
# .what = print the KEYBINDINGS jq program: upsert `$add` into the `Chat` block, or append one
# .why  = a `.bindings` that is not a list is a shape this half cannot merge into — refused via
#         `error`, never coerced, since a coerce would drop the human's own keymaps
####################################################################
_grove_provision_5_3_brains_keybindings_merge_filter() {
  echo 'if ((.bindings // []) | type) != "array" then error("bindings is not a list") else . end
    | .bindings = ((.bindings // []) as $b
      | if any($b[]; .context == "Chat")
        then [ $b[] | if .context == "Chat" then .bindings = ((.bindings // {}) + $add) else . end ]
        else $b + [ {context: "Chat", bindings: $add} ]
        end)'
}

####################################################################
# .what = print whether <settings> is already CONVERGED: `converged` or `drifted`
# .why  = a converged file is one the converge program (reap, strip, merge <patch>) leaves as
#         it found it — so there is no role hook to strip and no patch key to set
# guarantee: exits nonzero where jq cannot read <settings>, so "converged" is never inferred
####################################################################
_grove_provision_5_3_brains_settings_state() {
  local same
  same="$(jq --argjson patch "$2" "(. as \$was | ($3) == \$was)" "$1")" || return 1
  [[ "$same" == true ]] && { echo converged; return 0; }
  echo drifted
}

# .what = the backup name, declared once: `<prefix><utc stamp>.<pid><suffix>`
#   - the builder and the reap both read these, so the reap matches only names this bundle mints
#   - the GLOB pins the stamp's shape, so a human's own `settings.mine.bak.json` is never reaped
_GROVE_PROVISION_5_3_BRAINS_BACKUP_PREFIX='settings.'
_GROVE_PROVISION_5_3_BRAINS_BACKUP_SUFFIX='.bak.json'
_GROVE_PROVISION_5_3_BRAINS_BACKUP_STAMP_GLOB='[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]-[0-9][0-9]-[0-9][0-9].[0-9]*Z.[0-9]*'

# .what = print a fresh backup path beside <file>, stamped with the utc time (to the nanosecond)
#         and this pid — two applies in one second never share a name
_grove_provision_5_3_brains_backup_path() {
  echo "$(dirname "$1")/${_GROVE_PROVISION_5_3_BRAINS_BACKUP_PREFIX}$(date -u +%Y-%m-%dT%H-%M-%S.%NZ).$$${_GROVE_PROVISION_5_3_BRAINS_BACKUP_SUFFIX}"
}

# .what = how many settings backups beside the file outlive a reap — the newest are kept
_GROVE_PROVISION_5_3_BRAINS_BACKUPS_KEPT=10

####################################################################
# .what = remove every settings backup beside <settings> but the newest `..._BACKUPS_KEPT`
# .why  = each apply that writes adds a full copy (env, allow lists), and a box re-applied for
#         a year would hold hundreds. the name sorts by its utc stamp, so the newest sort last
# guarantee: exits nonzero, and names each survivor, where a removal fails
####################################################################
_grove_provision_5_3_brains_settings_backup_reap() {
  local dir old listed failed=0
  dir="$(dirname "$1")"

  # a list that fails is named, never read as "no backups to reap"
  if ! listed="$(find "$dir" -maxdepth 1 \
         -name "${_GROVE_PROVISION_5_3_BRAINS_BACKUP_PREFIX}${_GROVE_PROVISION_5_3_BRAINS_BACKUP_STAMP_GLOB}${_GROVE_PROVISION_5_3_BRAINS_BACKUP_SUFFIX}")"; then
    echo "   ✋ could not list the settings backups in $dir, so none was reaped" >&2
    echo "      fix: check the owner of $dir, then rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  while IFS= read -r old; do
    [[ -n "$old" ]] || continue
    rm -f -- "$old"
    [[ -e "$old" ]] || continue
    echo "   ✋ could not reap the old backup $old" >&2
    echo "      fix: check the owner of $dir, then rm $old" >&2
    failed=1
  done < <(printf '%s\n' "$listed" | sort | head -n "-$_GROVE_PROVISION_5_3_BRAINS_BACKUPS_KEPT")
  return $failed
}

####################################################################
# .what = make sure `~/.claude` exists — the dir every half writes into
# guarantee: exits nonzero, with its cause and a fix line, where the dir cannot be made
####################################################################
_grove_provision_5_3_brains_claude_dir_upsert() {
  mkdir -p "$HOME/.claude" && return 0
  echo "   ✋ could not create $HOME/.claude, so no claude file could be written" >&2
  echo "      ⇒ $HOME is likely read-only, full, or owned by another user" >&2
  echo "      fix: make $HOME writable by its owner, then" >&2
  echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
  return 1
}

# .what = print the last 12 lines of <text>, indented under a verdict
_grove_provision_5_3_brains_tail_indent() {
  printf '%s\n' "$1" | tail -n 12 | sed 's/^/         /'
}

####################################################################
# .what = remove <tmp> if the run is interrupted before the swap, then exit as signalled
# .why  = an interrupt must leave the original untouched AND no candidate beside it.
#         the swap clears the guard, since after the rename there is no tmp to remove
# 🛑 the caller's own INT/TERM/HUP traps are saved, and restored on unguard — a sourced
#    bundle must not clobber the driver's
####################################################################
_GROVE_PROVISION_5_3_BRAINS_TMP=""
_GROVE_PROVISION_5_3_BRAINS_TRAPS=""
_grove_provision_5_3_brains_tmp_guard() {
  _GROVE_PROVISION_5_3_BRAINS_TMP="$1"
  _GROVE_PROVISION_5_3_BRAINS_TRAPS="$(trap -p INT TERM HUP)"
  trap '_grove_provision_5_3_brains_tmp_abort 130' INT
  trap '_grove_provision_5_3_brains_tmp_abort 143' TERM
  trap '_grove_provision_5_3_brains_tmp_abort 129' HUP
}

# .what = the trap's body: remove the candidate, say so, exit with the signal's code
# .why  = an interrupted apply must leave no half-written candidate beside the target
_grove_provision_5_3_brains_tmp_abort() {
  rm -f -- "$_GROVE_PROVISION_5_3_BRAINS_TMP"
  echo "   ✋ interrupted before the swap — the target is untouched, the candidate removed" >&2
  echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
  exit "$1"
}

# .what = drop the guard: remove the guarded tmp (unless `keep`), restore the caller's traps
# .why  = one call serves every exit — after a swap the tmp is already gone, and a refused
#         write that wants its candidate read by a human passes `keep`
# guarantee: exits nonzero, and names what is left, where the tmp survives its removal or the
#            caller's traps cannot be restored — a cleanup is never reported as done unseen
_grove_provision_5_3_brains_tmp_unguard() {
  local tmp="$_GROVE_PROVISION_5_3_BRAINS_TMP" traps="$_GROVE_PROVISION_5_3_BRAINS_TRAPS" clean=0
  _GROVE_PROVISION_5_3_BRAINS_TMP=""
  _GROVE_PROVISION_5_3_BRAINS_TRAPS=""
  trap - INT TERM HUP

  # the tmp is removed unless the caller keeps it for a human to read
  [[ -n "$tmp" && "${1:-}" != keep ]] && rm -f -- "$tmp"
  if [[ -n "$tmp" && "${1:-}" != keep && -e "$tmp" ]]; then
    echo "   ✋ the candidate $tmp could not be removed, so it is left beside its target" >&2
    echo "      fix: check the owner of $(dirname "$tmp"), then rm $tmp" >&2
    clean=1
  fi

  # the caller's own traps come back as they were
  [[ -z "$traps" ]] && return $clean
  if ! eval "$traps"; then
    echo "   ✋ the caller's INT/TERM/HUP traps could not be restored after the swap" >&2
    echo "      ⇒ an interrupt later in this run takes the shell's default action" >&2
    clean=1
  fi
  return $clean
}

# .what = create <path> empty, mode 0600, and only if no file holds that name
# .why  = 0600 as mktemp made it — the global config candidate carries the oauth session
_grove_provision_5_3_brains_tmp_create() {
  ( umask 077; set -o noclobber; : > "$1" )
}

####################################################################
# .what = mint a GUARDED tmp beside <target>; its path lands in `_GROVE_PROVISION_5_3_BRAINS_TMP`
# .why  = beside the target, so the later `mv` is an atomic rename, never a cross-device copy.
#         the name is chosen first and the guard armed on it BEFORE the file exists, so no
#         instant holds a candidate on disk with no trap to remove it. runs in the caller's
#         shell, never a `$(…)`, since a trap set in a subshell dies with it
# guarantee: exits nonzero, with a fix line, where the tmp cannot be made; the guard is dropped
####################################################################
_grove_provision_5_3_brains_tmp_mint() {
  local tmp="$1.$$.${RANDOM}${RANDOM}"
  _grove_provision_5_3_brains_tmp_guard "$tmp"
  if ! _grove_provision_5_3_brains_tmp_create "$tmp"; then
    echo "   ✋ could not make a tmp beside $1, so it was left untouched" >&2
    echo "      fix: free space or permissions in $(dirname "$1"), then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    # the name was never ours, so it is not removed
    _GROVE_PROVISION_5_3_BRAINS_TMP=""
    _grove_provision_5_3_brains_tmp_unguard
    return 1
  fi
}

####################################################################
# .what = give a FILLED tmp <mode> and rename it over <target> — the one write path of all
#         three halves (settings at its declared mode; the global config and keybindings at 600)
# .why  = a rename needs the DIR writable, never the file, so a locked file is never
#         writable, not for an instant. the tmp lies beside <target>, so the `mv` is an
#         atomic rename (a /tmp tmpfs would make it a cross-device copy)
# guarantee: on any failure the tmp is removed and <target> is untouched
####################################################################
_grove_provision_5_3_brains_file_swap() {
  local tmp="$1" target="$2" mode="$3"
  if ! chmod "$mode" "$tmp"; then
    echo "   ✋ could not give the candidate $tmp mode $mode, so $target was left untouched" >&2
    echo "      fix: check the owner of $(dirname "$target"), then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    _grove_provision_5_3_brains_tmp_unguard; return 1
  fi
  if ! mv -f "$tmp" "$target"; then
    echo "   ✋ could not rename the candidate over $target, so it was left untouched" >&2
    echo "      ⇒ a rename needs the dir writable: $(dirname "$target")" >&2
    echo "      fix: make $(dirname "$target") writable by its owner, then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    _grove_provision_5_3_brains_tmp_unguard; return 1
  fi
  _grove_provision_5_3_brains_tmp_unguard
}

####################################################################
# .what = print a fingerprint of <file>: its inode, its mode, and its sha256
# .why  = bytes alone cannot prove the lock held — a writer that renames an identical copy
#         over the file changes its inode, and a chmod changes its mode, with no byte moved
# guarantee: exits nonzero where any of the three cannot be read
####################################################################
_grove_provision_5_3_brains_fingerprint() {
  local meta hash
  meta="$(stat -c '%i %a' "$1")" || return 1
  hash="$(sha256sum < "$1")" || return 1
  echo "$meta ${hash%% *}"
}

# .what = run <root>'s own init — the measured home writer — and print its output
# .why  = 300s bounds a hung npm (a registry stall) so an apply never waits forever;
#         `timeout` exits 124 when that bound fires
# 🛑 `CLAUDE_CONFIG_DIR` is unset for the init, as for `..._config_path`: an apply from an enrolled
#    claude inherits it, and an init that wrote the actor dir instead would leave home byte-equal
#    and prove naught about home
_grove_provision_5_3_brains_init_run() {
  ( cd "$1" && timeout -k 10 300 env -u CLAUDE_CONFIG_DIR npm run --silent prepare:rhachet </dev/null 2>&1 )
}

####################################################################
# .what = report an init the lock HALTS, with the init's <out>; the lock is KEPT
# .why  = the declaration is the lock bit's one owner, so the gate never re-modes the file. a
#         halt means the lock was declared `on` while an init that writes home is still in reach
#         of it — the repair is the declaration or the init, never a second writer of the bit
####################################################################
_grove_provision_5_3_brains_settings_halt_report() {
  echo "   ✋ boot gate: the lock HALTS rhachet init — the strip and the declared lock are kept" >&2
  echo "      ⇒ an install whose init writes home fails against this file while the lock is declared on" >&2
  echo "      ⇒ the init's last words:" >&2
  _grove_provision_5_3_brains_tail_indent "$1" >&2
  echo "      fix: upgrade that checkout's rhachet to a release whose init never writes home scope," >&2
  echo "           or set _GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK=off in 5.3.brains/_.sh; then" >&2
  echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
}

####################################################################
# .what = take a byte copy of <settings> at <backup>, BEFORE any write
# .why  = the strip deletes entries the commander may want back; this copy is the one place the
#         before survives, so the census and the merge read it, and a hand restore starts from it
# guarantee: exits nonzero, with a fix line, where the copy fails — no copy, no write
####################################################################
_grove_provision_5_3_brains_settings_backup() {
  # 🛑 a recovery point is never replaced — a name that already holds one is refused
  if [[ -e "$2" ]]; then
    echo "   ✋ $2 already holds a backup, so it was not overwritten and $1 was left untouched" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  # 🛑 minted 0600 by a noclobber create, then filled — never `cp -p`, which would carry a 0444 or
  #    0644 source's mode onto a copy of `env`, readable by every user on the box. the create also
  #    refuses atomically, so no writer can slip a file in between the test above and the copy
  if ! ( umask 077; set -o noclobber; : > "$2" ); then
    echo "   ✋ could not back up $1 → $2" >&2
    echo "      ⇒ no copy, no write: the file was left untouched" >&2
    echo "      fix: free space or permissions in $(dirname "$1"), then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  # the copy keeps the source's mtime, as `cp -p` did, so the reap's order is unchanged
  if ! cat "$1" > "$2" || ! touch -r "$1" "$2"; then
    echo "   ✋ could not back up $1 → $2" >&2
    echo "      ⇒ no copy, no write: the file was left untouched, and the partial copy removed" >&2
    echo "      fix: free space or permissions in $(dirname "$1"), then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    # the name was minted by this call, so the partial copy is ours to remove
    rm -f "$2"
    return 1
  fi
  echo "   • backup → $2"
}

# .what = 0 if an init's exit <code> says its 300s bound fired (`timeout` exits 124)
_grove_provision_5_3_brains_init_timed_out() {
  (( $1 == 124 ))
}

####################################################################
# .what = print the checkout this run executes from — the parent of `GROVE_SRC`
# .why  = the gate runs THAT checkout's init. never `git rev-parse` — a grove's checkout is
#         PUSHED, carries no .git, and git answers naught there (`define.provision-defect-shapes`, shape 8)
# guarantee: exits nonzero where `GROVE_SRC` is unset or the checkout holds no rhachet install
####################################################################
_grove_provision_5_3_brains_checkout_root() {
  [[ -n "${GROVE_SRC:-}" ]] || return 1
  local root
  root="$(dirname "$GROVE_SRC")"
  [[ -x "$root/node_modules/.bin/rhachet" ]] || return 1
  echo "$root"
}

# .what = 0 if <out> is an init halted by THIS lock — an EACCES on a `.claude/settings.json`
# .why  = an EACCES alone could come from any path the init touches; only one on the
#         settings file is the lock, so only that earns the write-bit restore
_grove_provision_5_3_brains_init_halted_by_lock() {
  [[ "$1" == *EACCES* && "$1" == *".claude/settings.json"* ]]
}

####################################################################
# .what = the BOOT GATE — after the lock, a real init must leave home untouched
# .why  = the measured home writer is a sprout's install step, `npm run prepare:rhachet`.
#         if a lock makes that init HALT, every sprout breaks, which is worse than the leak.
#         so the gate runs the same command in this checkout, through its own arrow
# ⚠️ the gate proves THIS checkout's init leaves home untouched — never that every writer is
#    stopped. a repo pinned below the shielded rhachet runs an init that writes home by open: under
#    `on` that install FAILS against the lock, and under `off` its hooks land until the next apply
#    strips them. the pass verdict names that exposure in the commander's words
# 🛑 the gate WRITES naught to home; the declaration is the lock bit's one owner
# outcomes:
#   - completes, home fingerprint equal     → this init leaves home untouched
#   - home CHANGED (bytes, inode, or mode)  → a writer other than the apply moved it; halt
#   - timed out (300s)                      → the gate proves naught; the declared mode is kept; halt
#   - halts on EACCES on the settings file  → only under `on`: report it, keep the lock, halt
#   - halts on aught else                   → the gate proves naught; the declared mode is kept; halt
#   - lock declared off                     → 🌙 no lock to prove; the init is NOT run (it would write home)
#   - no checkout, no arrow to home         → 🌙 the gate has no subject
# <backup> is the copy this apply took, or empty where the file was new to it
####################################################################
_grove_provision_5_3_brains_settings_boot_gate() {
  local settings="$1" backup="${2:-}" root target before after out code want

  # the declaration is read once and guarded, so a typo is never read as `off`
  if ! want="$(_grove_provision_5_3_brains_lock_declared)"; then
    echo "   ✋ boot gate: the lock declaration reads '$_GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK', neither on nor off, so the lock is unproven" >&2
    echo "      fix: set _GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK to on or off in 5.3.brains/_.sh, then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  # 🛑 under `off` there is no lock to prove, and the gate's own init would be a WRITER: an
  #    unshielded checkout writes its hooks through the arrow into the unlocked home, right after
  #    the strip. so the init is not run
  if [[ "$want" != locked ]]; then
    echo "   🌙 boot gate: the lock is declared off, so no lock to prove — no init is run"
    echo "      ⇒ a repo pinned below the shielded rhachet 1.49.2 still writes its hooks into home on install,"
    echo "        and no writer re-strips them between applies; the plan's ✋ role hooks is the one detector"
    return 0
  fi
  if ! root="$(_grove_provision_5_3_brains_checkout_root)"; then
    echo "   🌙 boot gate: no rhachet checkout beside this run, so no init to prove the lock against"
    return 0
  fi
  # an arrow that cannot be resolved is a broken tree, never a tree with no subject
  if ! target="$(_grove_provision_5_3_brains_arrow_target "$root/.claude/settings.json")"; then
    echo "   ✋ boot gate: $root/.claude/settings.json is an arrow that could not be resolved, so the lock is unproven" >&2
    echo "      read why: readlink -f $root/.claude/settings.json" >&2
    echo "      fix: repair that arrow, then rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  if [[ "$target" != "$settings" ]]; then
    echo "   🌙 boot gate: $root/.claude/settings.json is no arrow to $settings, so an init there never meets the lock"
    return 0
  fi

  if ! before="$(_grove_provision_5_3_brains_fingerprint "$settings")"; then
    echo "   ✋ boot gate: could not read the fingerprint of $settings, so the lock is unproven" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  echo "   • boot gate: npm run prepare:rhachet in $root (bounded at 300s)…"
  out="$(_grove_provision_5_3_brains_init_run "$root")"
  code=$?
  if ! after="$(_grove_provision_5_3_brains_fingerprint "$settings")"; then
    echo "   ✋ boot gate: could not read the fingerprint of $settings after the init" >&2
    echo "      ⇒ the init ran, but whether home moved is unproven" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  if [[ "$before" != "$after" ]]; then
    echo "   ✋ boot gate: the init CHANGED $settings, a file only the apply may write" >&2
    echo "      ⇒ inode, mode, sha256 — before: $before" >&2
    echo "                                after:  $after" >&2
    echo "      ⇒ a writer wrote it, renamed over it, or re-moded it — a mode lock stops only the first (it is by mode, not chattr +i)" >&2
    [[ -n "$backup" ]] && echo "      ⇒ $backup holds the file as it was before this apply" >&2
    [[ -z "$backup" ]] && echo "      ⇒ this apply took no backup — the file was already converged ([KEEP]) or new; the before is the fingerprint above" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply, then carry this up" >&2
    return 1
  fi

  if (( code == 0 )); then
    echo "   • boot gate: this checkout's init completed and left home untouched (bytes, inode, mode)"
    echo "      ⇒ not proven here: a repo pinned below the shielded rhachet 1.49.2 still writes home on install"
    echo "        and, with the lock on, that install FAILS until its pin moves"
    return 0
  fi

  if _grove_provision_5_3_brains_init_timed_out "$code"; then
    echo "   ✋ boot gate: npm run prepare:rhachet hit its 300s bound (exit 124)" >&2
    echo "      ⇒ home is untouched and the lock is kept, but the gate proves naught until the init completes" >&2
    _grove_provision_5_3_brains_tail_indent "$out" >&2
    echo "      fix: find the hang in $root (a registry stall is the usual), then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  # the gate writes naught: a lock that halts the init is reported, and the declaration decides
  if _grove_provision_5_3_brains_init_halted_by_lock "$out"; then
    _grove_provision_5_3_brains_settings_halt_report "$out"
    return 1
  fi

  echo "   ✋ boot gate: npm run prepare:rhachet failed (exit $code) for a reason other than the lock" >&2
  echo "      ⇒ the lock is kept, but the gate proves naught until the init runs clean" >&2
  _grove_provision_5_3_brains_tail_indent "$out" >&2
  echo "      fix: repair the init in $root, then rhx grove.provision --what 5.3.brains --mode apply" >&2
  return 1
}

####################################################################
# .what = print the REAP jq program — a merge only ADDS, so a RETIRED key outlives its declaration
#   - keys are named EXPLICITLY, once proven dead in the pinned cli (define.5-3-brains.declared-keys)
#   - ⚠️ ONE `del`, since an empty list would render a jq syntax error
#   - ⚠️ the `Agent` strip removes ONE entry; a list it empties is dropped
#   - 🛑 a `modelSettings.<model>.effortLevel` SHADOWS the declared `effortLevel`
#     - the cli writes one when a human picks an effort per model, and it wins over the top level
#     - a deep merge keeps it, so the declared default never reaches that model
#     - ⇒ the strip removes the effort key alone; an entry it empties is dropped
#   - 🛑 the reap drops only a container IT emptied: each branch runs only where its key is
#     present, so a `permissions.deny: []`, a `modelSettings: {}`, or a `modelSettings.<m>: {}` the
#     commander left empty is kept exactly as found (arm 18c), as the strip keeps his empties (18a)
####################################################################
_grove_provision_5_3_brains_reap_filter() {
  echo 'del(.env.DISABLE_UPDATES, .env.CLAUDE_CODE_SKIP_UPDATE_CHECK)
    | if (.permissions.deny | type) == "array" and (.permissions.deny | index("Agent")) != null
      then .permissions.deny -= ["Agent"]
        | if .permissions.deny == [] then del(.permissions.deny) else . end
      else . end
    | if (.modelSettings | type) == "object" and ([.modelSettings[] | objects | has("effortLevel")] | any)
      then .modelSettings |= with_entries(
          if (.value | type) == "object" and (.value | has("effortLevel"))
          then .value |= del(.effortLevel) | select(.value != {})
          else . end)
        | if .modelSettings == {} then del(.modelSettings) else . end
      else . end'
}

####################################################################
# .what = print the STRIP jq program — drop each role hook, then any matcher block it
#   emptied, then any event it left with no block, then `hooks` itself if it emptied that
# 🛑 a container the commander left empty — an `[]` event, a block with `hooks: []`, a
#    `hooks: {}` — is HIS, and stays: the strip prunes only what its own drop emptied
####################################################################
_grove_provision_5_3_brains_strip_filter() {
  echo "if (.hooks | type) == \"object\" and .hooks != {}
    then .hooks |= with_entries(
        .value as \$event
        | .value |= (if type == \"array\"
          then map(if (type == \"object\") and ((.hooks | type) == \"array\") and (.hooks != [])
              then .hooks |= map(select([ $_GROVE_PROVISION_5_3_BRAINS_ROLE_HOOK ] == []))
                | if .hooks == [] then empty else . end
              else . end)
          else . end)
        | select(.value != [] or \$event == []))
      | if .hooks == {} then del(.hooks) else . end
    else . end"
}

# .what = print the CONVERGE jq program: reap, then strip, then merge `$patch` over the rest
_grove_provision_5_3_brains_converge_filter() {
  echo "$(_grove_provision_5_3_brains_reap_filter) | $(_grove_provision_5_3_brains_strip_filter) | . * \$patch"
}

####################################################################
# .what = the SETTINGS half — `~/.claude/settings.json`
# ⚠️ an ENROLLED claude reads rhachet's role file instead (define.5-3-brains.declared-keys)
#
# 🛑 .the file takes the DECLARED mode — 0400 where `_GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK=on`,
#   0600 where `off` (in `_.sh`, with the reason it is off) — and this half is its one writer
#   - every tree's `.claude/settings.json` is an arrow (two hops) to this file, so a
#     tree's init that writes "its" settings writes HOME, and its hooks then fire in
#     every repo. measured: a sprout's install step (a pre-shield `rhachet init --hooks`)
#   - 0400 makes an `open` for write fail with EACCES. it does NOT stop a `rename`, which
#     needs only the dir — and a rename is how this half writes (`..._file_swap`)
#   - ⚠️ 0400 stops an open-writer only. a writer that renames past it is caught by the
#     verify, and undone by the next apply
#
# 🛑 .every role-authored hook is STRIPPED (`_GROVE_PROVISION_5_3_BRAINS_ROLE_HOOK`)
#   - every other key — env, model, permissions, statusLine, an unauthored hook — stays
#
# guarantee:
#   - a byte copy beside the file BEFORE any write; a failed copy halts the half
#   - a file that already holds the patch, no role hook, and the declared lock is never opened
#   - the census and the merge read the backup, so the backup is the before this apply converged
#   - the boot gate runs after this half on every apply, a `[KEEP]` too (`..._settings_step`)
# <settings> is the resolved target, <backup> the path a swap backs up to, <want> the declared mode
#   — all three from the step, so a backup exists on disk exactly where this half took one
####################################################################
_grove_provision_5_3_brains_settings_upsert() {
  local settings="$1" backup="$2" want="$3"
  local patch='{"env": {"DISABLE_AUTOUPDATER": "1", "DISABLE_INSTALLATION_CHECKS": "1", "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION": "false", "CLAUDE_CODE_DISABLE_COMMAND_INJECTION_CHECK": "1", "CLAUDE_CODE_ENABLE_TODO_TOOLS": "1", "ANTHROPIC_MODEL": "claude-opus-5-5[1m]", "CLAUDE_CODE_SUBAGENT_MODEL": "claude-sonnet-5-5[1m]", "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50", "CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS": "450000"}, "disableClaudeAiConnectors": true, "permissions": {"defaultMode": "auto"}, "model": "claude-opus-5-5[1m]", "effortLevel": "medium", "cleanupPeriodDays": 36500, "skipAutoPermissionPrompt": true, "tui": "fullscreen", "verbose": false, "feedbackDrafts": "off"}'
  local tmp

  ####################################################################
  # .no extant file, so the patch is written whole — at the declared mode, by rename
  ####################################################################
  if [[ ! -f "$settings" ]]; then
    _grove_provision_5_3_brains_tmp_mint "$settings" || return 1
    tmp="$_GROVE_PROVISION_5_3_BRAINS_TMP"
    if ! printf '%s\n' "$patch" > "$tmp"; then
      echo "   ✋ could not write the candidate $tmp, so $settings was not created" >&2
      echo "      fix: free space or permissions in $(dirname "$settings"), then" >&2
      echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
      _grove_provision_5_3_brains_tmp_unguard; return 1
    fi
    _grove_provision_5_3_brains_file_swap "$tmp" "$settings" "$want" || return 1
    echo "   • claude settings declared → $settings (mode $want, swapped in by rename)"
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

  local converge
  converge="$(_grove_provision_5_3_brains_converge_filter)"

  ####################################################################
  # .the SKIP — a file that already holds the converged content at the declared mode is
  #   never opened for write: no backup, no tmp (the guard the global config half uses)
  ####################################################################
  local state
  if ! state="$(_grove_provision_5_3_brains_settings_state "$settings" "$patch" "$converge")"; then
    echo "   ✋ jq could not read $settings" >&2
    echo "      ⇒ the file is likely not valid json, so it was left untouched" >&2
    echo "      read why: jq . $settings" >&2
    echo "      fix: repair it by hand, then re-apply, which restores its declared mode:" >&2
    echo "             chmod u+w $settings, edit, rhx grove.provision --what 5.3.brains --mode apply" >&2
    echo "        or move it aside, re-apply to write the declared keys fresh, then carry your own keys" >&2
    echo "        back from the moved copy by the same unlock, edit, re-apply" >&2
    return 1
  fi
  # only a read-back mode EQUAL to the declared one may skip — a write bit alone is not enough,
  # since 0644 or 0666 would let others read the commander's `env`. a mismatch or an unread mode
  # goes on to the write, which gives the file the declared mode
  # a mode that cannot be read is NAMED, never defaulted: it can never match, so the write runs and
  # the swap sets the declared mode — the one move that repairs an unread mode
  local was
  if ! was="$(_grove_provision_5_3_brains_file_mode "$settings")"; then
    echo "   • the mode of $settings could not be read, so it is rewritten at the declared mode ($want)"
    was=unread
  fi
  if [[ "$state" == converged && "$was" == "$want" ]]; then
    echo "   • claude settings already hold the patch, no role hook, and the declared mode ($want) → $settings [KEEP]"
    return 0
  fi

  ####################################################################
  # .the BACKUP — a byte copy beside the file, BEFORE any write. a failed copy halts
  ####################################################################
  # 🛑 the census and the merge read the BACKUP, never the live file — so the copy kept beside
  #    the file is provably the one this apply converged
  local roles
  _grove_provision_5_3_brains_settings_backup "$settings" "$backup" || return 1
  if ! roles="$(_grove_provision_5_3_brains_role_hook_count "$backup")"; then
    echo "   ✋ jq could not count the role hooks in $settings, so it was left untouched" >&2
    echo "      read why: jq . $settings" >&2
    return 1
  fi

  ####################################################################
  # .the MERGE — into a tmp beside the file, then locked and swapped in
  ####################################################################
  _grove_provision_5_3_brains_tmp_mint "$settings" || return 1
  tmp="$_GROVE_PROVISION_5_3_BRAINS_TMP"
  if ! jq --argjson patch "$patch" "$converge" "$backup" > "$tmp"; then
    echo "   ✋ jq could not merge the patch into $settings" >&2
    echo "      ⇒ the file is likely not valid json, so it was left untouched" >&2
    echo "      read why: jq . $settings" >&2
    _grove_provision_5_3_brains_tmp_unguard
    return 1
  fi
  # an EMPTY file is no json document, so jq reads naught, exits 0, and writes an empty tmp —
  # which would swap in as "merged" and never converge. refused here, before the swap
  if [[ ! -s "$tmp" ]]; then
    echo "   ✋ $settings holds no json document, so the merge produced an empty file; left untouched" >&2
    echo "      fix: write {} into it (chmod u+w first, if locked), then re-apply:" >&2
    echo "             rhx grove.provision --what 5.3.brains --mode apply" >&2
    _grove_provision_5_3_brains_tmp_unguard
    return 1
  fi
  _grove_provision_5_3_brains_file_swap "$tmp" "$settings" "$want" || return 1

  echo "   • role hooks stripped → $roles removed; every unauthored hook kept"
  # the mode change is named, so an apply that lifts or sets a lock never does it in silence
  echo "   • claude settings merged → $settings (mode $was → $want, swapped in by rename)"
}

####################################################################
# .what = the SETTINGS step — converge the file, then run the boot gate, on EVERY apply
# .why  = the gate proves a fact of the PAIR (this checkout's init, this home), and the checkout
#         moves far more often than the file. a gate run only on a swap would go stale at the
#         next rhachet bump, and a gate that halted once would be skipped by the next `[KEEP]`
# guarantee: no gate where the converge failed — a file this apply could not converge has no
#            lock to prove
# 🛑 the backup reap runs LAST, as its own verdict: a failed `rm` of an old copy never masks the
#    gate or the foreign-author census
####################################################################
_grove_provision_5_3_brains_settings_step() {
  local settings backup want failed=0

  # 🛑 the declaration is read FIRST — one that reads neither on nor off is refused before any
  #    read, backup, or write, so a typo leaves no trace in ~/.claude
  if ! want="$(_grove_provision_5_3_brains_mode_declared)"; then
    echo "   ✋ the lock declaration reads '$_GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK', neither on nor off, so $HOME/.claude/settings.json was left untouched" >&2
    echo "      fix: set _GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK to on or off in 5.3.brains/_.sh, then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  _grove_provision_5_3_brains_claude_dir_upsert || return 1
  # 🛑 the half writes the file the path resolves to (`..._settings_path`)
  if ! settings="$(_grove_provision_5_3_brains_settings_path)"; then
    echo "   ✋ $HOME/.claude/settings.json is an arrow that could not be resolved, so naught was written" >&2
    echo "      read why: readlink -f $HOME/.claude/settings.json" >&2
    return 1
  fi
  if ! backup="$(_grove_provision_5_3_brains_backup_path "$settings")"; then
    echo "   ✋ could not name a backup beside $settings, so it was left untouched" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  # a failed converge skips the gate alone — the census and the reap still speak their verdicts
  _grove_provision_5_3_brains_settings_converge_then_gate "$settings" "$backup" "$want" || failed=1
  _grove_provision_5_3_brains_settings_foreign_name "$settings" || failed=1
  _grove_provision_5_3_brains_settings_backup_reap "$settings" || failed=1
  return $failed
}

####################################################################
# .what = converge <settings>, then run the boot gate against it
# .why  = a file this apply could not converge has no lock to prove, so a failed converge
#         returns before the gate — one early return, no fork
####################################################################
_grove_provision_5_3_brains_settings_converge_then_gate() {
  local settings="$1" backup="$2" want="$3"
  _grove_provision_5_3_brains_settings_upsert "$settings" "$backup" "$want" || return 1

  # a backup on disk at the minted path is the one this apply took — truer than a flag. a
  #   `[KEEP]` took none, so the gate is handed no backup to restore from
  if [[ ! -e "$backup" ]]; then
    backup=""
  fi
  _grove_provision_5_3_brains_settings_boot_gate "$settings" "$backup"
}

####################################################################
# .what = name each hook in <settings> stamped by an author outside `repo=…`
# .why  = the strip never touches such a hook, so an apply alone cannot clear it — and an apply
#         that printed `[KEEP]` over one would go green while the verify ✋s the same file. the
#         upsert names the very set the verify reads, so the two never disagree
# guarantee: exits nonzero where a foreign hook stands or the census cannot be read
####################################################################
_grove_provision_5_3_brains_settings_foreign_name() {
  local foreign total
  if ! foreign="$(_grove_provision_5_3_brains_foreign_hooks_by_author "$1")"; then
    echo "   ✋ jq could not read $1, so its foreign-author hooks are uncounted" >&2
    echo "      read why: jq . $1" >&2
    echo "      fix: repair the json by hand, then rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  # no foreign author → no verdict to print
  if [[ -z "$foreign" ]]; then
    return 0
  fi
  if ! total="$(_grove_provision_5_3_brains_census_total <<< "$foreign")"; then
    echo "   ✋ $1 holds hooks by an author outside \`repo=…\`, and the census could not total them" >&2
    echo "      ⇒ the census totals with awk, so awk is absent or failed on this box" >&2
    echo "      read why: command -v awk" >&2
    return 1
  fi
  echo "   ✋ $1 holds $total hooks by an author outside \`repo=…\`, which no apply strips" >&2
  _grove_provision_5_3_brains_census_tree <<< "$foreign" >&2
  echo "      ⇒ each fires in every session on this box, as a role hook would" >&2
  echo "      fix: judge each author — a role's belongs in its repo, so widen" >&2
  echo "           _GROVE_PROVISION_5_3_BRAINS_ROLE_HOOK to it; a human's own, drop its \`author\`" >&2
  return 1
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
  local config tmp
  if ! config="$(_grove_provision_5_3_brains_config_path)"; then
    echo "   ✋ the claude global config is an arrow that could not be resolved, so naught was written" >&2
    echo "      read why: readlink -f $HOME/.claude.json $HOME/.claude/.config.json" >&2
    echo "      fix: repair that arrow, then rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  ####################################################################
  # .no extant file, so the patch is written whole — into a guarded tmp, then renamed in
  #   claude creates this file on its first run and merges its own defaults
  #   over whatever it finds, so a one-key file is a valid seed
  ####################################################################
  if [[ ! -f "$config" ]]; then
    _grove_provision_5_3_brains_tmp_mint "$config" || return 1
    tmp="$_GROVE_PROVISION_5_3_BRAINS_TMP"
    if ! printf '%s\n' "$patch" > "$tmp"; then
      echo "   ✋ could not write the candidate $tmp, so $config was not created" >&2
      echo "      ⇒ $(dirname "$config") is likely full or not writable by its owner" >&2
      echo "      fix: free space or permissions in $(dirname "$config"), then" >&2
      echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
      _grove_provision_5_3_brains_tmp_unguard; return 1
    fi
    _grove_provision_5_3_brains_file_swap "$tmp" "$config" 600 || return 1
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
  local panel
  if ! panel="$(_grove_provision_5_3_brains_config_diff_panel "$config")"; then
    echo "   ✋ jq could not read $config, so it was left untouched" >&2
    echo "      ⇒ the file is likely not valid json; it holds the oauth session, so it is never overwritten" >&2
    echo "      read why: jq . $config" >&2
    echo "      fix: repair the json by hand (never delete it — it holds the session), then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  if [[ "$panel" == shut ]]; then
    echo "   • claude global config already holds the diff panel shut → $config [KEEP]"
    return 0
  fi

  # 🛑 guard 2 — the tmp lands BESIDE the target, so the `mv` is an atomic
  #   rename; /tmp is a tmpfs here, and a cross-device `mv` is a copy
  _grove_provision_5_3_brains_tmp_mint "$config" || return 1
  tmp="$_GROVE_PROVISION_5_3_BRAINS_TMP"
  if ! jq --argjson patch "$patch" "$(_grove_provision_5_3_brains_config_merge_filter)" "$config" > "$tmp"; then
    echo "   ✋ jq could not merge the patch into $config" >&2
    echo "      ⇒ the file is likely not valid json, so it was left untouched" >&2
    echo "      read why: jq . $config" >&2
    echo "      fix: repair the json by hand (never delete it — it holds the session), then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    _grove_provision_5_3_brains_tmp_unguard
    return 1
  fi
  # an EMPTY file is no json document: jq reads naught, exits 0, and the shrink guard below
  # compares 0 with 0 — so it is refused here, or an empty file would swap in as "merged"
  if [[ ! -s "$tmp" ]]; then
    echo "   ✋ $config holds no json document, so the merge produced an empty file; left untouched" >&2
    echo "      fix: write {} into it (a fresh login fills the session back), then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    _grove_provision_5_3_brains_tmp_unguard
    return 1
  fi

  # ⚠️ this patch never shortens a value, so a smaller result means jq dropped
  #   state — and here that costs a human their session
  local was now
  # a size that cannot be read is a ✋, never an empty compare that fails the guard open
  if ! was="$(wc -c < "$config")" || ! now="$(wc -c < "$tmp")" || [[ ! "$was" =~ ^[0-9]+$ || ! "$now" =~ ^[0-9]+$ ]]; then
    echo "   ✋ could not size the global config and its merged candidate, so the shrink guard is unjudged" >&2
    echo "      ⇒ the write is refused and $config is untouched; the candidate is removed" >&2
    echo "      read why: wc -c < $config" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    _grove_provision_5_3_brains_tmp_unguard
    return 1
  fi
  if [[ "$now" -lt "$was" ]]; then
    echo "   ✋ the merged global config SHRANK — $was bytes in, $now bytes out" >&2
    echo "      ⇒ this patch never shortens a value, so a smaller result means state" >&2
    echo "        was dropped. the write is refused and $config is untouched" >&2
    echo "      read the candidate before you discard it: jq . $tmp" >&2
    echo "      ⇒ it is a full copy of the config, oauth session included, kept at mode 600; no apply reaps it" >&2
    echo "      fix: once read, rm $tmp, then rhx grove.provision --what 5.3.brains --mode apply" >&2
    _grove_provision_5_3_brains_tmp_unguard keep
    return 1
  fi

  _grove_provision_5_3_brains_file_swap "$tmp" "$config" 600 || return 1
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
  # `arrow` is the path claude reads; `file` is what it resolves to, and the one the half writes
  local arrow="$HOME/.claude/keybindings.json" file tmp
  local add='{"ctrl+x ctrl+s": null}'
  _grove_provision_5_3_brains_claude_dir_upsert || return 1

  # 🛑 a rename over a SYMLINK replaces the link, so the half writes the file it resolves to
  if ! file="$(_grove_provision_5_3_brains_arrow_target "$arrow")"; then
    echo "   ✋ $arrow is an arrow that could not be resolved, so naught was written" >&2
    echo "      read why: readlink -f $arrow" >&2
    echo "      fix: repair or remove that arrow, then rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "   ✋ jq is absent, so $file cannot be merged — refused rather than overwrite a human's keymaps" >&2
    echo "      ⇒ this bundle's provision phase installs jq, so it did not run or could not reach root" >&2
    echo "      fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  # 🛑 the same two guards the other halves hold: compare FIRST, so a file that already holds the
  #    unbind is never opened and no tmp is minted in ~/.claude; and the tmp lands BESIDE the
  #    target, so the `mv` is an atomic rename. an absent file merges from an empty `bindings`
  #    list, so the first write is guarded too
  # ⚠️ what remains is the read-modify-write window: a write by claude or a human between the merge
  #    read and the rename is lost to the rename. the two guards narrow it; no lock removes it, since
  #    claude takes none. a lost write fails one of two ways, and both are visible:
  #      - a human's own keymap lost → the merge kept every key it read, so only a write in that
  #        window is lost, and the next edit restores it
  #      - our unbind lost to a claude write-back → the verify's keybindings claim reddens, and the
  #        next apply re-converges
  local merged
  if ! merged="$(_grove_provision_5_3_brains_keybindings_merge "$file" "$add")"; then
    echo "   ✋ jq could not merge into $file — not valid json, or .bindings is not a list; left untouched" >&2
    echo "      read why: jq .bindings $file" >&2
    echo "      fix: repair it by hand so it parses and .bindings is a list, then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  # an EMPTY file is no json document: jq reads naught and exits 0, so the merge is empty — and
  # two empty documents compare `same`, which would print a false [KEEP]. refused here
  if [[ -z "$merged" ]]; then
    echo "   ✋ $file holds no json document, so the merge produced naught; left untouched" >&2
    echo "      fix: write {\"bindings\": []} into it, then rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi

  # an extant file already merged is kept; a read that fails is never taken for "differs"
  local held
  if ! held="$(_grove_provision_5_3_brains_keybindings_held "$file" "$merged")"; then
    echo "   ✋ jq could not compare the merged keybindings with $file, so it was left untouched" >&2
    echo "      read why: jq . $file" >&2
    echo "      fix: repair the json by hand, then rhx grove.provision --what 5.3.brains --mode apply" >&2
    return 1
  fi
  if [[ "$held" == same ]]; then
    echo "   • claude keybindings already unbind the ctrl+x ctrl+s chord → $file [KEEP]"
    return 0
  fi

  _grove_provision_5_3_brains_tmp_mint "$file" || return 1
  tmp="$_GROVE_PROVISION_5_3_BRAINS_TMP"
  if ! printf '%s\n' "$merged" > "$tmp"; then
    echo "   ✋ could not write the candidate $tmp, so $file was left untouched" >&2
    echo "      fix: free space or permissions in $(dirname "$file"), then" >&2
    echo "           rhx grove.provision --what 5.3.brains --mode apply" >&2
    _grove_provision_5_3_brains_tmp_unguard; return 1
  fi
  _grove_provision_5_3_brains_file_swap "$tmp" "$file" 600 || return 1
  echo "   • claude keybindings merged → $file (ctrl+enter is the one send-now key)"
}

# .what = print whether <file> already holds the <merged> document: `absent`, `same`, or `differs`
# guarantee: exits nonzero where <file> cannot be read, so a failed read is never "differs"
_grove_provision_5_3_brains_keybindings_held() {
  if [[ ! -f "$1" ]]; then
    echo absent
    return 0
  fi
  _grove_provision_5_3_brains_json_equivalence <(printf '%s\n' "$2") "$1"
}

# .what = print <file> merged with the bind <add>; an absent <file> merges from no binds
_grove_provision_5_3_brains_keybindings_merge() {
  local filter
  filter="$(_grove_provision_5_3_brains_keybindings_merge_filter)" || return 1
  [[ -f "$1" ]] && { jq --argjson add "$2" "$filter" "$1"; return; }
  jq --argjson add "$2" "$filter" <<< '{"bindings": []}'
}

# .why every half runs — a `&&` would hide the later verdicts (`rule.forbid.failhide`)
grove_provision_5_3_brains_configure_upsert() {
  local failed=0
  _grove_provision_5_3_brains_settings_step || failed=1
  _grove_provision_5_3_brains_config_upsert || failed=1
  _grove_provision_5_3_brains_keybindings_upsert || failed=1
  return $failed
}
