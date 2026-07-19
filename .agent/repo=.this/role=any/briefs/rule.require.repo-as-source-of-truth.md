# rule.require.repo-as-source-of-truth

## .what

the repo is the source of truth for all environment configuration — never modify config files directly on the machine

## .why

- **reproducibility** — fresh machines can be set up from scratch via the repo
- **version control** — changes are tracked, reviewable, and revertible
- **documentation** — `src/install_env.sh` serves as canonical docs for the env setup
- **idempotency** — commands can be re-run safely to update configs

## .scope

applies to all system and tool configurations:

- terminal configs (ptyxis, keybindings)
- git configs and aliases
- shell configs (zsh, bash_aliases)
- tool configs (keyd, codium)
- system settings (swappiness, inotify limits)

## .how

1. make changes in `src/install_env.sh` (or the relevant source file in `src/`)
2. run the relevant function or sync command to apply
3. commit the change to the repo

## .examples

### 👍 good — config via repo

```sh
# edit install_env.sh to update ptyxis theme
vim src/install_env.sh  # modify configure_ptyxis()

# re-run the function to apply
source src/install_env.sh && configure_ptyxis
```

### 👎 bad — direct config edit

```sh
# direct edit loses reproducibility
vim ~/.var/app/app.devsuite.Ptyxis/config/glib-2.0/settings/keyfile
```

## .sync commands

after changes to source files:

```sh
sync.devenv              # apply both aliases + zshrc
sync.devenv.bashaliases  # just aliases
sync.devenv.zshrc        # just zshrc
```

## .enforcement

direct config file edits without matched repo changes = lost on next sync or machine setup
