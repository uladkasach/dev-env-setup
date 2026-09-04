# howto: install configs from a worktree

## .what

a config artifact is copied from `$GROVE_SRC` by the bundle that owns it, so a worktree's
configs land the moment you run that worktree's own driver:

```bash
cd ~/git/more/_worktrees/dev-env-setup.<branch>
rhx grove.provision --what 2.7.aliases --mode apply
```

`howto.setup-from-worktree.md` owns how the driver self-locates, and the
`DEV_ENV_SETUP_DIR` override for the case where you invoke one checkout and want another's
`src/`.

## .why

test a config change on the real machine **before** you merge it. the alternative — merge
first, then sync — makes main the only way to try a change, which slows every iteration and
pushes unvalidated config to main.

## ⚠️ .the trap a hardcoded source sets

a sync that hardcodes `~/git/more/dev-env-setup/src/` copies the **main** checkout's config
whatever tree you ran it from. a function added in a worktree never appears in
`~/.bash_aliases`, and the sync reads as broken when it merely read the wrong source. the
run's `src:` header line is the proof of which tree it read.

## .the bundles that own a config

| artifact | owner |
|---|---|
| `~/.bash_aliases` | `2.7.aliases` |
| `~/.zshrc`, `~/.zshenv` | `2.5.zsh` |
| `~/.tmux.conf` | `2.8.tmux` |
| git identity + aliases | `2.2.git` |

## .note

a worktree install is for **local validation**, not the end state. main remains the source
of truth (`rule.require.repo-as-source-of-truth`) — the grove bootstrap
(`grove.provision._.sh --for cloud`) and the AMI bake both read main, so merge once validated.

## .see also

- `howto.setup-from-worktree.md` — how the driver locates its own `src/`
