#!/usr/bin/env bash
######################################################################
# .what = install the backup agent, its library, and its two units; enable the timer
#
# .why no early return on "the timer exists": each file is compared by CONTENT
#   (`cmp`), so a changed source re-copies on the next apply and only a matched
#   box is skipped (the write-once defect `1.8.tmpfiles` records)
# .why `daemon-reload` before `enable --now`: systemd caches unit files, so a
#   rewrite with no reload leaves the OLD definition live
# .why the box is READ before root is asked for: the camper seat holds no sudo,
#   so on a converged box it reports ✔ and on an unconverged one it declines,
#   and `ground`'s apply of this same bundle sets it (`bundle.root.declines`)
#
# guarantee:
#   - idempotent: a second apply on a converged box writes naught
######################################################################

grove_provision_5_24_backup_provision_upsert() {
  if ! grove_provision_5_24_backup_applies; then
    echo "   🌙 a ${GROVE_ENV_SERVER:-（underived）} box holds no grove role; grove backup is for groves"
    return 0
  fi

  ####################################################################
  # 0. what is ALREADY true — read before any privilege is asked for
  ####################################################################
  local src dst mode converged=1
  while IFS=$'\t' read -r src dst mode; do
    cmp -s "$src" "$dst" || converged=0
  done < <(grove_provision_5_24_backup_files)
  systemctl is-enabled grove-backup.timer >/dev/null 2>&1 || converged=0
  systemctl is-active grove-backup.timer >/dev/null 2>&1 || converged=0

  if [[ "$converged" -eq 1 ]]; then
    echo "   • the agent and its units match this checkout, and the timer is enabled ✔"
    return 0
  fi

  if ! pkg_can_sudo; then
    # ⚠️ `is-active` prints its word AND exits non-zero, so `|| echo` would print a second
    local state
    state="$(systemctl is-active grove-backup.timer 2>/dev/null)"
    bundle.root.declines "the grove backup agent" "grove-backup.timer is ${state:-absent}"
    return 0
  fi
  pkg_assert_sudo || return 1

  ####################################################################
  # 1. the four files — each from its declared source, every run
  ####################################################################
  while IFS=$'\t' read -r src dst mode; do
    if [[ ! -f "$src" ]]; then
      echo "   ✋ no $(basename "$src") at $src" >&2
      echo "      ⇒ this run's own checkout is incomplete" >&2
      return 1
    fi
    sudo install -D -m "$mode" -o root -g root "$src" "$dst" || return 1
  done < <(grove_provision_5_24_backup_files)
  echo "   • the agent, its library, grove-backup.service, and grove-backup.timer declared"

  ####################################################################
  # 2. reload FIRST, then enable — see the header
  ####################################################################
  sudo systemctl daemon-reload || {
    echo "   ✋ systemctl daemon-reload failed" >&2
    echo "      ⇒ the new unit files are on disk and the OLD definitions stay live" >&2
    return 1
  }

  if sudo systemctl enable --now grove-backup.timer; then
    echo "   • grove-backup.timer enabled and started (hourly, Persistent=true)"
  else
    echo "   ✋ could not enable grove-backup.timer" >&2
    echo "      ⇒ no backup runs, and this grove's unpushed work has one copy" >&2
    echo "      read why: systemctl status grove-backup.timer" >&2
    return 1
  fi
}
