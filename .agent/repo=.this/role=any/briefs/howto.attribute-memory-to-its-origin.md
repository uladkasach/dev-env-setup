# howto: attribute memory to its origin

## .what

how to find *what actually causes* memory pressure, when `ps` aggregation
by process name points at the wrong thing.

worked example: a machine at 27G/31G used, 53G swapped, whole desktop
crawls. `ps` blamed "node ×686". the real origin was 575 leaked keyrack
daemons — and their RAM cost was only ~390M. the damage was elsewhere.

## .why

three tools lie in three different ways:

| tool | the lie |
|------|---------|
| `ps` grouped by comm | names the **binary**, not the spawner |
| `ps`/`top` RSS | counts **shared** pages once per process |
| any process tool | cannot see **zombie cgroups** at all |

each lie sent us down a wrong path. the method below defeats all three.

---

## .step 1 — attribute by cgroup, not by process name

`ps` said `node ×686, 14.5G`. that names the binary. useless for origin,
because the spawners had already exited:

```
node PID 2341927
  PPid:   2455                              ← systemd; orphaned
  cgroup: .../tmux-spawn-01c1de0d-….scope   ← STILL the spawner's scope
```

**cgroup membership is assigned at fork and survives reparent to systemd.**
so the kernel still charges an orphan to the scope that created it. the
cgroup remembers what `ps` forgot.

```sh
.agent/repo=.this/role=any/skills/machine.attribute.memory.sh
```

this ranked scopes and exposed the anomaly instantly — two kitty scopes
with ~1,700 pids each, against 12–69 for every normal scope.

## .step 2 — read anon vs file before you tune anything

the same skill splits `memory.stat`:

```
anon (heap, needs swap): 42.2G
file (cache, droppable):  9.3G
```

anon dominates → there is no free memory to reclaim. this is what proved
`vm.swappiness=10` would not have helped: at low swappiness the kernel
prefers to evict page cache, and there was only 9.3G of it against 42.2G
of heap. it would have thrashed cache, then swapped anyway.

**check this ratio before you touch any reclaim knob.**

## .step 3 — drill to name the spawn path

```sh
machine.attribute.memory.sh --scope kitty-4008853-0.scope
```

319 processes in one scope, all identical, all `PPid: 1`. reading the
full cmdline from `/proc/$pid/cmdline` (the skill truncates at 42 chars —
go to /proc for the full string) named it:

```
node -e  const { startKeyrackDaemon } = require('…/rhachet/dist/…');
         startKeyrackDaemon({ socketPath: "/run/user/1000/keyrack.4.b04eaf03.sock" });
```

## .step 3b — read the source, then read the environ

cmdline names the code. it does **not** explain why the code misbehaves.
two guesses died here, both drawn from cmdline alone:

- guess: "daemons fight over one socket" → each socket appeared exactly once
- guess: "the hash is unstable/nondeterministic" → the source is deterministic

`node_modules/rhachet/dist/domain.operations/keyrack/daemon/infra/`:

```js
// getKeyrackDaemonSocketPath.js
`keyrack.${sessionId}.${homeHash}.sock`      // + optional .${owner}

// getHomeHash.js
const homePath = process.env['HOME'] ?? process.cwd();
return createHash('sha256').update(realpathSync(homePath)).digest('hex').slice(0, 8);
```

deterministic — **given a fixed HOME**. so the question becomes: was HOME fixed?
`/proc/$pid/environ` answered it:

```
HOME=/tmp/rhachet-test-1783309642324-uu19u7   ← unique temp dir
NODE_ENV=test
JEST_WORKER_ID=1
INIT_CWD=…/_worktrees/rhachet.vlad.fix-keyrack-sso-crossusername
```

these are **jest integration tests**. the suite sets HOME to a fresh
`/tmp/rhachet-test-$timestamp-$random` per run — correct test isolation,
which then feeds the daemon's identity function. so:

```
new HOME per test run → new homeHash → new socket path
  → find-or-create can never hit → new daemon per run
  → daemon outlives the test → PPid 1 → accrues forever
```

**but do not stop at the first origin you find.** a census by HOME shape
showed jest was only half of it:

```
286  jest.tmpdir.dash     leak
135  git.push.temphome    leak   <- git.commit.push integration tests
112  git.set.temphome     leak   <- git.commit.set integration tests
 30  jest.tmpdir.slash    leak
 14  REAL.home            legit
  8  keyrack.prunetest    leak
```

only **14 of 585** have a real HOME.

the first classifier matched only `/tmp/rhachet-test-*`, so every other
shape fell into the default bucket and was waved through as "real HOME."
**a classifier's default bucket hides what it cannot name** — always eyeball
raw values before you trust the counts.

### the second correction: verify the caller, not the label

the census names a HOME *shape*. it does not name the code that set it. to
read `git.set.temphome` as "rhx git.commit.set does this" was an inference,
not evidence — and it was wrong:

```sh
rhx git.repo.get lines --repos 'ehmpathy/rhachet-roles-ehmpathy' \
  --words 'git-set-home'
#  → 4 matches, ALL in *.integration.test.ts

rhx git.repo.get lines --repos 'ehmpathy/rhachet-roles-ehmpathy' \
  --words 'HOME=' --paths 'src/domain.roles/mechanic/skills/git.commit/*.sh'
#  → 0 matches
```

`genTempDir` is a `test-fns` export. the production `.sh` skills set no HOME
at all, so real commits inherit the real HOME and reuse one daemon
correctly. **571 of 585 were minted by test runs.**

two opposite claims were both asserted from weak evidence before the source
settled it. the lesson is not "tests, not production" — it is:

> a census bucket is a *hypothesis about a caller*, not the caller.
> grep the repo for the literal string before you name the origin.

## .step 4 — use PSS, never sum RSS

this is the step that changes the conclusion.

| metric | one daemon | why |
|--------|-----------|-----|
| Rss | 13.0 M | includes shared pages |
| **Shared_Clean** | **12.3 M** | node binary + libs, shared by ALL 519 |
| **Pss** | **714 K** | this process's *real* share |
| SwapPss | 9.1 M | its share of swap |

`/proc/$pid/smaps_rollup` gives PSS — shared pages divided across the
processes that map them. summing RSS across 519 processes that share one
node binary **overcounts by ~18x**.

- sum of RSS would say: ~9.4 G  ← wrong
- sum of PSS says: **~390 M RAM** ← right
- sum of SwapPss says: **~4.5 G swap**

verified against a second daemon (Pss 780K, Shared_Clean 16.9M) to
confirm the first was representative.

## .step 5 — count the invisible

```sh
machine.attribute.memory.sh --zombies
```

```
live cgroups:   126
zombie cgroups: 120
```

a zombie cgroup is removed but its pages stay charged. **zero live
processes**, so ps/top/htop cannot see it. ~1:1 zombie:live is a churn
signature — something creates and destroys scopes constantly.

## .step 6 — count the kernel's own overhead

`/proc/meminfo` and `/sys/block/zram0/mm_stat` hold memory no process owns:

| source | cost | note |
|--------|------|------|
| zram `mem_used_total` | **2.82 G** | 14.85 G compressed 5.4:1 into real RAM |
| PageTables | **1.19 G** | direct tax of 8,451 processes |
| Slab (unreclaimable) | 0.86 G | |
| KernelStack | 0.15 G | |

zram's 2.82 G is RAM that **no application can use and no tool attributes**.
`mem_limit` was `0` — uncapped, free to grow.

also `Committed_AS` 111 G vs `CommitLimit` 107 G = over-committed.

---

## .the payoff: cost was NOT where RSS pointed

for 575 leaked daemons:

| cost | amount | visible to ps? |
|------|--------|----------------|
| RAM (PSS) | ~390 M | overstated 18x as ~9.4 G |
| swap (SwapPss) | ~4.5 G | no |
| page tables | share of 1.19 G | no |
| zombie cgroups | share of 120 | no |
| zram hostage | share of 2.82 G | no |

the direct RAM cost is genuinely small. the harm is that 4.5 G of swap
helped fill zram, and full zram means every later eviction goes to **disk**
— which is the actual desktop-wide crawl.

**a leak can wreck a machine without holding much RAM.**

---

## .the checklist

1. `machine.attribute.memory.sh` — rank by cgroup, not process name
2. read anon vs file — decides whether reclaim tuning can help at all
3. `--scope $name` to drill; read full cmdline from `/proc/$pid/cmdline`
4. **`/proc/$pid/smaps_rollup` for PSS** — never sum RSS across siblings
5. `--zombies` — count what no process tool can see
6. `/proc/meminfo` + `/sys/block/zram0/mm_stat` — kernel + zram overhead

## .the mistakes this method caught

each of these was asserted from weak evidence, then disproved by the next step:

| claim | disproved by |
|-------|--------------|
| "minimap is the nvim slowdown" | selfwatch log: buffer count, not minimap |
| "node procs are claude children" | `/proc/$pid/task/*/children` empty; PPid 1 |
| "cap claude at MemoryMax=3G" | `memory.peak` 5.59 G — would have OOM-killed sessions |
| "claude sessions are the hog" | cgroup ranking: firefox 7.7 G, two kitty scopes 1,700 pids |
| "daemons fail to reuse one socket" | each socket hash appears exactly once |
| "the socket hash is unstable" | source is deterministic sha256(realpath(HOME)) |
| "18 M each = lots of RAM" | PSS 714 K; RSS overcounts shared pages 18x |
| "only jest leaks these" | census: 4 distinct HOME shapes, not 1 |
| "git.commit.set/push leak in production" | `HOME=` → 0 matches in the prod `.sh`; slugs live only in `*.integration.test.ts` |
| "the daemons merely sit on RAM" | they poll every 15 min — 1.25 B major faults, they *churn* it |

> measure at the boundary the kernel accounts at.
> ps aggregates by name; the kernel accounts by cgroup and by page share.
