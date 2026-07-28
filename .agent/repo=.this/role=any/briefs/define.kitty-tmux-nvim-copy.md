# define.kitty-tmux-nvim-copy

## .what

copy from nvim visual mode across kitty → tmux → nvim is a **three-layer key forward**, not a single copy key. this brief explains the parts and the subtleties that make it fragile.

## .the two copy paths (do not conflate them)

| selection method | who owns the selection | how copy works |
|------------------|------------------------|----------------|
| mouse drag | kitty | kitty reads its own selection, copies + toasts directly |
| nvim visual mode | nvim | kitty forwards a key to nvim; nvim yanks `"+y` itself |

these are independent. mouse-drag can work while visual-mode copy is dead, and vice-versa. always ask *which* path is broken before you diagnose.

## .the visual-mode forward chain

1. human presses `ctrl+c` (or `ctrl+shift+c`) in kitty
2. kitty runs the `copy_notify.py` kitten (`src/install_env.pt4.terminal.kitty.sh`)
3. the kitten's **forward branch** writes the keyboard-protocol key `CSI 99;6u` (= `<C-S-c>`) to its child
4. nvim's keymap `<C-S-c> → "+y` (`src/init.lua`) does the yank into the `+` clipboard register
5. `set-clipboard on` in tmux + kitty's OSC 52 relay carries the `+` register out to the desktop clipboard

the forward is `CSI 99;6u`, **never** the raw `^C` byte — so `ctrl+c` can never SIGINT the shell. interrupt lives on `ctrl+x` instead.

## .the gate: allowlist forward to nvim only (the hard invariant)

**hard invariant: `ctrl+c` / `ctrl+shift+c` must NEVER interrupt any receiver,
globally.** the forward is therefore sent to a strict **allowlist** of apps that
treat `CSI 99;6u` as copy — currently `{'nvim'}`. every other app (claude-cli,
shells, unknown TUIs) reads a ctrl+c-family key as interrupt, so it is never
sent to them. the gate **fails closed**: an app the kitten cannot confirm as an
allowed receiver gets no forward.

```python
FORWARD_ALLOWLIST = {'nvim'}
...
if _focused_app(window) in FORWARD_ALLOWLIST:
    window.write_to_child(b'\x1b[99;6u')
```

### how the kitten names the focused app

`_focused_app(window)` returns the command the human actually interacts with:

- **through tmux** — the *active pane's* command. the kitten finds the tmux
  client in the window's `/proc` subtree, reads its control pts
  (`readlink /proc/<pid>/fd/0`, which equals tmux's `#{client_tty}`), then asks
  tmux: `list-clients` → session for that tty, `list-panes` → the
  `#{pane_current_command}` of the active pane. forwards only if that is `nvim`.
- **no tmux** — `window.child.foreground_processes[0]` basename.

### why the old gate was wrong (history)

the original gate was `current_key_encoding_flags() or _holds_tmux(window)`:

- `current_key_encoding_flags()` reads kitty's **direct child**. through tmux the
  child is tmux, which never surfaces nvim's kitty-keyboard-protocol upward, so
  flags is **always 0** (verified live: `flags=3` bare nvim, `flags=0` through
  tmux). that killed copy through tmux, so `_holds_tmux` was added as an OR.
- but `_holds_tmux` returns true if tmux is **anywhere** in the subtree — it did
  not check *which pane* is active. so in a tmux window with claude-cli in the
  active pane, `ctrl+c` forwarded `CSI 99;6u` to claude, which read it as
  **interrupt**. that broke the invariant. the allowlist + active-pane detection
  replaces it.

## .the tmux relay (necessary but not sufficient)

`src/tmux.conf` must relay the protocol + clipboard, or the extended key + OSC 52 die in transit:

```
set -s extended-keys on
set -as terminal-features 'xterm-kitty:extkeys'
set -s set-clipboard on
set -as terminal-features 'xterm-kitty:clipboard'
```

**subtlety:** these are server options. a live `source-file` sets them but does NOT re-run the per-client keyboard-protocol handshake — a detach + reattach does. also each `set -as` appends, so repeated live sources leave the `terminal-features` list duplicated many times over (harmless, but a tell that the conf was re-sourced live rather than via a fresh server).

**these relay lines are required but do NOT open the kitten's gate.** the `/proc` tmux detection is what opens it. do not mistake correct tmux relay config for a live forward.

## .both keys are equal

`ctrl+c` and `ctrl+shift+c` both map to `kitten copy_notify.py`, so they behave identically everywhere: copy kitty's selection + toast, plus the allowlist forward. the builtin `copy_to_clipboard` action would skip both the toast and the forward, so the kitten backs both keys.

## .the invariant: never interrupt (why the allowlist, not a broad gate)

`ctrl+c` / `ctrl+shift+c` are **copy-only, globally** — they must never reach any
receiver as an interrupt. that is why the forward is an **allowlist** (only nvim),
not a broad "forward whenever a protocol/tmux is present" gate.

- **nvim** — has `<C-S-c> → "+y` → yanks. the one allowed receiver.
- **claude-cli** — reads the forwarded key as interrupt/cancel. so it is on the
  active pane, the kitten detects that and forwards **none** of it.
- **a bare shell / unknown TUI** — no yank keymap; also excluded.

the copy branch still always runs, so mouse-select + `ctrl+c` copies kitty's
selection + toasts from *any* app (claude included) — it just never forwards the
key onward. the shell's SIGINT lives on `ctrl+x` alone.

to allow a new app to receive the copy-forward, add its `pane_current_command` /
foreground comm to `FORWARD_ALLOWLIST` — and only if it truly yanks the key
rather than interrupts.

## .diagnose live, do not assume

when copy breaks, instrument the kitten — append `_focused_app(window)` and
`bool(selection)` to a log file, press the key once on each path, then read the
log. one press settles whether the focus was misread (so the allowlist shut the
gate) or the forward fired but died downstream. (write the log under the repo
`.temp/`, not `/tmp` — a hook blocks `/tmp` reads.)

## .see also

- `src/install_env.pt4.terminal.kitty.sh` — `copy_notify.py` + `reboot_window.py` kittens, the `map ctrl+c` / `map ctrl+shift+c` lines
- `src/tmux.conf` — extended-keys + clipboard relay
- `src/init.lua` — nvim `<C-S-c>` / `<C-c>` yank keymaps + `TextYankPost` toast
- `rule.require.solve-at-cause` — the gate fix works with kitty's own /proc pattern, not a time hack
