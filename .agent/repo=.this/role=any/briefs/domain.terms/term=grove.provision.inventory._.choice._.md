# domain.term: grove.provision.inventory

term.chosen   = grove.provision.inventory
term.kind     = noun
term.synonyms.forbidden:
- procedure    (names a SEQUENCE to walk; the roll is a declared set, and `--for` filters it)
- list         (generic; says no word about what it holds or who owns it)
- manifest     (a manifest declares an artifact's CONTENTS; this declares ACTS)
- steps        (the plural of a member, not a name for the whole — see `bundle`)
- pipeline     (implies each stage feeds the next; entries are independent and tag-filtered)
- recipe       (implies a one-time make; the whole point is that it is re-driven)

## .what
the ordered roll of `step <tag> <fn>` entries that `src/grove.provision._.sh` drives. **one
inventory, in one file** — a second one is forbidden by
`rule.require.grove-provision-as-the-only-entrypoint`.

each entry is a `bundle`: one tagged (`any` | `local` | `cloud`), idempotent
function. the inventory is what the entrypoint HAS; a step is what it holds.

## .why `inventory`, not `procedure`

the human named it, and corrected the robot's word to get it:

> and that each entry in that **inventory** must be idempotent
>
> — *"the upgrade inventory"*, after the robot had written "procedure"

the correction is substantive, not stylistic:

- a **procedure** is a sequence you walk start to end. that reading invites order dependence and
  a "resume where it stopped" mental model — and it is what let `install_env.grove.sh` exist,
  since a second machine kind seemed to need a second procedure.
- an **inventory** is a declared set of what a machine gets. `--for cloud|local` then reads as a
  FILTER over one inventory rather than a choice between two procedures. that is exactly the
  shape that retired the duplicate drivers.

so the noun encodes the architecture: **one inventory, filtered — never two procedures, picked
between.**

## .why it is `grove.provision.inventory`, prefixed twice
it belongs to the provision context and specifically to the `upgrade` operation within it. a bare
`inventory` would be free for any other roll (a grove inventory, a duct inventory), and the
glossary `.readme.md` requires the context in the term.

## .the entry contract
every entry in the inventory owes three things, per
`rule.require.grove-provision-as-the-only-entrypoint`:

1. **converge** — a re-run leaves the same state and reports no error
2. **be driven** — a chain of `bundle.upgrade` dispatches reaches it from the root, or it is
   dead code (`rule.require.every-function-has-a-driver`). ⚠️ a `step` line is NOT what this
   clause asks: a mention is not a drive, and there is no `step` driver to hold one
3. **never put a question to a human** — an unattended run must not block on a prompt

clause 3 belongs to idempotency because an entry that asks does not converge; it stops.

## .refs
- src/grove.provision._.sh              # THE entrypoint that drives it
- src/bundle.upgrade.sh                # the runtime — one operation, at every depth
- src/grove.provision/                  # the tree that IS the inventory; no second list
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.grove-provision-as-the-only-entrypoint.md

⚠️ two rows here named a driver file and a phase-file glob under `src/`, both deleted in the
2026-07-30 hard cut. the mechanism they described — a flat driver that listed step lines — was
replaced by the bundle TREE, which declares its own members
(`rule.require.bundle-as-sole-declaration`). the dead paths are named by their shape rather
than reproduced, so this correction cannot itself read as a pointer
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.10).

## .reason
see the ref-level cluster beside this choice:
- `term=grove.provision.inventory._.choice.reason.md` — etymology, why the human's correction
  mattered, evidence
