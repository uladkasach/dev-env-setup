# domain.term: stall

term.chosen   = stall
term.kind     = noun
term.synonyms.forbidden:
- load
- usage
- saturation
- busy

## .what

the share of wall time in which **at least one task waited** on a resource it could not get.

a stall is a statement about **waiters**, not about fill. a resource can be 100% consumed with
zero stall (every task got what it asked for) and a resource can stall while a level reads calm
(the burst was short but everyone queued behind it).

the kernel supplies it directly as `/proc/pressure/{cpu,io,memory}`; the `some` line is the one
that names a stall (`full` names a total halt).

## .refs

**the contract:**

- `.agent/repo=.this/role=any/skills/machine.usage.diagnose.sh` — emits `stall:` as its own
  header row, and checks it **before** every level threshold in the concerns pass

**the origin:**

- 2026-08-30 — a box read as "88% idle, load 15.61" and neither number could say what was
  contended. `/proc/pressure/cpu` answered outright: `some avg60=21.87`
- `howto.diagnose-machine-slowness.md` — the ladder this term sits at the top of

## .the boundary that makes this term carry weight

**a level and a stall answer different questions, and only the stall is actionable.**

| word | what it names | can it name the contended resource? |
|------|---------------|-------------------------------------|
| **stall** | someone waited on it | ✅ — that is its whole content |
| `load` | runnable + uninterruptible count | ✗ — conflates "at work" with "blocked" |
| `usage` | how full, right now | ✗ — a full resource with no waiters is fine |
| `saturation` | at capacity | ✗ — names the level, not the queue |
| `busy` | consumed | ✗ — the healthy case reads identical |

the case that settles it: **load 15.61 on 12 cores at 88% idle**. `load` says overloaded, `usage`
says idle, and the two disagree because each names a level. `psi cpu 21.87` says *tasks waited on
cpu*, which is neither, and is the fact worth a response.

## .a stall is bursty, never a point

the same box reported `psi cpu 0.02` and `psi cpu 15.00` inside the same session. both were true.
a stall from a spawn storm is spiky by nature, so a single sample can miss it entirely — read the
avg10/avg60/avg300 triple, never one number.

## .reason

see the ref-level file beside this choice:

- `term=stall._.choice.reason.md` — etymology, the misread it retires, evidence
