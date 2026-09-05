# domain.term: orphan

term.chosen   = orphan
term.kind     = noun
term.status   = ⚠️ AMBIGUOUS — five live senses, dispute OPEN (see `.reason`)
term.synonyms.forbidden:
- stray
- leftover
- remnant

## .what

a record that **outlived the referent that gave it its sense**, and which no reader will
report — the referent is gone, so no error fires; the record simply persists.

⚠️ **this `.what` is a PROPOSED unification, not a settled one.** the word is already live in
five places that do not all fit it (sense E below does not), and it is already recorded as a
forbidden synonym of two OTHER terms on the ground that it "already carries a distinct sense"
— singular. it carries five. the dispute in `.reason` is OPEN.

## .the five live senses

| # | sense | where |
|---|---|---|
| A | a PROCESS whose cwd was deleted | `src/machine/machine_resource_procs_find_orphan` |
| B | a grove ENTRY whose instance is gone | `git grove del --orphaned` |
| C | an ssm SESSION whose box is gone | `git grove stop --prune orphans` |
| D | an UNCITED artifact | `term=exhibit._.choice.reason.md:64` |
| E | a tracked FILE whose delete was lost in a merge | commit `0edb2e8` |

A–C share the proposed `.what`: a record that outlived its referent. **D and E do not.** an
uncited artifact never had a referent to outlive, and a lost-delete file is a live twin of a
file that moved — no referent died; the rename simply forked.

## 🛑 .the measured contradiction inside sense A

sense A does not agree with itself. one function, two incompatible definitions:

| site | says |
|---|---|
| `src/machine/machine_resource_procs_find_orphan:4` | *"finds processes whose cwd was deleted"* |
| `1.system/1.6.procs/1.6.1.finders/_.sh:7` | *"a process whose parent is gone"* |
| `2.7.aliases/bash_aliases.sh:183` | *"cwd deleted (stale worktrees)"* |

a deleted cwd and a departed parent are different conditions with different causes. the
implementation and the alias agree; **the bundle header is the outlier and is wrong.**

⇒ this is what an unitemized term costs: the header was written from the WORD, not from the
code, and the word licensed a plausible-but-false read that no check can see.

## ⚠️ .the two records that assume ONE sense

both were written to forbid `orphan` elsewhere, and both justify the forbid by appeal to a
single extant sense. that premise is false, so each argument is weaker than it reads:

- `term=shadow._.choice.reason.md:25` — *"already carries a distinct sense in this repo's
  vocabulary (an orphaned **process**)"* — names sense A only
- `term=strand._.choice.reason.md:21` — resolves a 2026-09-02 dispute against `orphan` with
  *"`orphan` says the account has no PARENT — but it has one"*

⇒ the CONCLUSIONS still hold — `shadow` and `strand` are the right words for their concepts.
what does not hold is the assumption that `orphan` is otherwise unambiguous.

## .refs

- `src/machine/machine_resource_procs_find_orphan` — sense A, the implementation
- `src/grove.provision/1.system/1.6.procs/1.6.1.finders/_.sh` — sense A, the wrong header
- `src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh` — `--orphaned`, sense B
- `.play/permanent/prove.orphan-sweep-bites.play.sh` — sense B, the clamp
- `.agent/repo=.this/role=any/briefs/domain.terms/term=entry._.choice._.md` — sense B
- `.agent/repo=.this/role=any/briefs/domain.terms/term=grove.stop._.choice.reason.md` — sense C
- `.agent/repo=.this/role=any/briefs/domain.terms/term=exhibit._.choice.reason.md` — sense D
- `.agent/repo=.this/role=any/briefs/hazard.idle-process-leak-crosses-the-swap-cliff.md` — sense A

## .reason

see the ref-level cluster beside this choice:

- `term=orphan._.choice.reason.md` — etymology, the OPEN dispute, and why it was not settled
  in the round that discovered it
