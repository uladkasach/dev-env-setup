# domain.term.choice.reason: leak

## .etymology

`leak` is the settled word in systems practice for memory a process holds and never returns. it
carries the right shape for this domain: a vessel that loses what it should retain, and the loss
compounds until the vessel fails. the failure point here has a name of its own — the **swap
cliff** — and the hazard brief pairs the two.

the word was already in this repo before any dispute: the brief
`hazard.idle-process-leak-crosses-the-swap-cliff.md` names it in its own filename. this cluster
does not introduce `leak`; it records why the word held when a weaker synonym was tested against
it.

## .disputes

### dispute: creep — raised 2026-08-25 — status: RESOLVED (keep `leak`)

- raised.by  = mechanic, mid-diagnostic
- claim      = while I described +8.5G/day of memory growth, I reached for **idle creep** rather
               than `leak`. `creep` felt more honest at that moment: the growth was real and
               measured, but swap sat at a flat zero across four samples, and every byte traced
               to ordinary long-lived processes (stacked claude sessions, an 8h-old browser tab).
               to call that a `leak` would have been the stronger, unproven claim.
- counter    = `creep` names only a **rate**. `leak` names a **defect** — growth with no upper
               bound. a rate is one measurement against another; a defect needs evidence the
               growth has no plateau. the two are not synonyms of equal strength, so the word
               must be chosen against the evidence in hand, never by feel.
- resolution = keep `leak` as the canonical contract word; record `creep` as a forbidden synonym
               **in contracts** while it stays allowed in prose to name a rate. the 2026-08-30
               sample settled which word the evidence supports: swap crossed 0 → 15.8G, iowait
               rose 6×, and two `nvim --embed` cores sat at ~1,080MB each (one 2d15h old). that
               is unbounded growth, so `leak` was earned and applied. dispute closed.

**the lesson the dispute preserves:** the restraint was correct on 2026-08-25 *and* the upgrade
was correct on 2026-08-30. the same concept warranted two different words on two days because
the evidence differed. a future traveler should read the swap column before they choose.

## .evidence

**the sample series** — five readings of `machine.diagnose.lag --quick`, same machine, one uptime:

| date | mem used | swap | iowait | verdict |
|------|----------|------|--------|---------|
| 08-24 14:11 | 5.1G (17%) | 0G | 5% | baseline |
| 08-24 22:27 | 10.7G (35%) | 0G | 0% | accumulation, plateau unproven |
| 08-25 20:39 | 19.2G (63%) | 0G | 1% | `creep` — a rate, no defect proven |
| 08-30 13:33 | 21.1G (69%) | **15.8G** | **6%** | **`leak`** — the cliff crossed |

the swap column is what turned the word. four samples of flat zero, then 15.8G paged out.

**the tell that `idle` misleads:** at 08-30 the summary read `idle: 89%` while load held 10.23
(1m) and 10.25 (5m) — sustained across minutes, so not the diagnostic's own cost. the machine was
not busy; it was blocked on I/O as it paged memory back. a `leak` past the cliff presents as an
idle machine that feels slow, which is exactly why the concept needs one unambiguous word.

**the prior incident** — 641 leaked keyrack daemons filled zram and forced disk-swap thrash. same
shape, different origin process. that incident is what makes `leak` a repo concern rather than a
generic systems term.

## ⚠️ .the correction — 2026-08-30, same day, later

the evidence table above named **nvim** as the leak origin. that attribution was **wrong**, and
the correction is the most useful lesson in this file.

it was drawn from `ps`-style RSS, which sorts by resident size per process. RSS names *the
binary that holds the pages*, not *the origin that leaked them*. once
`machine.attribute.memory` was repaired and cgroup attribution ran, the true origin appeared:

| by RSS (wrong) | by cgroup (true) |
|----------------|------------------|
| nvim, ~1,080MB ×2 — "biggest single offender" | tmux scope, 5.5G / **1,699 pids** |
| 5 claude sessions ≈ 3.2G | overstated — PSS shows a shared node binary |
| leaked daemons — **invisible** | **191 keyrack daemons**, 152 spawned within one hour |

the daemons were invisible to every process-level tool because each one is merely "node" — the
spawner had already exited, so they reparented to pid 1 with no trace of origin. cgroup
membership is assigned at fork and **survives reparent**, so the scope still charged them.

**the lesson, stated for the next traveler:** to name a leak you must attribute by **cgroup**,
never by process name. `ps` aggregation by comm answers "which binary holds memory", which is a
different question from "what leaked it". the same 191 daemons that were the true cause did not
appear in any top-15 RSS list at all.

nvim still holds a **real, separate** leak — the selfwatch log proves it (`bufs` 5,306 → 6,216 in
15 min while `rss` stayed flat behind a tripped breaker). two genuine leaks ran at once; RSS
surfaced the smaller and hid the larger.

## ⚠️ .the second correction — 2026-09-07, two contracts, opposite verdicts

the correction above fixed **where** a leak is attributed. this one fixes **how** it is tested,
and it was forced by the worst possible evidence: two declared operations, run one minute apart
against the same subject, that disagreed while both used this canonical word.

| operation | its verdict on nvim |
|---|---|
| `nvim.diagnose.watchdog` | 🔥 **BUFFER leak** — bufs grew by 1410 alongside 50M of rss |
| `machine.diagnose.class --of nvim` | footprint does **NOT** track age (r=0.34) — **a baseline, not a leak** |

both were computed correctly. both cannot be right. the word did its job — one concept, one name
— and the two skills still contradicted each other, which locates the defect in the **test**
rather than in the term.

### the two tests measure different things

| | what it watches | what it is |
|---|---|---|
| watchdog | **one member, across time** — the same pid re-read | the direct measure of a slope |
| class `r` | **many members, at one instant** — age stands in for elapsed time | a **proxy** for that slope |

the cross-sectional correlation substitutes *"an older member costs more"* for *"a member costs
more as it ages"*. that substitution is legitimate — and it is a `proxy`, so it carries a
condition, and the condition was never stated.

### the condition the proxy needs, and how it failed

age predicts cost across members only when the members are **comparable**. the 2026-09-07 sample:

```
pid=557041   22.7h    77M rss   3140M swap  = 3217M     <- 250M transcript, heavy worktree
pid=369781    1.1h    56M rss    366M swap  =  422M
pid=624555   22.6h    13M rss      3M swap  =   16M     <- same age as the outlier, 200x cheaper
pid=599512   22.6h    13M rss      3M swap  =   16M
pid=369750    1.1h     4M rss      1M swap  =    5M     <- a thin TUI, not a core
```

n=5, a 200× spread, and two members of the **same age** at 16M and 3217M. these share a `comm`
and share no workload: one is a `--embed` core with a 250M transcript, one is the thin TUI
beside it. pearson r over that is noise, and `r=0.34` carries no information whatever.

worse than uninformative — it was **printed as a verdict**, in the sentence *"a baseline, not a
leak"*, which is the exact shape `term=diagnose` forbids: a true computation wrapped in an
untrue license.

### what the contract owes

1. **a sample-size floor** — below ~8 comparable members, report r as *undetermined*, never as a
   verdict. the skill's own note already says *"a single member is a sample of one"*; the same
   logic bounds a correlation
2. **an outlier guard** — when the dearest member exceeds the median by an order of magnitude,
   the class is not one population and r describes no trend. say so
3. **the fallback is already right** — the same report's next line reads *"the spread is 5M to
   3217M — what a member HOLDS drives it."* that line was correct and useful while the r line
   above it was false. the fix is to demote r, not to add a new measure

### the lesson, stated for the next traveler

> **a leak is a slope within one member over time.** any test that reads across members at one
> instant is a proxy for that slope, and it holds only while the members are one population.
>
> where the two disagree, **the longitudinal read wins** — it measures the concept; the
> cross-sectional read merely stands in for it.

this also sharpens `class`: its cluster says members are *"interchangeable for attribution but
not for action."* this round adds a third column — they are **not interchangeable for the age
test either**. a shared `comm` licenses a shared bill, never a shared workload.

## .the neighbours

three nearby words that must not collapse into `leak`:

- **`bloat`** — a large but **steady** footprint. an `nvim --embed` core is heavy by design; the
  TUI/core split is normal and the heavy core is expected. bloat is a baseline, a leak is a slope.
- **`creep`** — a rate, as disputed above.
- **`runaway`** — a **cpu** defect, not a memory one. `nvim.diagnose.runaway.sh` flags both
  dimensions separately (`🔥 high CPU` vs `🐘 high MEM`), and the skill's own vocabulary keeps
  them apart. do not use `runaway` for a memory leak.
