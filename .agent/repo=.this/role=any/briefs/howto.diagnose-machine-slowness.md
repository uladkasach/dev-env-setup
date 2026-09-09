# howto: diagnose machine slowness

## .what

the ordered path from "it feels slow" to a named root cause. built from a 2026-08-30 session
that took ~3 hours and found **five** independent defects. the order below would have found them
in ~15 minutes.

## .why

the naive path — look at top CPU, look at top memory — is wrong more often than right. it names
the binary that holds a resource, never the origin that leaked it. this brief encodes the
attribution tools that do not lie, and the traps that cost the most time.

---

## the ladder — run in this order

### 0. read `idle` and `load` TOGETHER first

```sh
rhx machine.diagnose.lag --quick
```

the single most misread signal: **`idle: 89%` with `load: 24`**. the machine is not busy — it is
**blocked on I/O**, likely paged out. D-state counts toward load but not CPU.

| load | idle | means |
|------|------|-------|
| high | low | genuine cpu saturation — find the hot process |
| high | **high** | **blocked on I/O** — check swap, check D-state |
| low | high | not a machine problem — look at the app |

### ⚠️ 1. discount the diagnostic's own cost

`machine.diagnose.lag` spawns node processes that show at **150-950% cpu, elapsed=0s**. those are
the measurement, not the disease.

**the tell:** compare 1m vs 5m load. if 1m is high and 5m/15m are low, the spike is the tool. if
1m ≈ 5m, the load is real and sustained.

three separate rounds of this investigation were wasted on a "runaway node" that turned out to be
the snapshot skill that measured itself.

### 2. attribute memory by CGROUP, never by process name

```sh
rhx machine.attribute.memory --top 12
rhx machine.attribute.memory --orphans
rhx machine.attribute.memory --zombies
```

**this is the highest-value step in the whole ladder.** `ps`/RSS answers "which binary holds
pages" — a different question from "what leaked them".

proof from the session: RSS named nvim as the top offender. cgroup attribution found **191
orphaned keyrack daemons** in one tmux scope (1,699 pids / 5.5G) that appeared in **no** top-15
RSS list at all. each was merely "node", each had reparented to pid 1 after its spawner exited.

> cgroup membership is assigned at fork and **survives reparent**. process names carry no origin.

read the **anon** column — anon is the leak signal and the only memory that must swap. file cache
reclaims for free.

### 3. check the slab, not just the process table

```sh
cat /proc/meminfo | head -30
```

`SReclaimable` is the dentry/inode cache. it is **not** attributable to any process, so every
process-level tool is blind to it.

observed: **3.3 GB** of slab from ~13,000 `/tmp` fixture dirs. see the `/tmp` section below.

### 4. use the purpose-built evidence log before any general tool

for nvim, the watchdog already writes the answer:

```sh
tail -40 ~/.local/state/nvim/selfwatch.log
```

the diagnosis rule (from `howto.diagnose-nvim-hang`): **find which column climbs alongside
`rss_mb`.** `bufs` climbs → buffer leak. `ts` climbs → treesitter. neither → the vdiff/image
caches.

one `tail` named a buffer leak that no amount of `ps` would have found. purpose-built evidence
with the right columns beats every general-purpose tool.

### 5. only then, look at long-lived processes

sort by **elapsed**, not by %cpu. the worst offenders are quiet and old, not loud and new.

---

## the traps, ranked by cost

### trap 1 — RSS lies about origin (cost: ~1 hour)

covered above. attribute by cgroup.

### trap 2 — the detector has a blind spot in the middle

both extant detectors missed a `npm exec depcheck` that held ~24% of a core for **145 hours**:

- `machine_resource_procs_find_spinner` gated at `MIN_RATIO=50` — 24% never reached it
- `machine_resource_procs_find_runaway` only fires when system load crosses `cores*1.5`, then
  ranks by **instantaneous** %cpu — so it surfaced 1-second-old node processes at 150% and buried
  the 6-day offender at 24%

**a wedged process rarely pegs a core.** it polls, retries, or spins on a partial wait, so it
lands in the teens or twenties — below a 50% gate, above idle. that band is where the expensive
bugs live. `MIN_RATIO` is now 15.

### trap 3 — an age gate is a rate assumption (cost: ~30 min)

`keyrack.daemon.prune --min-age 60` found **17 of 191** prunable, because 152 had spawned within
the hour. at `--min-age 10` it found **122**.

> read the **skip** counts, not the prune count. a large `skip (younger than Nm)` means the gate
> is mis-tuned for the current leak rate.

### trap 4 — the guard can become the load

nvim's self-watchdog fired **40 times in one second**. libuv fires a repeat timer once per
*missed interval* when the event loop is starved — so a box deep in swap gets a catch-up
stampede, each fire a `/proc` read + buffer walk + GC + log append.

**the guard piled work on the machine exactly when it could least afford it.** any periodic timer
in a system under memory pressure needs a wall-clock guard, not just an interval.

its log had no cap either: 7.2 MB, written mid-storm.

### trap 5 — search for a prior issue BEFORE you file one

two issues were filed that duplicated month-old, better-researched ones (#442, #540). always:

```sh
gh issue list --repo <owner>/<repo> --search "<keywords>" --state all
```

---

## the fast path (copy-paste)

```sh
rhx machine.diagnose.lag --quick        # 0-1: load vs idle; discount elapsed=0s procs
rhx machine.attribute.memory --top 12   # 2: cgroup truth, read the anon column
rhx machine.attribute.memory --orphans  # 2: reparented procs, invisible to ps
cat /proc/meminfo | head -30            # 3: SReclaimable = dentry/inode slab
tail -40 ~/.local/state/nvim/selfwatch.log   # 4: which column climbs with rss
rhx keyrack.daemon.prune --min-age 10   # read the SKIP counts
rhx tmp.fixture.prune                    # plan first
rhx nvim.diagnose.runaway
```

---

## the lesson

> the loudest process is rarely the cause. attribute by cgroup, read the slab, and trust a
> purpose-built log over any general tool.

## .see also

- `hazard.big-tmp-costs-ram-not-disk.md` — why 13,000 dirs cost 3.3 GB of kernel slab
- `hazard.idle-process-leak-crosses-the-swap-cliff.md` — the leak → swap-cliff chain
- `howto.diagnose-nvim-hang.md` — the selfwatch log columns, and the two nvim defense layers
- `howto.attribute-memory-to-its-origin.md` — why cgroups beat `ps`
- `domain.terms/term=leak._.choice.reason.md` — the RSS-vs-cgroup correction, recorded
- `domain.terms/term=prune._.choice.reason.md` — the age-gate lesson
