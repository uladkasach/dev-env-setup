#!/usr/bin/env bash
######################################################################
# .what = a USER systemd timer that prunes orphaned keyrack daemons every 15
#         minutes, so the leaked-daemon population stays bounded with no human
#         in the loop
# .why
#   - 🛑 the slug says `keyrackd`, NEVER `rack` — `rack` names the credential
#     STORE, and "rackprune" reads as a prune of it
#   - it sits under `1.6.procs`: the subject is a leaked process POOL
#   - a timer, since 152 spawns/hour outrun any hand-run prune
#   - ⚠️ `--min-age 10`, since a 60m gate skips most of the live pool
#   - 🛑 the TIMER is an asset and the SERVICE is generated, from one reader
#     both halves ask, since its ExecStart names this box's checkout
#   - 🛑 a grove needs LINGER — its user manager dies when the duct closes, and
#     an enabled timer cannot see that
#   - ⚠️ an absent skill (a `--from src` push) is a 🌙, never a ✋
# .refs = howdoes.the-keyrackd-prune-stays-bounded.md — every .why, measured
#
# usage:
#   rhx grove.provision --what 1.6.4.keyrackd --mode plan
#   rhx grove.provision --what 1.6.4.keyrackd --mode apply
######################################################################

# .what = the unit names, spelled once
grove_provision_1_6_4_keyrackd_service_name() { printf 'keyrack_daemon_prune.service'; }
grove_provision_1_6_4_keyrackd_timer_name()   { printf 'keyrack_daemon_prune.timer'; }

# .what = where a user unit lives on this seat
grove_provision_1_6_4_keyrackd_unit_dir() { printf '%s/.config/systemd/user' "$HOME"; }

# .what = the age gate this box runs with — see the ⚠️ above for why not 60
grove_provision_1_6_4_keyrackd_min_age() { printf '10'; }

# .what = does this seat's user manager survive its last logout?
# .why  = one reader, asked by both halves (rule.require.one-command-provision)
# ⚠️ `show-user` FAILS for a seat with no session and no linger — that and
#    `Linger=no` both read "no"
grove_provision_1_6_4_keyrackd_lingers() {
  loginctl show-user "$USER" --property=Linger 2>/dev/null \
    | grep -qx 'Linger=yes'
}

# .what = the prune skill, as an absolute path off THIS run's checkout
# .why  = `.agent/` sits beside `$GROVE_SRC`; a hard-coded checkout path is
#         false on any worktree
# 🛑 apply `--from main` — a `--from tree` apply binds a PERMANENT timer to a
#    worktree a remove can delete, and a worktree plan's drift ✋ is CORRECT
grove_provision_1_6_4_keyrackd_skill() {
  printf '%s/../.agent/repo=.this/role=any/skills/keyrack.daemon.prune.sh' "$GROVE_SRC"
}

# .what = the DECLARED service bytes for this box
# .why  = one reader, asked by the upsert that writes it AND the verify that
#         diffs it. a reader in `_.sh` that only one half asks means the two
#         halves cut the set their own way (rule.require.one-command-provision)
grove_provision_1_6_4_keyrackd_service_text() {
  local skill
  skill="$(grove_provision_1_6_4_keyrackd_skill)"
  cat <<SERVICE
[Unit]
Description=Prune orphaned keyrack daemons

[Service]
Type=oneshot
ExecStart=$skill --min-age $(grove_provision_1_6_4_keyrackd_min_age) --mode apply
SERVICE
}

grove_provision_1_6_4_keyrackd() {
  bundle.upgrade 1.6.4.keyrackd.provision.upsert
  bundle.upgrade 1.6.4.keyrackd.provision.verify
}
