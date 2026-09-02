# howto: worktree setup

## .what

set DEV_ENV_SETUP_DIR when you use a worktree so install functions find the correct src/ path.

## .why

install functions default to `~/git/more/dev-env-setup/src/`. in worktrees, this points to the wrong repo copy.

## .setup

```bash
export DEV_ENV_SETUP_DIR=~/git/more/_worktrees/dev-env-setup.<branch>
```

replace `<branch>` with your worktree name.

## .example

```bash
export DEV_ENV_SETUP_DIR=~/git/more/_worktrees/dev-env-setup.vlad.kitty
source $DEV_ENV_SETUP_DIR/src/install_env.pt2.shell.sh
configure_tmux
```

## .affected functions

- `install_zsh`
- `install_starship`
- `configure_tmux`

## ⚠️ the sync.devenv.* aliases do NOT honor this var

`DEV_ENV_SETUP_DIR` covers the `install_env.*` functions above. it does **not** cover the
`sync.devenv.*` aliases — every one of them hardcodes `~/git/more/dev-env-setup/`, and
`bash_aliases.sh` holds no reference to the var at all.

so from a worktree, `sync.devenv.bashaliases` copies the **main checkout's** file over
`~/.bash_aliases`. if your work is uncommitted in the worktree, that **silently reverts it** —
and the alias reports success, because the copy did succeed. it copied the wrong source.

### the rule

| your work is… | to load it |
|---------------|-----------|
| uncommitted, in a worktree | `source <worktree>/src/bash_aliases.sh` — this shell only |
| committed + merged to main | `sync.devenv.bashaliases` — the checkout now holds it |

never run `sync.devenv*` to pick up worktree work. it reads a path you did not edit.

### the shape to recognize

same trap as a dependency patch applied to the copy you sit in rather than the copy the caller
resolves — the `rhx` global-vs-worktree patch of 2026-08-13 was this exact form. the general rule:

> when a tool reads a path, the path it resolves is a property of the TOOL, not of your cwd.
> check which copy the tool reaches before you trust that your edit is what ran.
