# domain.term: review

term.chosen   = review
term.kind     = verb
term.synonyms.forbidden:
- diagnose (reserved — a distinct sense, see below)
- inspect (reserved — a distinct sense, see below)
- audit
- report
- summarize
- analyze

## .what

to read an **accumulated record** back, ranked, so the next repair is chosen by evidence rather
than by memory.

`review` is retrospective and aggregate: it reads many past events at once, and it needs no live
subject. the fault it names may have happened yesterday, in a process long since exited.

## .why it is not `diagnose` or `inspect`

these three are **not synonyms** — they are three distinct senses, and this repo already spends
all three on `nvim` alone. the split is by **tense and subject**, and it is what keeps the skill
names legible at a glance:

| verb | tense | subject | answers |
|------|-------|---------|---------|
| `review` | retrospective, aggregate | a durable record | "what has cost me the most?" |
| `diagnose` | present | a live fault | "why is this one hung right now?" |
| `inspect` | present | a live entity | "what state is this process in?" |
| `test` | present | a subject you drive | "does it hold when i push it?" |

the tell: `review` is the only one of the four that still works when **no nvim is alive**. that
is the whole reason it earns its own word — the log outlives the process, so the verb that reads
it must not imply a live subject.

`audit` / `report` / `summarize` / `analyze` are forbidden as vaguer restatements of the same
sense; they add no distinction and would fragment one concept across four words.

## .refs

**the contract:**

- `.agent/repo=.this/role=any/skills/nvim.errors.review.sh` — the operation
- invoked as `rhx nvim.errors.review`

**the siblings that hold the other senses:**

- `.agent/repo=.this/role=any/skills/nvim.diagnose.runaway.sh` — present, live fault
- `.agent/repo=.this/role=any/skills/machine.diagnose.lag.sh` — present, live fault
- `.agent/repo=.this/role=any/skills/nvim.inspect.embed.sh` — present, live entity
- `.agent/repo=.this/role=any/skills/nvim.test.headless.sh` — present, driven subject

**the briefs:**

- `.agent/repo=.this/role=any/briefs/desktop/nvim/howto.review-nvim-errors.md` — when to review vs diagnose

## .reason

see the ref-level file beside this choice:

- `term=review._.choice.reason.md` — etymology, the evidence, why each synonym is forbidden
