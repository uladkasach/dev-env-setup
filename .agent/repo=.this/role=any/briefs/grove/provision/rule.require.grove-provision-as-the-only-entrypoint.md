# rule.require.grove-provision-as-the-only-entrypoint

## .what — one invariant, in three clauses

**`src/grove.provision._.sh` is the ONLY entrypoint allowed for "raise a machine's state to
what this repo declares".**

1. **one entrypoint.** every caller — a human, a skill, a play, a grove, a bake, CI — reaches
   the tree through that file and no other. any other path is either a **forwarder** to it,
   or it is forbidden.
2. **every entry in the upgrade inventory is idempotent.** the inventory is the ordered roll of
   `step <tag> <fn>` lines the entrypoint drives. each entry converges: a re-run leaves the same
   machine state and reports no error.
3. **it is called `provision` BECAUSE of clause 2.** the name is not a label preferred over
   `install`; it is a claim about the inventory. the word and the invariant are one fact.

break any clause and you have broken all three, because each is what makes the next true.

## .why the three are inseparable

read them backwards and the dependency is plain:

| clause | depends on | breaks how |
|--------|-----------|-----------|
| the NAME says `provision` | every entry converges | a non-idempotent entry makes the name a lie |
| every entry converges | one inventory to hold them | a second inventory holds entries nobody audits |
| one inventory | one entrypoint to drive it | a second entrypoint IS a second inventory |

so "one entrypoint" is not tidiness. it is the only place from which clause 2 can be checked at
all, and clause 3 is only honest while clause 2 holds.

### the name is a claim, not a preference

an **install** is done once. the word invites a procedure that is correct the first time and
undefined after — and a procedure like that is exactly what a second run breaks.

a **provision** names a DECLARED end state and drives toward it. that is the sense terraform
and `ahbode/infrastructure` already use, and it is only coherent if a re-drive is safe: to
provision an already-provisioned box must be a no-op, or the word says none of what it claims.
so:

> **`provision` is not the nicer word for install. it is the word you may use only once every
> entry in the inventory is idempotent.** the name was earned by the property, and it is
> revoked by any entry that loses it.

and it asserts no DIRECTION, which is what it buys over `upgrade`: a downward converge is
not a case the name mis-describes.

⚠️ **a forwarder kept "so old paths keep working" IS a second entrypoint** — the very thing
this rule forbids. it reads as a supported path, so new work lands on it, and then two doors
must be kept honest with each other forever. that is `install_env.grove.sh` again, one
generation later, in a politer name.

⇒ there is one door, and it is `src/grove.provision._.sh`.

### a second entrypoint has been grown FOUR times

| date | the duplicate | how it drifted |
|------|---------------|----------------|
| 2026-07-26 | `install_env.grove.sh` | a second list of the same steps, for a headless box |
| 2026-07-27 | `grove.provision.grove` | omitted `brains`, so every grove ran robot brains with no config |
| 2026-07-27 | the `grove.provision.*` slice suite | 8 of 11 slices called a function a `step` line already drove |
| 2026-07-29 | `rhx grove.provision` (the skill) | carried its own array of 7 config copies — configs, **no tools** |

⚠️ **every name in that table is the name the artifact CARRIED on that date**, and a rename
must not touch them. all four predate the `grove.provision` cutover
(`term=grove.provision._.choice.reason.md`), so a sweep that rewrites them makes the record
claim the live entrypoint was its own duplicate. measured 2026-08-31, on rows 3 and 4.

the fourth is the one this rule was written for, and it is the worst of the four:

on a fresh grove the skill laid dotfiles onto a box with **no node, no nvim, and no claude**,
then printed a full-green `cowabunga! … installed`. the human found it — `claude` →
`command not found` — on a box a `verify.` play had already called self-sustained.

each of the four was a **strict subset** of the real inventory that reported success. that is
the signature: a second entrypoint does not announce that it is partial; it announces that it
is done.

## .the rule

🛑 **every row below begins with `rhx`, and that is not cosmetic.** this rule binds the one
DRIVER; `rule.forbid.the-driver-by-path` binds the one SURFACE, and it forbids `bash
src/grove.provision._.sh` outright. ⚠️ this table's first row carried exactly that banned form
until 2026-09-03 — so the rule that declares the one door named the wrong handle, and ~140
tracked files had copied it.

| you want to… | you must… |
|--------------|-----------|
| upgrade this machine | `rhx grove.provision --mode apply` |
| upgrade from a worktree/branch | `rhx grove.provision --from tree \| main` — which `bash`es the driver |
| run one entry only | `--what <slug>`, through the same skill |
| upgrade a grove | `rhx git.grove.provision boot <name> --mode apply` |
| add a new capability | add a **bundle dir** under `src/grove.provision/` — the tree IS the inventory |
| do "the same, but for X" | decline inline on the fact X depends on, never a second entrypoint |

## .what a legitimate forwarder looks like

a forwarder is allowed — required, even, so old paths keep working. it must:

- **hold no bundle of its own.** it declares no phase, no file list, no copy pair
- **`exec` or `bash` the entrypoint**, so one process drives one inventory
- **forward every flag it does not own**, so a flag the driver grows later works through it on
  the day it lands, with no edit here

```sh
# .agent/…/skills/grove.provision.sh — adds ONLY the --from axis, then forwards the rest
DEV_ENV_SETUP_DIR="$(dirname "$SRC")" bash "$DRIVER" --mode "$MODE" ${PASS[@]+"${PASS[@]}"}
```

the skill above is the ONE forwarder in this repo, and it qualifies: it owns exactly one axis
(`--from`) and forwards the remainder without enumeration. `grove.provision._.sh` is the driver
itself, never a forwarder to anything.

> a passthrough that must **re-list** the flags it forwards is a second list, which is the
> defect this rule exists to forbid. forward the remainder; never enumerate it.

## .the entry contract — what "idempotent" obliges

each entry in the inventory owes three things:

1. **converge** — a re-run leaves the same state and reports no error
   (`rule.require.idempotent-install-procedures` carries the shapes and the anti-shapes)
2. **be driven** — it has a `step <tag> <fn>` line, or it is dead code
   (`rule.require.every-function-has-a-driver`)
3. **never put a question to a human** — an unattended run must not block on a prompt

### .why clause 3 belongs to idempotency

an entry that questions a human is not merely awkward — **it is not idempotent, because it does
not converge at all.** it stops.

worse, it stops invisibly. a run has a tty on stdin (a duct pane is a tty), but its stdout is
often a pipe — a `| tail`, a log capture, a `grove.send`. so the question is swallowed on the
way out while the read still waits on the way in.

the guard belongs at the **entrypoint**, declared once for the whole run:

```sh
export CI=1                             # corepack/pnpm: assume yes, never ask
export DEBIAN_FRONTEND=noninteractive   # apt/dpkg: never open a config dialog
```

a per-call guard is a second list, and a second list drifts — `src/zshrc.sh` had carried the
`CI=1` lesson, with that same note, long before the installer inherited it. the knowledge lived
in one file and never crossed into the other. that is this rule's own defect in miniature.

### ⚠️ .a caution about this very section

on 2026-07-29 `pnpm --version` hung in `ep_poll` on grove-1, and the prompt story above was
ASSUMED to be its cause. the two exports were written, and this section with them, before the
claim was tested. **the evidence then refuted it** — the hang reproduced with stdout on a tty and
no prompt on screen, and the fix had not even reached the grove at the moment it was credited.

the guard is still right on its own terms, so it stays. but the diagnosis is OPEN, and the
lesson is the one this whole rule circles:

> **a fix authored from a plausible cause, and then narrated as proven, is the same defect as a
> tick that cannot go red.** the story fits, the box stays broken, and the record now says
> otherwise. state the guard; do not credit it with a cure it was never shown to deliver.

## .the test

three questions, one per clause:

> 1. can this machine be upgraded by any path that does not end at `grove.provision._.sh`?
> 2. run the whole inventory twice, with stdout piped. does the second run report `failed: 0`,
>    and does neither run stall?
> 3. is every capability this repo installs reachable from that one run?

- all three answer well → the invariant holds
- any one does not → the name `upgrade` is currently a lie, and that is the defect to fix

question 3 is the one all four duplicates failed, and the one a check most easily omits:
**a config for a tool is not the tool.** assert the binary.

## .enforcement

- a second entrypoint that drives grove state, whatever it is called = **blocker**
- a caller that re-implements any part of the inventory rather than a forward to it = **blocker**
- a forwarder that enumerates the flags it passes instead of a forward of the remainder = **blocker**
- an entry that fails, stalls, or changes state differently on a second run = **blocker**
- an entry that reads stdin for a human's answer = **blocker**
- a `verify.` play that reports on the inventory without an assertion that the installed
  binaries are present = **blocker** (it is a tick that cannot go red)

## .see also

- `rule.require.grove-provision-as-the-only-verb` — the WORD; this rule is the ARTIFACT
- `rule.require.idempotent-install-procedures` — the per-entry shapes clause 2 demands
- `rule.require.every-function-has-a-driver` — every declared function owes a `step` line
- `rule.require.install-via-procedures` — never hand a human a one-off command
- `term=grove.provision._.choice._.md` / `term=grove.provision._.choice._.md` — the rename record
- `verify.grove.provision.applied.play.sh` — the check, and the two omissions it has now closed
