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
