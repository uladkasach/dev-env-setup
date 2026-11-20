#!/usr/bin/env bash
######################################################################
# .what = prove the box takes daily security updates and never reboots for them
#
# ⚠️ .why apt's MERGED config is read, not only our file
#   - a later drop-in (a `60…` a human or an image laid) would override ours,
#     and our file would still read byte-equal
#   - ⇒ `apt-config dump` answers what apt will actually do
#
# ⚠️ .why the timer is asked too
#   - the periodic values say WHAT to run; `apt-daily-upgrade.timer` is WHEN.
#     a box with the timer masked holds a perfect policy that never runs
#
# guarantee:
#   - READ-ONLY, and bounded: `systemctl` waits at most 5s
#   - an apt-config that cannot answer is named as that, never as a policy gap
#   - each claim prints its own verdict and returns 1 on a ✋, so the caller tallies
######################################################################

# claim 1 — each owned file is the declared one
grove_provision_1_14_updates_dropin_verify() {
  local declared="$1" live="$2"
  if ! cmp -s "$declared" "$live"; then
    echo "   ✋ ConstraintError: $live differs from the declared policy (or is absent)" >&2
    echo "      fix: from a seat with sudo: sudo -v && rhx grove.provision --what 1.14.updates --mode apply" >&2
    return 1
  fi
  echo "   • $live matches the declared policy ✔"
}

# claim 4 — the unattended run, and ONLY it, keeps a locally edited conffile
#   - the unit must hand APT_CONFIG to the run, and that file must say keep;
#     either half absent and an imagemagick security update waits forever
#   - the merged config every OTHER apt client reads must not say keep, else a
#     human's own upgrade drops a package's new conffile with no question asked
grove_provision_1_14_updates_keepconf_verify() {
  local merged="$1" keepconf env scoped
  keepconf="$(grove_provision_1_14_updates_keepconf)"
  env="$(timeout -k 2 5 systemctl show -p Environment apt-daily-upgrade.service 2>/dev/null)"
  if [[ "$env" != *"APT_CONFIG=$keepconf"* ]]; then
    echo "   ✋ ConstraintError: apt-daily-upgrade.service hands no APT_CONFIG=$keepconf to the unattended run" >&2
    echo "      ⇒ it skips any upgrade that would prompt over an edited conffile (imagemagick's policy.xml)" >&2
    echo "      read it: systemctl show -p Environment apt-daily-upgrade.service" >&2
    return 1
  fi
  scoped="$(APT_CONFIG="$keepconf" timeout -k 2 15 apt-config dump Dpkg::Options 2>&1)"
  if ! grove_provision_1_14_updates_dump_keeps_conffiles "$scoped"; then
    echo "   ✋ ConstraintError: the unattended run's apt config does not keep a local conffile" >&2
    echo "      read it: APT_CONFIG=$keepconf apt-config dump Dpkg::Options" >&2
    return 1
  fi
  if grove_provision_1_14_updates_dump_keeps_conffiles "$merged"; then
    echo "   ✋ ConstraintError: EVERY apt run keeps a local conffile silently, a human's included" >&2
    echo "      ⇒ a drop-in in /etc/apt/apt.conf.d/ sets Dpkg::Options; that choice belongs to the unattended run alone" >&2
    echo "      read it: grep -rn 'force-confold' /etc/apt/apt.conf.d/" >&2
    return 1
  fi
  echo "   • only the unattended run keeps a local conffile ✔ (a human's apt still asks)"
}

# claim 2a — apt runs unattended-upgrade daily
grove_provision_1_14_updates_daily_verify() {
  local dump="$1" live="$2"
  if [[ "$dump" != *'APT::Periodic::Unattended-Upgrade "1";'* ]]; then
    echo "   ✋ ConstraintError: apt's merged config does not run unattended-upgrade daily" >&2
    echo "      ⇒ a drop-in later than $live, or an absent one, overrides the policy" >&2
    echo "      read it: apt-config dump APT::Periodic" >&2
    return 1
  fi
  echo "   • apt runs unattended-upgrade daily ✔"
}

# claim 2b — unattended-upgrade never reboots this box
grove_provision_1_14_updates_noreboot_verify() {
  local dump="$1"
  if [[ "$dump" != *'Unattended-Upgrade::Automatic-Reboot "false";'* ]]; then
    echo "   ✋ ConstraintError: apt's merged config lets unattended-upgrade reboot this box" >&2
    echo "      ⇒ a reboot kills every duct pane and every run mid-flight" >&2
    echo "      read it: apt-config dump Unattended-Upgrade::Automatic-Reboot" >&2
    return 1
  fi
  echo "   • unattended-upgrade never reboots this box ✔"
}

# claim 2c — every allowed origin is a security origin
grove_provision_1_14_updates_origins_verify() {
  local dump="$1" live="$2" origins
  origins="$(grove_provision_1_14_updates_origins "$dump")"
  if ! grove_provision_1_14_updates_origins_are_security_only "$origins"; then
    echo "   ✋ ConstraintError: unattended-upgrade allows a non-security origin (or none at all)" >&2
    printf '%s\n' "${origins:-      (no origin listed)}" | sed 's/^/        /' >&2
    echo "      ⇒ a feature update could move a pinned tool on this box and not its peer" >&2
    echo "      read it: grep -rn 'Origins' /etc/apt/apt.conf.d/  — a drop-in later than $live names it" >&2
    return 1
  fi
  echo "   • only security origins are allowed ✔"
}

# claim 2d — the security origin the policy names is one this box's apt sources serve
#   - 📜 2026-11-17: `${distro_id}:…-security` reads `Pop:noble-security` on pop!_os,
#     which no archive carries; claim 2c read green and the daily run upgraded naught
#   - `apt-cache policy` reads the local lists only: no network, no root
grove_provision_1_14_updates_archive_verify() {
  local codename policy
  codename="$(grove_provision_1_14_updates_codename)"
  policy="$(timeout -k 2 15 apt-cache policy 2>/dev/null)"
  if ! grove_provision_1_14_updates_policy_serves_security "$policy" "$codename"; then
    echo "   ✋ ConstraintError: no apt source here serves o=Ubuntu,a=${codename:-<no codename>}-security" >&2
    echo "      ⇒ the policy allows only that archive, so the daily run would upgrade naught" >&2
    echo "      read it: apt-cache policy | grep -- '-security'" >&2
    echo "      fix: if the lists are stale, sudo apt update; if this box is not ubuntu-based," >&2
    echo "        its security archive needs its own Origins-Pattern row in 52grove-unattended-upgrades" >&2
    return 1
  fi
  echo "   • this box's apt sources serve the allowed security archive ✔ (o=Ubuntu,a=${codename}-security)"
}

# claim 3 — the timer that runs it is live
grove_provision_1_14_updates_timer_verify() {
  local timers
  timers="$(grove_provision_1_14_updates_timers | tr '\n' ' ')"
  if ! grove_provision_1_14_updates_timer_enabled; then
    echo "   ✋ ConstraintError: not every apt timer is enabled (${timers% })" >&2
    echo "      ⇒ the policy is declared and never runs" >&2
    echo "      fix: from a seat with sudo: sudo -v && rhx grove.provision --what 1.14.updates --mode apply" >&2
    return 1
  fi
  echo "   • ${timers% } are enabled ✔"
}

grove_provision_1_14_updates_configure_verify() {
  local declared live live_each dump failed=0
  live="$(grove_provision_1_14_updates_dropin)"

  while IFS=$'\t' read -r declared live_each; do
    grove_provision_1_14_updates_dropin_verify "$declared" "$live_each" || failed=1
  done < <(grove_provision_1_14_updates_files)

  # apt's merged config — stderr is kept: an apt-config that fails must say why,
  #   never read as "not daily". it is replayed under the 💥, never raw at column 0
  local errf
  errf="$(mktemp)" || { echo "   💥 MalfunctionError: mktemp failed, so apt-config's words could not be kept" >&2; return 1; }
  if ! dump="$(timeout -k 2 15 apt-config dump 2>"$errf")"; then
    echo "   💥 MalfunctionError: apt-config could not dump apt's merged config" >&2
    bundle.said "      " "$(cat "$errf")" >&2
    rm -f "$errf"
    return 1
  fi
  rm -f "$errf"
  grove_provision_1_14_updates_daily_verify "$dump" "$live" || failed=1
  grove_provision_1_14_updates_noreboot_verify "$dump" || failed=1
  grove_provision_1_14_updates_origins_verify "$dump" "$live" || failed=1
  grove_provision_1_14_updates_archive_verify || failed=1

  grove_provision_1_14_updates_keepconf_verify "$dump" || failed=1
  grove_provision_1_14_updates_timer_verify || failed=1

  return $failed
}
