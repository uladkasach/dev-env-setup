# domain.term: diagnose

term.chosen   = diagnose
term.kind     = verb
term.synonyms.forbidden:
- check
- inspect
- analyze
- monitor
- audit

## .what

to **read a machine and name what is wrong, with the evidence that says so** — a read that ends
in an accusation rather than a dump.

three properties define it, and all three are load-bearing:

1. **read-only** — a diagnose never kills, never mutates, never syncs. it may be run in a panic
   with no thought, so it must be safe to run in a panic with no thought
2. **it ends in a `concern`** — a says + a required fix. a report that lists numbers and names no
   suspect has not diagnosed; it has printed
3. **it names its evidence** — the number that indicts, so a human can disagree with the reasoning
   rather than only with the verdict (`rule.require.name-what-you-measured`)

the third is what separates it from every rejected synonym. a `check` returns pass/fail; a
diagnose returns *what is wrong and how it was known*.

## ⚠️ .the hazard the word must carry

**a diagnose is trusted in exactly the moments a human has no time to verify it.** it is run when
the box is slow, the deadline is close, and the `🪄` line will be pasted into a terminal unread.

so a wrong diagnose is not a wrong number — it is a wrong **action**. measured across 2026-09-04
to 09-06, three separate diagnoses named a remedy their evidence could not support:

| what it said | what happened |
|---|---|
| "the heaviest parent is where to cut: pid=38244 tmux …" | six live work sessions died; the fork rate did not move |
| "🪄 kill -9 &lt;9 orphans&gt;" | six of the nine were healthy chrome zygotes |
| "the heaviest parent is where to cut: pid=1" | that is init |

each was a true measurement wrapped in an untrue license. so the term now carries the line:

> **a diagnose names a suspect and its evidence. it does not pass sentence.** where the evidence
> cannot distinguish a busy workload from a runaway one, the fix names a **probe**, never a kill.

## .refs

**the contracts:**

- `machine.diagnose.churn` — fork rate + the parent each churner came from
- `machine.diagnose.class` — what one process class costs, and whether cost tracks age
- `machine.diagnose.lag` — a full snapshot for later analysis
- `machine.usage.diagnose` — the machine's whole state, stall-first ⚠️ see the dispute in
  `term=stall._.choice.reason.md`
- `nvim.diagnose.runaway` / `nvim.diagnose.watchdog` — the nvim pair
- `howto.diagnose-machine-slowness.md` — the ladder that orders them

**the origin:**

- itemized 2026-09-06 by the frequency audit `configure`'s `.reason` prescribes: 6 declared
  operations, the most of any verb in this repo's own skills, and no cluster

## .the boundary

| word | what it implies | fits? |
|------|-----------------|-------|
| **diagnose** | read, then name what is wrong and why | ✅ carries the accusation AND the evidence |
| `check` | pass or fail | ✗ a boolean; a diagnose must name *which* thing and *how known* |
| `inspect` | look closely, report what is there | ✗ ends in a dump; to name a suspect is the whole job |
| `analyze` | process data | ✗ names the computation, not the outcome a human needs |
| `monitor` | watch continuously | ✗ a diagnose is a single act, on demand; that is `watchdog`'s job |
| `audit` | check against a standard | ✗ presumes a declared rubric; a diagnose has a machine, not a spec |

`inspect` is the closest miss and the one already in use elsewhere (`nvim.inspect.embed`), which
is correct: that operation reports what is there and accuses no one. the two words mark a real
split — **inspect ends in a description, diagnose ends in a concern.**

## .reason

see the ref-level file beside this choice:

- `term=diagnose._.choice.reason.md` — etymology, the three wrong-remedy cases in full, and why
  the frequency audit found this term rather than an incident
