# domain.term.choice.reason: wedged

## .etymology

a **wedge** is driven into a gap and then holds by friction — it neither falls through nor comes
free. the metaphor is exact for the state: the process did not complete and did not die, and it
stays in that position under its own power.

the word also carries prior art in unix folklore, where a *wedged* terminal or device is one that
is live on paper yet advances no further. the domain narrows that sense to a process, and adds
the cost clause: **it still consumes cpu while it fails to advance**.

## .the case that named it

2026-08-30, on a box with 6d3h uptime:

```
npm run test:integration --testPathPatterns patent.priors.search
  pid=277073   elapsed=147h36m   cpu=10.6%
  cwd=~/git/ehmpathy/_worktrees/rhachet-roles-rhight.vlad.registrator-corp-franchise
```

147 hours exceeds the uptime of the boot it was found in, so it had been wedged since essentially
the moment the machine came up. no diagnostic on the box named it, across several days of
diagnoses, because:

- it was **not** the top cpu holder (10.6% against neighbours above 100%)
- it was **not** a memory holder (0.2%)
- it was **not** in D-state, and it was **not** a zombie
- `ps` showed it as a perfectly ordinary `R`/`S` process

it appeared in a `TOP 15 CPU` report repeatedly and was read past every time — the `elapsed`
column was present the whole while and carried the entire signal.

## .why the conjunction is the definition

each half of the predicate, alone, describes a healthy state:

| predicate | matches | verdict |
|-----------|---------|---------|
| `elapsed > 24h` alone | every daemon, every long-lived session | healthy |
| `pcpu > 5%` alone | every build, test run, compile | healthy |
| **both together** | work that should have ended and has not | **defect** |

this is why no level-based alarm could ever have caught it, and why the term had to name the
*conjunction* rather than either axis. a word that named one half would have licensed a detector
that finds only healthy processes.

## .the reinforcement it feeds

a wedged process is worse than its own cost when it **respawns children**. the same round:

```
pid=277073  npm run test:integration  elapsed=147h36m   ← the wedged parent
pid=277102  node <same worktree>      elapsed=2s  cpu=133%   ← its child, brand new
```

a 147-hour parent with a 2-second-old child at 133% of a core is a respawn loop. that puts a
wedged process at the head of the machine's only self-fed chain:

```
wedged parent respawns children
  → each child mints a fixture dir that is never reaped
  → dentry/inode slab grows
  → slab squeezes anon → swap → I/O stall
  → all work slows → runs overlap more → more children per wall-clock hour
```

so the term carries weight twice: it names a defect that evades every level alarm, **and** that
defect is frequently the fuel injector for the reinforcement loop described in
`hazard.big-tmp-costs-ram-not-disk.md`.

## .the threshold, and why it is what it is

`etimes > 86400` (24h) and `pcpu > 5.0`:

- **24h**, not 1h — a legitimate long test, a large build, or an overnight job must not be
  indicted. a day of continuous cpu is past every honest workload on a workstation.
- **5%**, not 1% — a long-lived daemon that ticks a timer sits near 1%. 5% is above tick noise
  and below any real workload, so it separates *still at work* from *merely alive*.

both are deliberately conservative: this concern proposes a kill, so a false positive is
expensive. an under-count here is preferable to a wrong indictment.

## ⚠️ .correction — the predicate produced false positives the same day

the threshold above is **incomplete**, and one round of live use proved it. on 2026-09-01 the
detector indicted three processes:

```
🪤 wedged — claude (pid 1120555) 34h at 5.2% cpu
🪤 wedged — claude (pid 2333244) 57h at 5.3% cpu
🪤 wedged — claude (pid 2834444) 47h at 5.6% cpu
```

all three were **healthy interactive sessions** doing real work. the fix each carried was
`kill -9`, so the report proposed destroying live work, which is the most expensive class of
false positive a diagnostic can produce.

**the cause is a gap between the word and the predicate.** `wedged` is defined by three
properties — alive, on cpu, and *makes no progress*. the predicate tests only the first two and
infers the third from duration. that inference holds for a batch job, which is expected to end,
and fails for an interactive session, which is expected to persist.

**the missing discriminator: a controlling terminal.** a process attached to a live tty has a
human at the other end, and a human is the progress the predicate cannot see. a batch process has
no tty, so a long-lived tty-less process on cpu remains a sound indictment.

so the predicate owes a third clause — no controlling terminal — and until it carries one, the
🪤 concern must be read as a **candidate**, never a verdict. the fix string was already worded
`confirm, then end it`, which is the only reason this misfire cost a read rather than a session.

**the durable lesson:** a term with a three-part definition needs a three-part predicate. where a
predicate infers one clause from a proxy, the proxy must be recorded as an assumption — here,
*"duration implies no progress"* — because that is the exact line along which it will break.

## .disputes

none raised on the word. `zombie` was never a candidate once its unix sense was checked; `hung`
and `stuck` both failed on the cost clause, which is the half that makes the state matter.

the **predicate** is under correction (see above), but the term is not in dispute — the false
positives came from an incomplete test of a sound definition, not from a wrong word.

## .the neighbours

- **`runaway`** — a live detector for high cpu **now**, with no duration test. it catches the
  spawn storm; wedged catches the long tail. both ship, and they overlap only by accident.
- **`spinner`** — sustained high cpu over ~30 min. the nearest neighbour, and the difference is a
  matter of degree: a spinner may still finish, a wedged process will not.
- **`orphan`** — a process whose cwd was deleted. orthogonal: an orphan may be healthy, and a
  wedged process usually has a valid cwd.
