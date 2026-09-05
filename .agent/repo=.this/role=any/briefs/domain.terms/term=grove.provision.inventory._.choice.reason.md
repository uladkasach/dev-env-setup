# domain.term.choice.reason: grove.provision.inventory

## .etymology

an **inventory** is a roll of what is held. a warehouse inventory lists what is in the warehouse;
this one lists what a machine gets. the word carries three properties the domain needs and that
its rivals do not:

1. **it is a SET, not a walk.** an inventory has members; it does not have a start and an end. so
   `--for cloud` filters it, and no reader expects "resume where it stopped".
2. **it is DECLARATIVE.** an inventory states what is held, not how it got there. that matches a
   convergent upgrade, where every entry is idempotent and the run re-drives the declaration.
3. **it is SINGULAR by instinct.** a warehouse with two inventories has a ledger problem, and
   every reader feels that without being told. `procedure` carries no such instinct — two
   procedures for two machine kinds sounds perfectly reasonable, which is exactly how this repo
   grew four duplicate drivers.

## .how it was settled — a one-word correction from the human

the robot wrote "procedure". the human corrected it mid-stream:

> and create an invariant in the .agent/repo=.this/role=any/briefs that grove.provision is the
> _only_ entrypoint allowed and that each entry in that **inventory** must be idempotent
>
> — followed, unprompted, by: *"the upgrade inventory"*

a term that arrives as a correction is worth more than one authored from scratch, because the
correction names what the wrong word got wrong. here the wrong word had a track record: three of
the four duplicate-driver incidents are legible as "this machine kind needs its own procedure",
and not one of them is legible as "this machine kind needs its own inventory".

> **a noun that makes a defect sound reasonable is a defect in the vocabulary.** `procedure` made
> a second driver sound like a second concept. `inventory` makes it sound like a ledger error —
> which is what it always was.

## .the words that lost

| word | why it lost |
|------|-------------|
| `procedure` | names a sequence to walk. invites order dependence, and made four duplicate drivers sound like separate concepts rather than one split record |
| `list` | generic. says no word about what it holds or who owns it. `duct.list` already uses `list` as a VERB, so a noun sense would overload it |
| `manifest` | a manifest declares an artifact's CONTENTS (a package manifest, a cargo manifest). this declares ACTS to perform, which is a different kind of roll |
| `steps` | the plural of a member. `bundle` is already the term for one entry, so `steps` names no new concept — it merely avoids a name for the whole |
| `pipeline` | implies each stage feeds the next. entries are independent and tag-filtered; a `--what install_zsh` run drives one entry with no upstream at all |
| `recipe` | implies a one-time make, which is precisely the sense `install` → `upgrade` was renamed to kill |

## .the relationship to its members

| term | what it names | cardinality |
|------|---------------|-------------|
| `grove.provision.inventory` | the whole roll | exactly ONE, repo-wide |
| `bundle` | one entry in it | many |

the two were settled two days apart, and the pair is now complete: the step term explains what a
member is and that there is only one KIND of member; the inventory term explains what the
collection is and that there is only one INSTANCE of it.

## .disputes

none raised. the human named it, and the robot's own word was the loser — so no rival remained to
argue for.

## .evidence

- **discovery: five whys on a defect, not on a name.** the round did not set out to name this
  noun. it set out to write `rule.require.grove-provision-as-the-only-entrypoint`, and the noun
  was needed because clause 2 ("each entry must be idempotent") had no word for what the entries
  are IN. a term needed to state an invariant is a term the domain genuinely holds.
- **the four incidents, re-read through the word.** each is a second inventory that reported
  success while it held a strict subset:

  | date | the duplicate | what it omitted, or wrongly duplicated |
  |------|---------------|----------------------------------------|
  | 2026-07-26 | `install_env.grove.sh` | a whole second copy of the roll, for a headless box |
  | 2026-07-27 | `grove.provision.grove` | omitted `brains` — every grove ran robot brains with no config |
  | 2026-07-27 | the slice suite | 8 of 11 slices called a function a `step` line already drove |
  | 2026-07-29 | the `rhx grove.provision` skill | 7 config copies, no tools — dotfiles onto a box with no claude |

- **invariant:** exactly one inventory exists, and `grep -cE '^\s*step +(any|local|cloud) '`
  over `src/` must find its entries in exactly one file. `verify.grove.provision.applied` counts
  them, and the count is what separates a current checkout from one older than the `--for` axis.
- **verified 2026-07-29:** the entrypoint drives 60 entries, `--for cloud` filters to 22 ran /
  36 skipped, and a re-run reports every entry already current. the filter sense held.

## .refs
- `term=bundle._.choice._.md` — one entry of this inventory
- `term=grove.provision._.choice._.md` — the operation that drives it
- `term=--for._.choice._.md` — the axis that filters it
- `rule.require.grove-provision-as-the-only-entrypoint` — the invariant this noun was minted to state
