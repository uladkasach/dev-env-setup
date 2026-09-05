# domain.term.choice.reason: provision (on-box)

## .etymology

`provision` is the word `ahbode/infrastructure` already uses for what it does to a box. the
lifecycle has two halves — infra provisions the INSTANCE, this repo provisions the TREE
onto it — and before the cutover each half had its own verb, so a reader had to learn that
`git.grove.provision` drives `grove.provision` and that the two name one arc.

the cutover collapses that. one act, one word, and the address says which end of the duct
you stand at.

## .the objection that was RAISED and DISPROVED

> `grove.provision` would be FALSE on a laptop. `grove.provision` runs on `local@unix`, and
> a grove is a cloud box.

the premise is wrong, and one file disproves it — `term=grove._.choice._.md`:

> a machine (a host) that holds trees. **`localhost` is a grove; an ec2 box is a grove.**
>
> settled by the human 2026-08-30: *"local and cloud are two types of groves."*

⇒ the objection was an assumption asserted with no read of the term that owns the word. it is
recorded because it is cheap to re-raise and costs a session each time
(`gotcha.my-own-note-became-my-evidence`, `rule.require.trust-but-verify`).

## 🛑 .the collision `bundle.upgrade` was spared

a total cut would retire `upgrade` as this repo's convergence verb, which puts
`bundle.upgrade` in question. it cannot simply follow:

| candidate | for | against |
|---|---|---|
| keep `bundle.upgrade` | its subject is a BUNDLE, not a box; the cutover is about the box verb | leaves one `upgrade` alive, so the cut is not total |
| `bundle.provision` | total cut | **collides** — `provision.upsert` / `provision.verify` are two of the four phases it drives, so the name means "half of what this does" at the site where both halves run |
| `bundle.drive` | no collision; `driven` is already itemized here | a third verb to learn |

⇒ **kept `bundle.upgrade`.** the rework stays clean if the human overrules: one function
name, with a known call set.

## .the measured blast radius — 2026-08-31

| what | count |
|---|---|
| files under `src/grove.provision/` | 197 |
| brief lines that held the old name | 302 |
| phase functions `grove_provision_<slug>_<phase>` | 4 per bundle |
| env vars `<OLD>_*` → `GROVE_*` | every bundle |

## ⚠️ .the hazard that was CLAIMED and MEASURED FALSE

a mid-cutover box was feared: `<OLD>_ENV_SERVER` exported by an INSTALLED `~/.zshenv` and
read by an INSTALLED `~/.bash_aliases`, so a box with the new checkout and the old `$HOME`
would hold one name in each, with the repair bundle unable to run.

the measurement disproves it. every `GROVE_*` var is computed at RUN time by the checkout
itself, and no installed artifact reads one:

```
grepsafe <OLD>_ --glob zshenv.sh       → 0
grepsafe <OLD>_ --glob ductwork.sh     → 0
grepsafe <OLD>_ --glob bash_aliases.sh → 0
grepsafe <OLD>_ --glob termwork.sh     → 0
```

⇒ the vars never cross the checkout boundary, so their rename was contained exactly as every
other step was.

⚠️ recorded because the false claim was written into the plan as a BLOCKER, and would have
bought a needless "read both names for one release" design. **an asserted hazard costs as
much as a missed one.**

## 🛑 .the LITERAL bytes a rename must NOT touch

a repo-wide `sedreplace` rewrites prose that quotes the old name, and two kinds of quote are
load-bear:

1. **a verbatim human quote** — `rule.require.briefs-obey-the-prose-rules` exempts it, and a
   rewritten quote is a fabricated one
2. **a marker some box already carries on disk** —
   `4.3.1.terminfo`'s `GROVE_TERMINFO_MARKERS_LEGACY` holds the exact strings a prior slug
   wrote into a live rc. rewrite an entry there and the prune matches none of it, so the box
   keeps the old block AND gains a new one — the exact defect the list exists to stop

⇒ both were caught by a read of the diff, and neither by a check. a rename pass is a place to
re-read the SHAPE, not only the letters.

## .evidence

- the human, 2026-08-31: *"why do i still see grove.provision anywhere instead of exclusively
  grove.provision throughout? i thought we agreed on the hard cutover."* — then, offered a
  scoped or a full rename: *"Full rename — I did mean everywhere"*
- `term=grove._.choice._.md` — the laptop-is-a-grove settlement the name rests on
- `.dream/2026_07_28.rename-install-env-to-grove-provision.dream.md` — the PRIOR hard cut,
  whose shape this one repeats

## .disputes

### dispute: which word does the ON-BOX verb take?  —  raised 2026-08-30  —  status: RESOLVED 2026-08-31
- raised.by  = `term=grove.provision._.choice.reason.md`, which left it open after the human
               settled that `grove.provision` must retire
- claim      = the on-box half should be a SUB-VERB of the one dispatcher —
               `rhx git.grove.provision self`, since `apply` collides with `--mode apply`
- counter    = a sub-verb makes every on-box call carry the FOREST-side prefix, on a box that
               has no forest — `git.` means "reach another machine" in all thirteen of its
               siblings. and the on-box call is the one a human types most.
- resolution = the human took the two-address shape: `rhx grove.provision` on the box,
               `rhx git.grove.provision boot <name>` off it. the `git.` prefix carries the
               direction, so no third word is needed and `self` is retired unshipped.
