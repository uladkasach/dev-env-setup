# gotcha: `git.grove.push --into` names the DESTINATION, not the parent

> ## ✅ FIXED AT CAUSE — 2026-07-31
>
> the skill handles both wrong forms itself, and differently — only one is deterministically
> wrong. prose a caller must have READ is not the defense:
>
> | form | what the skill does now |
> |---|---|
> | a `~/` or `/` prefix | **REFUSES**, exit 2, and prints the corrected command |
> | `--into` names the parent | **SHOWS** a real file's resolved path, before the write |
>
> ```
> ✋ --into must be HOME-RELATIVE: drop the '~' prefix
>    └─ fix:
>         rhx git.grove.push grove-1 --from src --into git/more/x/src --mode plan
>
>    🔭 so, on grove-1:
>       src/backup_env.sh  →  $HOME/git/more/x/backup_env.sh
>       ↑ if that is not where you want it, --into is wrong
> ```
>
> **why the second is shown and never refused:** `--from src --into wip/src` is
> right, `--into wip` is wrong, and `--into wip/src.old` is a legitimate rename —
> so a rule keyed on the basenames would block real work, and a check that cries
> wolf gets silenced (`gotcha.a-check-that-cries-wolf-gets-silenced`). the sample
> path answers *the exact question this brief's `.the test` asks a human to hold
> in their head*, with a real filename, before any byte moves.
>
> the brief is kept because the MEASUREMENT below is the evidence the guard
> exists — delete the story and the next reader deletes the guard. read on for
> what it cost.

## .what

`rhx git.grove.push <grove> --from <dir> --into <path>` places **the contents of
`<dir>`** at `<path>`. so `<path>` must end with the name you want those contents
to live under — and must **not** start with `~/` or `/`.

```sh
rhx git.grove.push grove-1 --from src    --into git/more/dev-env-setup.wip/src      # ✔
rhx git.grove.push grove-1 --from .agent --into git/more/dev-env-setup.wip/.agent   # ✔

rhx git.grove.push grove-1 --from src    --into git/more/dev-env-setup.wip          # ✋ scatters
rhx git.grove.push grove-1 --from src    --into ~/git/more/dev-env-setup.wip/src    # ✋ literal ~
```

## .why it bites

both wrong forms **exit 0 and print `🐢 cowabunga!`**. there is no complaint to
notice. the damage is found later, by a symptom that looks like an unrelated problem.

### form 1 — a leading `~/` or `/`

`--into` is resolved against the grove's `$HOME` already. a leading `~/` makes
`$HOME/~/git/…` — a directory literally named `~`. the push succeeds; the content
is simply not where the caller will ever look.

### form 2 — naming the parent

measured on grove-1, 2026-07-30:

```sh
rhx git.grove.push grove-1 --from src    --into git/more/dev-env-setup.wip --mode apply
rhx git.grove.push grove-1 --from .agent --into git/more/dev-env-setup.wip --mode apply
```

this emptied **both trees onto the checkout root**. `grove.provision/`,
`bash_aliases.sh`, `playbooks/`, `repo=*/` — 28 entries, each a level too high.
worse, `.agent/readme.md` **overwrote** the repo's own `readme.md`, which is the
one case where the mistake destroys rather than duplicates.

## .why the caller was not the cause

four playbooks documented form 2 **in their own usage lines**:

```sh
#   rhx git.grove.push <grove> --from src --into git/more/dev-env-setup --mode apply
```

so the mistake was **inherited, not invented** — the docs taught it. three briefs
plus the skill's own `--help` separately taught form 1. a caller who reads the
docs and follows them lands in both traps.

that is the durable lesson: when a usage line is wrong, every caller who trusts
it reproduces the defect. each one reads as a fresh human error rather than
as the one doc bug it actually is (`rule.require.solve-at-cause`).

## 🛑 .the guard is UNCONDITIONAL, and a `| tail` still defeats it — 2026-08-14

the `🔭 so, on <grove>:` block prints on `--mode apply` too, not merely on a plan, so the
guard sits where it needs to. the CALLER defeats it anyway:

```sh
rhx git.grove.push <grove> --from src --into 'git/more/dev-env-setup' --mode apply | tail -12
```

the preview sits ABOVE the transfer summary, so `tail -12` kept the summary — `🐢 cowabunga!`
— and discarded the one line that names the defect. the push went through, flattened `src/`
onto the checkout root, and reported success.

⚠️ **the second alarm made it worse, not better.** with a wrong `--into`, the skill's
`🌙 the destination holds files this source does not` list fires — and every path in it looked
like a stale file to sweep:

```
🌙 the destination holds files this source does not:
      src/machine/tmp-cleanup.timer
      src/firefox/firefox.cfg
      src/grove.provision/6.apps/6.5.onepassword/provision.verify.sh
```

those are the REAL checkout's own files. the list is correct about set difference and reads as
an accusation about the grove. the output that outlived the cut pointed at the wrong subject
entirely, with a `rm -rf` command to run. a caller who acted on it would have deleted the tree
they meant to update.

### .the shape, beyond this one skill

> **a guard prints; a pipe decides whether anyone reads it.** the skill cannot know that its
> most important line was cut. a truncated invocation converts a live guard into silence, and
> the summary that outlives the cut is the least informative part.

it is the mirror of `gotcha.a-check-that-cries-wolf-gets-silenced` measurement 2, where an
output PAD disarmed a `^`-anchored pattern. there the format moved; here the format was fine
and the READER dropped it. either way an invisible dependency on output shape is what broke.

⇒ **for any command whose safety rests on a preview, read the HEAD, never the TAIL.** a
preview is placed before the act by definition, so `| head -N` keeps the guard and `| tail -N`
keeps the receipt.

## .the test

> ⚠️ **the skill runs this test FOR you** — every `--mode` prints a real file's resolved
> destination (the `🔭 so, on <grove>:` line). you need not hold the question in your head,
> but you do have to let that line reach your eyes.

before any `git.grove.push`, read `--into` aloud and ask:

> "after this runs, what is the full path of one file from `--from`?"

if the answer is not `<into>/<that file's path inside --from>`, the `--into` is
wrong.

## .the cleanup, if it already happened

⚠️ **no play SWEEPS this, deliberately.** a play may never write to a machine
(`rule.forbid.repair-plays`), and a sweep here is worse than most: it cleans up a **mistake**
rather than converges a **state**, so it could never belong to a bundle either.

### .to DETECT one, derive the stray set — never list it

a stray is **invisible until somebody lists the checkout root by eye**. measured on
`grove-ahbode-v20260811`: 23 entries at the root, dated **2026-07-30** — a complete second
`grove.provision/` tree that had survived two weeks, every apply, and every play run on that
box.

⚠️ the rule that found all 23 is DERIVED, which is the part worth reuse:

> a root entry whose NAME also appears in `src/` is a flattened copy

all 23 satisfy it; `readme.md`, `package.json`, and `devenv.bootstrap.sh` do not. a
hand-written list of "what belongs at the root" would have gone stale the first time a file
was added, and a check keyed on a stale list reports a clean root forever
(`gotcha.a-check-that-cries-wolf-gets-silenced`, m.3).

the durable fix is upstream: the ⚠️ block in `git.grove.push`'s header, and the question in
`.the test` above. a stray is cheap to avoid and awkward to sweep.

if a box already carries strays, remove them by hand, and mind the two traps that cleanup
had to learn:

- a **symlink** stray (`src/nvim.md`) is invisible to `[[ -e ]]`, because `-e`
  follows the link and the target dangles one level up. the test must be
  `-e || -L`.
- `readme.md` cannot be swept by name, since the root is *supposed* to have one.
  it is swept by **content** — identical to `.agent/readme.md` ⇒ impostor.

## .see also

- `.agent/repo=.this/role=any/skills/git.grove.push.sh` — the ⚠️ block in its header, and
  the GUARD: the push refuses a `--into` that would scatter a tree into a seat's `$HOME`,
  which is the fix at cause
- `rule.forbid.repair-plays` — why a sweep may not be a play
- `rule.require.solve-at-cause` — fix the doc, not the caller
- `rule.require.errors-name-the-fix` — why a silent `exit 0` is the real defect here
