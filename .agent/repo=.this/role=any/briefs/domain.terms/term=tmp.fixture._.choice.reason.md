# domain.term.choice.reason: tmp.fixture

## .etymology

`fixture` is the settled word in test practice for the prepared state a test runs against — the
data, the files, the environment set up before an assertion. this domain narrows it to one
concrete form: **the directory that holds that prepared state for a single run**.

the word was chosen over four nearby candidates because only `fixture` names an **owner**. that
distinction is not stylistic — it is what makes a safe removal predicate expressible at all.

## ⚠️ .why the term carries a `tmp.` prefix

the repo already spends `fixture` on a different concept — a synthetic FILE a play feeds its own
reader, with a wanted verdict attached (`term=fixture._.choice._.md`). two objects, one word.

the glossary's scope rule decides it: *"could another domain object in this repo take this same
word?"* — it demonstrably could, and did. so the term is prefixed with its context.

the useful detail is that **the contract was already right**. the declared operation has always
been `tmp.fixture.prune`, never `fixture.prune`. the code carried the prefix before the glossary
did, so this file conforms the record to the contract rather than the reverse — which is the
direction the scope rule wants, and the opposite of a rename imposed on live code.

⚠️ the adjacent `fixture` cluster is left as-is. by the same test IT is owed a prefix too
(`play.fixture` is the candidate), but that rename reaches the whole play vocabulary and is the
human's call. recorded, not taken.

## .the evidence — why an owner-word beats a location-word

a prune must answer one question: *may this be removed?* the candidate words differ in whether
they can answer it:

| word | the property it names | the predicate it yields |
|------|----------------------|-------------------------|
| **tmp.fixture** | a run owns it | "the run is over" → safe |
| `tempdir` | it lives under `/tmp` | "it is in /tmp" → **unsafe** |
| `scratch` | its data is throwaway | no owner named → no predicate |

the counter-example that settles it: `/run/user/1000/keyrack.*.sock` is a temp path, is not a
fixture, and is **live**. a predicate built on "temp" reaps a live socket. a predicate built on
ownership — matched prefix, no live process cwd, past an age gate — cannot.

so the term is load-bear rather than decorative: the skill's three-part predicate is a direct
consequence of what the word means.

## .the invariant the word carries

a fixture is minted *for a run* and expected to die *with it*. that is not an aspiration, it is
the definition. two consequences follow:

1. **an abandoned fixture is a defect by definition.** it needs no separate rule to be wrong —
   the word already says so.
2. **the allocator owns the teardown.** if a fixture must die with its run, the operation that
   mints it is the only place that reliably knows when that is. a teardown registered at each
   call site is a rule that must be remembered, and a rule that must be remembered will be
   forgotten (`rule.require.pitofsuccess`).

the measured instance: ~55 call sites each minted a fixture inline. that count is exactly the
number of places the defect could be reintroduced. one allocator reduces it to one.

## .the scale that made it visible

| observation | value |
|-------------|-------|
| abandoned fixtures of one prefix | 12,901 of 15,385 /tmp dirs (84%) |
| kernel slab held to cache them | 3.3 GB `SReclaimable` |
| after a prune | 2,963 dirs, 2.21 GB slab |

worth the record: **no process-level tool could see this.** the slab is charged to no process, so
`ps`, `top`, and cgroup attribution were all blind. the only signals were `SReclaimable` in
`/proc/meminfo` and a raw directory count — which is how a five-figure population went unnoticed.

⚠️ and it refills. measured 2026-09-07: 931 dirs; 2026-09-08: 3,536 — roughly 118/hour with no
change to the workload. the prune is a chore, never a fix; the allocator is the fix.

## .disputes

none raised on the boundary. the four synonyms were weighed at authorship and each fails the
owner test above; they are recorded as forbidden rather than disputed because no contract had
reached for them.

the `tmp.` prefix is not a dispute either — it conforms the record to a contract that already
carried it. the OPEN question is the adjacent `fixture` cluster, recorded in its say file.

## .the neighbours

- **`fixture`** (unprefixed) — the play's synthetic subject. a different object entirely; see the
  disambiguation at the top of its say file
- **`sandbox`** — an *isolation boundary* (what a process may reach). a fixture may live inside a
  sandbox; they are orthogonal concepts, not synonyms
- **`workdir`** — the cwd of a process. often a real repo, frequently not disposable. the prune
  skill uses "is a live process's cwd" as a **skip** condition precisely because a workdir must
  survive
- **`daemon`** — the twin leak. throwaway fixture dirs used as `HOME` mint daemons keyed to that
  HOME, so an unreaped fixture leaks a process too. one allocator fix bounds both
- **`prune`** — the verb that acts on this noun, and the reason the owner property matters
