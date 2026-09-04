# define.grove-provision-bundles

## .what

how the bundle framework works. this brief EXPLAINS; it forbids none of it.

read it first. the two rules beside it — `rule.require.grove-provision-bundles` (the tree) and
`rule.require.upgrade-entries-verify-themselves` (the phases) — state what you must not do,
and each assumes you already hold the model. this is the model.

## .the one-pass picture

```
src/grove.provision._.sh            THE ROOT
│   reads the top-level bundle DIRS and dispatches each in numeric order.
│   it holds no list — the filesystem IS the inventory
│
└─→ src/bundle.upgrade.sh          THE RUNTIME
    │   bundle.upgrade <slug>  — look up the function the slug names, call it
    │   plus: the `--what` filter, the mode gate, the indent, BUNDLE_BROKEN
    │
    └─→ src/grove.provision/        THE TREE
        │
        4.3.kitty/_.sh                     a bundle. its body DISPATCHES
        │   bundle.upgrade 4.3.1.terminfo
        │   bundle.upgrade 4.3.2.emulator
        │
        ├── 4.3.1.terminfo/_.sh            a bundle. it dispatches four phases
        │   ├── provision.upsert.sh        make xterm-kitty EXIST
        │   ├── provision.verify.sh        infocmp xterm-kitty      ← THE GATE
        │   ├── configure.upsert.sh        stty erase '^?' into rc
        │   └── configure.verify.sh        prove a future session erases on ^?
        │
        └── 4.3.2.emulator/_.sh            a bundle. it DECLINES on a headless box
```

## .the ideas that carry it

### 1. one operation, at every depth

`bundle.upgrade <slug>` is the only dispatch. the root calls it; every body that composes calls
it for each part. it alone owns:

- the `--what` filter — a match on the slug's NUMERIC path, so `4.3.kitty` names its whole
  subtree (`4.3.1.terminfo` is not a *string* prefix of it)
- the **mode gate** — a slug's final verb says whether it mutates, so `--mode plan` is one test
  against the name rather than a guard copied into every upsert body
- the indent that makes depth legible
- `BUNDLE_BROKEN`, which stands a bundle's later phases down once one fails

so a skip at depth three prints exactly as a skip at depth one. **a bundle that hand-rolled its
own gate would go blind inside itself** — its internal skips would be invisible, and
`--mode plan` would no longer be a complete account of the run.

### 2. there are NO node kinds

a body either dispatches its children or does the work, and the runtime does not care which. a
phase is a bundle. a section is a bundle. turtles all the way down.

🛑 **do not reintroduce a `leaf` / `composite` split.** a prior runtime carried one, plus a
third exit code and a tally, all to keep a COUNT honest. the count was the defect: a parent
scored `0` landed in `ran` beside its children, so `4.3.kitty` printed ✔ on a headless box
whose only applicable child was skipped. `src/bundle.upgrade.sh` holds the full argument.

### 3. applicability is the bundle's OWN business

the environment travels down the tree untouched, and each bundle reads it for itself:

```sh
[[ "$GROVE_ENV_SERVER" == local@* ]] || return 0
```

why: kitty needs a screen, and **its terminfo entry does not** — the box that needs that entry
is the headless one a kitty CONNECTS TO. a parent that gated its child would take custody of a
claim the child owns.

⚠️ read the TIER the bundle depends on. `local@*` is coarser than *"a human is here"*:
`local@cicd` is local tier with no screen and no human (`repo.overview.md`).

⚠️ there is no `grove_env_has_screen` / `grove_env_has_human` predicate, and do not write
one — each name claimed a fact its body could not check.

### 4. each body reports its OWN outcome

there is no roll and no tally. a body names its verdict with its fix
(`rule.require.errors-name-the-fix`), and the run's exit code says whether any bundle failed —
the one fact a caller needs.

## .what a run guarantees

```sh
rhx grove.provision --for cloud --mode plan --what 4.3.kitty
```

- **the verify runs under `plan`.** a verify writes no state, so it is safe in either mode, and
  *"what does this machine currently fail?"* is the most useful thing a plan can say. only the
  **upsert** is withheld.
- **`provision.verify` is a GATE.** when it fails, `configure` never runs. a config written
  onto an absent artifact exits 0 while it does, and that 0 reads as coverage forever.
- **a decline is not a failure.** a gpu terminal on a headless box is the correct outcome, so
  the bundle returns early with a 🌙 and inflates no count.
- **one failed phase stands its siblings down.** without that, three phases print three
  identical fix lines for one cause, and a reader cannot tell the root from its shadows.

## .why a bundle has FOUR phases and not two

two concerns × two halves:

| | upsert — drive it | verify — prove it |
|---|---|---|
| **provision** | make the artifact EXIST | prove it exists, and is USABLE |
| **configure** | make it SHAPED as declared | prove the shape holds |

the split is not bookkeeping. *"backspace draws a space"* has **two independent causes** — no
`xterm-kitty` entry (provision), and a tty that erases on `^H` while kitty sends `^?` (configure).
a fix for either alone leaves the symptom. two phases means each is separately driven and separately
proven.

and "usable" is stricter than "present": `rhx` was present, on PATH, reachable from a login shell —
and threw on `--version`. every presence check passed on a binary that cannot run.

### a verify that cannot observe its own subject

`4.3.1.terminfo/configure.verify.sh` declares *"a FUTURE interactive session erases on `^?`"*.
an upgrade run is not an interactive session — its stdin is closed. so it can observe the
declaration in the rc file, and it **cannot** observe that the declaration takes effect.

⚠️ a verify in that position must say which half it proved. a silent ✔ claims authority it
does not have; a ✋ cries wolf, and a run full of false failures gets ignored.

## .where the code is

| path | what |
|---|---|
| `src/grove.provision._.sh` | the root: reads the top-level dirs, dispatches each |
| `src/bundle.upgrade.sh` | the runtime: `bundle.upgrade`, the `--what` filter, the mode gate |
| `src/grove.env.sh` | the `Environment`, derived once |
| `src/grove.for.sh` | `--for local\|cloud`, DERIVED from `$server`'s tier |
| `src/grove.provision/` | the tree, which IS the inventory |

## .see also

- `rule.require.grove-provision-bundles` — the tree's rules: what a body may not do
- `rule.require.upgrade-entries-verify-themselves` — the four phases, and the gate
- `rule.require.bundle-as-sole-declaration` — the bundle holds its concern ONCE, and calls out
  only to the three runtime primitive families
- `rule.require.conform-to-sdk-environment` — the `Environment` that travels down
- `domain.terms/term=bundle._.choice._.md` — the word, and its forbidden synonyms
- `domain.terms/term=claim._.choice._.md` — what the roll counts, and why `0` is not enough
