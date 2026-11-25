# rule.require.ctrl-enter-interrupts

## .what

**in claude, enter never waits on a tool, and ctrl+enter cuts the turn — in every window:
plain kitty, kitty → tmux, and kitty → ssh → a grove's tmux.**

| key | action | while claude works |
|---|---|---|
| enter | `chat:sendNow` | a live tool moves to the background and keeps its work; the message reaches claude in the same turn. idle: it submits |
| ctrl+enter | `chat:cancel` (the esc action) | the turn stops — a reply, a Stop hook, a step that cannot move to the background — and what is queued goes out |
| ctrl+x ctrl+s | unbound | claude's default send-now chord; kitty maps ctrl+x to `^C`, so it cannot be typed here |

📜 measured 2026-11-24 on claude-code 2.1.330, via `rhx term.keys.probe`: enter mid-tool moved a
90s loop to the background and claude answered at once; ctrl+enter mid-reply printed
`Interrupted`. from 2.1.281 the default send-now backgrounds a tool rather than stop the turn,
which made a long turn impossible to cut without esc — the reason ctrl+enter is the interrupt.

## .why it breaks by default

claude reads ctrl+enter only when the key arrives with its modifier. two facts cut it:

| link | fact | measured |
|---|---|---|
| kitty | ignores modifyOtherKeys, the mode an app inside tmux falls back to; ctrl+enter leaves as a bare `^M` | 2026-10-04: a byte logger that asked for mode 2 read `^M` for ctrl+enter, in tmux AND out |
| tmux 3.4 | cannot speak kitty's keyboard protocol, so an app inside it never gets kitty's own encode | the same logger, inside tmux |
| claude | its hint shows `ctrl+x ctrl+s` whenever `$TMUX` is set, whatever the keyboard can do (`Voe()`/`HAt()` in the cli) | `rhx brains.claude.strings --pattern 'chat:sendNow'` |

⇒ and on this repo's kitty the chord is untypeable: kitty maps `ctrl+x` to `^C`, so the hint
advertised a key that interrupts the turn the wrong way.

## .the three parts that hold it — each in the bundle that owns its file

| part | where | what it does |
|---|---|---|
| the marker | `2.8.tmux/tmux.conf` hooks | attach sets the kitty user var `in_tmux`, detach clears it — written to the CLIENT tty, so it crosses ssh too |
| the encode | `4.3.2.emulator/kitty.conf` | `map --when-focus-on var:in_tmux ctrl+enter send_text all \x1b[13;5u` — tmux parses it as C-Enter and relays it |
| the binds | `5.3.brains` → `~/.claude/keybindings.json` | Chat block: `"enter": "chat:sendNow"`, `"ctrl+enter": "chat:cancel"`, `"ctrl+x ctrl+s": null` |

measured after all three: inside tmux, ctrl+enter arrived as `^[[13;5u` while enter,
shift+enter, and ctrl+j stayed `^M`; a live claude in tmux backgrounded a tool on enter and
interrupted on ctrl+enter.

⚠️ an enrolled clone reads `keybindings.json` from its actor dir (`CLAUDE_CONFIG_DIR`), which
rhachet does not yet link to `~/.claude/` (rhachet #579), so a clone keeps claude's default keys.

## 🛑 .the moves that look right and are not

| move | why it fails |
|---|---|
| hide `$TMUX` from claude in the `claude()` wrapper | claude reads `$TMUX` in a dozen places — DCS passthrough for terminal queries, sync output, truecolor clamp, mouse hints, agent-team panes. it fixes one hint and silently breaks those |
| `map --when-focus-on cmdline:tmux …` | `cmdline` matches the command the kitty window LAUNCHED (the shell), never the tmux in front of it. measured: the map never fired |
| `send_key ctrl+enter` instead of `send_text` | send_key re-encodes for the app kitty sees — tmux, in legacy mode — which yields the very `^M` the map exists to avoid |
| a `client-attached` hook alone | `new-session` attaches without it and fires `client-session-changed`. measured: the var stayed unset |
| `extended-keys always` / `extended-keys-format csi-u` in tmux | they change what tmux EMITS. the modifier died in kitty before tmux read a byte |
| `~/.claude/keybindings.json` alone | an ENROLLED clone reads `$CLAUDE_CONFIG_DIR/keybindings.json` — the actor dir — so the hint stays wrong there until rhachet links the file in |

## .how to re-prove it

`howto.probe-the-key-chain-with-a-live-logger` — a logger that sends `\033[>4;2m` (the ask
claude makes) and prints each byte, opened in a real kitty window, inside and outside tmux, with
a human's finger on the key. `kitty @ --to <socket> ls` shows `user_vars.in_tmux` when the marker
is the link in doubt — no keypress needed for that one.

## .enforcement

- a tmux window where ctrl+enter reaches an app as `^M` = **blocker**
- a claude hint inside tmux that names `ctrl+x ctrl+s` = **blocker**
- any of the moves in the table above, proposed as the fix = **blocker**

## .see also

- `howto.probe-the-key-chain-with-a-live-logger` — the instrument that measured every row here
- `gotcha.tmux-carries-no-super-modifier` — the same kitty → tmux modifier loss, for super
- `gotcha.kitty-rewrites-ctrl-j` — kitty's other enter-key rewrite
- `define.claude-code-config` — which file claude reads, and why an enrolled clone reads another
