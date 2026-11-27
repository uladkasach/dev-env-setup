#!/usr/bin/env bash
######################################################################
# .what = prove the box runs this checkout's idle check, with no drop-in beside
#         it, on an enabled and active timer — and show how its last run went
#
# .why it `cmp`s the bytes, never the presence
#   - every cloud grove already holds an `idle-hibernate.sh` — infra's first-boot
#     copy. presence would pass the very check that hibernated a box under its
#     crews; only the bytes tell this checkout's check from that one
#
# .why drift and health are two blocks, each with its own fix
#   - drift is config an apply sets, so its fix is a ground apply
#   - health is how the last run went, and whether the next can act. an apply resets
#     systemd's record of the run, but cannot clear a source the check could not read,
#     so health shows the check's own record (`/run/idle-hibernate.last`), which a
#     camper can read, and what that Result says of the run
#   - so "no failed run is on record" is the claim, never "the last run went clean":
#     right after an apply, no tick has run yet
#
# .why every box shows its last tick and its last sleep, drifted or not
#   - "why is this box awake?" and "why did it sleep?" must answer from one read on the
#     seat a crew runs on — and a drifted box (every infra-born grove, until its first
#     ground apply) is exactly the box that question is asked of
#   - the record's verdict line names the newest stir and what each source saw; its age
#     shows whether the timer still ticks. the age is a note, never a ✋: a box that just
#     woke shows an old tick until its timer catches up, and a gate there would cry wolf
#   - the sleep record keeps its own file, since a wake's first tick rewrites the record
#
# guarantee:
#   - READ-ONLY. it reads files and unit state; repairs no state
#
# exit:
#   0 = converged and healthy
#   1 = a drift or a symptom is named on stderr, with the fix
######################################################################

# .what = seconds since a record's `at=<iso> exit=<n>` line; exits 1 on a line it cannot parse
# .note = a record is a world-readable boundary, so an unparsed `at=` shows no age, never a fault
grove_provision_1_15_hibernate_configure_verify_age_secs() {
  local at then age
  at="${1#at=}"; at="${at%% *}"
  # only the check's own iso stamp ages: `date -d` reads a lone `x` as a military zone, and would age it
  [[ "$at" == [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T* ]] || return 1
  then="$(date -u -d "$at" +%s 2>/dev/null)" || return 1
  age=$(( $(date +%s) - then ))
  [[ "$age" -ge 0 ]] || age=0
  echo "$age"
}

# .what = that age as `<n>s` / `<n>m` / `<n>h`; empty if unparsed
grove_provision_1_15_hibernate_configure_verify_age() {
  local age
  age="$(grove_provision_1_15_hibernate_configure_verify_age_secs "$1")" || return 0
  if [[ "$age" -lt 120 ]]; then echo "${age}s"
  elif [[ "$age" -lt 7200 ]]; then echo "$((age / 60))m"
  else echo "$((age / 3600))h"; fi
}

# .what = the last tick, as `•` lines: when it ran, how long ago, and its verdict — or why none has
# .why each "none" names its true cause: an older check writes no record, a pre-check skips
#   every tick, or the next tick is due. one promise for all three is false on two of them
grove_provision_1_15_hibernate_configure_verify_last_tick() {
  local lines verdict head age secs fired period rec="$GROVE_PROVISION_1_15_HIBERNATE_RECORD"
  period="$(grove_provision_1_15_hibernate_declared "$GROVE_PROVISION_1_15_HIBERNATE_TIMER" OnUnitActiveSec)"
  if ! lines="$(grove_provision_1_15_hibernate_record_lines)"; then
    if ! grove_provision_1_15_hibernate_check_is_current; then
      echo "   • no tick on record at $rec — the installed check is older than this checkout's, and writes none; the ground apply installs one that does"
    elif grove_provision_1_15_hibernate_ticks_skipped; then
      echo "   • no tick on record at $rec — a pre-check skips every tick, so none is written until the ground apply retires it"
    else
      # an error is never shown where a time belongs: a refused read says it was refused, with its text
      if fired="$(grove_provision_1_15_hibernate_systemctl show -p LastTriggerUSec --value "$GROVE_PROVISION_1_15_HIBERNATE_TIMER" 2>&1)"; then
        echo "   • no tick on record yet at $rec — the timer last fired: ${fired:-unknown}"
      else
        echo "   • no tick on record yet at $rec — when the timer last fired is unknown: systemctl gave no answer (${fired:-no text})"
      fi
      echo "     ⇒ the next tick writes it within ${period}s; a timer that fired and left none names a check that cannot write it"
    fi
    return 0
  fi
  head="$(head -1 <<< "$lines")"
  verdict="$(grove_provision_1_15_hibernate_record_verdict "$lines")"
  age="$(grove_provision_1_15_hibernate_configure_verify_age "$head")"
  echo "   • the last tick, $head${age:+ ($age ago)}: ${verdict:-no verdict line in the record}"
  # a tick older than three periods says the timer stopped, unless the box just woke
  secs="$(grove_provision_1_15_hibernate_configure_verify_age_secs "$head")" || return 0
  [[ "$secs" -le $(( 3 * ${period:-300} )) ]] && return 0
  # while a pre-check skips the ticks, the record is stale by design — never a stopped timer
  if grove_provision_1_15_hibernate_ticks_skipped; then
    echo "     ⇒ a pre-check skips every tick, so this record is the last run before it; the ground apply retires it"
    return 0
  fi
  echo "     ⇒ the timer ticks every ${period}s: unless this box just woke, the timer has stopped or the check cannot write its record — read: systemctl status $GROVE_PROVISION_1_15_HIBERNATE_TIMER"
}

# .what = the last sleep, as one `•` line — or why none is on record
grove_provision_1_15_hibernate_configure_verify_last_sleep() {
  local lines verdict head age rec="$GROVE_PROVISION_1_15_HIBERNATE_SLEEP_RECORD"
  if ! lines="$(grove_provision_1_15_hibernate_record_lines "$rec")"; then
    if grove_provision_1_15_hibernate_check_is_current; then
      # a cold boot clears /run — and so does a hibernate that fell back to a plain stop
      echo "   • no sleep on record at $rec — none since this box last booted cold; a cold boot clears it, so for a sleep before that, read CloudTrail's StopInstances events for this instance"
    else
      echo "   • no sleep on record at $rec — the installed check is older than this checkout's, and records no sleep; for a sleep before the ground apply, read CloudTrail's StopInstances events for this instance"
    fi
    return 0
  fi
  head="$(head -1 <<< "$lines")"
  verdict="$(grove_provision_1_15_hibernate_record_verdict "$lines")"
  age="$(grove_provision_1_15_hibernate_configure_verify_age "$head")"
  echo "   • the last sleep, $head${age:+ ($age ago)}: ${verdict:-no verdict line in the record}"
  # the record lands before the act and reads `exit=0` once aws accepts it; `unanswered` means
  # the act failed or never returned, so this box may never have slept at all
  [[ "$head" == *" exit=unanswered" ]] || return 0
  # the act's 💥 lands in that same run's tick record, stamped with the same `at=`; any later
  # tick overwrites it, so the last tick names why only while it IS the sleep's run
  local tick why
  if tick="$(grove_provision_1_15_hibernate_record_lines)" && [[ "$(head -1 <<< "$tick" | cut -d' ' -f1)" == "${head%% *}" ]]; then
    # the 💥 is quoted here, from that tick's own record: "names why" with no line shown points nowhere
    why="$(grep -m1 '💥' <<< "$tick")"
    echo "     ⇒ the stop act never answered: this box judged itself idle and may never have slept — the 💥 in the last tick names why:"
    echo "       ${why:-its record holds no 💥 line — read the journal: rhx machine.journal.read --scope system --unit $GROVE_PROVISION_1_15_HIBERNATE_SERVICE}"
  else
    echo "     ⇒ the stop act never answered: this box judged itself idle and may never have slept — a later tick overwrote its 💥, so read why from the ground seat: rhx machine.journal.read --scope system --unit $GROVE_PROVISION_1_15_HIBERNATE_SERVICE"
  fi
}

# .what = the record beneath a non-clean Result, or where to read why when there is none
grove_provision_1_15_hibernate_configure_verify_record() {
  local result="$1" lines line at="$GROVE_PROVISION_1_15_HIBERNATE_RECORD"
  grove_provision_1_15_hibernate_result_has_record "$result" || return 0
  if ! lines="$(grove_provision_1_15_hibernate_record_lines)"; then
    echo "      ⇒ its record at $at is unreadable: $lines" >&2
    echo "      ⇒ from the ground seat, read why: rhx machine.journal.read --scope system --unit $GROVE_PROVISION_1_15_HIBERNATE_SERVICE --since today" >&2
    return 0
  fi
  echo "      ⇒ its record, at $at:" >&2
  while IFS= read -r line; do echo "      │ $line" >&2; done <<< "$lines"
}

grove_provision_1_15_hibernate_configure_verify() {
  local drift health result line
  drift="$(grove_provision_1_15_hibernate_drift)"
  health="$(grove_provision_1_15_hibernate_health)"
  if [[ -z "$drift" && -z "$health" ]]; then
    echo "   • the idle check and its units match this checkout ✔"
    echo "   • no drop-in of their own on either unit, no reload owed, and no stopgap ✔"
    echo "   • $GROVE_PROVISION_1_15_HIBERNATE_TIMER is enabled and active, and no failed run is on record ✔"
    grove_provision_1_15_hibernate_configure_verify_last_tick
    grove_provision_1_15_hibernate_configure_verify_last_sleep
    return 0
  fi

  # the ticks first: they answer "why is it awake?" on a drifted box too
  grove_provision_1_15_hibernate_configure_verify_last_tick
  grove_provision_1_15_hibernate_configure_verify_last_sleep

  # health before drift: the drift block closes on its own `⇒ now:` and `⇒ fix`, so a health ✋
  #   printed after it would read as if that fix were its own
  if [[ -n "$health" ]]; then
    # a `⇒` line is the gap above it continued — its fix — so it sits under that ✋, never as one
    while IFS= read -r line; do
      [[ "$line" == "⇒ "* ]] && { echo "      $line" >&2; continue; }
      echo "   ✋ $line" >&2
    done <<< "$health"
    # the Result's own record and gloss, when it names a run that did not go clean
    if result="$(grove_provision_1_15_hibernate_result)" && ! grove_provision_1_15_hibernate_result_is_clean "$result"; then
      grove_provision_1_15_hibernate_configure_verify_record "$result"
      echo "      ⇒ $(grove_provision_1_15_hibernate_result_gloss "$result")" >&2
    fi
  fi
  if [[ -n "$drift" ]]; then
    while IFS= read -r line; do
      echo "   ✋ $line" >&2
    done <<< "$drift"
    echo "      ⇒ now: $(grove_provision_1_15_hibernate_risk)" >&2
    echo "      ⇒ fix, from the ground seat: rhx grove.provision --what 1.15.hibernate --mode apply" >&2
  fi
  return 1
}
