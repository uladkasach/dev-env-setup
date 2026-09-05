# rule.require.upgrade-entries-verify-themselves

> 📖 **new to bundles? read `define.grove-provision-bundles.md` first.** it holds the tree, the
> four phases, and a worked trace. this rule states the PHASE contract and assumes that model.

## .what

a bundle that carries phases is a directory of up to five files:

```
src/grove.provision/<path>/<order>.<slug>/
  _.sh                     # the bundle's root — operations its phases share
  provision.upsert.sh      # make the artifact EXIST
  provision.verify.sh      # prove it exists
  configure.upsert.sh      # make it SHAPED as declared
  configure.verify.sh      # prove it is shaped as declared
```

two concerns (**provision**, **configure**) × two halves (**upsert**, **verify**). a bundle may
own any subset.

> 🛑 there is ONE kind of bundle and one operation — `bundle.upgrade <slug>` — at every depth,
> so a phase is a bundle too and a body is free to dispatch or to do the work. **do not
> reintroduce a `leaf` / `composite` split**: its tally is what let a parent print ✔ on a box
> whose only applicable child was skipped (`term=bundle`, `src/bundle.upgrade.sh:14-19`).
>
> so applicability is an early `return 0` in the body, never an `--applies` argument, and a
> broken chain is recorded in `BUNDLE_BROKEN` rather than a third exit code.

the invariant this enforces, stated on its own:

> **a leaf that cannot prove its own declaration holds has not delivered it.** an exit code reports
> whether commands ran. that is a different claim from whether the machine now matches what was
> declared, and only the second one is the point.

## .why

### 1. "it ran" and "it holds" are different claims — and this repo has paid for the gap

an `upsert` exits 0 when its commands returned 0. it says not one word about whether the declared
state was reached. every one of these actually happened here:

| the upsert said | what was true |
|---|---|
| `✔ install_env pushed` (2026-07-29) | the payload landed at `src/src/`; the driver read the old copy. **three** credited fixes ran nowhere |
| `✔ configure_tmux` | the conf was written; `xterm-kitty` terminfo was absent, so tmux refused for a human anyway |
| `✔ install_robot_brains` | `rhx` installed and is **unrunnable** — it throws on `--version` |
| `✔ 22 ran / 2 failed` | the two failures were named; the *unrunnable* third was invisible, because nobody asked it to run |

none of those is a bug in an upsert. each is the absence of a **verify**. the upsert reported
honestly; its claim was narrower than the claim we read it as.

> a run that reports `22 ran` has told you 22 procedures returned 0. it has NOT told you the
> machine is right, and the difference is every defect in the table above.

### 2. provision must be proven before configure is attempted

a `configure` that runs against an absent artifact writes a file nobody reads, and **exits 0**
while it does. that is the `configure_tmux`-with-no-terminfo shape, and it is structural: the two
concerns are ordered, so the boundary between them is exactly where a check belongs.

```
provision.upsert → provision.verify → configure.upsert → configure.verify
                   └─ a gate, not a report: if this fails, configure is SKIPPED,
                      because a config written onto an absent artifact is a lie
                      that will read as success forever
```

### 3. it is the same get/set split declastruct already speaks

this is why the structure is worth imposing *now*, ahead of the lift. the quartet is not a
bespoke convention — it is a declarative resource, spelled out longhand:

| this repo's file | declastruct's half | what it answers |
|---|---|---|
| `*.verify.sh` | `get` | what state is the machine in? |
| `*.upsert.sh` | `set` | drive it to the declared state |

so a `provision` pair is one resource (the artifact) and a `configure` pair is a second (its
shape). when these lift into `declastruct-unix`, each pair becomes a resource with its natural
`get`/`set`, and the `_.sh` root becomes the dependency edge between the two. **no rewrite** —
the shape is already the target shape. (see `.dream/2026_07_29.provision-unix-via-declastruct-unix`)

### 4. a per-entry verify beats one centralized checker

this repo once had a centralized one — a single `diagnose` play that checked coreutils across
the whole box — and it made the case against itself:

- it holds a **hand-kept list** of tools and config paths, so it is a second list beside the
  inventory, and a second list drifts (the exact defect that retired `install_env.grove.sh`)
- it can only check what its author thought to name; the entry knows its own declaration
- it reports a machine-wide verdict, so a failure needs a hunt for which entry owns it

a verify beside its upsert cannot drift from it, because they are the same entry.

> keep the central play — it is the right tool for a *triage* of an unknown box. it is the wrong
> tool for a *guarantee*, and the guarantee is what an inventory owes.

## .the four contracts

### `provision.upsert.sh` — make it exist

- idempotent: a re-run on a provisioned machine is a no-op that exits 0
  (`rule.require.grove-provision-as-the-only-entrypoint`, clause 2)
- **never** questions a human — the run is unattended
- installs, downloads, creates the dir/unit/binary; writes no config

### `provision.verify.sh` — prove it exists

- **READ-ONLY.** it may not repair. a verify that fixes is an upsert with a false name, and it
  can never report a defect because it has already erased it
- exits `0` = the artifact is present and usable; `1` = it is not, and says which
- "usable" is stricter than "present": `rhx` is present and throws. a verify that stops at
  `command -v` would have passed it

### `configure.upsert.sh` — make it shaped as declared

- runs **only** when `provision.verify` passed
- idempotent, unattended, same as above

### `configure.verify.sh` — prove it is shaped as declared

- READ-ONLY, same as above
- checks the declaration, not merely the file's presence. `~/.tmux.conf` **exists** on grove-1 and
  tmux still refuses a kitty client — presence is not the declaration

### `_.sh` — the bundle's root

it dispatches its phases, in written order, and holds any operation more than one of them asks:

```sh
grove_provision_4_3_1_terminfo() {
  bundle.upgrade 4.3.1.terminfo.provision.upsert
  bundle.upgrade 4.3.1.terminfo.provision.verify
  bundle.upgrade 4.3.1.terminfo.configure.upsert
  bundle.upgrade 4.3.1.terminfo.configure.verify
}
```

`bundle.upgrade` owns the flow every phase meets alike:

```
--mode plan       ── the slug's trailing verb decides: `upsert` is withheld, `verify` always runs
provision.verify  ── fail → the bundle is recorded in BUNDLE_BROKEN
configure.*       ── SKIPPED while its bundle sits in BUNDLE_BROKEN
```

⚠️ **the mode gate is ONE test, in the runtime, against the slug's trailing verb** — never a
`[[ $GROVE_MODE == apply ]]` guard copied into each upsert body. and **applicability is an early
`return 0` in the body**, beside the reason it declines, rather than a flag the root passes up:

```sh
# a gpu terminal needs a display; a cloud box has none
[[ "$GROVE_ENV_SERVER" == local@* ]] || return 0
```

🛑 **there is no exit-code table** — no `4 inapplicable`, no `3 unproven`. a decline is a
`return 0` with a `🌙`, and the run's exit code says only whether some bundle failed, because
each body already reports its own outcome with the fix named.

**.why one shared runtime and not the same 20 lines per bundle** — 60 copies of that flow is 60
chances for one to diverge, and the one that diverges reports a pass it did not earn.

## ⚠️ .the hard-cut mandate

**every entry converts. there is no bare-function shape to inherit.**

settled by the human, 2026-07-29:

> yeah basically hard cut away into bundles exclusively. everything should now be in terms of
> `grove.provision --what $bundle` format

fix-forward alone cannot reach it: **an entry nobody touches is an entry nobody converts**, and
the untouched entries are precisely the ones that quietly broke. a step no human has read in
months is where a silent miss survives.

so the conversion is a migration, done in WAVES:

| when | what you owe |
|---|---|
| you **add** an entry | it is born a quartet. no exemption |
| you **touch** an entry | convert it, then make your change |
| a **wave** reaches its section | every entry in that section converts, verifies included |

a wave is one section of the inventory (`2.shell`, `4.terminal`, …), converted together and
proven by a `--mode plan` run for both `--for local` and `--for cloud`. one section per change
keeps a review possible without an exemption for the untouched.

⚠️ the migration's own risk: ~60 verifies come due at once, and most will honestly start as exit-3
stubs. that is the intended shape — a stub is a COUNTED debt (see below), where a bare function
was an uncounted one. what is forbidden is a stub that exits 0.

### an empty verify is allowed — and must SAY it is empty

a verify you cannot write today may be a stub. the debt is real and the structure should hold it
rather than block on it. **but a stub must never be mistaken for a pass**, because
`rule.forbid.failhide` is exactly the defect on offer here: a `verify` that exits 0 with no check
is indistinguishable from a `verify` that checked and approved.

so a stub declares itself:

```sh
#!/usr/bin/env bash
# .what = UNVERIFIED — this entry's declaration is not yet checkable
# .why  = <the honest reason. "not yet written" is an acceptable reason;
#          it is the SILENCE that is forbidden, not the absence>
echo "🌙 unverified — <slug>.provision has no check yet"
exit 3            # 3 = unverified. NOT 0 (approved), NOT 1 (failed)
```

**exit 3 is the whole mechanism.** it makes the debt a number the driver can count, so the roll
reads:

```
🌲 grove.provision done
   ├─ access prep · server cloud@aws.ec2 · commit main@a1b2c3d+
   ├─ ran:          22
   ├─ inapplicable: 36
   ├─ unverified:    8      ← the debt, visible and countable
   └─ failed:        2
```

an unverified count that climbs is a signal. an unverified count that is invisible is how you get
`22 ran` on a machine where `rhx` throws.

> allow the empty verify. never allow the silent one.

## .the worked example — `4.3.1.terminfo`

on 2026-07-29 the `xterm-kitty` terminfo entry was absent on a grove, which is why tmux refused
("unsuitable terminal"), ncurses tools garbled, and backspace was drawn as a space for a human
ssh'd in from kitty. **one absent entry, three complaints that each read as its own bug** — and no
run reported a defect, because no run was ever asked to check.

```
src/grove.provision/4.terminal/4.3.kitty/4.3.1.terminfo/
  _.sh                  # dispatches the four, in order
  provision.upsert.sh   # pkg_install kitty-terminfo
  provision.verify.sh   # infocmp xterm-kitty            → 0 or 1
  configure.upsert.sh   # findsert `stty erase '^?'` into the rc files
  configure.verify.sh   # the rc line is present → but does it TAKE?
```

`provision.verify` is one line — `infocmp xterm-kitty` — and it is the line whose absence cost all
three complaints. that is the argument for this rule in miniature: **the check was cheap; its
absence was not.**

two details of that leaf are the rule at work:

- **the verify is NOT `dpkg -l kitty-terminfo`.** a package's presence is the upsert's business;
  whether the *entry is resolvable* is the declaration. ask the question the human's tools ask.
  (`tput -T xterm-kitty` fails the same test from the other side: tput answers from a fallback, so
  it can exit 0 on a box that holds no entry at all.)
- **`configure.verify` exits 3, honestly.** its declaration is "a FUTURE interactive session erases
  on `^?`", and an upgrade run owns no interactive tty — its stdin is closed. it can observe the
  declaration in the rc file; it cannot observe that the declaration TAKES. a 0 there would claim
  authority it does not have.

## .the test

for any entry, ask three:

1. **can it prove it worked?** — if the only evidence is exit 0, it cannot
2. **could its configure run against an absent artifact and still exit 0?** — if yes, the
   `provision.verify` gate is load-bear, not decorative
3. **would its verify pass on a machine where the tool is present but broken?** — if yes, it
   checks presence where it should check usability (`rhx`, `command -v`, exit 0 — all three passed
   on a binary that throws)

## .enforcement

- a **new** inventory member authored as a bare function = **blocker**
- a **touched** member left as a bare function = **blocker**
- a `verify` that repairs = **blocker** (it is an upsert; it can never report the defect it fixes)
- a `verify` stub that exits `0` rather than `3` = **blocker** (`rule.forbid.failhide`)
- a `verify` that claims what this run cannot observe = **blocker** (exit `3` and name the gap)
- `configure.upsert` that runs when `provision.verify` failed = **blocker**
- honest debt reported by no line of the run = **blocker** (invisible debt is not debt, it is a
  false pass)
- a bundle that re-implements `bundle.upgrade`'s flow inline = **blocker** (a second copy of the
  gate is a second chance to omit it)
- a `[[ $GROVE_MODE == apply ]]` guard inside an upsert body = **blocker**; the mode gate is ONE
  test in the runtime, against the slug's trailing verb

## .see also

- `rule.require.grove-provision-as-the-only-entrypoint` — the entrypoint + idempotency invariant
  this sits inside. that rule says every entry converges; this one says every entry **proves** it
- `rule.require.grove-provision-as-the-only-verb` — why the act is `upgrade`, which is why an entry
  is a declaration and not an installation
- `rule.require.every-function-has-a-driver` — every function needs a `step` line. the `_.sh` root is
  what that line names once an entry is a quartet
- `rule.require.bundle-as-sole-declaration` — the four phases must hold the concern's BODY, not
  merely call a `pt*.sh` function that holds it
- `rule.forbid.failhide` (mechanic) — the rule the exit-3 stub exists to satisfy
- `rule.require.idempotent-operations` (architect) — `upsert`/`verify` are `set`/`get`; the naming
  is deliberate
- `.dream/2026_07_29.provision-unix-via-declastruct-unix.dream.md` — the lift this shape is
  pre-fitted for
