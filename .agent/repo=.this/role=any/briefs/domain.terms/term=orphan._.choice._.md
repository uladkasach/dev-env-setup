# domain.term: orphan

term.chosen   = orphan
term.kind     = noun
term.status   = ⚠️ AMBIGUOUS — six live senses, dispute OPEN (see `.reason`)
term.synonyms.forbidden:
- stray
- leftover
- remnant
- waif
- unparented

## .what

a record that **outlived the referent that gave it its sense**, and which no reader will
report — the referent is gone, so no error fires; the record simply persists.

⚠️ **this `.what` is a PROPOSED unification, not a settled one.** the word is already live in
six places that do not all fit it (senses D and E do not), and it is already recorded as a
forbidden synonym of two OTHER terms on the ground that it "already carries a distinct sense"
— singular. it carries six. the dispute in `.reason` is OPEN.

## .the six live senses

| # | sense | where |
|---|---|---|
| A | a PROCESS whose cwd the kernel attests is deleted | `src/machine/machine_resource_procs_find_orphan` |
| B | a grove ENTRY whose instance is gone | `git grove del --orphaned` |
| C | an ssm SESSION whose box is gone | `git grove stop --prune orphans` |
| D | an UNCITED artifact | `term=exhibit._.choice.reason.md:64` |
| E | a tracked FILE whose delete was lost in a merge | commit `0edb2e8` |
| **F** | **a PROCESS whose PARENT exited, so init adopted it** | `machine.diagnose.churn`, `machine.attribute.memory --orphans` |

A–C share the proposed `.what`: a record that outlived its referent. **D and E do not.** an
uncited artifact never had a referent to outlive, and a lost-delete file is a live twin of a
file that moved — no referent died; the rename simply forked.

**F fits the `.what`, and it is the unix sense** — the platform has meant exactly this since the
first fork. it is imported unchanged, which is precisely why it cannot be redefined locally: an
imported word carries its own sense onto every box this runs on.

## 🛑 .A and F are BOTH correct, and the header that mixed them was not

the contradiction recorded here read as one function with two definitions:

| site | says | verdict |
|---|---|---|
| `src/machine/machine_resource_procs_find_orphan:4` | *"processes whose cwd was deleted"* | sense A ✔ |
| `1.6.procs/1.6.1.finders/_.sh:7` | *"a process whose parent is gone"* | ⛔ **was wrong HERE** |
| `2.7.aliases/bash_aliases.sh:183` | *"cwd deleted (stale worktrees)"* | sense A ✔ |

⚠️ the earlier read called the middle row *"the outlier"* and stopped there. that was half the
verdict. **"a process whose parent is gone" is not a false sense — it is sense F, real and
separately shipped.** the defect was that it described the wrong function.

so the header was not a stray phrase; it was a live term applied to the wrong subject, which is
the harder error to see — a traveler who knows sense F reads it as correct. ⇒ fixed 2026-09-08:
the header now names the cwd condition, and marks the parent reading as explicitly NOT its sense.

## ⚠️ .sense A splits again — attested vs unseen

sense A is *"the kernel attests the delete"*, and that word is load-bearing. until 2026-09-06 the
implementation joined two different tests with one `||`:

```sh
if [[ "$cwd" == *"(deleted)"* ]] || [[ ! -d "$cwd" ]]; then
```

- `*"(deleted)"*` — the **kernel** appends this once the inode is unlinked. universal
- `[[ ! -d "$cwd" ]]` — the path is not visible to **this observer**. a mount namespace or a
  permission alone can cause it, and neither is a delete

chrome hardens its sandbox: each zygote chdirs into `/proc/<crashpad-pid>/fdinfo`. once that pid
exits the path stops being visible, while every zygote stays healthy. six were offered under a
`kill -9` banner that claimed a kernel attestation. ⇒ the second clause is now reported as
`unseen`, and never joins the kill list (`term=unseen`).

## .why sense F is worth its own name

a sense-F orphan is **unattributable by the ordinary route**. `ps` reports `ppid=1`, which names
init — a process that did no work and asked for none. so it defeats every report that ranks by
parent, because the true culprit already died.

that is why `machine.diagnose.churn` splits its `orphans` line out of the blame rank rather than
let init accumulate every dead chain and outrank a real spawner (`term=host` records the adjacent
failure, where a LIVE parent contains work it did not cause).

## ⚠️ .the two records that assume ONE sense

both were written to forbid `orphan` elsewhere, and both justify the forbid by appeal to a single
extant sense. that premise is false, so each argument is weaker than it reads:

- `term=shadow._.choice.reason.md:25` — *"already carries a distinct sense in this repo's
  vocabulary (an orphaned **process**)"* — names a process sense, and there are **two** (A, F)
- `term=strand._.choice.reason.md:21` — resolves a 2026-09-02 dispute against `orphan` with
  *"`orphan` says the account has no PARENT — but it has one"* — that is sense F, argued as
  though F were the only sense

⇒ the CONCLUSIONS still hold — `shadow` and `strand` are the right words for their concepts. what
does not hold is the assumption that `orphan` is otherwise unambiguous.

## .refs

- `src/machine/machine_resource_procs_find_orphan` — sense A, the implementation + the
  attested/unseen split
- `src/grove.provision/1.system/1.6.procs/1.6.1.finders/_.sh` — sense A, header corrected
- `src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh` — `--orphaned`, sense B
- `.agent/repo=.this/role=any/skills/machine.diagnose.churn.sh` — sense F, split out of the rank
- `.agent/repo=.this/role=any/skills/machine.attribute.memory.sh` — sense F, `--orphans`, and why
  cgroups still attribute them correctly
- `.play/permanent/prove.orphan-sweep-bites.play.sh` — sense B, the clamp
- `.agent/repo=.this/role=any/briefs/domain.terms/term=entry._.choice._.md` — sense B
- `.agent/repo=.this/role=any/briefs/domain.terms/term=grove.stop._.choice.reason.md` — sense C
- `.agent/repo=.this/role=any/briefs/domain.terms/term=exhibit._.choice.reason.md` — sense D
- `.agent/repo=.this/role=any/briefs/hazard.idle-process-leak-crosses-the-swap-cliff.md` — sense A

## .the boundary

| word | what it implies | fits? |
|------|-----------------|-------|
| **orphan** | the referent died; the record lives on | ✅ and, for F, the platform's own sense |
| `stray` | wandered off by its own act | ✗ the record did not move; its referent left |
| `leftover` | surplus from a whole that was used | ✗ names abundance, not a dead referent |
| `remnant` | a fragment of a larger whole | ✗ an orphan is intact, never a piece |
| `waif` | discovered with no known origin | ✗ the origin is known — it simply exited |
| `unparented` | never had a parent | ✗ every process is forked from one |

## .reason

see the ref-level cluster beside this choice:

- `term=orphan._.choice.reason.md` — etymology, the OPEN dispute, and why it was not settled in
  the round that discovered it
