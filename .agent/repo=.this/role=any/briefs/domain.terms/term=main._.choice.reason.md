# domain.term.choice.reason: main

## .etymology

`main` is not a word this domain coined — it is git's own default branch, which this repo
sets explicitly (`git config --global init.defaultBranch main`, `install_env.pt2.shell.sh`).
it was adopted rather than chosen, and that is the strongest kind of adoption: the human
already types it a dozen times a day.

it earns a glossary entry not because it was invented, but because it is now **half of a
declared pair** — `main | tree` — and a pair must be itemized to be enforceable.

## .what settled it — the human, 2026-07-28

> we use main | tree ubiquitously already

that is the whole argument. the pair was already the live vocabulary; the glossary sat
behind the code, not ahead of it.

## .the choice this closed — `--version local|global`

`rhx grove.provision` carried a flag `--version local|global`, which picked WHICH CHECKOUT
the configs are read from. it had two defects:

1. **`version` named the wrong concept.** a version is `v1.2.3`. this flag names a *place*.
   `--version global` never meant "the published version"; it meant "the other directory".
2. **`local` was overloaded.** the same command carries `--for local|cloud`, where `local`
   marks *a machine with a screen and a human*. one word, two unrelated concepts, one
   command — the exact defect `rule.forbid.domain-term-synonyms` blocks, and the exact
   shape `ubiqlang.ambiguous-from-overload` warns of.

`--from main|tree` closes both: `from` names a source, and neither value borrows a word
`--for` owns.

## .the near-miss worth a record — `--from worktree|checkout`

the robot first proposed `--from worktree|checkout`. that proposal was **already forbidden
by the glossary it was meant to serve**: `term=tree._.choice._.md` lists `checkout` under
`term.synonyms.forbidden`, precisely because `checkout` is generic and blind to the
machine-level structure above it.

so a proposal to fix a synonym overload introduced a forbidden synonym. the lesson is not
that the robot was careless — it is that **a term proposal must be checked against the
extant clusters before it is spoken**, per `rule.require.domain-discovery-for-term-proposals`.
the glossary already held the answer; it was not read first.

## .the asymmetry — `this` vs `tree` — SETTLED 2026-07-29, in favor of `tree`

the repo shipped two `--from` flags with two words for "the one i am in now":

| command | flag | values |
|---------|------|--------|
| `git tree set <branch>` | `--from` | `main` \| `this` → **now `main` \| `tree`** |
| `rhx grove.provision` | `--from` | `main` \| `tree` |

the robot logged this as an open question and argued it *might* not be drift, on the
grounds that the two flags take different KINDS of value — `git tree set` a git ref,
`grove.provision` a directory.

the human settled it in one line:

> its tree; we should use tree

and the argument for the split does not survive a second look. **both flags answer the same
question** — *which of the two places on this machine?* — and the answer set is the pair
`main | tree`. that the one carries a ref and the other a directory is an implementation
detail of what each does with the answer; it is not a difference in what the human is
asked. a flag's vocabulary belongs to the question, not to the type the callee happens to
want.

so `this` is a **forbidden synonym of `tree`** in a `--from` contract, recorded in
`term=tree._.choice._.md`.

### the lesson the round paid for

the robot had the evidence to settle this and chose to log it instead. the entry read
`status: unsettled … contracts use main|tree meanwhile` — which quietly ships the drift it
names. one line from the human closed it.

that is the SAME shape as round 27's `duct.uri` collision: *the glossary recorded the
problem and the record stood in for the fix.* twice now, a note has felt like diligence and
been avoidance. so:

> **a dispute you can argue to a conclusion is not a dispute. it is a decision you declined
> to make.** open a dispute when the evidence genuinely does not settle it — never as a
> place to put a call you would rather not own.

## .evidence

- ubiquity, `main`: `git release main`, `git tree set --from main`, `git.repo.pull`
  (`git checkout main && git pull`), `init.defaultBranch main`, and prose throughout
  `bash_aliases.sh` ("the main checkout", "in main repo")
- ubiquity, `tree`: the whole `git tree get|set|del|status` family, plus its own cluster
- the pair test: a traveler says "carve a tree off main" and "install from main, not from
  the tree" — both spoken aloud, which is the bar `def.domain-discovery` sets
- decomposition: the where-does-this-code-live axis on one machine has exactly two cells —
  the trunk checkout, and the N worktrees carved from it. `main | tree` walks that product
  with no leftover cell

## .disputes

### dispute: this — raised 2026-07-28 — status: RESOLVED 2026-07-29 (keep `tree`)
- raised.by  = robot (logged, not argued)
- claim      = `grove.provision --from tree` should be `--from this`, to match the extant
               `git tree set --from main|this`, so one `--from` vocabulary serves both
- counter    = the two flags take different kinds of value — `git tree set` takes a git
               ref (where `this` = the current branch), `grove.provision` takes a directory
               (where `tree` = this worktree). `tree` is the declared term for that
               directory; `this` would be a synonym for it
- resolution = the human settled it — "its tree; we should use tree". the direction went the
               OTHER way than the dispute proposed: rather than the provision context adopt `this`, the
               extant `git tree set --from main|this` was renamed to `main|tree`. both flags
               ask the same question (which of the two places on this machine?), so both
               take the same answer set. `this` is recorded as a forbidden synonym of
               `tree`, and `git tree set --from this` now fails with an error that names
               the fix
