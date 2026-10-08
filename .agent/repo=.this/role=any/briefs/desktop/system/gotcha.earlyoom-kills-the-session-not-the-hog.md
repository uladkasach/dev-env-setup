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

## .see also

- `hazard.idle-process-leak-crosses-the-swap-cliff` — the same orphan class, measured before
- `howto.attribute-memory-to-its-origin` — the cgroup method
- `machine.journal.read` — the skill that answered this
