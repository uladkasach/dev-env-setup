# dev-env-setup

## .what

personal development environment configuration repo — shell configs, aliases, tools, and setup commands for debian-based linux (pop-os, ubuntu).

## .components

### src/

| file | purpose |
|------|---------|
| `bash_aliases.sh` | shell aliases + functions (copied to `~/.bash_aliases`) |
| `zshrc.sh` | zsh config with oh-my-zsh + spaceship theme (copied to `~/.zshrc`) |
| `install_env.sh` | full environment setup procedure (keyd, ptyxis, codium, docker, etc) |
| `backup_env.sh` | backup current env to 1password |

### bash_aliases.sh highlights

- **smart npm/npx**: auto-routes to pnpm in pnpm projects, npm in npm projects
- **git aliases**: `git release`, `git tree`, `git grab` (worktree + patch management)
- **aws profiles**: `use.ahbode.dev`, `use.ahbode.prod`, etc
- **github app tokens**: `get_github_app_token` for short-lived installation tokens
- **utilities**: `speedtest.internet`, `power.suspend`, `sync.devenv`, etc

### install_env.sh highlights

- **keyd**: capslock = ctrl (held) / escape (tapped); ralt/rctrl = vim arrows
- **ptyxis**: gpu-accelerated terminal with vim-style tab nav (ctrl+h/l)
- **gitui**: terminal git tui with desert theme + hjkl navigation
- **codium**: vscodium with microsoft extensions + sync-settings
- **fnm**: fast node manager with pnpm + corepack

### codium/

| file | purpose |
|------|---------|
| `sync.settings.yml` | zokugun.sync-settings config for vscode settings backup |
| `redundant.extensions.yml` | list of extensions to avoid |

### guides/

vim/nvim command references, eol upgrade notes.

### keeb/

hhkb keyboard layout documentation.

## .sync workflow

```sh
# pull latest from repo
devenv.sync.repo

# apply configs to system
sync.devenv              # both aliases + zshrc
sync.devenv.bashaliases  # just aliases
sync.devenv.zshrc        # just zshrc
```

## .key patterns

- configs live in `src/`, get copied to `~/` on sync
- 1password stores secrets (aws creds, vpn configs, etc)
- flatpak for sandboxed apps (firefox, spotify, slack)
- keyd for system-wide key remapping
