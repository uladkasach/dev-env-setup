# hazard: an idle-process leak crosses the swap cliff

## .what

606 leaked keyrack daemons — each ~714 K of real RAM, 1.6% of a 32 G machine
in total — made the entire desktop stall for **4.4 accumulated hours**.

Removal of those 606 processes took the machine from "latency in every
interaction" to "latency no longer noticeable."

This brief records **why so little memory did so much harm**, because the
naive arithmetic says it should have been irrelevant.

## .why it looks impossible

```
606 daemons × 714 K PSS  =  528 M real RAM
528 M / 31 G             =  1.6% of the machine
```

No one would predict a desktop-wide crawl from 1.6% of RAM. The arithmetic
is correct, and the conclusion drawn from it is wrong — because **RAM
footprint was never the mechanism.**

## .the actual chain

### 1. each daemon is a whole node runtime

Not a thin helper. A V8 heap, a libuv loop, ~9–13 M of anonymous pages. Anon
memory cannot be dropped; it can only be written to swap.

### 2. idle means the kernel evicts them — correctly

These daemons do no work at all. Idle anon pages are precisely what the
reclaim path should evict. This is not a kernel defect; the kernel did the
right thing with a bad population.

```
606 daemons × ~9 M SwapPss  ≈  5.3 G evicted to swap
```

### 3. the eviction lands in zram, and zram is a fixed budget

```
/dev/zram0     16 G   priority 1000   ← fills first
/swapfile2     36 G   priority   -2   ← disk
/swapfile      36 G   priority   -3   ← disk
```

zram compresses ~5.9:1, so 5.3 G of daemon heap costs only ~900 M of real
RAM to store. **But it consumes 5.3 G of the 16 G zram budget** — a third of
the fast swap tier, spent on processes that perform no work.

### 4. the cliff

zram reached 99.6% full. Past that point every further eviction goes to a
**disk** swapfile.

| tier | fault cost | ratio |
|------|-----------|-------|
| zram (has headroom) | ~microseconds | 1x |
| disk swapfile | ~milliseconds | **~1000x** |

There is no warning at this boundary and no gradual slope. Performance falls
off a cliff.

### 5. the daemons poll, so they churn what they hold

This is the step that converts a static cost into continuous damage.

`scheduleAutoTermination` runs a `setInterval` every 15 minutes. So:

```
606 daemons ÷ 900 s  ≈  0.67 wakeups per second, forever
```

Each wakeup touches a heap that was swapped out → **major fault** → the pages
must be read back in → the daemon goes idle → the pages get evicted again.

A leak that merely *held* memory would be survivable. This one **cycles** it,
around the clock, at a rate no one ever sees.

Observed counters:

```
pgmajfault               1,256,164,969   ← 1.25 billion major faults
pswpin                   1,268,727,120
workingset_restore_anon    129,159,428   ← anon evicted, then needed again
```

`workingset_restore_anon` is the thrash signature: pages the kernel decided
were cold, that turned out to be warm.

### 6. direct reclaim spreads the pain to innocent processes

When free memory runs short and a process requests a page, the kernel cannot
serve it from the free list. It makes **that process** perform the reclaim
work synchronously.

```
allocstall_normal      156,716
pgsteal_direct      91,493,255
pgscan_direct      247,285,086
```

Firefox asks for a page → firefox performs reclaim → **firefox stalls.**
The daemons created the pressure; every other process pays it.

> **the victim is never the culprit.**

This is exactly why it presented as *"the whole computer comes to a crawl"*
and never as *"keyrack is slow."* No process-level tool could point at the
cause, because the cause was not slow — it was asleep.

### 7. the measured toll

```
PSI memory full total = 15,752,650,907 µs = 4.4 hours
```

`full` means **every** task was stalled at once — the machine performed zero
work for a cumulative 4.4 hours.

## .the lesson: threshold effects, not proportional ones

The instinct is to rank causes by size. 5.3 G of 96 G total swap looks like a
minor share, so it reads as a minor cause.

That instinct fails at a threshold. zram was at 99.6%. The daemons were the
**marginal** gigabytes — the ones that pushed it past full.

> a dam at 99.6% capacity. the last 1% is not "1% of the flood."
> it is the whole flood.

Remove the marginal load and the system crosses back. That is why the
improvement felt total rather than incremental: **the fix was not a 1.6%
reduction, it was a change of regime.**

## .why cgroup attribution was required to find it

Every spawner had exited, so the daemons showed `PPid: 1`, reparented to
systemd, with no trace of origin. `ps` grouped them as `node ×686` — the
binary, not the culprit.

Cgroup membership is assigned **at fork and survives reparent**, so each
orphan still sat in the scope of the session that created it:

```
node PID 2341927
  PPid:   2455                              ← systemd; orphaned
  cgroup: .../kitty-4008853-0.scope         ← STILL the spawner's scope
```

The kitty scopes carried ~1,700 pids each against 12–69 for a normal scope.
**Kitty was not the leak** — it was merely the accounting parent. After the
prune those same scopes hold 114 and 12 pids.

## .the detection signature

Suspect this class of hazard when all of these hold:

| signal | where | meaning |
|--------|-------|---------|
| high pid count in one scope | `machine.attribute.memory` | orphan accrual |
| anon ≫ file | `memory.stat` | no cache left to reclaim; tuning cannot help |
| zram near `disksize` | `/sys/block/zram0/mm_stat` | at the cliff edge |
| `workingset_restore_anon` climbs | `/proc/vmstat` | thrash, not mere pressure |
| `pgsteal_direct` large | `/proc/vmstat` | innocent processes made to reclaim |
| PSI memory `full` accrues | `/proc/pressure/memory` | machine-wide dead time |
| low PSS, high SwapPss | `smaps_rollup` | cheap in RAM, expensive in swap |

The last row is the trap. A per-process RAM figure of 714 K invites dismissal.

## .the ongoing risk

The prune is a **mop, not a repair.** The count went 585 → 641 within a single
session, because every integration-test run sets a throwaway `HOME`, which
mints a fresh socket hash, which spawns a fresh daemon that never exits.

Verified: production `.sh` skills set no `HOME` (`HOME=` → 0 matches), so real
commits inherit the real `HOME` and reuse one daemon. The throwaway `HOME`
comes from `genTempDir` (a `test-fns` export) in `*.integration.test.ts`.
**571 of 585 were minted by test runs.** Test isolation is correct behavior —
the defect is that the daemons outlive the suite.

Until the upstream defects land, re-run periodically:

```sh
rhx keyrack.daemon.prune              # plan
rhx keyrack.daemon.prune --mode apply # signal TERM
```

Upstream repair is tracked in `.dream/2026_07_31.keyrack-daemon-expiry.dream.md`
— two defects, both in already-shipped code: a `hasEverHadKeys` guard that
prevents auto-termination for daemons that never held a key, and an `@all`
prune glob pinned to the caller's own `homeHash`.

## .see also

- `howto.attribute-memory-to-its-origin.md` — the method that found it
- `skills/machine.attribute.memory.sh` — cgroup ranking, orphans, zombies
- `skills/keyrack.daemon.prune.sh` — the mop

---

> a leak can wreck a machine without much resident memory.
> measure the cliff, not the footprint.
