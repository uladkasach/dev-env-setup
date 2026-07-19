# pref: shell keybinds

## .what

keybind preferences for the interactive zsh shell.

## .we don't use emacs

the human does not use emacs, and does not rely on zsh's emacs-mode edit keybinds
(`ctrl+a` / `ctrl+e` for line start/end, `ctrl+k` kill, etc). so those keys are
free to rebind to more useful actions — no need to preserve their emacs-default
behavior.

**implication:** when a single key like `ctrl+e` has an emacs-mode default, prefer
the more useful bind over the default. do not hold a key hostage to emacs muscle
memory the human does not have.

## .edit command line → ctrl+e

`ctrl+e` opens the current shell input in `$EDITOR` (nvim) via zsh's
`edit-command-line` widget. see `src/zshrc.sh`.

- primary: `ctrl+e`
- fallback: `ctrl+x ctrl+e` (zsh's own default for this widget) stays bound too
- `ctrl+e` used to be emacs `end-of-line`; that is intentionally given up (see above)

`$EDITOR` and `$VISUAL` are both `nvim` (`src/zshrc.sh`), so the command opens in
nvim, not vim.

## .apply

```bash
sync.devenv.zshrc   # then open a new shell, or: source ~/.zshrc
```

## .see also

- `src/zshrc.sh` — the `bindkey` lines + `$EDITOR`/`$VISUAL` exports
