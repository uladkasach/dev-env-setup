#!/usr/bin/env bash
######################################################################
# .what = host security updates, applied by the box itself —
#         `unattended-upgrades`, security origin only, never a reboot
#
# .why
#   - a grove's bootstrap installed it by hand, outside the inventory
#   - security origin only: a feature update can move a pinned tool mid-week
#   - never a reboot: a duct is tmux, and a reboot kills every pane mid-run;
#     on a laptop it kills the human's session
#   - EVERY kind: no physical fact keeps a laptop from it. the tool asks no
#     question, so there is no prompt to gate, and a human at the keyboard is a
#     capability claim, never a reason to decline
#     (`rule.forbid.divergence-without-a-physical-reason`)
#   - every write is root's, so a seat with no sudo declines by name
#
# usage:
#   rhx grove.provision --what 1.14.updates --mode apply
#   sudo -v && rhx grove.provision --what 1.14.updates --mode apply   # a laptop
######################################################################

# .what = the apt drop-in this bundle owns, by its live path
# .why `52` sorts after `20auto-upgrades` and `50unattended-upgrades`, so its values win
grove_provision_1_14_updates_dropin() { printf '/etc/apt/apt.conf.d/52grove-unattended-upgrades'; }

# .what = the drop-in this checkout declares
# .note the path is a literal assignment: `prove.declared-assets-are-tracked` reads
#       it there, and reads no `printf` (it strips those as fix-text)
grove_provision_1_14_updates_declared() {
  local declared="$GROVE_SRC/grove.provision/1.system/1.14.updates/52grove-unattended-upgrades"
  printf '%s' "$declared"
}

# .what = the conffile choice, scoped to the unattended run ALONE
# .why  = `4.5.nvim` fences its rules into imagemagick's policy.xml, a package conffile.
#   unattended-upgrade skips any package whose upgrade would prompt over an edited
#   conffile, so with no choice declared that security update would wait forever.
#   the choice (keep ours; the next apply re-fences) is declared in a file apt reads
#   ONLY where `APT_CONFIG` names it — and only the timer's service names it. a human's
#   own `sudo apt upgrade` reads naught of it, and still asks
grove_provision_1_14_updates_keepconf() { printf '/etc/apt/grove-unattended-keep-conffiles.conf'; }
grove_provision_1_14_updates_keepconf_declared() {
  local declared="$GROVE_SRC/grove.provision/1.system/1.14.updates/grove-unattended-keep-conffiles.conf"
  printf '%s' "$declared"
}

# .what = the systemd drop-in that hands the keepconf file to the unattended run
grove_provision_1_14_updates_unitdropin() { printf '/etc/systemd/system/apt-daily-upgrade.service.d/52grove-keep-conffiles.conf'; }
grove_provision_1_14_updates_unitdropin_declared() {
  local declared="$GROVE_SRC/grove.provision/1.system/1.14.updates/apt-daily-upgrade.keep-conffiles.conf"
  printf '%s' "$declared"
}

# .what = the (declared, live) pairs this bundle owns, one per line, tab-separated
# .note = shared by configure.upsert (what to write) and configure.verify (what to compare)
grove_provision_1_14_updates_files() {
  printf '%s\t%s\n' \
    "$(grove_provision_1_14_updates_declared)" "$(grove_provision_1_14_updates_dropin)" \
    "$(grove_provision_1_14_updates_keepconf_declared)" "$(grove_provision_1_14_updates_keepconf)" \
    "$(grove_provision_1_14_updates_unitdropin_declared)" "$(grove_provision_1_14_updates_unitdropin)"
}

# .what = are BOTH of apt's daily timers enabled? (bounded: systemctl dials a socket)
# .why  = `apt-daily.timer` refreshes the lists, `apt-daily-upgrade.timer` applies them;
#   either one masked leaves a declared policy that upgrades naught
grove_provision_1_14_updates_timers() { printf '%s\n' apt-daily.timer apt-daily-upgrade.timer; }
grove_provision_1_14_updates_timer_enabled() {
  local t
  for t in $(grove_provision_1_14_updates_timers); do
    [[ "$(timeout -k 2 5 systemctl is-enabled "$t" 2>/dev/null)" == enabled ]] || return 1
  done
}

# .what = do these Dpkg options keep a local conffile with no prompt? (a transformer)
grove_provision_1_14_updates_dump_keeps_conffiles() {
  [[ "$1" == *'"--force-confold";'* && "$1" == *'"--force-confdef";'* ]]
}

# .what = the origin rows of an `apt-config dump`, one per line (a transformer)
# .why  = the two keys unattended-upgrade reads its sources from, named once
grove_provision_1_14_updates_origins() {
  printf '%s\n' "$1" | awk '/^Unattended-Upgrade::(Allowed-Origins|Origins-Pattern):: /'
}

# .what = are these origin rows all security origins, and at least one? (a transformer)
grove_provision_1_14_updates_origins_are_security_only() {
  [[ -n "$1" ]] || return 1
  ! printf '%s\n' "$1" | grep -qv 'security'
}

# .what = this box's release codename, as unattended-upgrade reads it (a reader)
# .why  = pop!_os names its own VERSION_CODENAME and carries ubuntu's in UBUNTU_CODENAME;
#   the security archive is ubuntu's, so ubuntu's codename is the one that matches
grove_provision_1_14_updates_codename() {
  local f="${GROVE_PROVISION_1_14_OS_RELEASE:-/etc/os-release}"
  ( . "$f" 2>/dev/null; printf '%s' "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}" )
}

# .what = does this box's apt policy serve the security archive the policy names? (a transformer)
# .why  = an origin row that matches no archive upgrades naught and reads green
grove_provision_1_14_updates_policy_serves_security() {
  local policy="$1" codename="$2"
  [[ -n "$codename" && "$policy" == *"o=Ubuntu,a=${codename}-security"* ]]
}

grove_provision_1_14_updates() {
  bundle.upgrade 1.14.updates.provision.upsert
  bundle.upgrade 1.14.updates.provision.verify
  bundle.upgrade 1.14.updates.configure.upsert
  bundle.upgrade 1.14.updates.configure.verify
}
