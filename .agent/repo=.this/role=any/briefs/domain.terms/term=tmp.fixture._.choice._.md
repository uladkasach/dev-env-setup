# domain.term: tmp.fixture

term.chosen   = tmp.fixture
term.kind     = noun
term.synonyms.forbidden:
- tempdir
- scratch
- sandbox
- workdir

## ⚠️ .why this term is PREFIXED

`fixture` is already taken, by a different concept: a **synthetic subject a play builds to ask a
question of its own reader** (`term=fixture._.choice._.md`). that one is a file with a wanted
verdict; this one is a directory with an owner. they share a word and no other property.

the glossary's own scope test settles it:

> could another domain object in this repo take this same word? **yes → the term MUST be
> prefixed with its context.**

so this term carries its context, and the contract already did: the declared operation is
`tmp.fixture.prune`, never a bare `fixture.prune`. the prefix was in the code before it was in
the glossary — this file conforms the record to the contract rather than the reverse.

⚠️ the neighbouring `fixture` cluster stays bare. whether IT should become `play.fixture` is a
question about the play vocabulary, not about this term, and it is not settled here.

## .what

a directory a test harness mints to hold one run's state, keyed to that run and expected to die
with it. what defines it is **ownership by a run**, not its location or its lifetime.

## .refs

**the contract:**

- `.agent/repo=.this/role=any/skills/tmp.fixture.prune.sh` — the declared operation; its
  `PATTERNS` list is the set of fixture prefixes this machine knows

**the origin:**

- 2026-08-30 — 12,901 abandoned fixture dirs of one prefix found in `/tmp`, which held 3.3 GB of
  kernel slab
- `hazard.big-tmp-costs-ram-not-disk.md` — the hazard the term names

## .the boundary that makes this term carry weight

**`tempdir` is forbidden because it names the wrong property.** "temp" describes *where the dir
lives*; `tmp.fixture` describes *what owns it*. only the second supports the predicate a prune
needs:

| word | names | can a prune act on it? |
|------|-------|------------------------|
| **tmp.fixture** | owned by a test run | ✅ — reap once the run is gone |
| `tempdir` | lives under `/tmp` | ✗ — a socket dir also lives there |
| `scratch` | holds throwaway data | ✗ — names no owner, so no safe predicate |
| `sandbox` | isolated from the host | ✗ a distinct concept (an isolation boundary) |
| `workdir` | the cwd of a process | ✗ a distinct concept, and often a real repo |

the practical test: `/run/user/1000/keyrack.*.sock` is a **tempdir** and is **not** a fixture. a
prune that keyed on "temp" would reap a live socket. one that keys on ownership cannot.

## .the term implies its own defect

a fixture is *expected* to die with its run. so **an abandoned fixture is by definition a
defect** — the word carries the invariant. that is why the fix belongs in the allocator that
mints it (`rule.require.pitofsuccess`), never in each call site's discipline.

## .reason

see the ref-level file beside this choice:

- `term=tmp.fixture._.choice.reason.md` — etymology, the boundary evidence, the allocator rule
