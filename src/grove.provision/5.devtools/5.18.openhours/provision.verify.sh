#!/usr/bin/env bash
######################################################################
# .what = prove the three installed files match this checkout, the timer is
#         ENABLED and ACTIVE, the reconciler's cwd is BUILT and AT THE PIN, the
#         two gate skills ANSWER from it, and report the live gate state
# .why
#   - ⚠️ the timer needs BOTH `is-enabled` (next boot) and `is-active` (this one)
#   - 🛑 SKILL REACH is its own claim — every other row was ✔ on a box whose
#     cwd linked no role, so only an ask from that cwd proves the gate can move
#   - ⚠️ LINGER and the live gate are reported, never failed
#   - 🛑 the CONVERGE leg is unproven on a box with no drift, by design
# .refs = howdoes.the-openhours-gate-converges.md — how the verify proves the gate
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no gate and no unit
######################################################################

grove_provision_5_18_openhours_provision_verify() {
  local failed=0
  local bin_dir="$HOME/.local/bin"
  local unit_dir="$HOME/.config/systemd/user"

  ####################################################################
  # 0. the OPT-OUT claim — a torn-down box is CONVERGED, not broken
  #
  # ⚠️ the claim inverts with the flag. an opted-out box that still carries a
  #   live timer is the defect this reads for: the tree says no gate, and a
  #   timer that blocks commits anyway is a state no declaration holds
  ####################################################################
  if [[ "$GROVE_OPENHOURS_ENABLED" != "true" ]]; then
    local residue=0 state_out
    state_out="$(systemctl --user is-active machine_openhours_reconcile.timer 2>/dev/null)"
    [[ "$state_out" == "active" ]] && residue=1
    [[ -f "$unit_dir/machine_openhours_reconcile.timer" ]] && residue=1
    [[ -f "$bin_dir/machine_openhours_reconcile" ]] && residue=1

    if [[ "$residue" -eq 0 ]]; then
      echo "   • openhours is opted out, and no gate is installed ✔"
      echo "     opt in: set GROVE_OPENHOURS_ENABLED=true in this bundle's _.sh"
      return 0
    fi

    echo "   ✋ openhours is opted out and the box still carries a gate" >&2
    echo "      ⇒ the timer is '${state_out:-absent}' and its files remain, so a" >&2
    echo "        schedule no declaration holds still blocks commits" >&2
    echo "      fix: rhx grove.provision --what 5.18.openhours --mode apply" >&2
    return 1
  fi

  ####################################################################
  # 1. the three files match this checkout
  ####################################################################
  local pair
  for pair in \
    "machine_openhours_reconcile:$bin_dir/machine_openhours_reconcile" \
    "machine_openhours_reconcile.service:$unit_dir/machine_openhours_reconcile.service" \
    "machine_openhours_reconcile.timer:$unit_dir/machine_openhours_reconcile.timer"
  do
    local name="${pair%%:*}"
    local dst="${pair#*:}"
    local src="$GROVE_SRC/machine/$name"

    if [[ ! -f "$dst" ]]; then
      echo "   ✋ $name is absent from $dst" >&2
      echo "      fix: rhx grove.provision --what 5.18.openhours --mode apply" >&2
      failed=1
    elif [[ ! -f "$src" ]]; then
      echo "   🌙 $name is installed, but this checkout holds no $src"
    elif diff -q "$src" "$dst" >/dev/null 2>&1; then
      echo "   • $name matches this checkout ✔"
    else
      echo "   ✋ the installed $name DIFFERS from this checkout" >&2
      echo "      read the drift: diff $src $dst" >&2
      echo "      fix: rhx grove.provision --what 5.18.openhours --mode apply" >&2
      failed=1
    fi
  done

  # 2. the mode bit, which a byte-diff cannot see — an unexecutable payload
  #    fails every tick with 203/EXEC
  if [[ -x "$bin_dir/machine_openhours_reconcile" ]]; then
    echo "   • the reconciler is executable ✔"
  else
    echo "   ✋ $bin_dir/machine_openhours_reconcile is not executable" >&2
    echo "      ⇒ every tick fails 203/EXEC and the gate never converges" >&2
    echo "      fix: rhx grove.provision --what 5.18.openhours --mode apply" >&2
    failed=1
  fi

  # 2.5 the installed schedule matches the tree — a DIFF, never presence: a
  #     stale copy enforces yesterday's window
  local want_schedule
  want_schedule="$(grove_provision_5_18_openhours_schedule_render)"
  if [[ ! -f "$GROVE_OPENHOURS_SCHEDULE" ]]; then
    echo "   ✋ no schedule at $GROVE_OPENHOURS_SCHEDULE" >&2
    echo "      ⇒ the reconciler reads no window and dies on every tick" >&2
    echo "      fix: rhx grove.provision --what 5.18.openhours --mode apply" >&2
    failed=1
  elif diff -q <(printf '%s\n' "$want_schedule") "$GROVE_OPENHOURS_SCHEDULE" >/dev/null 2>&1; then
    echo "   • schedule matches the tree ✔ — days $GROVE_OPENHOURS_DAYS, ${GROVE_OPENHOURS_FROM}–${GROVE_OPENHOURS_TILL} $GROVE_OPENHOURS_ZONE"
  else
    echo "   ✋ the installed schedule DIFFERS from what the tree declares" >&2
    echo "      ⇒ the gate enforces a window no declaration holds" >&2
    echo "      the box holds:  cat $GROVE_OPENHOURS_SCHEDULE" >&2
    echo "      the tree wants: days $GROVE_OPENHOURS_DAYS, ${GROVE_OPENHOURS_FROM}–${GROVE_OPENHOURS_TILL} $GROVE_OPENHOURS_ZONE" >&2
    echo "      fix: rhx grove.provision --what 5.18.openhours --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 3. THE claim — the timer is live NOW and survives a reboot
  ####################################################################
  local state_active state_enabled
  state_active="$(systemctl --user is-active machine_openhours_reconcile.timer 2>/dev/null)"
  state_enabled="$(systemctl --user is-enabled machine_openhours_reconcile.timer 2>/dev/null)"

  if [[ "$state_active" == "active" ]]; then
    local next
    next="$(systemctl --user list-timers machine_openhours_reconcile.timer --no-pager 2>/dev/null | head -2 | tail -1)"
    echo "   • machine_openhours_reconcile.timer is active ✔"
    [[ -n "$next" ]] && echo "     next: $next"
  else
    echo "   ✋ machine_openhours_reconcile.timer is '${state_active:-absent}', not active" >&2
    echo "      ⇒ every file above can be byte-perfect and the gate never moves" >&2
    echo "      read why: systemctl --user status machine_openhours_reconcile.timer" >&2
    echo "      fix: rhx grove.provision --what 5.18.openhours --mode apply" >&2
    failed=1
  fi

  if [[ "$state_enabled" == "enabled" ]]; then
    echo "   • the timer is enabled — it returns after a reboot ✔"
  else
    echo "   ✋ the timer is '${state_enabled:-absent}', not enabled" >&2
    echo "      ⇒ it may be active THIS boot and gone the next, so the gate" >&2
    echo "        silently stops converging while the check above passes" >&2
    echo "      fix: rhx grove.provision --what 5.18.openhours --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 4. can the reconciler REACH the two gate skills — see the header
  ####################################################################
  # ⚠️ the SHARED three-valued reader, never a `[[ -d ]]` here. one set, one
  #   cut — the upsert decides whether to build on the same fact this grades
  #   (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
  local skill probe_rc probe_out cwd_state
  cwd_state="$(grove_provision_5_18_openhours_cwd_state)"

  case "$cwd_state" in
    whole)
      echo "   • the reconciler's cwd is built and at the pin ✔"
      echo "     $GROVE_OPENHOURS_CWD"
      ;;
    absent)
      echo "   ✋ the reconciler's cwd was never built at $GROVE_OPENHOURS_CWD" >&2
      echo "      ⇒ rhx resolves a skill among the roles linked into its cwd, so" >&2
      echo "        every tick dies before it reads a clock" >&2
      echo "      fix: rhx grove.provision --what 5.18.openhours --mode apply" >&2
      failed=1
      ;;
    *)
      echo "   ✋ the reconciler's cwd reads 'half' — built, and not to the pin" >&2
      echo "      ⇒ expected a git repo that holds both gate skills at:" >&2
      echo "        ${GROVE_OPENHOURS_ROLE_PKGS[*]}" >&2
      echo "      fix: rhx grove.provision --what 5.18.openhours --mode apply" >&2
      failed=1
      ;;
  esac

  # 🛑 the state reader proves no part of REACH — only an ask from that cwd does
  if [[ "$cwd_state" == "whole" ]]; then
    for skill in "git.commit.uses" "radio.uses"; do
      probe_rc=0
      probe_out="$( cd "$GROVE_OPENHOURS_CWD" && rhx "$skill" get --global 2>&1 )" || probe_rc=$?
      if [[ "$probe_rc" -eq 0 ]]; then
        echo "   • rhx $skill answers from that cwd ✔"
      else
        echo "   ✋ rhx $skill did not answer (exit $probe_rc)" >&2
        echo "      ⇒ the timer ticks, the clock math runs, and the gate never" >&2
        echo "        moves — a failure with no symptom except an open gate" >&2
        # ⚠️ the probe's OWN sentence, quoted — never the stack frames (q1)
        echo "$probe_out" \
          | grep -iE '(error|✋|🛑|no skill|not found|required)' \
          | grep -vE '^\s*(at |[0-9]+ \|)' | head -4 \
          | sed 's/^/        │ /' >&2
        echo "      read why: cd $GROVE_OPENHOURS_CWD && rhx $skill get --global" >&2
        failed=1
      fi
    done
  fi

  ####################################################################
  # 5. linger — reported, never failed (see the header)
  ####################################################################
  local linger
  linger="$(loginctl show-user "$USER" --property=Linger --value 2>/dev/null)"
  if [[ "$linger" == "yes" ]]; then
    echo "   • linger is on — the timer survives a logout ✔"
  else
    echo "   🌙 linger is off for '$USER'"
    echo "      harmless while a human session is live; on a HEADLESS box the"
    echo "      user manager exits with the last session and the gate stops."
    echo "      grant it from a seat with sudo: sudo loginctl enable-linger $USER"
  fi

  # 6. what the gate reads RIGHT NOW — reported, never failed: an assert would
  #    be a second copy of the policy the payload owns
  local commit_meter="$HOME/.rhachet/storage/repo=ehmpathy/role=mechanic/.meter/git.commit.uses.jsonc"
  local radio_meter="$HOME/.rhachet/storage/repo=bhuild/role=dispatcher/.meter/radio.uses.global.jsonc"
  local commit_now="open" radio_now="open"
  [[ -f "$commit_meter" ]] && commit_now="closed"
  [[ -f "$radio_meter"  ]] && radio_now="closed"
  echo "   • gate right now — commit: $commit_now · radio: $radio_now"
  echo "     read the store: rhx rhachet.storage.get --what '.meter/*' --body"

  # 7. 🛑 the one claim NO verify here can make — the CONVERGE leg runs only on
  #    drift, and to manufacture drift would OPEN a gate a human closed
  echo "   🌙 the CONVERGE leg is unproven on a box with no drift"
  echo "      it runs only when the gate disagrees with the clock, so the next"
  echo "      real boundary crossing is what proves it. read the verdict:"
  echo "        journalctl --user -u machine_openhours_reconcile.service --since today"

  return $failed
}
