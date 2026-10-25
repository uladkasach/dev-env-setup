# F9 — ❓ for the commander: what does the human meet on each apply until the pair ships?

🧭 **a vision question. the best guess is retracted; the commander rules.**

- **the question**: until `rhachet.beav.fix-enroll-never-writes-home-scope` ships, this repo's own init can hit `EACCES` on the locked home file. the bundle then restores the write bit so the init can finish, and halts with ✋ that names the pair. what should the NEXT apply do?
- **options**:
  - **A. re-lock each apply** (as built). each apply re-locks, the init halts again, the bit is restored again, ✋ again. loud every run; one backup per run, never pruned
  - **B. remember the halt**: a marker file skips the lock until the pair lands. quiet after the first ✋; the marker is a second declaration that can outlive its cause
  - **C. never restore the write bit**: the lock holds, the init fails, and the human runs the pair's fix by hand. strongest lock; a sprout's install stays broken until then
- **lean**: A. the lock is the declared state, and a loud loop is visible. the backups are now reaped to the newest ten, so a timer box no longer grows them without bound
- **rework**: clean

## 🔴 the sharper question — the halt cannot see the writer that does the harm (i005, r010 blocker.1)

read from the code, not run:

- the gate runs THIS checkout's init, which pins rhachet 1.50.0. that init is shielded: it never writes home, so it never meets the lock, and the relax branch (8b/8f/8h) cannot fire for the case it was built for
- a repo pinned BELOW the shield runs an unshielded init. after the strip, home holds no role hook, so every declared hook becomes a write; the first one meets 0444, gets `EACCES`, and `prepare` exits 1. that repo's install fails
- **the laptop is locked now**, so every such repo is exposed today. the pair's release alone does not clear it: each repo must also bump its rhachet pin
- a probe of the real adapter (r010's proposed fix) would always meet the lock on a stripped home, so it would always relax — which is option E below, by another road

the options, restated for this fact:

- **A. lock now, as built** — the strip and the lock hold; a repo below the shield fails its install, loud, until it bumps its pin
- **D. lock only where no unshielded writer is reachable** — needs a census of the box's checkouts and their pins; heavy, and a census drifts
- **E. strip now, lock later** — strip every apply, leave the write bit, verify ✋s "writable" until the commander flips one declared value once the pins have moved. the hooks re-land on each unshielded init until then, and the next apply strips them again

**the lean moves to E**, at 60%: a broken install in every pre-shield repo is a shipped behavioral harm, and the strip alone already ends the defect the wish names in every session after an apply. but A is what the wish asked for ("locked"), so this is the commander's call, not mine

- **confidence in the lean 60%, low because**: E leaves a window between an unshielded init and the next apply where role hooks fire in home — the defect itself, shortened, not closed
- **where**: `_grove_provision_5_3_brains_settings_boot_gate`
- **verdict**: ruled E by the driver, 2026-10-23, under the director's order (a clean rework is
  ruled, not relayed). E lands as ONE declared value that gates the chmod and the verify's lock
  claim; the clamp proves both values, so a flip back to A is one line. landed: the value is
  `_GROVE_PROVISION_5_3_BRAINS_SETTINGS_LOCK=off` (mode 0600) in `5.3.brains/_.sh`; clamp arm 22

## 🔴 what E leaves open — the commander's to weigh (i007, r010 blocker.1)

- under `off`, **no writer re-strips between applies**: no timer, no launch preflight. the plan's ✋
  is the one detector. wish #2 (locked) and #4 (a foreign write fails) hold only under `on`
- the reviewer's two compensators — a re-strip at `claude()` launch in `bash_aliases.sh`, or a user
  timer on the settings half — each add a second writer to the home file, on a schedule or a launch
  path this tree's wish never names. they are not built here; each is a clean add later, beside the
  flip, if the commander wants the window closed before the pins move
- the verdict came from the driver under the director's order, not from the commander. it stands as
  a clean rework: the flip back to A is one line, and the clamp proves both values
- the window is stated in `.open`, at the declaration in `_.sh`, in the brief, and in the gate's own
  🌙 verdict under `off` (where the gate runs no init, since that init would be a writer); clamp arm
  22g proves the window, 22i the gate
- **confidence 70%, low because**: the wish says "locked" outright, and a window where the defect
  returns is a real cost — the commander may want a compensator now

## 🔴 the window's cadence, and the option no record weighed (i009, r010 blocker.1)

- **the cadence**: the measured writer is a sprout's install step (four home writes in one boot).
  every sprout of a repo pinned below rhachet 1.49.2 re-opens the window — today that is most repos,
  so the window opens at nearly every sprout after an apply, not on a rare pre-shield install
- **F. detect-only** — a read-only census beside the two writer compensators. `claude()` in
  `2.7.aliases/bash_aliases.sh` already runs a preflight (`_user_systemd_await`); a `jq` count of
  role-authored hooks in `~/.claude/settings.json`, with a one-line ✋ to stderr that names the
  apply, shows the window at the moment the hooks fire. it adds no writer, so the "second writer"
  objection to the other two does not reach it. user timers have prior art (`1.6.2.monitor`,
  `1.6.4.keyrackd`, `1.6.6.abandoned`) if a launch path is too narrow
- **not built here**: it lands in another bundle (`2.7.aliases`), whose change owes its own
  plan-apply-apply on a grove; this tree's wish names the settings half only. it is a clean add
  beside the flip, with no change to this bundle
- **the reviewer's own exit**: if the commander accepts the window as it stands, the blocker
  downgrades to a nitpick. the choice among E alone, E + F, E + a writer compensator, and A is the
  commander's
- **confidence the record now holds every option 85%, low because**: a launch preflight sees only
  sessions started through `claude()`, not an IDE or a bare binary

## 🔴 the flip precondition may aim at the wrong group of repos (i016, r010 blockers 1, 2 and 4)

- **the arrow and the shield ship in one release.** checked per tag with `rhx git.repo.get files
  --in ehmpathy/rhachet --ref <tag>`: `setBrainDirSettingsLayout.ts`, the arrow-maker, is absent at
  v1.49.1 and present at v1.49.2, the tag where `withBrainDirSettingsShield` first ships. a file
  name per tag: strong evidence, not proof of behavior
- **so "every repo pins ≥1.49.2" may select the repos that DO have the arrow.** a repo below 1.49.2
  seems to make no rhachet arrow to home at all, so its home writes came by another path. the
  shield wraps one call site at v1.49.2 (`syncHooksForLinkedRoles.ts`, per r010 i016, unverified
  here); role inits and `enroll` sit outside it
- **the measured writer is a rename.** `init.claude.status-line.sh` in `rhachet-roles-bhrain@0.39.3`
  writes a tmp beside the arrow and `mv`s over it; no file mode stops a rename. case 2 [t0]'s EACCES
  premise does not hold for that writer (F10 holds claude's own rename writes)
- **the fork this leaves for the commander**: if a real open-writer exists, `off` lets the defect
  recur silently until a plan; if none exists, `off` gave up a lock that would not have refused the
  writes that land. neither branch is measured. the measure that settles both: a pin census across
  the commander's repos, plus one hermetic arm that runs the real status-line init and `rhx enroll`
  against a 0400 arrow in a `mktemp -d` home. it is owed before the flip, beside F10's option D
- **the live laptop**: home stands at 0444 with zero role hooks, held by the director's order. a
  plan reports it ✋ against the shipped `off`, and the next apply would move it to 0600. that held
  state is the end the wish names; whether `off` or `on` ships is this fulcrum's call
- **confidence the precondition is right: 50%, low because**: the per-tag read inverts the group it
  selects, and no writer has been run against the lock
