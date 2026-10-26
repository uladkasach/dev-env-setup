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
#     an enabled timer cannot see that. `1.6.7.linger` owns that claim, for
#     every seat; this bundle no longer restates it
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

# .what = the prune skill, as an absolute path off THIS run's checkout
# .why  = `.agent/` sits beside `$GROVE_SRC`; a hard-coded checkout path is
#         false on any worktree
# 🛑 apply `--from main` — a `--from tree` apply binds a PERMANENT timer to a
#    worktree a remove can delete, and a worktree plan's drift ✋ is CORRECT
#   the checkout root is `$GROVE_SRC`'s parent, cut by string so no `..` reaches a unit or a message
grove_provision_1_6_4_keyrackd_skill() {
  local src="${GROVE_SRC%/}"
  printf '%s/.agent/repo=.this/role=any/skills/keyrack.daemon.prune.sh' "${src%/*}"
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

# .what = whether the unit at $1 holds the declared service bytes, exact
# .why  = a pipe into `cmp -s -` leaves its writer on EPIPE when cmp exits before it reads
#         (an absent unit); where SIGPIPE is ignored, as on a CI runner, the writer prints
#         `write error: Broken pipe` into the phase's own output. each side is read whole,
#         a sentinel keeps the final newlines, and no pipe is left to break
grove_provision_1_6_4_keyrackd_service_matches() {
  local unit="$1" want got
  [[ -f "$unit" ]] || return 1
  want="$(grove_provision_1_6_4_keyrackd_service_text; printf x)"
  got="$(cat -- "$unit"; printf x)"
  [[ "$want" == "$got" ]]
}

grove_provision_1_6_4_keyrackd() {
  bundle.upgrade 1.6.4.keyrackd.provision.upsert
  bundle.upgrade 1.6.4.keyrackd.provision.verify
}
