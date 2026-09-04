# domain.term: smoketest

term.chosen   = smoketest
term.kind     = noun — a CONCEPT, in no slug
term.synonyms.forbidden:
- verify        (taken by `git.grove.ready.verify`, and READ-ONLY by definition. a smoketest
                 writes — that write is the whole point, per `.what` below)
- prove         (taken as a play verb. a `prove`'s subject is a CLAIM about a run — is this
                 idempotent? does the tree settle? a smoketest's subject is a BOX's
                 CAPABILITY, and it lives in `skills/`, not `playbooks/`)
- check         (says a claim was looked at, not that a job was run)
- healthcheck   (names a cheap liveness poll, run on a timer. this runs a full job, once,
                 and takes minutes)
- acceptance    (names the ROLE the gate plays, not the ACT it performs. `rule.require.
                 smoketest-before-a-grove-is-declared-ready` is where that role is stated)
- e2e           (names the SPAN of a run and asserts no verdict; and it is a qualifier this
                 repo already uses in a subject slot — `prove.svc-chat-integration-e2e`)
- validate      (says a shape was inspected; a smoketest exercises)

## 🛑 .the word names an ACT; the slug that performs it is `git.grove.provision test`

this concept has **no slug of its own**. the act it names is the `test` verb of
`git.grove.provision`, and the word survives here — which is where a concept with no slug
belongs. ⚠️ do not mint a `grove.smoketest` slug to "restore" it: that is a second
entrypoint, and the concept did not need one.

⇒ `test` is therefore **not** a forbidden synonym. the noun-first prefix settles the clash
`git.repo.test` would otherwise cause: `git.grove.provision test` judges a BOX,
`git.repo.test` judges a REPO. two namespaces, one verb, and the subject is in the name.

## .what

**one command that makes a box do a REAL JOB, end to end, and judges the result.** exit 0 is
the acceptance criteria for a grove — not a green `grove.provision`, not a converged plan, not
a human's read of the logs.

```sh
rhx git.grove.provision test <name>
```

on this repo's grove that job is `ahbode/svc-chat`'s integration suite: sync the tree to
latest `origin/main`, install its deps, provision a testdb, run the suite, tally it green.

## ⚠️ .it WRITES, and that is what makes it deterministic

every other read in this repo is forbidden to change the box. this one must, and the reason is
exactly the reason it exists:

> a gate whose verdict depends on **who ran what by hand beforehand** is not a gate.

so a smoketest **establishes** every precondition rather than assumes it. the sync, the deps,
and the fixture are steps 1-3, run every time. that is the line between it and
`git.grove.ready.verify`:

| | reads | writes | its subject |
|---|---|---|---|
| `git.grove.ready.verify` rungs 1-5 | yes | never | **the box** |
| `git.grove.provision test` steps 0-4 | yes | its own fixtures | **the box, plus a tree on it** |

📜 the split is clean by SUBJECT because it once was not. the ladder held two further rungs
— `6 tree` and `7 suite` — and rung 7 ran `git.repo.test --what integration --mode apply`
against the same live testdb step 4 uses. so **the two ladders shared one write**, and 6-7
asked three questions steps 1, 2, and 4 already ask
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).

⇒ the ladder asks about the machine; the smoketest asks about a tree on it. a rung that
crosses that line is the m.9 shape, and it re-earns the same duplicate write.

⚠️ the write is BOUNDED, and the bound is `rule.forbid.repair-plays`: none of what it writes
is **grove state**. node_modules is workspace state, the testdb is a fixture, the checked-out
ref is fixture freshness. the CLONE is grove state — so when the tree is absent, the
smoketest **halts and names `5.10.repos`** rather than clone it itself. that refusal is where
the line is enforced rather than merely described.

## .why a JOB and not a checklist

measured 2026-08-12, on a box that reported **zero claims on both seats**:

| the signal | said | and yet |
|---|---|---|
| `grove.provision --mode plan`, ground | ✔ 127 · ✋ 0 | — |
| `grove.provision --mode plan`, camper | ✔ 125 · ✋ 0 | — |
| `git.repo.test` on svc-chat | — | **0 tests ran** |

three faults stood between that converged box and a suite that could run, and NO bundle verify
could see any of them, because none is grove state.

⇒ **a converged box is not a capable box.** the bundle tree declares what a machine HAS; only
a job proves what it can DO.

## .what it does NOT replace

- `grove.provision --mode plan` — still the way to see WHICH bundle a box lacks. a smoketest
  says only that the box works
- `git.grove.ready.verify` — still the diagnostic. it halts one rung at a time with a precise fix,
  and the smoketest CALLS it (step 0) rather than duplicate it
- `prove.*` — a `prove` proves a BUNDLE; a smoketest proves a BOX

## .refs
- .agent/repo=.this/role=any/skills/git.grove.provision.test.sh          # the gate
- .agent/repo=.this/role=any/skills/git.grove.operations.sh         # the transport both it and
                                                                #  `git.grove.ready.verify` ride
- .agent/repo=.this/role=any/briefs/grove/reach/rule.require.smoketest-before-a-grove-is-declared-ready.md
- .agent/repo=.this/role=any/briefs/grove/reach/howto.add-a-new-grove.md    # ends here
- .agent/repo=.this/role=any/briefs/grove/reach/howto.adopt-a-replacement-grove.md  # ends here

## .reason
see the ref-level cluster beside this choice:
- `term=smoketest._.choice.reason.md` — the etymology from hardware, why it is a SKILL and not
  a play, and the `prove` dispute
