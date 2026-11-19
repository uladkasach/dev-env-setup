#!/usr/bin/env bash
######################################################################
# .what = install this bundle's apt drop-in: daily, security origin only,
#         never a reboot (`52grove-unattended-upgrades`, beside this file)
#
# .why a drop-in of our own, never an edit of the package's files
#   - `50unattended-upgrades` is the package's conffile and `20auto-upgrades`
#     is debconf's; an edit to either is a second writer on their bytes, and a
#     package upgrade prompts over it on a box no human sits at
#   - apt reads `apt.conf.d/` in name order and the last value wins, so `52…`
#     overrides both and owns every value it sets; `#clear` empties the origin
#     lists first, so the package's own list cannot widen ours
#
# guarantee:
#   - idempotent: a byte-equal drop-in is a no-op, with no root asked
#   - reads the box first; a seat with no root declines by name
#   - every root call is bounded; `systemctl` dials a socket that can hang
######################################################################

# .what = write one owned file as root; the unit drop-in owes systemd a reload
grove_provision_1_14_updates_file_install() {
  local declared="$1" live="$2" said
  if ! said="$(timeout -k 5 30 sudo install -D -m 0644 -o root -g root "$declared" "$live" 2>&1)"; then
    echo "   💥 MalfunctionError: could not write $live" >&2
    bundle.said "      " "$said" >&2
    echo "      read why: ls -ld $(dirname "$live")" >&2
    return 1
  fi
  echo "   • $live written"
  [[ "$live" == "$(grove_provision_1_14_updates_unitdropin)" ]] || return 0
  said="$(timeout -k 5 30 sudo systemctl daemon-reload 2>&1)" && return 0
  echo "   💥 MalfunctionError: $live is on disk and systemd did not reload it" >&2
  bundle.said "      " "$said" >&2
  echo "      read why: systemctl status apt-daily-upgrade.service" >&2
  return 1
}

grove_provision_1_14_updates_configure_upsert() {
  local declared live stale=() timer_current=0

  # every owned file: absent from the checkout is a fault; differs on the box is owed
  while IFS=$'\t' read -r declared live; do
    if [[ ! -r "$declared" ]]; then
      echo "   💥 MalfunctionError: the declared file is absent at $declared" >&2
      echo "      ⇒ the checkout is partial; re-pull it, then re-run" >&2
      return 1
    fi
    cmp -s "$declared" "$live" || stale+=("$declared"$'\t'"$live")
  done < <(grove_provision_1_14_updates_files)
  grove_provision_1_14_updates_timer_enabled && timer_current=1

  if (( ${#stale[@]} == 0 && timer_current )); then
    echo "   • policy, unattended conffile choice, and both apt timers current ✔ (daily, security only, no reboot)"
    return 0
  fi

  bundle.root.owns "the unattended-upgrades policy" \
    "${#stale[@]} policy file(s) out of date, apt timers $( (( timer_current )) && echo enabled || echo 'not enabled')" || return 0
  pkg_assert_sudo || return 1

  local pair
  for pair in "${stale[@]}"; do
    grove_provision_1_14_updates_file_install "${pair%%$'\t'*}" "${pair#*$'\t'}" || return 1
  done

  # the periodic values say WHAT to run; the timers are WHEN — a masked timer runs naught
  (( timer_current )) && return 0
  local timers
  mapfile -t timers < <(grove_provision_1_14_updates_timers)
  # 🛑 a MASKED unit is an admin's deliberate "never run this" — the apply does not
  #   override it. it fails loud and names the one command that lifts the mask, so the
  #   verify's fix (this apply) still has an exit, and the human makes the call
  local unit masked=()
  for unit in "${timers[@]}"; do
    [[ "$(timeout -k 5 10 systemctl is-enabled "$unit" 2>/dev/null)" == masked ]] && masked+=("$unit")
  done
  if (( ${#masked[@]} )); then
    echo "   ✋ ConstraintError: a masked apt timer, so the policy on disk never runs (${masked[*]})" >&2
    echo "      ⇒ a mask is an admin's own refusal, and this apply does not lift it" >&2
    echo "      fix: if the box should take security updates, lift it, then re-apply —" >&2
    echo "        sudo systemctl unmask ${masked[*]}" >&2
    echo "        rhx grove.provision --what 1.14.updates --mode apply" >&2
    return 2
  fi
  local said
  if ! said="$(timeout -k 5 30 sudo systemctl enable --now "${timers[@]}" 2>&1)"; then
    echo "   💥 MalfunctionError: could not enable ${timers[*]}" >&2
    echo "      ⇒ the policy is on disk and never runs" >&2
    bundle.said "      " "$said" >&2
    echo "      read why: systemctl status ${timers[*]}" >&2
    return 1
  fi
  echo "   • ${timers[*]} enabled"
}
