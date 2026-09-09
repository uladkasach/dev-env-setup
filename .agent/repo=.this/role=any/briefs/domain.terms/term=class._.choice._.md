# domain.term: class

term.chosen   = class
term.kind     = noun
term.synonyms.forbidden:
- group
- kind
- family
- bucket
- type

## .what

the set of every live process that shares one `comm`, treated as **one accountable unit**.

what defines a class is that its cost is charged to the set rather than to any member. a class can
hold the most memory on a machine while no member of it ranks high individually — that is not an
edge case, it is the normal shape of a session-per-worktree workload.

the members are interchangeable for attribution but **not** for action: which member to close is a
per-member question, and a class profile exists precisely to answer it.

⚠️ nor are they interchangeable for a **trend**. a shared `comm` licenses a shared bill; it never
licenses the assumption of a shared workload. on 2026-09-07 two nvim members of the same age cost
16M and 3217M — one a `--embed` core with a 250M transcript, one the thin TUI beside it. any
statistic computed across a class presumes one population, and that presumption is the class
profile's job to test, never to assume (`term=leak`, the second correction).

## .refs

**the contract:**

- `.agent/repo=.this/role=any/skills/machine.diagnose.class.sh` — the declared operation;
  `--of <comm>` profiles a class, `--drill <pid>` breaks one member down
- `.agent/repo=.this/role=any/skills/machine.usage.diagnose.sh` — the `census` row groups by class

**the origin:**

- 2026-09-02 — 15 `claude` members held 10.7G rss + 16.2G swap. no member exceeded 4G, so every
  per-process threshold on the box stayed silent while the class held ~40% of memory in use

## .the boundary that makes this term carry weight

**the forbidden words all name a loose collection; `class` names an accountable one.**

| word | what it implies | fits? |
|------|-----------------|-------|
| **class** | a set that is charged as one, with comparable members | ✅ accountability is the content |
| `group` | any collection, by any criterion | ✗ names no membership rule |
| `kind` | a category | ✗ **overloaded** — `rule.prefer.kind-over-type` owns it for a domain discriminator |
| `family` | related but not identical | ✗ a class shares one exact comm, not a resemblance |
| `bucket` | a container after a sort | ✗ names the container, not the members |
| `type` | a static category | ✗ a class is a live population, and `type` is spoken for in code |

`kind` deserves the sharpest line: this org already has `rule.prefer.kind-over-type`, which makes
`kind` the canonical word for a **domain discriminator** on an object. a class is a runtime
population, not a discriminator, so to reuse the word would collide two settled senses.

## .a class is profiled, never merely counted

a count answers *how many*, and that is the least useful fact about a class. the questions that
follow a count are what the profile exists for:

- does cost track **age**? (a leak) or is it flat? (a headcount)
- what does the **cheapest** member cost — the floor no close can remove?
- which member is **dearest** — the one to close first?

so the contract reports a spread and a correlation, not a total. a class report that stops at the
total is a census row, and the census already did that job.

## .reason

see the ref-level file beside this choice:

- `term=class._.choice.reason.md` — etymology, the leak-vs-baseline split, the drill
