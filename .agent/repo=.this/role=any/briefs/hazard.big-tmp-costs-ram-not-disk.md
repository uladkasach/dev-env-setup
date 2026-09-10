# hazard: a big /tmp costs RAM and latency, not disk

## .what

a `/tmp` with tens of thousands of directories degrades the **whole machine** — not because it
fills the disk (the dirs are tiny) but because **directory count** taxes kernel memory, every
path lookup, and boot.

the usual source is a **test harness that mkdtemps a fixture dir per run and never reaps it**.
any harness can do this; the specific prefix changes over time, so diagnose by shape rather than
by name: a large family of same-prefix dirs in `/tmp` with no live process attached.

one measured instance: **12,901 of 15,385** `/tmp` dirs were abandoned fixtures of a single
prefix (84%), and the kernel held **3.3 GB** of reclaimable slab to cache them.

## .why it is counter-intuitive

every process-level tool is **blind** to this cost:

- `ps`, `top`, `htop` — see zero; no process owns it
- `machine.attribute.memory` — sees zero; no cgroup is charged
- `df` — sees almost none of it; the dirs are empty

it is kernel memory, charged to no owner. the only place it shows is `/proc/meminfo`:

```sh
cat /proc/meminfo | head -30
```

```
KReclaimable:    3341984 kB
Slab:            3980260 kB
SReclaimable:    3341984 kB   <- the dentry + inode cache
SUnreclaim:       638276 kB
```

## .the four costs, in order of impact

### 1. dentry/inode slab (the big one)

the kernel caches a `dentry` + `inode` struct per directory it has touched. at ~13,000 dirs (plus
their children) that reached **3.3 GB**.

**"reclaimable" is not "free".** the label means the kernel *can* evict it under pressure — but
eviction is work:

- the shrinker must **walk and evict** those objects, which burns CPU at the exact moment memory
  is already tight
- it competes with the anon pages that genuinely need RAM, so it *deepens* a swap event rather
  than relieves it
- a slab that large fragments, so allocation of new kernel objects slows

so a big `/tmp` does not merely hold RAM — it makes every future memory-pressure event more
expensive.

### 2. every path scan becomes O(n)

`readdir`, glob, `find`, and shell completion all walk the entire directory. observed: a ripgrep
over `/tmp` **exceeded a 20-second timeout** and returned no result.

anything that touches `/tmp` — including tools you did not think touched it — pays this on every
call.

### 3. boot blocks

`systemd-tmpfiles-setup.service` walks `/tmp` at boot. on a LUKS system this costs **minutes**
(ref: pop-os/pop#1048). that is the failure this eventually presents as.

### 4. inode exhaustion

inodes are held until removal. a filesystem can run out of inodes with gigabytes of free space.

## .why a daily cleanup timer cannot win

`tmp-cleanup.timer` exists and runs daily:

```
ExecStart=/usr/bin/find /tmp -mindepth 1 -mtime +3 -delete
```

it does not keep up, for two reasons:

1. **the gate is 3 days** — everything younger survives every pass
2. **the fill rate exceeds the drain rate** — test harnesses mkdtemp per run, all day

a daily sweep with a 3-day gate against a continuous fill is a losing race. the pool grows
monotonically while the timer reports success.

## .the fix

**at the source (the real cure): the ALLOCATOR owns the teardown.**

a fixture dir must be reaped by the same operation that mints it. put the guarantee in one shared
allocator — a `genTempDir`-style operation — never in each call site's discipline:

```ts
// the allocator registers its own teardown; a caller cannot forget
export const genTempDir = async (input: { prefix: string }) => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), input.prefix));
  afterAll(async () => { await fs.rm(dir, { recursive: true, force: true }); });
  return dir;
};
```

**why the allocator and not the call site:** a per-call-site `afterAll` is a rule every future
author must remember, and a rule that must be remembered is a rule that will be forgotten. one
allocator makes teardown structural — the leak becomes impossible rather than merely discouraged
(`rule.require.pitofsuccess`). it also gives one place to add a `--keep` escape hatch for a failed
test a human wants to inspect.

**the tell that an allocator is missing:** a search for the fixture prefix returns dozens of call
sites that each mkdtemp inline. that count is the number of places the leak can be reintroduced.

**locally (the bound):**

```sh
rhx tmp.fixture.prune              # plan
rhx tmp.fixture.prune --mode apply # remove
```

a 30-minute gate rather than 3 days, and it skips any dir that is a live process's cwd. this
bounds the symptom; only the allocator fix removes the cause.

## .the tell

if the machine feels sluggish and **no process explains it** — cgroup attribution comes back
clean, top CPU is quiet, swap is modest — check the slab. a cost charged to no owner is invisible
to every tool that reports per-process.

```sh
cat /proc/meminfo | head -30      # SReclaimable
tree -L 1 -d /tmp | tail -1       # directory count
```

a `SReclaimable` in the GB range with a `/tmp` in the thousands is this hazard.

## .enforcement

- a test harness that mkdtemps without a registered teardown = **blocker**
- reliance on a daily `-mtime +N` sweep as the only bound on a continuous fill = **blocker**

## .see also

- `howto.diagnose-machine-slowness.md` — where this sits in the diagnostic ladder (step 3)
- `hazard.idle-process-leak-crosses-the-swap-cliff.md` — the sibling hazard, in anon rather than slab
- `.agent/**/skills/tmp.fixture.prune.sh` — the bound
