#!/usr/bin/env bash
######################################################################
# .what = a USER systemd timer that prunes orphaned keyrack daemons every 15
#         minutes, so the leaked-daemon population stays bounded with no human
#         in the loop
#
# 🛑 .why the slug says `keyrackd` and NEVER `rack`
#   - `rack` is a declared term, and it names the credential STORAGE:
#     `~/.rhachet/keyrack/`, its host manifest, its vault files
#     (`term=rack._.choice._.md`). `5.12.rack` is the bundle that owns it
#   - so a slug of `rackprune` reads as *"prune the credential store"* — a
#     destructive act on the one store this bundle must never touch, and the
#     exact misread `term=prune` exists to prevent
#   - 📜 that slug shipped for an hour on 2026-09-08 before the glossary round
#     caught it. an overload is easiest to commit on the round you MERGE the
#     term, because the word is fresh in the hand and its forbid list is not
#   - ⇒ `keyrack` is the COMMAND, which `term=rack` keeps legal for exactly
#     that use, and `-d` is unix's suffix for a program's daemons. the subject
#     is the daemon POOL, so the slug names the daemons
#
# .why it sits under `1.6.procs` and not under `5.12.rack`
#   - `1.6.procs` is the RUNAWAY-PROCESS concern, and it splits its leaves by
#     WHO asks: a human (`1.6.1.finders`), a timer (`1.6.2.monitor`), no one
#     (`1.6.3.earlyoom`). this is the timer arm for a second population
#   - the subject is the leaked daemon POOL, never keyrack the tool. `earlyoom`
#     likewise kills processes it did not create
#   - `5.12.rack` owns the rack's STORAGE — a manifest entry. a box can hold
#     one concern and not the other
#
# .why a timer, and not a chore a human remembers
#   - each `rhx` invocation may spawn a keyrack daemon under a temp home
#     (`/tmp/pii-brain-live-*`). when its spawner exits, the daemon orphans to
#     pid 1 and holds ~55MB of ANON memory — the one kind that must swap
#   - measured 152 spawns/hour, so a hand-run prune cannot keep up: by
#     2026-08-30 the pool held 191 daemons and the box was 17.4G into swap. an
#     earlier incident reached 641
#   - the daemons are invisible to `ps` aggregation (each is merely `node`,
#     each reparented), so only a scheduled prune keeps the pool bounded
#   - ref: `hazard.idle-process-leak-crosses-the-swap-cliff.md`
#
# ⚠️ .why `--min-age 10`, not the skill's 60m default
#   - at 152/hour a 60m gate skips the whole live population: it caught 17 of
#     191, where 10m caught 122 (`term=prune._.choice.reason.md`)
#   - age is the WEAKEST of the skill's three predicates. the real safety is
#     "temp home AND spawner dead", and 10 minutes already clears the fork race
#
# 🛑 .why the SERVICE is generated and the TIMER is an asset
#   - the timer holds no path, so it is a tracked file under `src/machine/` and
#     `provision.verify` can `cmp` the installed copy against it, exactly as
#     `1.8.tmpfiles` does
#   - the service holds an ExecStart that names THIS BOX's checkout, so no one
#     file can be the declared bytes for every box. it is generated instead —
#     but from ONE reader that BOTH halves ask, so the verify still diffs
#     installed bytes against declared ones
#   - ⇒ this is not the heredoc defect `1.6.procs/_.sh` warns about. that one
#     had no reader to compare against; this one does
#
# 🛑 .why a grove needs LINGER, and the laptop never did
#   - a `systemctl --user` manager starts at a seat's first login and STOPS at
#     its last logout. a laptop's graphical session never logs out, so every
#     prior user timer here (`1.6.2.monitor`, `4.3.4.snapshot`, `6.5.onepassword`)
#     was born on a box that keeps its manager alive for free
#   - a grove has no graphical session. its only login is the duct, so the
#     manager — and this timer with it — dies the moment that pane closes
#   - ⇒ `loginctl enable-linger` is what keeps a user manager up past logout,
#     and it is the ONE part of this bundle a seat without sudo cannot do for
#     itself. ground sets it for every human seat, camper included
#     (`rule.require.seam-claims-have-an-owner`; `5.8.docker` set the precedent)
#
# ⚠️ .why an ENABLED timer is not evidence the prune runs
#   - `is-enabled` and `is-active` both answer from INSIDE a live user manager,
#     so on a grove they answer ✔ right up until the duct closes and the whole
#     manager goes with them. neither can see its own mortality
#   - ⇒ linger is a THIRD claim, and the only one that outlives the session that
#     put the question
#
# ⚠️ .why the skill can be ABSENT, and why that is a 🌙 rather than a ✋
#   - the skill lives under `.agent/`, which sits OUTSIDE `src/`. `boot` pushes
#     `--from .` precisely so a grove holds it (`git.grove.provision.boot.sh`),
#     so a booted grove HAS the skill and this decline does not fire there
#   - it fires on a box pushed by hand with `--from src`, which several howtos
#     still spell. an unprunable box is a degradation, never a failed provision,
#     so the phase reports and continues
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
#
# .why  = both halves ask it — the upsert to know whether a write is owed, the
#         verify to make it a claim. one reader, so the two cannot cut it their
#         own way (rule.require.one-command-provision)
#
# ⚠️ `show-user` FAILS outright for a seat with no session and no linger, which
#    is the exact state a grove's camper sits in between ducts. so the absent
#    case and the `Linger=no` case must both read as "no", and a bare exit-code
#    test would call the first an error
grove_provision_1_6_4_keyrackd_lingers() {
  loginctl show-user "$USER" --property=Linger 2>/dev/null \
    | grep -qx 'Linger=yes'
}

# .what = the prune skill, as an absolute path off THIS run's checkout
# .why  = `$GROVE_SRC` is `<checkout>/src`, and `.agent/` sits beside it. a
#         hard-coded `~/git/more/dev-env-setup` would be the first checkout-path
#         assertion in the whole bundle tree, and it is false on any worktree
#
# 🛑 .the cost, and why the ✋ it produces is CORRECT
#   - this unit outlives the run that wrote it, so an apply `--from tree` binds
#     a PERMANENT timer to a worktree a `git worktree remove` can delete. the
#     ExecStart then names a path that is gone, and the prune stops with no
#     signal — a timer that fires into an absent command logs and exits
#   - measured 2026-09-09 on this box: the installed unit named
#     `~/git/more/dev-env-setup` and a worktree plan reported drift on the
#     service. that ✋ is the mechanism at work, NOT a false alarm — the two
#     checkouts genuinely declare different ExecStarts
#   - ⇒ apply this bundle `--from main`. a `--from tree` apply is for a test of
#     the bundle, and it leaves a unit only another apply can put right
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
