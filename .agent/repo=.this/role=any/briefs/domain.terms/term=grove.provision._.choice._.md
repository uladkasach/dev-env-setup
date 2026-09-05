# domain.term: provision (on-box)

term.chosen   = grove.provision
term.kind     = verb
term.synonyms.forbidden:
- grove.provision  (SUPERSEDED 2026-08-31 — see `term=grove.provision`)
- install         (superseded twice over — see `term=grove.provision`)
- sync            (superseded — it named two directions at once, see `term=git.repo.pull`)
- upgrade         (asserts a direction the act does not have; a pin can move a box DOWN)
- update
- refresh
- reload
- setup
- apply           (already TAKEN — the `--mode plan|apply` axis)
- converge        (jargon; no traveler says it aloud)

## .what
converge THIS grove to the state this repo declares.

## .the ONE verb, at TWO addresses

```
rhx grove.provision                     # THIS grove          — runs ON the box
rhx git.grove.provision boot <name>     # a REMOTE grove      — runs on your laptop
```

the `git.` prefix means forest-side across the whole family (`git.grove.push`,
`git.grove.send`, `git.grove.wake`), so the pair reads as one verb at two addresses
rather than as a collision. `boot` steps 2-3 send the bare form down the duct — the
recursion is real, and the prefix is what makes it legible.

## .why the laptop is a grove too, so the name is TRUE everywhere

the objection writes itself: *"`grove.provision` is false on `local@unix` — a grove is a
cloud box."* `term=grove._.choice._.md` disproves the premise:

> a machine (a host) that holds trees. **`localhost` is a grove; an ec2 box is a grove.**

settled by the human 2026-08-30. so there is one act, on one kind of subject, and one word
covers every box this repo serves.

## .why `provision` and not `upgrade`

`upgrade` asserts a direction — *up* — and the act is direction-neutral: pin an older
starship in the repo and a converged machine moves DOWN to meet it. that wrinkle was
recorded and tolerated for a month.

`provision` also settles a split the repo already carried a cost for.
`ahbode/infrastructure` **provisions** the instance; this **provisions** the tree onto
it — so the two halves of one lifecycle share one verb, and `git.grove.provision` no longer
has to forbid `upgrade` as a synonym of the very act it drives.

## ⚠️ .`bundle.upgrade` KEEPS its name, and that is deliberate

`bundle.upgrade` is the runtime that drives one bundle's four phases, and it cannot follow
this rename: **`provision` is ALREADY a phase name inside a bundle.** the four are
`provision.upsert`, `provision.verify`, `configure.upsert`, `configure.verify`.

so `bundle.provision` would name the whole runtime after ONE of the two phase pairs it
drives — an overload at the exact site where both pairs run
(`rule.forbid.domain-term-synonyms`).

⇒ the cutover's subject is the verb a HUMAN types at a BOX. `bundle.upgrade`'s subject is a
bundle, and no human types it.

## .the two NEIGHBOUR verbs that keep their names

🛑 **the noun/verb split licenses no spare.** the retired noun is forbidden repo-wide — see
`term=devenv._.choice._.md`, the family tombstone — so *"the cutover renamed only a VERB"*
justifies no site that still holds it. the claim this section makes is narrower: these two
VERBS were never the cutover's subject.

| verb | why it stays |
|---|---|
| `git.repo.pull` | its subject is the REPO, and its direction is the opposite one (remote → here) |
| `grove.bootstrap` | it runs BEFORE a checkout exists — it is what makes `grove.provision` reachable |

⇒ the loop stays legible: `git.repo.pull` (remote → here), `grove.provision` (here → box).

## .refs
where the term is declared / used:
- `src/grove.provision._.sh`                                # the entrypoint
- `src/grove.provision/**`                                  # the bundle tree it drives
- `.agent/repo=.this/role=any/skills/grove.provision.sh`    # the rhx skill
- `src/bash_aliases.sh`                                     # the alias + its `<TAB>` synonyms
- `.agent/…/briefs/grove/provision/rule.require.one-command-provision.md`   # the bar it must meet

## .reason
see the ref-level cluster beside this choice:
- `term=grove.provision._.choice.reason.md` — the cutover, the objection that was raised and
  disproved, and the collision that `bundle.upgrade` was spared
