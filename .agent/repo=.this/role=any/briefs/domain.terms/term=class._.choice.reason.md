# domain.term.choice.reason: class

## .etymology

latin *classis* — a division of the roman citizenry **by property assessment**. the word named a
set defined by what its members were worth, and that is precisely the sense the domain needs: a
class is a set the machine charges as one.

the modern computing sense (a template that shares behavior) is close enough to feel familiar and
far enough to stay clear, because a runtime population is not a template. what carries across is
the part that matters — **members of a class are comparable to each other**, so a spread over them
is meaningful, where a spread over an arbitrary collection is noise.

## .the case that named it

2026-09-02:

```
class          members    rss      swap
claude              15   10.7G    16.2G
```

no member exceeded 4G. every per-process threshold on the box stayed silent while this one class
held roughly 40% of memory in use. the census row was the first artifact to name it, and the
census row was also the limit of what it could say — a count and a total, no more.

## .the split the profile exists to make

a class total answers no question on its own, because two very different failures produce the same
total. the profile separates them with a single number — the correlation between a member's age
and its footprint:

| r | what it says | the fix |
|---|--------------|---------|
| → 1 | cost tracks age — a **leak** | fix the leak; a close only buys time |
| → 0 | cost is flat — a **headcount** | close members; there is no leak to fix |

for `claude`, **r = 0.19**. the class is a headcount, not a leak. that one number is the whole
reason a class is profiled rather than merely counted.

## ⚠️ .correction — i twice advised the wrong close, before i measured

before this measurement i twice told the human to "close the oldest sessions." that advice was a
**leak assumption stated before evidence**, and it was wrong.

| pid | age | transcript | anon | total cost |
|-----|-----|------------|------|------------|
| 4059672 | 47h | 435M / 17 files | 1249M | 3596M |
| 2333244 | 59h | — | — | 3520M |
| 1332718 | **180h** | 36M / 1 file | 189M | **1030M** |

the **oldest** member was the **cheapest** — 3.5× cheaper than a member a quarter its age. cost
tracks transcript volume, which is a proxy for work done, not for time alive.

the defect was not in the arithmetic. it was in the **sort order**: the member list came back
ordered by age while the advice beneath it spoke of cost. a reader who trusts the order acts on
the first row, so the order silently made the recommendation.

> **the durable lesson: a sort order encodes a hypothesis.** to sort by age is to assert that age
> predicts cost. state that assertion, or sort by the axis the advice names.

the member list now sorts by footprint, and the report prints `cheapest · median · dearest` rather
than a lone floor — three points, so no single row can pose as the answer.

## ⚠️ .the second defect — the drill hid its own failure

`--drill <pid>` locates a session's transcript under `~/.claude/projects/<slug>/`, where the slug
derives from the cwd. the first slug rule replaced only `/`:

```sh
D_SLUG=$(printf '%s' "$D_CWD" | sed 's|/|-|g')   # 👎 wrong
```

claude replaces **every** non-alphanumeric char, so a cwd with a `.` or a `=` produced a slug that
matched no directory. zero files were found, `D_TX_M` defaulted to `0`, and `0` flowed into the
numeric branch that reads:

```
transcript is small (0M) — the cost is runtime baseline
```

the true transcript was **435M**. the report stated the exact opposite of the truth, with the
confidence of a measurement.

> **the durable lesson: a default value is a failhide in wait.** where a sentinel shares the value
> space of a real reading, absent-and-zero cannot be told apart from measured-and-zero. the sentinel
> needs its own flag.

the fix is both halves — the slug rule now matches claude's, and a `D_TX_FOUND` flag gates the
numeric branch so an absent directory reaches a `💥` failloud rather than a false verdict.

## .why the profile reports a spread, never a total

a count answers *how many*, and that is the least useful fact about a class. the questions a
human actually holds after a count are:

- what does the **cheapest** member cost? that is the floor no close can remove
- what does the **dearest** cost? that is the member to close first
- how far apart are they? a wide spread means the choice of which to close matters; a narrow one
  means it does not

so the contract reports three points and a correlation. a class report that stops at the total is
a census row, and the census already did that job.

## ⚠️ .the second hazard — one application can hold many classes

measured 2026-09-06. the census top-5 read:

```
├─ claude           22 procs  10.2G
├─ chrome           24 procs   1.4G
├─ kitty            24 procs   1.0G
├─ kitten           48 procs   0.5G
└─ firefox-bin       1 procs   0.4G
```

firefox reads as the cheapest app on the box. the full per-process view said otherwise:

```
├─  8.6G (27.7%)  Isolated  ×37
```

**8.6G**, second only to claude — and absent from the census entirely, because firefox's content
processes carry the comm `Isolated Web Co` (truncated from *Isolated Web Content*), not
`firefox-bin`. the class keyed on comm was correct. the human's read of it was not.

so the term carries a second hazard, and it is the **inverse** of the first:

| | hazard one | hazard two |
|---|---|---|
| what happens | cost lands on a set, no member shows it | cost lands on a set whose NAME does not identify its owner |
| what it defeats | a per-process threshold | a per-name read |
| the tell | 15 members at 3% each | a familiar app ranked implausibly cheap |

> **a class is keyed on `comm`, and one application may own several.** where a class name is
> unfamiliar, or a familiar application ranks implausibly cheap, that application's cost is split
> across comms and no single row holds it.

this is not a defect in the key — to group by comm is what makes a class measurable at all. it is
a defect in the **inference** a reader draws, so the cure is a reader's habit rather than a code
change: when a census row surprises you by its cheapness, look for its siblings under another
name.

## .disputes

none raised. `kind` was the only serious contender and it lost on the overload test: this org
already has `rule.prefer.kind-over-type`, which makes `kind` the canonical word for a **domain
discriminator** on an object. a class is a live runtime population, not a discriminator, so to
reuse the word would collide two settled senses.

## .the neighbours

- **`census`** — the index; a class profile is the page. the census names which classes exist and
  what each costs in total; the class profile answers the questions that follow one row of it.
- **`churn`** — a rate of births. a class is a live population at one instant; churn is how fast
  that population turns over. a class can be flat in count and violent in churn.
- **`leak`** — unbounded growth of a resident population. the class profile is the instrument that
  tests for a leak (via r) rather than assumes one — this exact test is what corrected the advice
  above.
