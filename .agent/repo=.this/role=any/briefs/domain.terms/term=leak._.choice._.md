# domain.term: leak

term.chosen   = leak
term.kind     = noun
term.synonyms.forbidden:
- creep
- bloat
- drift
- growth

## .what

memory a process holds and does not release, which grows without bound over the process
lifetime. the defect ends at the **swap cliff** — the point where the machine pages to disk and
every read stalls on I/O.

a `leak` is a **defect claim**, not a rate. it asserts the growth has no upper bound. ordinary
accumulation that plateaus is not a leak.

## .refs

**the contract:**

- `.agent/repo=.this/role=any/briefs/hazard.idle-process-leak-crosses-the-swap-cliff.md` — the
  hazard brief that owns the word
- `.agent/repo=.this/role=any/skills/nvim.diagnose.runaway.sh` — emits `🐘 high MEM` against a
  1GB threshold; the detector for this concept in the nvim case
- `.agent/repo=.this/role=any/skills/machine.attribute.memory.sh` — attributes held memory to its
  origin process

**the origin:**

- the keyrack daemon incident — 641 leaked daemons filled zram, forced disk-swap thrash
- 2026-08-30 sample — two `nvim --embed` cores at ~1,080MB each, one 2d15h old, with swap at
  15.8G after four prior samples held a flat zero

## .the boundary that makes this term carry weight

**`creep` is forbidden because it is weaker, not because it is wrong.** the two words make
different claims, and to swap them is to overstate or understate a defect:

| word | claims | provable by |
|------|--------|-------------|
| **leak** | growth without bound; a defect | swap engaged, or growth past a plateau |
| `creep` | a rate of growth | one measurement against a prior one |

a rate alone does not prove a defect — long-lived processes accumulate and plateau. so `creep`
may be used in **prose** to name a rate, and must not be used in a **contract** where `leak` is
the concept.

`bloat` names a large **steady** footprint (an nvim `--embed` core is heavy by design, not
leaked). `drift` belongs to config, not memory.

## .reason

see the ref-level file beside this choice:

- `term=leak._.choice.reason.md` — etymology, the dispute that settled it, evidence
