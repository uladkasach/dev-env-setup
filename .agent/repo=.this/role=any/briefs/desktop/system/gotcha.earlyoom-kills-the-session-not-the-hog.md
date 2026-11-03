# gotcha: earlyoom killed the session, and spared the hog

## .what

under memory pressure, earlyoom with the package default args killed the session's own daemons
and left the process that caused the pressure alive. the user manager died, every kitty window
died with it, and `nvim` / `claude` then failed with `Failed to connect to bus: Connection refused`.

## .the measurement — 2026-10-07, this laptop

`rhx machine.journal.read --scope system --unit earlyoom.service --since 17:30`:

```
low memory! mem avail 1399 of 31717 MiB (4.41%), swap free 5709 of 57343 MiB (9.96%)
sending SIGTERM to "gvfs-goa-volume": badness 800, VmRSS 6 MiB
sending SIGTERM to "gcr-ssh-agent":   badness 800, VmRSS 4 MiB
sending SIGTERM to "dbus-broker-lau": badness 800, VmRSS 4 MiB   ← the session bus
sending SIGTERM to "speech-dispatch": badness 800, VmRSS 3 MiB
sending SIGTERM to "systemd":         badness 733, VmRSS 7 MiB   ← the user manager
```

the user unit, at its stop: **27.4G memory peak, 45.2G swap peak**, and **~254 processes left
behind** — nearly all orphaned `node`, accrued across a 35-day session.

## .why

- earlyoom ranks by `oom_score`, never by size. systemd's user manager raises the score of
  every small daemon it starts, so a 4 MiB daemon outranks a 2 GiB node runtime
- an orphan is reparented to `systemd --user`, which never reaps an idle one. so leaked tool
  subprocesses accrue for as long as the session lives
- a user manager killed by SIGTERM stops CLEAN, and `user@.service` carries no `Restart=`, so
  it stayed dead, and its bus socket stayed on disk and refused every connection

## .the repairs

| defect | repair |
|---|---|
| earlyoom picks infrastructure first | `1.6.3.earlyoom/earlyoom.default`: `--avoid` the session daemons, `--prefer` node/claude/bun/jest. clamp: `prove.earlyoom-spares-the-session` |
| a dead user manager stays dead | `1.6.5.usermanager`: `Restart=always` drop-in on `user@.service` |
| `nvim` / `claude` wrappers fail on a dead bus | one path: wait for the manager to answer, then the capped launch; a mute manager fails loud with the fix |
| the orphan population grows unwatched | `1.6.6.abandoned`: an hourly user timer kills each process abandoned over 24h (ours · spawner dead · not its cgroup's oldest · >24h) and logs each kill to `~/.local/state/grove/abandoned.reaped.log`. clamp: `prove.abandoned-procs-are-reaped` |

🛑 **`--avoid` / `--prefer` are weights of ±300, never exclusions** (earlyoom v1.7). the first
clamp draft baited a fake `systemd` at the max score (1333) and the policy "failed": 1333−300
still beat 666+300. the policy holds on the REAL gap — a session daemon (adj 200) lands at 500,
an orphan node (adj 0) at 966+ — so a bait that tests it must carry that same gap.

⚠️ **the kernel score has a floor of 666.** `oom_score` reports `(1000 + adj + rss term) × 2/3`,
so an adj-0 process of any size starts at 666, and the rss term adds only ~1 point per ~90 MB on a
box with 89 GB of RAM+swap. that is why 254 orphans of a few hundred MB each never outranked one
4 MiB daemon at adj 200: earlyoom kills one process at a time, and the hog was a POPULATION.

⚠️ **the reaper bounds the leak; it does not fix its source.** the origin of the ~254 orphans
died with the session, so it could not be attributed. the reap log names each victim's argv,
so the next origin is attributable from the log alone — read it before you blame a tool.

## .the reaper bundle — `1.6.6.abandoned`

- "abandoned" is four rules, declared once in `src/machine/machine_resource_procs_reap_abandoned`:
  ours · spawner dead · not its cgroup's oldest process · older than 24h
- why a timer: no extant reader watched the population
  - `1.6.4.keyrackd` reaps ONE population, the keyrack daemons
  - `machine.usage.diagnose` runs only when a human asks
  - earlyoom kills ONE process by score, as measured above
  - ⇒ the population has to be reaped by age, before memory pressure exists
- every box, no decline: a grove leaks the same tool subprocesses, and has no human to notice
- no linger claim: `1.6.4.keyrackd` runs first and grants linger to every human seat, and the
  timer rides on the same user manager. a second claim would be a second declaration of one fact
- the service is generated and the timer is an asset, the same split as `1.6.4.keyrackd`
  - the ExecStart names the checkout's executable, so it comes from one reader both halves ask
  - the timer holds no path, so it is a tracked file the verify can `cmp`
  - ⇒ apply `--from main`. a `--from tree` apply binds the timer to a worktree that
    `git worktree remove` can delete

## .see also

- `hazard.idle-process-leak-crosses-the-swap-cliff` — the same orphan class, measured before
- `howto.attribute-memory-to-its-origin` — the cgroup method
- `machine.journal.read` — the skill that answered this
