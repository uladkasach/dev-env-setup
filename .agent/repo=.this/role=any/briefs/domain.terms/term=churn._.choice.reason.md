# domain.term.choice.reason: churn

## .etymology

to **churn** is to agitate a vessel so its contents turn over continuously. the word names motion
without accumulation — the butter churn's paddle never gets anywhere, and that is precisely the
point.

the sense carries into business usage (customer churn = arrivals and departures, not headcount)
and it is the same sense the domain needs: **population turnover, not population size**. a machine
at 200 forks/sec may hold a steady 560 processes. the count says calm; the turnover says otherwise.

## .the case that named it — a load nobody could attribute

2026-09-01, 12 cores:

```
load    41.50 / 34.85 / 26.24
psi cpu 71.09%                  ← tasks waited on cpu 71% of wall time
idle    0%
```

the entire top-cpu list was under 2 seconds old, except one process:

```
etimes  pcpu  pid       args
  2296  18.7  3718338   /usr/local/bin/nvim --embed     ← the ONLY long-lived burner
```

so a 41.5 load had exactly **one** explicable contributor at 18%. every diagnostic on the box —
`ps`, `top`, the runaway hunter, the census — could account for a fraction of it. the rest was
invisible because it had already exited.

the rate made it visible at once:

| measure | reading |
|---------|---------|
| forks | **209–384/sec** |
| context switches | **36,000–60,000/sec** |
| distinct pids per name, 5s window | `bash` 51, `sh` 42, `zsh` 40, `run.bun.rhachet` 27 |

at roughly 5ms of kernel work per fork+exec, 200/sec is about one full core spent on process
**setup**, before any of that work performs its task. 384/sec is nearly two.

## .the honest correction this term forced

my own attempts to read those processes failed repeatedly:

```
cat: /proc/3939614/cmdline: No such file or directory
💨 [exited] (was 1600% CPU — gone before re-read)
```

i read those as tooling errors and worked around them. they were not errors — **they were the
measurement**. a process that vanishes between two reads is telling you its lifetime is shorter
than your sampling interval, which is the definition of churn.

the lesson: when a per-process probe keeps failing on missing pids, stop repairing the probe and
switch to a rate. the failure IS the finding.

## .the parent rule — a churner's name is never the culprit

the top `born` names were `sh`, `bash`, `zsh`, `node`, `run.bun.rhachet`. every one of those names
a **runtime**, not a cause. no action follows from "bash was born 51 times."

the accountable party is the parent, which is long-lived and therefore readable:

```
14 spawns  pid=74765    tmux new-session -d -s rhachet-roles-ghlitch...
14 spawns  pid=10457    claude
12 spawns  pid=1119362  claude
 7 spawns  pid=4059672  claude
```

that turns an unactionable rate into a name. the operation therefore reports **both** — the rate
proves churn exists, the parent says where to cut. a churn report without parent attribution
satisfies curiosity and licenses no action, which fails `rule.require.errors-name-the-fix`.

the mechanism is a 4-deep exec chain per hook invocation:

```
.bin/rhachet (sh) → bin/run (sh) → run.bun (bash) → run.bun.*.bc (ELF)
```

10 PreToolUse hooks per Bash call, times ~16 concurrent sessions. each link is individually
cheap and correct; the product is a spawn storm.

## .why this measurement was owed earlier

a prior round proposed a hook-multiplex fix and **retracted** it, because the argument rested on
invocation *count* (12 hook matchers) rather than a measured cost. that retraction was correct at
the time — the arithmetic was speculation.

209–384 forks/sec is the measurement that was missing. the same proposal now stands on evidence.
worth the record: the retraction was not wrong, it was *early*, and the right response to an
unmeasured claim is to go measure it rather than to argue it more forcefully.

## .disputes

none raised. `thrash` was the only serious contender and it lost on the overload test — this
machine has had genuine memory thrash, so the word is spoken for and the two failures need
opposite responses (relieve memory vs. reduce spawns).

## .the neighbours

- **`stall`** — what churn *produces*. psi cpu 71% is the stall; 384 forks/sec is the churn that
  caused it. the stall says a resource is contended; the churn says why.
- **`leak`** — unbounded growth of a **resident** population. churn's population is roughly
  constant; its members simply keep being replaced. a leak accumulates, churn does not.
- **`wedged`** — a single process that will not finish. the opposite failure: churn is many
  processes that finish too fast to observe.
- **`load`** — the runqueue count churn inflates. load is the symptom, churn one of its causes.
