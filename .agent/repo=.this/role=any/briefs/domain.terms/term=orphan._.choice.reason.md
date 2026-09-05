# domain.term.choice.reason: orphan

## .etymology

from the kinship sense: a child whose parent is gone. unix inherited it precisely — an *orphan
process* is one whose parent exited, so `init` adopts it. that precision is what made the word
attractive, and its spread past that one referent is what cost it.

the repo reached for `orphan` five separate times, each time by analogy rather than by a look at
what the word already named here. no cluster existed to check against, so each reach was locally
reasonable and the collision was invisible.

## 🛑 .the ambiguity is what this round found

`rule.forbid.domain-term-ambiguity` and `rule.forbid.term.addition.ambiguous` both forbid a term
that reads more than one way. `orphan` reads five ways, and — the sharp part — it is **already
cited twice as evidence AGAINST other candidate words**, on the express ground that it carries a
distinct sense. singular.

so the glossary has twice ruled *"do not use `orphan` here, it means another thing"* while never
recording what that other thing is. a forbid whose premise was never written down cannot be
checked, and this one turns out to be false.

⚠️ this is the `gotcha.a-check-that-cries-wolf-gets-silenced` m.6 shape, applied to vocabulary
rather than to a reader: **a true, authoritative, in-repo sentence used to settle a question it
was never about.** `term=strand`'s counter-argument — *"`orphan` says the account has no PARENT,
but it has one"* — is sound against the KINSHIP sense. it says none of senses B, C, D, or E,
which are the whole of what `orphan` actually does here.

## .disputes

### dispute: orphan — raised 2026-09-04 — status: OPEN

- raised.by  = mechanic, on the `vlad/boot-grove-box` rebase
- claim      = `orphan` is overloaded across five live senses and must be split. senses A–C
               share a real shape (a record that outlived its referent) and could keep the
               word; D and E do not fit it and need their own terms.
- counter    = the word sits on a PUBLISHED cli surface — `git grove del --orphaned`,
               `git grove stop --prune orphans`, `machine.usage.diagnose.orphan` — plus a
               permanent clamp (`prove.orphan-sweep-bites`) and a test snap
               (`snap.orphan-roster-is-populated`). a rename breaks a human's muscle memory,
               and the ambiguity has cost exactly one measured defect so far.
- resolution = **unsettled.** see below.

## .why this was NOT settled in the round that found it

the learner's own bar is *"a term the round SETTLED → capture it NOW; defer ONLY a term you
truly cannot finish."* this one is genuinely unfinished, for two reasons:

1. **it is a fulcrum whose rework is not clean.** the choice tips a published cli surface. per
   `rule.always.defer-fulcrums-to-last`, a fulcrum whose reversal would force a teardown is
   flagged, never best-guessed. a rename applied and then reverted would churn the clamp, the
   snap, the alias, and the human's fingers.
2. **the round that found it was a REBASE.** to fold a vocabulary split into a rebase would
   breach `rule.require.review-test-changes` — an unrelated refactor smuggled into a
   history-rewrite, which is the hardest place for a reviewer to see it.

⇒ so the round captured what it MEASURED (the five senses, the sense-A contradiction, the two
false premises) and left the CHOICE open. the measurement is the durable half; the rename is a
decision the human owns.

## .evidence

each sense read off its own site, 2026-09-04 — never from the commit message that prompted the
review (`gotcha.my-own-note-became-my-evidence`):

```
src/machine/machine_resource_procs_find_orphan:4   # finds processes whose cwd was deleted
1.6.procs/1.6.1.finders/_.sh:7                     # a process whose parent is gone
2.7.aliases/bash_aliases.sh:183                    # cwd deleted (stale worktrees)
2.7.aliases/bash_aliases.sh:2676                   # unregister every grove whose instance is gone
term=grove.stop._.choice.reason.md:51              # --prune orphans … ssm sessions whose box is gone
term=exhibit._.choice.reason.md:64                 # uncited → an exhibit or an orphan
```

the sense-A contradiction is a **live defect**, not a doc nit: the bundle header describes a
condition its own script does not test. two of three sites say *cwd deleted*; the `_.sh` says
*parent gone*. a reader who trusts the bundle header will hunt the wrong hazard.

## .the open questions the human owns

1. does `orphan` keep senses A–C, or narrow to one?
2. sense D (an uncited artifact) — is `orphan` right, or does `term=exhibit` already carry it?
3. sense E (a lost-delete file) — needs a word. it is **not** `shadow`, which is defined by
   PATH precedence and not by count: the flat twin outranked no one, it was merely tracked
   and dead.
4. whichever way 1–3 land, `1.6.1.finders/_.sh:7` is wrong today and is fixable now.

## .see also

- `rule.forbid.domain-term-ambiguity` — the rule this term violates
- `term=shadow._.choice.reason.md` / `term=strand._.choice.reason.md` — the two records whose
  premise this corrects
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.6, the shape of a true sentence applied
  to the wrong claim
