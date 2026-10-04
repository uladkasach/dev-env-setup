# howdoes: the keyrackd prune keeps the leaked-daemon pool bounded

## .what

`1.6.4.keyrackd` installs a USER systemd timer that prunes orphaned keyrack daemons every 15
minutes, so the leaked pool stays bounded with no human in the loop. this brief carries the
arguments and measurements behind each clause of its header.

## 🛑 the slug says `keyrackd`, NEVER `rack`

- `rack` is a declared term for the credential STORAGE — `~/.rhachet/keyrack/`, its host
  manifest, its vault files (`term=rack._.choice._.md`). `5.12.rack` owns it
- a slug of `rackprune` reads as *"prune the credential store"* — a destructive act on the one
  store this bundle must never touch, and the exact misread `term=prune` exists to prevent
- 📜 that slug shipped for an hour on 2026-09-08 before the glossary round caught it. an
  overload is easiest to commit on the round you MERGE the term: the word is fresh in the
  hand and its forbid list is not
- ⇒ `keyrack` is the COMMAND, which `term=rack` keeps legal for exactly that use, and `-d` is
  unix's suffix for a program's daemons. the subject is the daemon POOL

## it sits under `1.6.procs`, not `5.12.rack`

- `1.6.procs` is the RUNAWAY-PROCESS concern, split by WHO asks: a human (`1.6.1.finders`), a
  timer (`1.6.2.monitor`), no one (`1.6.3.earlyoom`). this is the timer arm for a second
  population
- the subject is the leaked POOL, never keyrack the tool — `earlyoom` likewise kills processes
  it did not create. `5.12.rack` owns a manifest entry; a box can hold one and not the other

## a timer, never a chore a human remembers

- each `rhx` call may spawn a keyrack daemon under a temp home (`/tmp/pii-brain-live-*`). when
  its spawner exits, the daemon orphans to pid 1 and holds ~55MB of ANON memory — the one
  kind that must swap
- 📜 measured **152 spawns/hour**. by 2026-08-30 the pool held **191 daemons** and the box was
  **17.4G into swap**; an earlier incident reached **641**
- the daemons are invisible to `ps` aggregation (each is merely `node`, each reparented), so
  only a scheduled prune keeps the pool bounded (`hazard.idle-process-leak-crosses-the-swap-cliff.md`)

## ⚠️ `--min-age 10`, not the skill's 60m default

- at 152/hour a 60m gate skips the live population: 📜 it caught **17 of 191**, where 10m
  caught **122** (`term=prune._.choice.reason.md`)
- age is the WEAKEST of the skill's three predicates. the real safety is "temp home AND
  spawner dead", and 10 minutes already clears the fork race

## 🛑 the SERVICE is generated and the TIMER is an asset

- the timer holds no path, so it is a tracked file under `src/machine/`, and
  `provision.verify` can `cmp` the installed copy, exactly as `1.8.tmpfiles` does
- the service's ExecStart names THIS BOX's checkout, so no one file can be the declared bytes
  for every box. it is generated — from ONE reader BOTH halves ask, so the verify still diffs
  installed bytes against declared ones
- ⇒ not the heredoc defect `1.6.procs/_.sh` warns about: that one had no reader to compare
  against; this one does

## 🛑 a grove needs LINGER, and the laptop never did

- a `systemctl --user` manager starts at a seat's first login and STOPS at its last logout. a
  laptop's graphical session never logs out, so every prior user timer here (`1.6.2.monitor`,
  `4.3.4.snapshot`, `6.5.onepassword`) was born on a box that keeps its manager alive for free
- a grove has no graphical session. its only login is the duct, so the manager — and this
  timer — dies the moment that pane closes
- ⇒ `loginctl enable-linger` keeps a user manager up past logout, and it is the ONE part of
  this bundle a seat without sudo cannot do for itself. ground sets it for every human seat,
  camper included (`rule.require.seam-claims-have-an-owner`; `5.8.docker` set the precedent)

### ⚠️ an ENABLED timer is not evidence the prune runs

`is-enabled` and `is-active` both answer from INSIDE a live user manager, so on a grove they
answer ✔ right up until the duct closes and the manager goes with them. neither can see its
own mortality — linger is a THIRD claim, and the only one that outlives the session that put
the question.

### `show-user` FAILS outright for a seat with no session and no linger

that is the exact state a grove's camper sits in between ducts. so the absent case and
`Linger=no` must both read "no" — a bare exit-code test would call the first an error.

## ⚠️ the skill can be ABSENT, and that is a 🌙, never a ✋

- the skill lives under `.agent/`, OUTSIDE `src/`. `boot` pushes `--from .` precisely so a
  grove holds it (`git.grove.provision.boot.sh`), so a booted grove HAS it
- the decline fires on a box pushed by hand with `--from src`, which several howtos still
  spell. an unprunable box is a degradation, never a failed provision — the phase reports
  and continues

## 🛑 the skill path is off THIS run's checkout, and that has a cost

`$GROVE_SRC` is `<checkout>/src`, and `.agent/` sits beside it. a hard-coded
`~/git/more/dev-env-setup` would be the first checkout-path assertion in the bundle tree, and
false on any worktree.

- the cost: this unit outlives the run that wrote it, so an apply `--from tree` binds a
  PERMANENT timer to a worktree a `git worktree remove` can delete. the prune then stops with
  no signal — a timer that fires into an absent command logs and exits
- 📜 2026-09-09, this box: the installed unit named `~/git/more/dev-env-setup` and a worktree
  plan reported drift on the service. that ✋ is the mechanism at work, NOT a false alarm —
  the two checkouts genuinely declare different ExecStarts
- ⇒ apply this bundle `--from main`. a `--from tree` apply is for a test of the bundle, and it
  leaves a unit only another apply can put right

## .see also

- `1.6.4.keyrackd/_.sh` — the header this brief backs
- `hazard.idle-process-leak-crosses-the-swap-cliff.md` — the pool's cost
- `term=rack` · `term=prune` — the slug argument
