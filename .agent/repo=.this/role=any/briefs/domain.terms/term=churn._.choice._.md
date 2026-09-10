# domain.term: churn

term.chosen   = churn
term.kind     = noun
term.synonyms.forbidden:
- storm
- thrash
- flood
- spam
- load

## .what

a **rate of process births** — work that costs the machine through how often it starts, not
through how much any one instance holds.

churn is defined by turnover, so its members are individually trivial and collectively decisive.
each spawn lives well under a second and holds almost no memory, yet at a few hundred per second
the kernel spends whole cores on fork+exec setup before any of that work does anything.

the defining property: **churn cannot be sampled per member.** by the time a reader opens
`/proc/<pid>`, that pid is gone. only a rate is observable.

## .refs

**the contract:**

- `.agent/repo=.this/role=any/skills/machine.diagnose.churn.sh` — the declared operation; reads
  the fork rate from `/proc/stat`'s monotonic `processes` counter, then attributes it to a live
  parent

**the origin:**

- 2026-09-01 — load 41.5 on 12 cores with psi cpu **71%**, and exactly ONE long-lived cpu burner.
  no per-process tool could name the other 70%: 209–384 forks/sec, ~36k–60k context switches/sec
- `howto.diagnose-machine-slowness.md` — the ladder this term adds a rung to

## .the boundary that makes this term carry weight

**every forbidden word names a volume; only `churn` names a turnover.**

| word | what it claims | fits? |
|------|----------------|-------|
| **churn** | a rate of birth and death; members are transient | ✅ turnover is the whole content |
| `storm` | an intense burst | ✗ implies an abnormal peak — churn is often steady state |
| `thrash` | repeated eviction and reload | ✗ **overloaded** — the platform owns it for swap/cache |
| `flood` | more volume than capacity | ✗ names a quantity, not a lifecycle |
| `spam` | unwanted repetition | ✗ pejorative; the spawns are legitimate work |
| `load` | the runqueue count | ✗ the **symptom** churn produces, not churn itself |

`thrash` deserves the sharpest line: it already denotes *memory thrash* — pages evicted and
faulted back in a loop. that is a distinct failure this machine has genuinely had. to reuse the
word for process turnover would collide two different diagnoses that demand opposite fixes.

## .churn is measured as a rate or not at all

a per-process tool is structurally blind here — the population turns over faster than it can be
read. so the contract reads a **monotonic counter delta** (`/proc/stat` `processes`) over a known
window, which is exact rather than sampled.

the corollary that makes the term useful: a churner's own name (`sh`, `node`, `bash`) names a
runtime, never a culprit. the accountable party is the **parent**, which is long-lived and
therefore readable. the operation reports both.

## .reason

see the ref-level file beside this choice:

- `term=churn._.choice.reason.md` — etymology, the invisible-load case, the parent rule
