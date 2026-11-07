#!/usr/bin/env bash
######################################################################
# .what = prove the agent is enrolled AND that its last run landed
#
# 🛑 .why the RUN is its own claim
#   - every file can match and the timer can be active while each run fails —
#     no bucket declared, no credential, a grant refused
#   - ⇒ an enrollment check alone would print ✔ over a grove whose work has one
#     copy, which is the exact silence this bundle exists to end (case=3)
#   - so the verify renders the status line every surface renders, and a ✗ there
#     is a ✗ here, with the cause and the fix's owner
#
# .why a fresh enroll is ✓ with no run yet: the timer fires at the top of the
#   hour, so a box enrolled minutes ago has had no chance to run. that grace
#   ends after two hours, when "no run yet" becomes ✗ STALE · never
#
# guarantee:
#   - READ-ONLY. the camper seat runs it with no sudo; every read is world-readable
######################################################################

grove_provision_5_24_backup_provision_verify() {
  if ! grove_provision_5_24_backup_applies; then
    echo "   🌙 a ${GROVE_ENV_SERVER:-（underived）} box holds no grove role; grove backup is for groves"
    return 0
  fi

  # shellcheck source=./grove.backup.operations.sh
  source "$GROVE_SRC/grove.provision/5.devtools/5.24.backup/grove.backup.operations.sh"

  # the fix names the seat that can make it: a seat with no sudo cannot enroll a root unit
  local failed=0 fix="rhx grove.provision --what 5.24.backup --mode apply"
  pkg_can_sudo || fix="$fix, from the seat with sudo (ground); this seat holds none"

  ####################################################################
  # 1. the four files match this checkout
  ####################################################################
  local src dst mode absent=0
  while IFS=$'\t' read -r src dst mode; do
    if [[ ! -f "$dst" ]]; then
      absent=1
      failed=1
    elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
      echo "   ✋ the installed $dst DIFFERS from this checkout" >&2
      echo "      read the drift: diff $src $dst" >&2
      echo "      fix: $fix" >&2
      failed=1
    fi
  done < <(grove_provision_5_24_backup_files)

  if [[ "$absent" -eq 1 ]]; then
    echo "   ✗ grove backup · NOT ENROLLED" >&2
    echo "      └─ fix: $fix" >&2
    return 1
  fi

  ####################################################################
  # 2. the timer is live now, and returns after a reboot
  ####################################################################
  local active enabled
  active="$(systemctl is-active grove-backup.timer 2>/dev/null)"
  enabled="$(systemctl is-enabled grove-backup.timer 2>/dev/null)"
  if [[ "$active" != active || "$enabled" != enabled ]]; then
    echo "   ✗ grove backup · NOT ENROLLED · timer is ${active:-absent}, ${enabled:-absent}" >&2
    echo "      └─ fix: $fix" >&2
    return 1
  fi

  local next_at next_in=""
  next_at="$(systemctl show grove-backup.timer -p NextElapseUSecRealtime --value 2>/dev/null)"
  next_at="$(date -u -d "$next_at" +%s 2>/dev/null)" \
    && next_in=" · next run in $(grove_backup_age $(( next_at - $(grove_backup_now) )))"

  ####################################################################
  # 3. THE claim — the last run landed every unit
  ####################################################################
  if [[ ! -f "$(grove_backup_status_file)" ]]; then
    local since
    since="$(systemctl show grove-backup.timer -p ActiveEnterTimestamp --value 2>/dev/null)"
    since="$(date -u -d "$since" +%s 2>/dev/null)" || since=0
    if (( $(grove_backup_now) - since < GROVE_BACKUP_STALE_SECS )); then
      echo "   • grove backup · enrolled${next_in} ✔"
      return "$failed"
    fi
  fi

  local line
  if line="$(grove_backup_status_line enrolled)"; then
    echo "   • grove backup · ${line}${next_in} ✔"
    return "$failed"
  fi

  echo "   ✗ grove backup · ${line#✗ }" >&2
  local owed
  owed="$(jq -r '.fix // empty' "$(grove_backup_status_file)" 2>/dev/null)"
  [[ -n "$owed" ]] && echo "      ├─ $owed" >&2
  jq -r '.failures[]? | "      ├─ \(.unit): \(.why)"' "$(grove_backup_status_file)" 2>/dev/null | head -n 10 >&2
  echo "      └─ read the runs: journalctl -u grove-backup --since -3h" >&2
  return 1
}
