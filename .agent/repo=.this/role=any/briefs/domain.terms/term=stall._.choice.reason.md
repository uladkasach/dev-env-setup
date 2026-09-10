# domain.term.choice.reason: stall

## .etymology

`stall` is the plain english for *forward motion that halted*, and it is the word the linux
kernel itself chose: PSI stands for **P**ressure **S**tall **I**nformation, merged in 4.20. the
domain adopts the kernel's own noun rather than a private coinage, so a reader who greps
`/proc/pressure` finds the same word the contract prints.

`pressure` is the kernel's **parent** term (the file family is `pressure/`), so it is not a
forbidden synonym — it is the container. `stall` is the quantity inside it, and the quantity is
what a diagnosis acts on.

## .the misread this term retires

the four forbidden words all name a **level**. a level cannot answer the one question a
diagnosis asks — *what is contended?* — because a level says how full a resource is, never
whether anyone waited for it.

the measured case, 2026-08-30:

| reading | verdict it implies | true? |
|---------|-------------------|-------|
| `load 15.61` on 12 cores | overloaded, 1.30x | ambiguous |
| `88% idle` | almost no work at all | ambiguous |
| `psi cpu some avg60=21.87` | **tasks waited on cpu** | ✅ decisive |
| `psi io some avg60=0.06` | disk was NOT the problem | ✅ decisive |

load and idle disagreed because each named a level from a different side. neither could name the
resource. the third line did, in one number, and it also **cleared** disk — which mattered,
because the prior day's diagnosis of the same box had correctly blamed I/O, and this one no
longer could.

## .the two errors it prevents, both of which were made

1. **high load + high idle read as "busy."** it is the opposite: tasks exist that cannot run.
   the pair is the most misread signal on the machine, which is why the concerns pass branches
   on `idle > 70` and says *blocked, not busy* in words.
2. **a stale stall read as current.** 94 hours of accumulated io-stall total sat in
   `/proc/pressure/io` from an earlier swap-thrash incident. the `total=` counter is
   since-boot and monotonic; only the `avgN` windows describe now. an author who reads `total`
   re-diagnoses a fixed problem.

## .the sample-rate lesson

within one session the same box gave:

```
psi cpu some avg60=21.87     ← a spawn storm, mid-burst
psi cpu some avg60=0.02      ← minutes later, between bursts
psi cpu some avg60=14.84     ← again
```

all three were correct. the stall was **real and bursty**, driven by short-lived spawns each
above 100% of a core. a single point sample nearly produced a retraction of a true finding.

two consequences the contract carries:

- print the **triple**, not one window — a burst hides in avg300 and shows in avg10
- render at **2dp** — at 1dp a live `0.04` rounds to `0.0` and reads as clean

## .disputes

the four synonyms were weighed at authorship: each names a level, and the level/stall split is
the whole reason the term exists. one dispute is open on where that forbid reaches.

### dispute: `usage`, in the skill name `machine.usage.diagnose` — raised 2026-09-06 — status: OPEN

- raised.by = the frequency audit that itemized `diagnose`
- found     = `usage` sits in this term's `term.synonyms.forbidden`, and
              `.agent/repo=.this/role=any/skills/machine.usage.diagnose.sh` is a declared
              operation. worse, this cluster's own `.refs` cites that skill as **the contract**
              for `stall` — so the glossary points at a contract that carries the forbidden word
- claim     = the name is correct as it stands. the skill reports the machine's **whole** state
              — stall, levels, classes, churn, concerns. `usage` there names the *breadth of
              the read*, not the metric, so it is a different sense of the word than the one
              this term forbids
- counter   = `rule.forbid.domain-term-synonyms` scopes the forbid to **contracts**, and a skill
              name is a contract by that rule's own definition. the sense-split above is exactly
              the argument `rule.forbid.domain-term-ambiguity` refuses: one word that serves two
              jobs is the defect, not the defence. and the harm is live — this skill's whole
              design lesson was that a level read as a stall, so its **name** carries the word
              its **body** was built to demote
- weighed   = `machine.state.diagnose` — `state` is the breadth the claim wants, with no
              collision. reads true against the body: stall, levels, classes, churn, concerns
              are all state. `machine.diagnose.*` siblings each name one facet; this one names
              the whole, so it belongs beside them rather than under a second verb order
- cost      = a rename changes a command the human types daily, and the string is cited in
              `howto.diagnose-machine-slowness.md`, in this file, and in `term=diagnose`'s refs.
              that is a clean rework — a rename plus three citation edits, no teardown — but it
              is the human's call, not the audit's
- verdict   = **left OPEN for the human.** the recommendation is `machine.state.diagnose`. the
              canonical word is unchanged either way: `stall` stays the metric, and the skill
              still reads stall before every level, whatever it is called

## .the neighbours

- **`iowait`** — a cpu-time accounting bucket, not a stall. it says a core sat idle *with* an
  outstanding I/O, which undercounts when other work fills the core. psi io is strictly better.
- **`D-state`** — a per-process state (uninterruptible sleep). a headcount of D-state procs is a
  proxy for io stall; psi io is the direct measure, so the count is kept only as corroboration.
- **`level`** — the general class the forbidden words belong to (mem %, swap depth, slab GB).
  levels stay in the report; they are how *full*, and severity needs both.
