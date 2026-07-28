# kitty.hazard.copy-forward-regressions

## .what

the `ctrl+c` / `ctrl+shift+c` copy path (kitty → tmux → nvim) is a fragile
multi-layer key forward. several small edits silently break it. this brief lists
the regressions to guard against. the full architecture is in
`define.kitty-tmux-nvim-copy.md` — read that first.

## .the hard invariant (do not regress this)

**`ctrl+c` / `ctrl+shift+c` must NEVER interrupt any receiver, globally.** they
are copy-only. the forward of `CSI 99;6u` goes to an **allowlist** (nvim only);
no other app ever receives it. this is the non-negotiable rule the whole design
serves — any change that lets the key reach claude-cli / a shell / an unknown
TUI as an interrupt is a regression, full stop.

## .the invariants that must hold

1. `ctrl+c` and `ctrl+shift+c` both run `kitten copy_notify.py` — never the
   builtin `copy_to_clipboard` (which skips both the toast and the forward).
2. the forward writes `CSI 99;6u` (`\x1b[99;6u`), never the raw `^C` byte.
3. the shell's SIGINT lives on `ctrl+x` (`send_text all \x03`), not `ctrl+c`.
4. the forward is gated by an **allowlist** (`FORWARD_ALLOWLIST = {'nvim'}`) on
   the *focused app*: the active tmux pane's `#{pane_current_command}` through
   tmux, else the window's foreground process. it **fails closed** — an
   unconfirmed focus forwards none.
5. nvim maps `<C-S-c> → "+y`; tmux relays `extended-keys` + `set-clipboard`.

break any one and copy dies on at least one path — or worse, the invariant
breaks and a ctrl+c interrupts claude.

## .the regressions to guard against

| edit | what breaks | why |
|------|-------------|-----|
| widen the gate back to "flags != 0 OR tmux-in-subtree" | **ctrl+c interrupts claude** | that gate does not check *which* pane is active; it forwards to whatever is in the tmux window, incl. claude |
| gate on `_holds_tmux` (tmux anywhere in subtree) | same — interrupts claude | tmux-present ≠ nvim-focused; must detect the *active pane* |
| swap kitten for builtin `copy_to_clipboard` | toast + nvim-visual copy gone | builtin does neither toast nor forward |
| break the active-pane detection (tmux `list-clients`/`list-panes`, or `fd/0` tty read) | nvim-through-tmux copy dies (fails closed) | no confirmed nvim focus → no forward. safe (never interrupts) but copy stops |
| add an app to the allowlist that treats the key as interrupt | that app interrupts on ctrl+c | only add apps that truly *yank* `<C-S-c>` |
| forward the raw `^C` instead of `CSI 99;6u` | shell SIGINTs on ctrl+c | defeats the "ctrl+c is copy-only" design |
| remove `extended-keys on` / kitty extkeys from tmux.conf | forwarded key dies in transit | tmux drops the extended key without the relay |
| remove `set-clipboard on` / clipboard feature | yank never reaches desktop | OSC 52 relay severed |
| source tmux.conf live and assume it took | handshake not re-run | server opts set, but per-client kbd-protocol handshake needs detach+reattach |

## .to allow a new copy-forward receiver

add its `pane_current_command` / foreground comm to `FORWARD_ALLOWLIST` in
`copy_notify.py` — **only** if it yanks `<C-S-c>` rather than interrupts. when in
doubt, leave it out: fail-closed protects the invariant.

## .how to not regress: verify live, both paths

after ANY edit to the kitten, tmux.conf, or the nvim keymaps, prove both copy
paths by hand — they fail independently:

1. **mouse-drag copy** (kitty owns selection): select, `ctrl+c`, paste elsewhere.
2. **nvim visual copy through tmux** (the fragile one): in nvim *inside tmux*,
   visual-select, `ctrl+c`, paste elsewhere.
3. **no phantom interrupt**: in a shell, in claude-cli, and in any other TUI,
   `ctrl+c` / `ctrl+shift+c` must NOT interrupt (interrupt is `ctrl+x` only).
   test claude-cli specifically — it is the app that first exposed this.

if a path breaks, instrument the kitten (append `_focused_app(window)` and
`bool(selection)` to a log under the repo `.temp/`, not `/tmp` — a hook blocks
`/tmp` reads), press once per path, read the log. one press settles whether the
focus was misread (allowlist shut the gate) or the forward fired but died
downstream. diagnose live; never assume.

## .see also

- `define.kitty-tmux-nvim-copy.md` — the full architecture + the two copy paths
- `src/install_env.pt4.terminal.kitty.sh` — `copy_notify.py`, the `map` lines
- `src/tmux.conf` — extended-keys + clipboard relay
- `src/init.lua` — nvim `<C-S-c>` yank keymap + `TextYankPost` toast
- `rule.require.solve-at-cause` — the gate fix uses kitty's own /proc pattern
