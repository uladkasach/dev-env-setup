# domain.term: concern

term.chosen   = concern
term.kind     = noun
term.synonyms.forbidden:
- alert
- warning
- issue
- problem
- finding

## .what

a crossed threshold, paired with the move that clears it.

a concern is **two-part by construction**: the observation is only half of it, and a concern that
states what is wrong without the move to fix it is malformed — not merely unhelpful. the pair is
enforced in the contract, so an author cannot record one half alone.

it carries a third field, **severity**, which never prints. severity exists to order the list so
the first line is the one to act on.

## .refs

**the contract:**

- `.agent/repo=.this/role=any/skills/machine.usage.diagnose.sh` — the `concern()` function,
  `concern <severity> <says> <fix>`; all three parameters are required, and the section renders
  each as a `says` line with its `🪄 fix` beneath

**the origin:**

- 2026-08-30 — the concern set was authored as bare strings and **deferred** from the glossary
  with a stated trigger: *"owed the moment the concern set stabilizes or a second caller reuses
  it."*
- 2026-08-31 — the trigger fired: the strings became a declared function with a three-part
  contract, so the debt came due and was paid

## .the boundary that makes this term carry weight

**every forbidden word names only the observation, and so licenses a report with no fix.**

| word | what it promises | does it oblige a fix? |
|------|------------------|-----------------------|
| **concern** | a crossed threshold **and** its remedy | ✅ — the pair is the definition |
| `alert` | a signal fired | ✗ — a klaxon owes the hearer no cure |
| `warning` | a caution | ✗ — advisory by nature, action optional |
| `issue` | a state that is wrong | ✗ — and overloaded with the tracker sense |
| `problem` | a difficulty | ✗ — states a state, implies no move |
| `finding` | a discovery | ✗ — audit vocabulary; a report, not a response |

`issue` deserves the sharpest line: this repo already reads and writes github **issues** via
`radio.task.push`. to use the word for a threshold report would overload a term the toolchain
owns, and a reader could not tell which sense a given sentence meant.

## .the word obliges the shape

`concern` is chosen because it implies **a party who cares** — a concern belongs to someone, and
whoever holds it wants it resolved. that is why the report says *"heres what concerns me"* in the
first person and why a fix is mandatory. an `alert` can be shouted into an empty room; a concern
is raised **to** someone, and it owes them a next step.

so the term carries weight rather than decoration: it is the reason `concern()` takes `fix` as a
required parameter rather than an optional one.

## .reason

see the ref-level file beside this choice:

- `term=concern._.choice.reason.md` — etymology, the deferral that was honored, the severity rank
