#!/usr/bin/env bash
######################################################################
# .what = converge the idle check, its two units, and the timer — see `_.sh`
#
# .why the READ comes before root (`define.provision-defect-shapes`, shape 2)
#   - a converged box is left untouched, with no sudo asked
#   - the camper seat holds no root, so it declines with 🌙; the ground seat
#     converges, and the camper then finds the box converged
#
# .why every file is staged beside its target and renamed over it
#   - the timer fires every 300s; a tick that read a half-written check could
#     act on a torn file. a rename is atomic within one filesystem, and the
#     stage sits in the target's own dir so the rename never crosses one
#   - the stage name is unique per run (`mktemp`), so two applies at once never
#     share a stage, and neither renames the other's half-written file
#
# ⚠️ .why reload, THEN retire, THEN reload again
#   - systemd caches unit files, so a rewrite with no reload leaves the old
#     definition live — and a removed drop-in stays in force until a reload
#   - `DropInPaths` names only what systemd has LOADED. a drop-in written with no
#     reload is invisible to it until the first reload — so the retire reads after
#     that reload, and a second reload follows any retire. one apply converges
#
# .why an active timer is always restarted
#   - `enable --now` leaves an active timer as it was, so a new schedule would
#     wait on a restart. a restart keyed to "this run rewrote the file" is lost
#     when a run dies after the rename; the apply runs only on drift, and a
#     restart of a 300s timer costs naught, so it restarts every time
#
# .why each leaf reports on stdout, and the retire count rides in a global
#   - a leaf run inside `$(…)` must push its progress to stderr, which the runtime
#     neither pads nor orders against stdout. `_retire` zeroes and reads the one
#     global, `RETIRED`, itself, so no caller holds that contract
#
# .why the drift reader, never the health reader, gates the apply
#   - drift is what an apply sets. how the last run went is a fault the apply cannot
#     clear, so a converged box with a bad run is left alone and asks no root; the
#     verify names the fault, with the journal read as its fix
#
# guarantee:
#   - idempotent: a converged box is skipped; a drifted one is re-converged
#   - after a run, the box holds this checkout's check and units, root-owned at
#     their declared modes, loaded, no drop-in of their own, no stopgap, and an
#     unmasked, enabled, active timer
######################################################################

# .what = report a box fault this apply hit: what failed, what it leaves live, and the fix
# .usage = grove_provision_1_15_hibernate_fault <what> [<left live>] [inline]
#   - inline = the tool's error text rides on the 💥 line itself, so the fix points there.
#     without it the tool printed its own error first, and "above" is where it sits
# .note = returns 1, so a caller writes `|| { grove_provision_1_15_hibernate_fault …; return 1; }`
grove_provision_1_15_hibernate_fault() {
  local where="the error above"
  [[ "${3:-}" == inline ]] && where="the error on the 💥 line"
  echo "   💥 MalfunctionError: $1" >&2
  [[ -z "${2:-}" ]] || echo "      ⇒ $2" >&2
  echo "      └─ fix: read $where, then re-run from the ground seat: rhx grove.provision --what 1.15.hibernate --mode apply" >&2
  return 1
}

# .what = each declared file — from this checkout, root-owned at its mode, renamed into place
# .note = exit 2 on an incomplete checkout (the caller must fix it); 1 on a box fault
grove_provision_1_15_hibernate_set_artifacts() {
  local pair src staged PAIR_NAME PAIR_DST PAIR_MODE
  local owner="$GROVE_PROVISION_1_15_HIBERNATE_OWNER"
  for pair in "${GROVE_PROVISION_1_15_HIBERNATE_PAIRS[@]}"; do
    grove_provision_1_15_hibernate_pair "$pair"
    src="$(grove_provision_1_15_hibernate_src "$PAIR_NAME")"
    if [[ ! -f "$src" ]]; then
      echo "   ✋ ConstraintError: no $PAIR_NAME at $src" >&2
      echo "      ⇒ this run's own checkout is incomplete; fix: git.repo.pull, then re-run" >&2
      return 2
    fi

    # bytes match in a regular file: hold the declared mode and owner, and move on.
    # a symlink falls through to the rename, which replaces the link and never its target
    if grove_provision_1_15_hibernate_is_declared_copy "$src" "$PAIR_DST"; then
      grove_provision_1_15_hibernate_is_held_at "$PAIR_DST" "$PAIR_MODE" && continue
      sudo chown "$owner" "$PAIR_DST" && sudo chmod "$PAIR_MODE" "$PAIR_DST" || {
        grove_provision_1_15_hibernate_fault "could not set $PAIR_DST to $PAIR_MODE $owner"; return 1; }
      echo "   • $PAIR_DST held at $PAIR_MODE $owner"
      continue
    fi

    # bytes differ: stage beside the target, then rename over it
    sudo mkdir -p "$(dirname "$PAIR_DST")" \
      && staged="$(sudo mktemp "$PAIR_DST.grove-provision.XXXXXX")" || {
        grove_provision_1_15_hibernate_fault "could not stage $PAIR_DST"; return 1; }
    if ! sudo install -m "$PAIR_MODE" -o "$(grove_provision_1_15_hibernate_owner_uid)" \
         -g "$(grove_provision_1_15_hibernate_owner_gid)" "$src" "$staged" \
       || ! sudo mv -f "$staged" "$PAIR_DST"; then
      sudo rm -f "$staged"
      grove_provision_1_15_hibernate_fault "could not install $PAIR_DST" "the box still holds its prior copy"
      return 1
    fi
    echo "   • $PAIR_DST declared"
  done
}

# .what = reload systemd, so the units on disk are the units it runs
grove_provision_1_15_hibernate_reload() {
  grove_provision_1_15_hibernate_systemctl_root daemon-reload && return 0
  grove_provision_1_15_hibernate_fault "systemctl daemon-reload failed" "the new units are on disk and the OLD definitions stay live"
}

# .what = retire each drop-in of the two units' OWN `<unit>.d/` — see `_.sh`
# .output = GROVE_PROVISION_1_15_HIBERNATE_RETIRED — the count of files removed
grove_provision_1_15_hibernate_del_dropins() {
  local f dir found dirs=()
  # an unanswered read is no proof the units carry none: halt before the timer arms
  found="$(grove_provision_1_15_hibernate_dropins)" || {
    grove_provision_1_15_hibernate_fault "could not list the units' drop-ins, so none was retired"; return 1; }
  while IFS= read -r f; do
    [[ -n "$f" && -e "$f" ]] || continue
    sudo rm -f "$f" || { grove_provision_1_15_hibernate_fault "could not remove the drop-in $f"; return 1; }
    echo "   • retired the drop-in $f"
    GROVE_PROVISION_1_15_HIBERNATE_RETIRED=$((GROVE_PROVISION_1_15_HIBERNATE_RETIRED + 1))
    dirs+=("$(dirname "$f")")
  done <<< "$found"
  # each emptied `<unit>.d` goes too — read only once every drop-in in it is gone, so
  # a dir that held two is never named as left behind after the first
  for dir in $(printf '%s\n' "${dirs[@]}" | sort -u); do
    grove_provision_1_15_hibernate_del_dropin_dir "$dir" || return 1
  done
  return 0
}

# .what = remove one emptied `<unit>.d` dir; one that still holds a file no `*.conf`
#         glob reads stays, and is harmless — systemd reads none of it
grove_provision_1_15_hibernate_del_dropin_dir() {
  local dir="$1" err
  [[ "$dir" == *.d && -d "$dir" ]] || return 0
  err="$(sudo rmdir "$dir" 2>&1)" && return 0
  if [[ "$err" == *"Directory not empty"* ]]; then
    # name what stays, and the one step that clears it: a bare "left in place" asks the reader to go look
    echo "   🌙 $dir holds a file systemd does not read; left in place — it changes no unit"
    # one name per entry, joined by `, `: a bare space would read two files as one spaced name
    echo "      ⇒ it holds: $(sudo ls -A "$dir" 2>&1 | paste -sd ',' | sed 's/,/, /g')"
    echo "      ⇒ to clear it, once each file is known to be no one's: sudo rm -r $dir"
    return 0
  fi
  grove_provision_1_15_hibernate_fault "could not remove the emptied $dir: $err" "" inline
}

# .what = retire the stopgap pre-check, the migration from the 2026-10-22 incident
# .why  = crews died when the old check hibernated a busy grove; a hand-written
#         `ExecCondition=` pre-check held the box until this fix. its drop-in goes
#         with `del_dropins`; this removes the executable it ran
# .remove = once every cloud grove has had one ground apply of this bundle, delete
#         this function and `GROVE_PROVISION_1_15_HIBERNATE_STOPGAP`
# .output = GROVE_PROVISION_1_15_HIBERNATE_RETIRED — incremented when the file goes
grove_provision_1_15_hibernate_retire_stopgap() {
  local stopgap="$GROVE_PROVISION_1_15_HIBERNATE_STOPGAP"
  [[ -e "$stopgap" ]] || return 0
  sudo rm -f "$stopgap" || { grove_provision_1_15_hibernate_fault "could not remove $stopgap"; return 1; }
  echo "   • retired the stopgap pre-check $stopgap"
  # the stopgap held on PRESENCE (any tmux server, any brain process); the check holds on
  # ACTIVITY. say so at the moment the hold changes, so no commander learns it from a sleep
  echo "     ⇒ a box now holds on activity, never on presence: a crew that prints naught, writes no trace, and takes no keystroke for $(grove_provision_1_15_hibernate_idle_limit) sleeps — keep one pane that prints to hold it"
  GROVE_PROVISION_1_15_HIBERNATE_RETIRED=$((GROVE_PROVISION_1_15_HIBERNATE_RETIRED + 1))
}

# .what = unmask and arm the timer; restart it when it was already active; name each hand hold undone
grove_provision_1_15_hibernate_arm_timer() {
  local timer="$GROVE_PROVISION_1_15_HIBERNATE_TIMER" was_active
  # is-enabled / is-active exit non-zero on a plain "disabled" / "inactive", so the
  # answer is read from stdout; a real fault still reaches stderr, never a sink
  if [[ "$(grove_provision_1_15_hibernate_systemctl is-enabled "$timer")" == masked ]]; then
    grove_provision_1_15_hibernate_systemctl_root unmask "$timer" || {
      grove_provision_1_15_hibernate_fault "could not unmask $timer" "the box no longer hibernates itself when idle"; return 1; }
    echo "   • unmasked $timer — a hand hold is undone"
  fi
  was_active="$(grove_provision_1_15_hibernate_systemctl is-active "$timer")"
  grove_provision_1_15_hibernate_systemctl_root enable --now "$timer" || {
    grove_provision_1_15_hibernate_fault "could not enable and start $timer" \
      "the box no longer hibernates itself when idle, and bills by the hour — read why: rhx machine.journal.read --scope system --unit $timer --since today"
    return 1; }
  # the restart runs on every path, so a mis-read `was_active` can never skip it;
  # on a timer `enable --now` just started, it is a harmless second start
  grove_provision_1_15_hibernate_systemctl_root try-restart "$timer" || {
    grove_provision_1_15_hibernate_fault "could not restart $timer on its declared schedule" "the timer keeps whatever schedule it last loaded"; return 1; }
  if [[ "$was_active" != active ]]; then
    echo "   • $timer re-armed — it was ${was_active:-unreported}; a hand stop is undone"
    return 0
  fi
  echo "   • $timer restarted on its declared schedule"
}

# .what = retire every second writer — the units' own drop-ins, then the stopgap —
#         and reload once more if any went, so systemd forgets them
grove_provision_1_15_hibernate_retire() {
  GROVE_PROVISION_1_15_HIBERNATE_RETIRED=0
  grove_provision_1_15_hibernate_del_dropins || return 1
  grove_provision_1_15_hibernate_retire_stopgap || return 1
  [[ "$GROVE_PROVISION_1_15_HIBERNATE_RETIRED" -gt 0 ]] || return 0
  grove_provision_1_15_hibernate_reload
}

# .what = forget the last run's Result, so the verify in this same pass reads the
#         new config's runs, never a fault the retired writers caused
# .why a Result outlives the config that made it: on a box the stopgap held, it
#   reads `exec-condition` until the next tick, after the apply removed the cause
# .why it runs BEFORE the timer arms: a timer whose elapse has passed fires at once,
#   and that tick's Result is real evidence the reset must never erase
# .note = a failed reset is loud and returns 0: the config is converged, so the verify
#   still runs and names the stale fault, which clears on the next tick
grove_provision_1_15_hibernate_reset_result() {
  grove_provision_1_15_hibernate_systemctl_root reset-failed "$GROVE_PROVISION_1_15_HIBERNATE_SERVICE" && return 0
  grove_provision_1_15_hibernate_fault "could not reset the last result of $GROVE_PROVISION_1_15_HIBERNATE_SERVICE" \
    "the verify below may name a fault from before this apply; it clears on the next tick"
  return 0
}

# .what = the first gap the drift reader named — the one a decline reports
grove_provision_1_15_hibernate_drift_first() {
  head -n 1 <<< "$1"
}

grove_provision_1_15_hibernate_configure_upsert() {
  # 1. what already holds — read before any privilege is asked for
  local drift
  drift="$(grove_provision_1_15_hibernate_drift)"
  if [[ -z "$drift" ]]; then
    echo "   • the idle check and its units match this checkout, and $GROVE_PROVISION_1_15_HIBERNATE_TIMER is armed ✔"
    return 0
  fi

  # it does not hold, and this seat cannot set it — the seat with root owns it
  bundle.root.owns "the idle check, with its units," "$(grove_provision_1_15_hibernate_drift_first "$drift")" || return 0
  pkg_assert_sudo || return 1

  # 2. declare the files, reload, then retire what the reload revealed
  grove_provision_1_15_hibernate_set_artifacts || return $?
  grove_provision_1_15_hibernate_reload || return 1
  grove_provision_1_15_hibernate_retire || return 1

  # 3. clear the last result, then arm the timer, so a tick the arm fires stays on record
  grove_provision_1_15_hibernate_reset_result
  grove_provision_1_15_hibernate_arm_timer
}
