# rule.require.repo-as-source-of-truth

## .what

the repo is the source of truth for all environment configuration — never modify a config
file directly on the machine.

## .why

- **reproducibility** — a fresh machine is built from the repo, so a change the repo has
  never seen is a change the next machine will not get
- **version control** — changes are tracked, reviewable, revertible
- **documentation** — `src/grove.provision/` **is** the canonical record of what a box gets;
  the directory tree is the inventory (`rule.require.bundle-as-sole-declaration`)
- **idempotency** — a re-run converges, so a second apply is safe

## .scope

every system and tool configuration:

- terminal (kitty, fonts, terminfo)
- git config and aliases
- shell (zsh, bash_aliases, starship, tmux)
- tools (keyd, codium, nvim)
- system settings (swappiness, inotify limits, swap, earlyoom)

## .how

1. change the artifact in `src/` — or the phase in `src/grove.provision/<slug>/`
2. apply it through the entrypoint
3. commit

```sh
rhx grove.provision --what 4.3.2.emulator --mode plan    # see what would change
rhx grove.provision --what 4.3.2.emulator --mode apply   # apply it
```

## .examples

### 👍 good — change the repo, apply through the entrypoint

```sh
# kitty's config lives in its bundle's configure phase
vim src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/configure.upsert.sh

# apply it, and let the bundle's verify prove it landed
rhx grove.provision --what 4.3.2.emulator --mode apply
```

### 👎 bad — a direct edit on the box

```sh
# lost on the next apply, and the next machine never gets it
vim ~/.config/kitty/kitty.conf
```

### 👎 also bad — `source` + call

```sh
source <some-file> && configure_kitty
```

it is a one-off command that skips the bundle's verify
(`rule.require.install-via-procedures`).

⚠️ **a worked example names a SLUG, and a slug can be deleted.** no check reddens when the
prose stays true and every command in the block answers *"no bundle named …"*. the reader
who follows the example is the detector — run the slug before you trust the block.

## .the commands

```sh
git.repo.pull   # remote → here
grove.provision     # repo → machine — the WHOLE tree, every bundle at every depth
```

⚠️ **`grove.provision` drives the entire bundle tree**, never a narrow config copy. a brief
that describes it more narrowly sends a reader elsewhere for the rest, which is the
second-path habit this repo keeps at bay.

⚠️ **and this line carries NO count and NO retired term** — both by measurement. a count in
a brief is a second declaration of a fact the tree already holds, and it decays with no
signal. the retired word is the worse half and the one a re-count misses: `leaf`/`composite`
was deleted 2026-07-30 after its tally let a composite print ✔ on a box whose only applicable
child was skipped (`term=bundle._.choice._.md`).

to narrow the run, name a slug — never reach for another command:

```sh
grove.provision --what 2.7.aliases --mode apply
grove.provision --what 2.5.zsh     --mode apply
```

(`grove.provision.bashaliases` and friends still exist, but they are pure synonyms for
`--what <slug>`, kept only so `<TAB>` completes. they are deliberately not grown.)

## .enforcement

- a config edited on the box with no matched repo change = **blocker** — it is lost at the
  next apply, and the next machine never gets it
- a change applied by any path other than the entrypoint = **blocker**
  (`rule.require.grove-provision-as-the-only-entrypoint`)

## .see also

- `rule.require.bundle-as-sole-declaration` — the tree is the inventory
- `rule.require.install-via-procedures` — never hand a human a one-off
- `rule.require.upgrade-entries-verify-themselves` — applied is not proven
