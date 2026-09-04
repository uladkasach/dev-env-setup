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
4. the forward is gated **twice, by whoever can see the answer**:
   - **kitty**, for a LOCAL duct — an allowlist (`FORWARD_ALLOWLIST = {'nvim'}`)
     on the active tmux pane's `#{pane_current_command}`, else the window's
     foreground process. fails closed.
   - **tmux**, for BOTH — `bind -n C-S-c if -F '#{m:*nvim*,...}' 'send-keys C-S-c'`
     in `src/tmux.conf`. it runs ON the host that holds nvim, so its read is a
     fact rather than an inference.
5. nvim maps `<C-S-c> → "+y`; tmux relays `extended-keys` + `set-clipboard`.

## 🛑 .why the kitty gate is DELIBERATELY open over ssh

over a remote duct this box holds only the ssh client, so every local reader
answers `ssh`. so the kitty allowlist **cannot** confirm nvim, and it correctly
refused — which made a visual-mode `ctrl+c` a silent no-op on every grove.

⚠️ it read as healthy, and that is the shape to remember: kitty's own
mouse-drag copy still fired and still toasted, so **one live path masked one
dead path**. the two paths fail independently and only one of them is loud.

⇒ so the kitten forwards past its allowlist **when it sees an `ssh` in the
window's subtree**, and the far tmux decides. the invariant survives because
the forward is `CSI 99;6u`, never `^C` — the worst a wrong receiver gets is an
inert escape at a prompt, never a signal.

🛑 **do not "harden" this back to allowlist-only.** that restores a defect the
kitten cannot detect: it would go green on every check and stay dead on every
grove.

⚠️ the one loose end: a far host with **no tmux at all** (a bare `ssh`, never a
duct) gets the escape with no gate. inert, and out of scope — a duct IS tmux.

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
| drop `bind -n C-S-c` from tmux.conf | **copy dies everywhere, local included** | it is now the gate for both ducts; the kitten defers to it |
| keep the bind, drop its re-emit | copy dies everywhere | a root bind SWALLOWS the key for every app; the re-emit is what hands it to nvim |
| change the re-emit to `send-keys C-S-c` | copy dies everywhere, and every OTHER link stays green | tmux 3.2a cannot ENCODE an extended key into a pane. measured 2026-09-03: bind fired ✔, condition matched ✔, nvim saw no key — on a minimal AND the real init, so it is the encode, never nvim. use `send-keys -H 1b 5b 39 39 3b 36 75` |
| narrow the kitten back to allowlist-only | remote copy dies, silently | over ssh every local reader answers `ssh`; that is the defect this replaced |
| bind `-n C-c` in tmux instead of `C-S-c` | **every interrupt in the session dies** | a root bind eats the key; `extended-keys` is what keeps the two distinct |
| drop `map ctrl+super+r send_key ctrl+alt+r` from kitty.conf | ctrl+super+r reaches nvim as a bare `r` — the REPLACE operator, one keystroke from a stray edit | tmux carries no super modifier, in any version, so the rewrite must happen upstream in kitty (`gotcha.tmux-carries-no-super-modifier`) |
| change that map to `send_text` | right for nvim, literal garbage at a shell | the kitty protocol is negotiated per APP, so ctrl+alt+r has no single wire form; only `send_key` re-encodes per receiver |
| bind a NEW key that carries SUPER, for use inside a duct | it arrives as its bare base key, and the receiver acts on it | super is local-only unless kitty translates it first |

## .to allow a new copy-forward receiver

add its `pane_current_command` / foreground comm to `FORWARD_ALLOWLIST` in
`copy_notify.py` — **only** if it yanks `<C-S-c>` rather than interrupts. when in
doubt, leave it out: fail-closed protects the invariant.

## .how to not regress: verify live, both paths

after ANY edit to the kitten, tmux.conf, or the nvim keymaps, prove both copy
paths by hand — they fail independently:

1. **mouse-drag copy** (kitty owns selection): select, `ctrl+c`, paste elsewhere.
2. **nvim visual copy through a LOCAL tmux** (the fragile one): in nvim *inside
   tmux*, visual-select, `ctrl+c`, paste elsewhere.
3. **nvim visual copy through a REMOTE duct** — the same, in an ssh'd duct. this
   path has its OWN gate (tmux's), so path 2 green says none about it.
4. **no phantom interrupt**: in a shell, in claude-cli, and in any other TUI,
   `ctrl+c` / `ctrl+shift+c` must NOT interrupt (interrupt is `ctrl+x` only).
   test claude-cli specifically — it is the app that first exposed this.

if a path breaks, instrument the kitten (append `_focused_app(window)` and
`bool(selection)` to a log under the repo `.temp/`, not `/tmp` — a hook blocks
`/tmp` reads), press once per path, read the log. one press settles whether the
focus was misread (allowlist shut the gate) or the forward fired but died
downstream. diagnose live; never assume.

## .see also

- `define.kitty-tmux-nvim-copy.md` — the full architecture + the two copy paths
- `src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/configure.upsert.sh` —
  `copy_notify.py`, the `map` lines
- `src/tmux.conf` — extended-keys + clipboard relay
- `src/init.lua` — nvim `<C-S-c>` yank keymap + `TextYankPost` toast
- `rule.require.solve-at-cause` — the gate fix uses kitty's own /proc pattern