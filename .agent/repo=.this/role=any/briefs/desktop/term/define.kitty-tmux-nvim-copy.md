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
2. kitty runs the `copy_notify.py` kitten (declared by `4.3.2.emulator`)
3. the kitten's **forward branch** writes the keyboard-protocol key `CSI 99;6u` (= `<C-S-c>`) to its child
4. nvim's keymap `<C-S-c> → "+y` (`src/init.lua`) does the yank into the `+` clipboard register
5. `set-clipboard on` in tmux + kitty's OSC 52 relay carries the `+` register out to the desktop clipboard

the forward is `CSI 99;6u`, **never** the raw `^C` byte — so `ctrl+c` can never SIGINT the shell. interrupt lives on `ctrl+x` instead.

## .the gate: TWO of them, placed where the answer lives

**hard invariant: `ctrl+c` / `ctrl+shift+c` must NEVER interrupt any receiver,
globally.** the forward is `CSI 99;6u`, never `^C`, so it cannot carry a signal
at all — and it is still gated, so it reaches only an app that yanks on it.

| the duct is… | who decides | on what |
|---|---|---|
| **local** | kitty's kitten | `FORWARD_ALLOWLIST = {'nvim'}` vs the active pane's command |
| **remote** | the far **tmux** | `bind -n C-S-c if -F '#{m:*nvim*,#{pane_current_command}}'` |

```python
# 1. LOCAL — the kitten can see the pane, so it judges
pids = _window_pids(window)
if _focused_app(window, pids) in FORWARD_ALLOWLIST:
    window.write_to_child(b'\x1b[99;6u')
    return

# 2. REMOTE — it cannot, so it delivers and lets the far tmux judge
if _subtree_has_ssh(pids):
    window.write_to_child(b'\x1b[99;6u')
```

### 🛑 why the remote arm exists

over ssh this box holds only the ssh client. `/proc`, tmux, and
`foreground_processes` all answer `ssh`, so the allowlist could never confirm
nvim and correctly refused — which made visual-mode copy a **silent no-op on
every grove**.

⚠️ and it read as healthy: kitty's own mouse-drag copy still fired and still
toasted. **one live path masked one dead path**, which is why the two paths at
the top of this brief must never be conflated.

⇒ the judgment moved to tmux, which runs ON the host that holds nvim. its read
of `pane_current_command` is a fact, not an inference across a pipe. that same
bind serves the local duct too, so both paths now agree.

### how the kitten names the focused app

`_focused_app(window)` returns the command the human actually interacts with:

- **through tmux** — the *active pane's* command. the kitten finds the tmux
  client in the window's `/proc` subtree, reads its control pts
  (`readlink /proc/<pid>/fd/0`, which equals tmux's `#{client_tty}`), then asks
  tmux: `list-clients` → session for that tty, `list-panes` → the
  `#{pane_current_command}` of the active pane. forwards only if that is `nvim`.
- **no tmux** — `window.child.foreground_processes[0]` basename.

### 🛑 two gates that look right and are not

- **`current_key_encoding_flags()`** reads kitty's **direct child**. through tmux
  that child is tmux, which never surfaces nvim's kitty-keyboard-protocol upward,
  so flags is **always 0** (measured live: `flags=3` bare nvim, `flags=0` through
  tmux). a gate on it kills copy through tmux entirely.
- **"tmux is anywhere in the subtree"** does not name *which pane* is active. in a
  tmux window with claude-cli in the active pane it forwards `CSI 99;6u` to claude,
  which reads it as **interrupt** — the invariant broken.

⇒ the allowlist plus active-pane detection is what holds both halves.

## .the tmux relay (necessary but not sufficient)

`src/tmux.conf` must relay the protocol + clipboard, or the extended key + OSC 52 die in transit:

```
set -s extended-keys on
set -as terminal-features 'xterm-kitty:extkeys'
set -s set-clipboard on
set -as terminal-features 'xterm-kitty:clipboard'
```

**subtlety:** these are server options. a live `source-file` sets them but does NOT re-run the per-client keyboard-protocol handshake — a detach + reattach does. also each `set -as` appends, so repeated live sources leave the `terminal-features` list duplicated many times over (harmless, but a tell that the conf was re-sourced live rather than via a fresh server).

**these relay lines are required and are not the gate.** `src/tmux.conf` carries
BOTH concerns and they are independent:

| line | role |
|---|---|
| `extended-keys` + `extkeys` / `set-clipboard` + `clipboard` | the **relay** — without it the key and the OSC 52 die in transit |
| `bind -n C-S-c if -F '#{m:*nvim*,…}' 'send-keys C-S-c'` | the **gate** — it decides whether nvim gets the key |

⚠️ the gate DEPENDS on the relay: without `extended-keys`, tmux cannot tell
`C-S-c` from `C-c`, so the bind never matches.

⚠️ a root (`-n`) bind SWALLOWS the key for every app in the session. the
`send-keys C-S-c` re-emit is what hands it back to nvim — drop that half and
copy dies everywhere, local included.

## .both keys are equal

`ctrl+c` and `ctrl+shift+c` both map to `kitten copy_notify.py`, so they behave identically everywhere: copy kitty's selection + toast, plus the allowlist forward. the builtin `copy_to_clipboard` action would skip both the toast and the forward, so the kitten backs both keys.

## .who is on the allowlist, and who is not

- **nvim** — has `<C-S-c> → "+y`, so it yanks. the one allowed receiver.
- **claude-cli** — reads the forwarded key as interrupt/cancel. on the active pane
  the kitten detects it and forwards **none** of it.
- **a bare shell / unknown TUI** — no yank keymap; also excluded.

the copy branch always runs, so mouse-select + `ctrl+c` copies kitty's selection
and toasts from *any* app, claude included — it merely never forwards the key
onward. the shell's SIGINT lives on `ctrl+x` alone.

to allow a new receiver, add its `pane_current_command` / foreground comm to
`FORWARD_ALLOWLIST` — and only if it truly yanks the key rather than interrupts.

## .diagnose live, do not assume

when copy breaks, instrument the kitten — append `_focused_app(window)` and
`bool(selection)` to a log file, press the key once on each path, then read the
log. one press settles whether the focus was misread (so the allowlist shut the
gate) or the forward fired but died downstream. (write the log under the repo
`.temp/`, not `/tmp` — a hook blocks `/tmp` reads.)

## .see also

- `src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/configure.upsert.sh` — `copy_notify.py` + `reboot_window.py` kittens, the `map ctrl+c` / `map ctrl+shift+c` lines
- `src/tmux.conf` — extended-keys + clipboard relay
- `src/init.lua` — nvim `<C-S-c>` / `<C-c>` yank keymaps + `TextYankPost` toast
- `rule.require.solve-at-cause` — the gate fix works with kitty's own /proc pattern, not a time hack