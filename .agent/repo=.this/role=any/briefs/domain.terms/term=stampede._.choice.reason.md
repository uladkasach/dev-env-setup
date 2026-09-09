# domain.term.choice.reason: stampede

## .etymology

spanish *estampida* — a herd that has stood penned and pressed, then breaks all at once. the
word carries two halves at the same time: the **pressure that built** and the **release**. that
pair is exactly the phenomenon, and it is why the shorter words lose.

`burst` names only the release. `backlog` names only the pressure. a stampede is both, and the
defect lives in their junction — the fires were correct to owe, and correct to pay, and ruinous
to pay together.

## .the case that named it

2026-09-02. the nvim watchdog trend log held 40 consecutive lines with one timestamp:

```
2026-09-02T13:28:28 rss_mb=1426 cpu_ticks=14842 bufs=14691 ts=0 tripped=true
2026-09-02T13:28:28 rss_mb=1427 cpu_ticks=0     bufs=14691 ts=0 tripped=true
2026-09-02T13:28:28 rss_mb=1428 cpu_ticks=0     bufs=14691 ts=0 tripped=true
... 37 more, same second
```

the `cpu_ticks=14842` on the first line and `0` on every line after is the fingerprint: one fire
observed the whole starvation interval, then 39 more fired against a clock that had not moved.

the cause is libuv's contract for a repeat timer: a missed interval is **owed, not skipped**. the
box was deep in swap, this core went unscheduled for roughly 20 minutes, and 40 intervals came
due at the instant it was rescheduled.

## .why the guard is not merely an optimization

each fire costs a `/proc/self/status` read, a walk over every buffer, and a log append. at 40
fires that is 40 buffer walks over a core that holds 14,691 buffers, plus 40 disk appends —
imposed on a machine already so contended that this process could not get a timeslice.

so the guard against a leak becomes a load, and it does so **precisely when the machine is
worst off**. that inversion is the whole reason the concept needed a name: a load that appears
only under load is invisible to every measurement taken when things are calm.

## ⚠️ .the defect it caught in my own instrument, on the first run

the skill that reports a stampede computed its growth rate like this:

```sh
mins = (n-1) / 2   # 👎 wrong: assumes one line == one 30s tick
```

the timer is **configured** for 30 seconds, so i treated 30 seconds as a fact about each line.
under a stampede that assumption is exactly inverted — 40 lines spanned **0 seconds**. the skill
divided a real 17M of growth by a fictional 20 minutes and printed:

```
rss: 1126M → 1143M   (+17M, 0.9M/min)
```

a calm, confident, wrong number, for a core in free fall. worse, the tool that reported the
stampede was itself fooled by it.

> **the durable lesson: a cadence is an assumption, never a measurement.** a configured interval
> says what a timer *intends*; only two timestamps say what it *did*. wherever elapsed time is
> derived from a count of events, the derivation holds only while the cadence holds — and the
> cases worth a diagnostic are exactly the cases where it does not.

the fix reads the wall clock (`date -d "$T_TO" - date -d "$T_FROM"`), and a zero-second span
across many lines prints `rate unknowable` plus the stampede concern, rather than a fabricated
rate.

## .this is the fourth instance of one pattern

each of these shipped a confident string that read as actionable and aimed at the wrong target,
and each did so because a **proxy stood in for the real measurement, unchecked**:

| term | the proxy | what it stood for |
|------|-----------|-------------------|
| `wedged` | duration | no progress |
| `class` | sort order | the axis the advice named |
| `orphan` | ppid | the party that acted |
| `stampede` | line count | elapsed time |

the pattern is now stable enough to state as a check, not a lesson: **for every number a report
prints, name what it actually measured, and confirm that is what the sentence claims.**

## .disputes

none raised, but the boundary against `churn` was close enough to warrant the explicit table in
the say file. `storm` was already recorded as a forbidden synonym of `churn`, so a nearby word
for a nearby concept is the exact shape of drift the glossary exists to catch.

the split holds because the two differ on the property that decides the fix: churn has many
actors and a real window, so a rate is meaningful and a parent is cuttable. a stampede has one
actor and no window, so no rate exists and the fix is a cadence guard.

## .the neighbours

- **`churn`** — the nearest neighbour, and the one most at risk of collapse. see the table in
  the say file; the split is actor-count and tense.
- **`stall`** — the cause upstream. a stampede is what a psi cpu stall looks like *from inside*
  the stalled process, once it is finally scheduled.
- **`watchdog`** — the mechanism that stampedes here. any repeat timer can, but a watchdog is
  the case where it matters most, because a watchdog exists to help under load.
- **`concern`** — a stampede is reported first among concerns, because it invalidates every
  number beneath it. a concern that voids its siblings must be ordered above them.
