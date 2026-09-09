# domain.term.choice.reason: orphan

## .etymology

greek *orphanós* — bereft of a parent. unix inherited it precisely: an *orphan process* is one
whose parent exited, so `init` adopts it. that precision is what made the word attractive, and
its spread past that one referent is what cost it.

the repo reached for `orphan` six separate times, each by analogy rather than by a look at what
the word already named here. no cluster existed to check against, so each reach was locally
reasonable and the collision was invisible.

## ⚠️ .this is a word the domain did NOT choose

`orphan` was **imported**, and it arrived with its sense already fixed by the platform. that
changes the obligation:

- for a word this repo coins, the repo may draw the boundary
- for a word the platform coins, the repo may only **adopt or avoid**

so sense F is not one of six equals — it is the one this repo does not own. every other sense
was layered onto a word that already had a fixed meaning on every box this runs on, which is
why the collision looks like clever analogy at each site and like ambiguity across them.

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
condition its own reader does not test. two of three sites say *cwd deleted*; the `_.sh` says
*parent gone*. a reader who trusts the bundle header will hunt the wrong hazard.

### 🛑 a SIXTH reach — 2026-09-07, with this cluster already written

diagnosing `audio.record.start`, the seal phase was found to keep running after `rhx` had
already exited and returned the human's prompt. the sentence reached for was *"the work
carried on orphaned"* — the plain unix reading: **a child whose parent is gone.**

⇒ that is the KINSHIP sense, which is precisely the reading `1.6.1.finders/_.sh:7` states and
the implementation does not test. so the sixth reach landed on the one sense this file already
names as the outlier, in an unrelated subsystem, four days later.

⚠️ **and the cluster existed the whole time.** it was not consulted before the word was used;
it was consulted after, at the conform-or-dispute step, which is what caught it. that is the
durable finding:

> **an ambiguous term is not repaired by a file that documents the ambiguity.** the word
> arrives faster than the check does, so the record catches the drift on review and never at
> the keyboard.

⇒ so this reach is **evidence for the split**, not a seventh sense to add: it strengthens the
claim side of the open dispute and settles none of the four questions below. the audio sentence
was reworded rather than adopted (`rule.forbid.domain-term-synonyms` — adhere, or dispute,
never drift).

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
## .the case that pinned it

2026-09-02. the churn skill attributed each spawn to its live parent, and the rank came back:

```
├─  31 spawns  pid=1        /sbin/init
├─  14 spawns  pid=74765    tmux new-session ...
└─   9 spawns  pid=1120555  claude
```

init topped the list, and the concern beneath it read *"the heaviest parent is where to cut:
pid=1"* — advice no human can act on, and which would take the box down if they tried.

the cause is that **init is not a parent in the sense the rank means**. it forked none of those
processes. it inherited them, one dead chain at a time, and its count is therefore a sum of
other parents' leftovers. a rank by ppid silently treats an adoption as a fork.

the fix is a single awk clause (`$2 != 1`) plus a separate line for the count that clause removes.
the count still matters — a high orphan tally says chains die mid-flight, which is a real result —
it just names a **different** fix than a heavy live parent does. so it gets its own row, not a
place in a rank it would distort.

## .the durable lesson

> **an aggregate is not an agent.** where a report ranks by a key, check whether every value of
> that key names a party that *acted*. init, `unknown`, `other`, and `null` are buckets, not
> parties, and a bucket at the top of a rank produces a fix no one can perform.

this is the same shape as two prior corrections in this glossary, and the third instance is what
makes it a pattern rather than a mishap:

- `wedged` — the predicate tested two of three clauses and inferred the third from a proxy
- `class` — the member list sorted by age while the advice spoke of cost
- `orphan` — the rank charged a bucket that performed no action

each shipped a confident, actionable-seeming string that pointed at the wrong target.

## ⚠️ .dispute — the cwd sense, still OPEN

### dispute: orphan (cwd-deleted sense) — raised 2026-09-02 — status: OPEN

- raised.by  = this round
- claim      = `machine.usage.diagnose` has a `hunt orphan` section that reports a process whose
               **cwd was deleted** — a real and distinct defect, and the word reads naturally for
               it (the process lost its home).
- counter    = `orphan` is the platform's word for a reparented process, and two other contracts
               in this repo already use it that way (`machine.attribute.memory --orphans`,
               `machine.diagnose.churn`). one word now carries two senses across three skills a
               human runs back to back. `rule.forbid.domain-term-synonyms` forbids the overload,
               and the imported sense has the stronger claim — it cannot be moved, whereas the
               local sense can.
- proposal   = keep `orphan` for the unix sense. rename the cwd-deleted sense to **`adrift`** —
               a process still under way with its anchorage removed. `adrift` is unclaimed here,
               reads unambiguously, and keeps the two defects distinguishable in a report.
- resolution = **not yet settled.** the rename touches shipped human-read output, so it is
               flagged rather than applied. a human decides whether `adrift` is the word.

⚠️ **why this was not silently renamed:** the collision is live and costly, but the fix edits a
string a human reads every day. per `rule.always.defer-fulcrums-to-last`, the rework is clean (a
label swap with no downstream dependency), so the right move is to best-guess the word, record it,
and let the human confirm — not to change their vocabulary unasked.

## .the neighbours

- **`churn`** — a rate of births. orphans are the residue of churn: a chain fast enough to churn
  is a chain whose parents die before their children do.
- **`wedged`** — a process that will not finish. orthogonal: a wedged process usually has a live
  parent, and an orphan is usually healthy. the two share only that both evade a level alarm.
- **`class`** — a set grouped by `comm`. orphans defeat the *parent* axis of attribution while a
  class survives it, which is exactly why the census groups by name rather than by lineage.
- **`attribution`** — the cgroup-charge sense. cgroup membership is assigned at fork and **survives
  reparent**, so a cgroup still charges an orphan to the session that spawned it. that is the one
  route an orphan does not defeat, and it is why `machine.attribute.memory` exists.
