# howto: termwork role tabs

## .what

open one kitty window that hosts several ducts as tabs — one per role — with a
clean tab bar (role names) and a tmux footer that shows repo + branch.

## .why

- a worktree often needs more than one live session (mechanic, foreman, ...)
- one window with role tabs beats a window per role: less clutter, one place to look
- the tab bar shows the short role, not the long globally-unique duct name
- the tmux footer shows where you are (repo left, branch right) at a glance

## .the interface

`--for <role>` is the one flag you need. a role's duct lives at `<terminal>/<role>`.

```bash
# ductwork (or raw tmux) creates the role sessions first
duct.open --on worktree/mechanic
duct.open --on worktree/foreman

# first --for opens the window; its base tab is the mechanic role
term.open --via kitty --on worktree --for mechanic

# a later --for adds a tab for the foreman role
term.open --via kitty --on worktree --for foreman
```

that is the whole lifecycle. address a role's tab the same way for the other verbs:

```bash
term.read --via kitty --on worktree --for foreman
term.send --via kitty --on worktree --for foreman --what "npm test"
term.stop --via kitty --on worktree --for foreman   # close just that tab
term.stop --via kitty --on worktree                 # close the whole window
```

## .what --for expands to

`--for <role>`  ≡  `--tab <role> --duct <terminal>/<role>`

- the tab **title** is the clean `<role>` (mechanic, foreman)
- the tab **attaches** the duct `<terminal>/<role>` (globally unique)
- commands address the tab by its role **id**, so the long duct name never leaks

`--for` is local-only. it must not be combined with `--tab`/`--duct` (those are the
low-level primitives it is built on).

## .the footer (two bars, two jobs)

when the window has 2+ tabs you see two bars stacked:

```
 dev-env-setup                              vlad/fix-terms      <- tmux status line
[ mechanic ][ foreman ]                                        <- kitty tab bar
```

- **kitty tab bar** (bottom): the role tabs. hidden at one tab, shown at 2+ (kitty
  default). titles carry ≥1 space of whitespace on each side.
- **tmux status line** (above it): `repo` on the left, `branch` on the right. the
  shell computes these and pushes them to tmux pane options `@repo`/`@branch` (see
  `_set_terminal_title` in `src/zshrc.sh`); tmux reads them in `status-left`/
  `status-right` (see `src/tmux.conf`). no git subprocess on a status refresh.

outside a git repo `@repo`/`@branch` are empty, so the footer clears (no stale value).

## .try it

a demo opens a persistent `mechanic` + `foreman` window so you can eyeball the
tab bar + footer without a real worktree:

```bash
rhx termwork.test demo     # pops the window, leaves it open
rhx termwork.test clean     # reap the demo (and any leftover test sessions)
```

## .tests

the behavior is covered by `.agent/repo=.this/role=any/skills/termwork.test.sh`:

| command | checks |
|---------|--------|
| `rhx termwork.test`            | stub: --for/--tab/--duct logic, back-compat (headless) |
| `rhx termwork.test live`       | real kitty + tmux: role tabs attach distinct ducts |
| `rhx termwork.test tmuxcheck`  | tmux status-left/right read @repo/@branch |
| `rhx termwork.test shellcheck` | real zsh pushes @repo/@branch into tmux |
| `rhx termwork.test clean`      | reap leftover twtest-*/twdemo sessions + windows |

## .apply (source edits → deployed)

these live in `src/` and take effect once synced:

- **zshrc** (the @repo/@branch push): `sync.devenv.zshrc`, then open a new shell
- **tmux.conf** (the footer): re-run `configure_tmux`, then `tmux source-file ~/.tmux.conf`
- **kitty** (tab whitespace): re-run the kitty section of `install_env.pt4.terminal.kitty.sh`,
  then reload kitty config (`ctrl+shift+f5`)

## .see also

- `howto.terminal-window-management.md` — full termwork api reference
- `howto.termwork-roundtrip.md` — open/read/send/stop base flow
- `src/termwork.sh` — the implementation (`--for` in `term.open`)
