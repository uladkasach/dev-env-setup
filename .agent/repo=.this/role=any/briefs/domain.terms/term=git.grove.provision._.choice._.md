# domain.term: provision

term.chosen   = git.grove.provision
term.kind     = verb
term.synonyms.forbidden:
- setup        (says a state was reached, and no word about what reached it)
- bootstrap    (already TAKEN — `grove.bootstrap` is the pre-repo first contact)
- configure    (a PHASE of one bundle; to reuse it here overloads a live word)
- upgrade      (SUPERSEDED repo-wide 2026-08-31 — see `term=grove.provision`)
- deploy       (moves an artifact TO a box; this converges the box itself)
- install      (superseded repo-wide — see `term=grove.provision`)

## ⚠️ .`grove.provision` is NOT a synonym — it is this verb at the OTHER address

```
rhx grove.provision                     # THIS grove   — runs ON the box
rhx git.grove.provision boot <name>     # a REMOTE one — runs on your laptop
```

`git.` means forest-side in all thirteen of its siblings, so the prefix carries the
direction and no second word is needed. `boot` steps 2-3 send the bare form down the duct.

## .what
carry a box from BARE to acceptance-grade, in one command: reach it, push the
checkout, drive its one apply per seat, and gate it.

> `git.grove.provision` is the SEQUENCER. it converges no state of its own — every
> write it causes is a bundle's, driven through `grove.provision`.

## .the two verbs, and no third

```
git.grove.provision boot <name>    put a bare box into acceptance-grade   (writes)
git.grove.provision test <name>    ask whether it holds                   (reads)
```

they are a PAIR, and one dispatcher holds both because a split invited a caller to
re-state its callee's subject — measured 2026-08-30, when the gate halted with a
correct per-rung reason and the driver printed its own sentence underneath, which
named the wrong machine (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4).

⚠️ the slug is NOUN-FIRST on purpose. `rule.require.treestruct` asks `[verb][...noun]`
of a MECHANISM — a function, a type, a file. an `rhx` slug is a NAMESPACE ADDRESS,
so it is `[noun][...subnoun][verb]`: that is what keeps fourteen `git.grove.*`
commands under one `<TAB>` prefix where `wake.git.grove` would scatter them.

## ⚠️ .the boundary — a sequencer, never a second entrypoint

`rule.require.grove-provision-as-the-only-entrypoint` forbids a second path that
drives grove state. this is not one, and the line is exact:

| it does | it does NOT |
|---|---|
| order the steps, and refuse to skip one | write any grove state |
| judge each step's exit code | hold a bundle, a phase, or a fix |
| carry the checkout (`grove.push`) | converge what the tree does not |

⇒ delete this skill and every fact it produces is still reachable by hand. delete
`grove.provision` and it has no work at all. that asymmetry is the test.

## .why the word is `provision` and not a synonym

it is the word `ahbode/infrastructure` already uses for what it does to a box —
so the two halves of one lifecycle now share one verb: infra **provisions** the
instance, this **provisions** the tree onto it.

## .refs
where the term is declared / used:
- .agent/repo=.this/role=any/skills/git.grove.provision.sh        # the dispatcher
- .agent/repo=.this/role=any/skills/git.grove.provision.boot.sh   # the write half
- .agent/repo=.this/role=any/skills/git.grove.provision.test.sh   # the read half
- .agent/repo=.this/role=any/briefs/grove/provision/howto.provision-a-grove.md
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.one-command-provision.md
- .agent/repo=.this/role=any/briefs/grove/provision/rule.forbid.deferred-provision-defects.md

## .the neighbours
- `grove.wake` / `grove.trust` — `boot` step 1, reach
- `grove.push` — the carry, twice (one per seat)
- `grove.provision` — the apply this drives, and the sole writer
- `smoketest` — the CONCEPT `test` performs (`term=smoketest`); it holds no slug

## .reason
see the ref-level cluster beside this choice:
- `term=git.grove.provision._.choice.reason.md` — etymology, the rejected synonyms,
  and why the sequence earned a verb rather than a life as prose
