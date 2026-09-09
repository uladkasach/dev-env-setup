# domain.term.choice.reason: census

## .etymology

`census` carries, from roman practice onward, one invariant the domain needs: **it counts
everyone**. a census is not a sample, not a shortlist, and not a contest — it is the complete
enumeration of a population, grouped by the categories the counter cares about.

that invariant is the whole reason the word was chosen over `top`. every other candidate names a
*selection*; only `census` names a *totality*.

## .the blind spot it names

a per-process view has a structural failure mode: **a class can hold the most while no member
ranks high.** the two are not in tension — a diffuse class is exactly the case a top-N cannot
represent.

the measured instance, 2026-08-30:

| view | what it showed | verdict a reader draws |
|------|----------------|------------------------|
| `top 15 mem` | 12 separate `claude` rows, 1.5%–3.4% each | "memory is diffuse, no big holder" |
| census | `claude · 13 procs · 8.7G` | "one class holds ~47% of memory in use" |

both read the same `/proc`. the top-N was not wrong about any single number; it was structurally
unable to add them up. a threshold hung off a per-process metric inherits the same blindness —
which is why a diffuse class evades every per-process alarm ever written.

the full census that round:

```
claude           13 procs  8.7G
node             58 procs  3.8G
Isolated Web Co  15 procs  2.3G
nvim              4 procs  1.3G
kitty            12 procs  0.6G
```

the second row is the other half of the lesson: `node` at 58 processes was invisible to the
top-15 too, and it turned out to be the spawn storm behind the cpu stall.

## .the SIGPIPE trap that made it lie

the first implementation cut the census with `sort -rn | head -5`. `head` exits at its fifth
line, hands SIGPIPE to `sort`, and under `set -o pipefail` the whole command substitution
resolved **empty** — the report printed a census with zero rows and no error:

```
   └─ 🌕 census: who holds it, by name
         ├─                   0 procs  G rss
```

worse than absent, because a blank row reads as a measurement. two repairs, both durable:

1. **cut with `awk NR<=n`, never `head`.** awk reads to EOF, so the cut cannot race its writer.
2. **fail loud on an empty capture.** the contract now prints `💥 census empty` rather than an
   empty template, per `rule.forbid.failhide`.

the general lesson: a totality-word makes a silent truncation a **correctness** defect, not a
cosmetic one. the word raised the bar the code had to meet.

## .the accuracy caveat, stated plainly

the census sums **RSS**, which double-counts pages shared between members of a class — 13 claude
processes share one binary's text. so the total overstates.

this is accepted, and the reason is scope: the census exists to **rank classes**, and every class
is overstated by the same mechanism, so the order is sound. when the question shifts from *which
class* to *how much exactly*, the census hands off to `machine.attribute.memory`, which reads PSS
and cgroup charge. one tool ranks, the next attributes.

## .disputes

none raised. `top` was the incumbent by habit rather than by argument — the machine's prior tools
all used it — and the 8.7 GB it could not see settled the matter without a counter-case.

## .the neighbours

- **`top`** — kept as a legitimate, distinct view: when the question is *which individual is
  hot*, a top-N is right and a census is useless. the two coexist in the same report.
- **`attribution`** — the cgroup-charge view (`machine.attribute.memory`). a census groups by
  *name*; attribution groups by *origin*. a reparented daemon breaks the first and not the second.
- **`hunt`** — the detector pass that names individual suspects. the census frames the population;
  the hunt names members within it.
