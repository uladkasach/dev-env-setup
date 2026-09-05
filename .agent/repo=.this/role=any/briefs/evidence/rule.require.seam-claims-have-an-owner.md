# rule.require.seam-claims-have-an-owner

## .what

when bundle **A** declares a HANDLE whose BODY bundle **B** installs, the claim
*"the handle names something that exists"* belongs to **A**, and A's verify must
assert it.

it is not enough that A proves its handle exists and B proves its file exists.
that pair leaves the **seam** — the link between them — owned by neither, and a
break there stays invisible while both bundles report green.

## .why

this repo kills the same defect over and over: **two answers to one question**
(`rule.require.identical-bundle-composition`, `.two lists drift`). the seam is
that defect in its subtlest form — not two lists that disagree, but two verifies
that each assume the other looked.

it is worse than an unchecked fact, because the greens are *actively reassuring*.
a reader sees two ✔ and concludes the path is proven. an unchecked fact at least
looks unchecked.

## .the measurement — 2026-07-30

`git tree` is a git alias whose body is a shell function:

```sh
# 2.2.git/configure.upsert.sh — the HANDLE
git config --global alias.tree '!bash -c "source ~/.bash_aliases && git_alias_tree \"\$@\"" --'
```
```sh
# src/bash_aliases.sh — the BODY, installed by 2.7.aliases
git_alias_tree() { ... }
```

what each verify asserted:

| bundle | its claim | verdict |
|---|---|---|
| `2.2.git` | `git config --get alias.tree` succeeds | ✔ |
| `2.7.aliases` | `~/.bash_aliases` is present, current, and parses | ✔ |

rename `git_alias_tree` in `bash_aliases.sh` and **both stay green**. the config
still holds the alias. the file still parses, and still matches the checkout it
was copied from — so even the `cmp` freshness check passes. yet:

```
$ git tree
git_alias_tree: command not found
```

and each bundle's header pointed at the other. `2.2.git` said, in as many words,
*"whether that file exists is `2.7.aliases`'s claim, and its own verify makes
it"* — true, and beside the point. the file's existence was never the question.

## .the rule

| the fact | its owner |
|---|---|
| the handle exists | A — the bundle that declares it |
| the body's FILE exists, is current, parses | B — the bundle that installs it |
| **the handle names a body that is DEFINED** | **A** — it is a fact about A's artifact |

A owns the seam because the handle is A's artifact, and a handle that names an
absent symbol is a broken handle — A's defect, not B's.

## .how A must report it

A asserts the target, but must not steal B's verdict on the file:

- the body is defined → `• … ✔`
- the body is absent while the file is present → `✋`, and name the fix
- the **file** is absent → `🌙`, and say the ✋ is B's to make

that last line is what keeps one fact from carrying two verdicts. if A ✋'d on an
absent file, a repair to B would leave A's red line standing until A re-ran, and
a reader would see two failures where one exists.

## .derive the target, never list it again

A already declares the handles. A's verify already names them. a **third**
hand-kept roster of "which handles are delegates, and what each points at" would
reintroduce the very defect this rule closes.

read the target out of the handle's own value:

```sh
# the alias value already names its function — extract it rather than restate it
[[ "$value" =~ (git_alias_[a-z_]+) ]] || continue
fn="${BASH_REMATCH[1]}"
grep -qE "^${fn}\(\)" "$HOME/.bash_aliases" || undefined+=("$alias_name → $fn")
```

## .prove the check discriminates

a seam check that has only met a healthy box is unproven — it printed ✔, but so
would `true`. break the seam on purpose, confirm it goes red, restore, confirm it
goes green. a `prove.git-alias-seam` probe is the reference shape.

this is not ceremony. the seam went unchecked for so long because **two green lines
were trusted, and neither had met a real break.**

## .where else this shape appears

any bundle pair where one declares a reference and another supplies the referent.
in each, ask: *if the referent were renamed, would any verify go red?* if the
answer is no, the seam has no owner.

### the audit — every seam in this repo, 2026-07-30

the whole tree was walked to learn whether the defect was a pattern. it was one instance:

| seam | referent | owner | verdict |
|---|---|---|---|
| git alias → shell function | `git_alias_tree` | **nobody** | ✋ **the defect this rule was written for** |
| zshrc `source ~/.bash_aliases` | the FILE | `2.7.aliases` | ✔ owned |
| `bash_aliases.sh` → ductwork / termwork | the FILES | `2.7.aliases` | ✔ owned (all three in one `pairs` list) |
| `kitty.desktop` `Exec=kitty` | the BINARY | `4.3.2.emulator` | ✔ owned — `command -v kitty`, plus a `kitten` run |
| `tmux.conf` `run '~/.tmux/plugins/tpm/tpm'` | the ENTRYPOINT | `2.8.tmux` | ✔ owned — and its header says why the entrypoint, not the dir |
| COSMIC Terminal action → kitty | the VALUE | `3.3.desktop` | ✔ owned — it reads the value, not the file |
| `rhx git.grove.*` skills → `git_alias_grove` | the FUNCTION | the skill itself | ✔ self-guarded with `command -v` |

**why the git alias was the one that slipped, and the others did not.** every
owned row above points at a FILE, a BINARY, or a VALUE — things whose bundle
naturally tests them, because their absence is that bundle's own visible failure.
the git alias points at a **symbol inside another bundle's file**. that is the one
referent whose absence is invisible from both sides: the file is there and parses,
so B is content; the alias is there and is well-formed, so A is content.

so the shape to hunt is not "a reference across bundles" — most of those are fine.
it is **a reference INTO a file another bundle owns**, where the file's existence
and the symbol's existence are different facts.

## .the test

> if the thing my handle names were renamed tomorrow, would MY verify notice?

- yes → the seam is owned
- no, but B's verify would → check it; B almost certainly proves the FILE, not the SYMBOL
- no → **blocker**

the sharper form, from the audit above:

> does my handle point at a **file**, or at a **symbol inside** a file?

a file has an owner already — the bundle that installs it. a symbol inside
someone else's file has none by default, and is where this defect lives.

## .enforcement

- a handle whose referent no verify asserts = **blocker**
- a seam check that ✋s on the referent's FILE being absent, where another bundle
  owns that file = **blocker** (report `🌙`; one fact, one verdict)
- a hand-kept third list of handles-and-targets, where the handle's own value
  names the target = **blocker**
- a seam check never exercised against a deliberate break = **nitpick**

## .see also

- `rule.require.identical-bundle-composition` — the two-lists defect this is a form of
- `rule.require.bundle-as-sole-declaration` — one declaration per concern
- `rule.forbid.failhide` — a green that proves no claim is the same dishonesty
