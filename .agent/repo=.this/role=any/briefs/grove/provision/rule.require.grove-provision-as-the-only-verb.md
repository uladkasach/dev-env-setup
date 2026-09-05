# rule.require.grove-provision-as-the-only-verb

## .what

**`grove.provision` is the one and only verb for "converge a machine's state to what this repo
declares".** `install`, `sync`, `setup`, `update`, `refresh`, `upgrade`, and `configure` are
forbidden as names for that act — in every contract: alias, function, file name, flag, skill,
doc, and commit message.

`provision` wins the slot because it is the word `ahbode/infrastructure` already uses for
what it does to a box — so the two halves of one lifecycle share one verb
(`term=grove.provision._.choice._.md`).

⚠️ **`bundle.upgrade` is exempt, and only it.** `provision` is ALREADY a phase name inside a
bundle (`provision.upsert`, `provision.verify`), so a rename there would overload a live word at
the exact site where both phase pairs run. its subject is a bundle, not a box, and no human
types it.

there is ONE operation, ONE driver, ONE list of steps, and ONE `--for` flag that selects which
machine kind a run is for. a second entrypoint that does "the same but for X" is forbidden by
construction, whatever it is called.

## .why

### the object is never blank

every box already ships a tree — a login shell, a PATH, `/etc/skel` dotfiles. so no run ever
puts a tree on an empty machine; what happens, always and on the first run too, is that an
EXTANT TREE is CONVERGED to the declared state. `install` names a first-time act that later
runs merely repeat, which is not what occurs.

⚠️ `upgrade` also named the convergence, and better than `install` did — but it asserts a
DIRECTION the act does not have: pin an older starship in the repo and a converged machine moves
DOWN to meet it. `provision` carries no direction, so it is the word that finally fits.

this is a domain-discovery argument, and it beats a convenience one: name the operation for the
object's truth, not the procedure's shape (`def.domain-discovery`).

### two words invited two implementations, three times over

the repo has now grown a duplicate driver **three separate times**, and each time the split
vocabulary is what licensed it:

| date | the duplicate | what it duplicated | how it drifted |
|------|---------------|--------------------|----------------|
| 2026-07-26 | `install_env.grove.sh` | the step list, for a headless box | two lists of the same steps, drifted step by step |
| 2026-07-27 | `grove.provision.grove` | the slice list, for a grove | omitted `brains`, so every grove ran the robot brains with no config |
| 2026-07-27 | the `grove.provision.*` slice suite | **the steps themselves** | 8 of 11 slices called the exact function a `step` line already drove, with identical tags |

the third is the sharpest lesson, because it was built by someone (me) who had just diagnosed
the first two. a second word made a second implementation feel like a second *concept* rather
than a duplicate. one word forecloses that.

### the split also spawned a fake term

to justify the third duplicate, a term `grove.provision.slice` was minted, with the claim "a
step is a unit of procedure, a slice is a unit of the object". it does not survive contact with
the code: the `brains` slice calls `configure_robot_brains`, which IS a step. the distinction
was authored to license a duplication — the exact defect `rule.forbid.domain-term-synonyms`
exists to prevent. it was retracted the day it was written.

**a new term that exists to explain why two things are not duplicates is a smell.** check
whether it names a real difference in the domain, or a difference you need to be true.

## .the invariant

1. **one verb** — `grove.provision`. no synonym names this act in any contract.
2. **one driver** — `src/grove.provision._.sh`, with `src/bundle.upgrade.sh` as the runtime it
   dispatches through. every unit of work is a directory under `src/grove.provision/`.
3. **one unit** — a `bundle`: a directory that either dispatches its children or carries up to
   four phases. there is no second kind of unit, and no `leaf` / `composite` split
   (`term=bundle._.choice._.md`).
4. **one axis** — `--for cloud|local`, declared once in `src/grove.for.sh`. no operation holds
   its own copy of the detection or the rule.

   ⚠️ there is no per-step `any|local|cloud` tag. a bundle declines INLINE, on a direct read of
   `$GROVE_ENV_SERVER`, because a two-valued tag cannot express `local@cicd` — a local tier
   with no screen and no human (`rule.require.identical-bundle-composition`, which also forbids
   the `grove_env_has_*` predicates that briefly replaced the tag).
5. **subsets are FILTERS, never lists** — "just the configs", "just a grove" are expressed with
   `--for` and `--what`, never as a second entrypoint with its own enumeration.
6. **`grove.provision.<part>` is a THIN WRAPPER** — a named subpart is allowed and wanted, but it
   must expand to `--what <steps>` over the one driver. it may never enumerate work of its own.
   the test: delete the wrapper and the work still runs, because the steps live in the driver.

## .the test

> am I about to write a second place that enumerates what a machine gets?

- yes → stop. it belongs as `step` lines plus a `--for` / `--what` filter.
- no → carry on.

and its companion, for vocabulary:

> am I about to name this act something other than `upgrade`?

- yes → stop, unless you open a dispute (`howto.domain-term-disputes`). do not drift.

## .the boundary — the CONTRACT renames; the internals need not

this rule binds the **contract layer** — what a human types and reads — and stops there.
`rule.forbid.domain-term-synonyms` binds contracts: names a caller reads and types. a private
function name inside one driver is not a contract.

| layer | verb |
|-------|------|
| the command a human types | `grove.provision`, `grove.provision.*` — it must speak the domain's word |
| a private name inside one driver | not a contract; this rule does not reach it |

the sharper reason: at the STEP level, `install` is frequently the honest word. a step that
fetches a toolchain that was genuinely absent DOES install it. it is the TREE as a whole —
the object that always already exists — that is upgraded, never installed. one word per
concept holds; these are two concepts.

## .examples

### 👎 forbidden — a second entrypoint for a subset

```sh
# a hand-kept list of what a grove gets. drifts the moment a step is added
alias grove.provision.grove='grove.provision.bashaliases && grove.provision.zshrc && ...'
```

### 👍 required — the subset is a filter over the one list

```sh
grove.provision --for cloud                      # every step a headless box takes
grove.provision --for cloud --what configure_neovim   # one step of it
```

### 👎 forbidden — a synonym in a contract

```sh
alias sync.env='...'       # `sync` implies two sides reconcile; both halves overwrite
alias install.env='...'    # `install` implies a blank machine, which never exists
alias upgrade.env='...'    # `upgrade` implies a version bump; this converges a declaration
```

🛑 **do NOT sweep this block into the canonical name.** it is the FORBIDDEN column, and a
rename pass that reads it as prose turns the rule's own counter-example into its rule — this
happened here on 2026-09-02, and for a while this file forbade `grove.provision` itself
(`define.cry-wolf-measurements`, m.10: a correction that re-creates the defect it corrects).

## .enforcement

- a synonym of `upgrade` used to name this act in any contract = **blocker**
- a second entrypoint that enumerates what a machine gets = **blocker**
- a second copy of the `--for` detection or its tag rule = **blocker**
- a new term minted to explain why two implementations are not duplicates = **blocker**

## .see also

- `term=grove.provision._.choice._.md` — the term, its forbidden synonyms, the disputes it won
- `term=git.repo.pull._.choice._.md` — the first retired synonym
- `term=grove.provision._.choice._.md` — the second, retired here
- `rule.require.grove-provision-as-the-only-entrypoint` — this rule's twin. this one binds the
  WORD; that one binds the ARTIFACT (`src/grove.provision._.sh`), the inventory it drives, and
  why the word is EARNED by the inventory's idempotency rather than merely preferred
- `rule.require.every-function-has-a-driver` — every function is driven by a `step` line
- `rule.forbid.domain-term-synonyms` — adhere to the canonical word, or dispute it
- `def.domain-discovery` — why the object's truth beats the procedure's shape
