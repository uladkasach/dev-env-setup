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

## .the tmux gate gotcha (the core subtlety)

the kitten's forward branch is **gated**. the original gate was:

```python
if window.screen.current_key_encoding_flags():
    window.write_to_child(b'\x1b[99;6u')
```

`current_key_encoding_flags()` reads kitty's **direct child**.

- kitty → nvim: child is nvim, protocol on → flags != 0 → forward fires → yank works
- kitty → tmux → nvim: child is **tmux**, and tmux never surfaces nvim's kitty-keyboard-protocol upward → flags is **always 0** → forward never fires → copy dead

verified live: `flags=3` bare nvim, `flags=0` through tmux. this is structural, not session state — a net-new tmux fails identically.

### the fix

the kitten also detects tmux directly via a `/proc` subtree walk from `window.child.pid` (same technique `reboot_window.py` uses, because kitty's `foreground_processes` returns empty when tmux holds the pty). it forwards when **either** flags != 0 **or** tmux is the child:

```python
if window.screen.current_key_encoding_flags() or _holds_tmux(window):
    window.write_to_child(b'\x1b[99;6u')
```

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

`ctrl+c` and `ctrl+shift+c` both map to `kitten copy_notify.py`, so they behave identically everywhere: copy kitty's selection + toast, plus forward to the child. the builtin `copy_to_clipboard` action would skip both the toast and the forward, so the kitten backs both keys.

## .diagnose live, do not assume

when copy breaks, instrument the kitten — add a debug line that appends `current_key_encoding_flags()` and `bool(selection)` to a log file, press the key once on each path, then read the log. one press settles whether the gate is shut (flags=0) or the forward fires but dies downstream. (write the log under the repo `.temp/`, not `/tmp` — a hook blocks `/tmp` reads.)

## .tradeoff

the forward reaches a **bare shell inside tmux** too (it also gets `CSI 99;6u` on `ctrl+c`). harmless because interrupt lives on `ctrl+x`, but it is a deliberate deviation from "ctrl+c is copy-only, untouched escape at the prompt".

## .see also

- `src/install_env.pt4.terminal.kitty.sh` — `copy_notify.py` + `reboot_window.py` kittens, the `map ctrl+c` / `map ctrl+shift+c` lines
- `src/tmux.conf` — extended-keys + clipboard relay
- `src/init.lua` — nvim `<C-S-c>` / `<C-c>` yank keymaps + `TextYankPost` toast
- `rule.require.solve-at-cause` — the gate fix works with kitty's own /proc pattern, not a time hack
