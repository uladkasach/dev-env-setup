# gotcha: kitty rewrites ctrl+j, and tmux then flattens it to a bare `<CR>`

## .what

kitty rewrites `ctrl+j` into `shift+enter` **before any app sees it**:

```
src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/kitty.conf:217
map ctrl+j send_key shift+enter
```

what nvim then receives depends on **whether tmux is in the path**:

| path | ctrl+j arrives as | bytes |
|---|---|---|
| a bare terminal, no rewrite | `<C-j>` | `0a` |
| kitty → nvim | `<S-CR>` | `80 fc 02 0d` |
| 🔴 **kitty → tmux → nvim** — the daily path | **`<CR>`** | `0d` |

⇒ **through tmux, ctrl+j is indistinguishable from Enter.** shift+enter has no distinct legacy
byte sequence, and tmux never negotiated the enhanced keyboard protocol
(`howdoes.a-key-event-reaches-nvim`, wall 1), so the key degrades to `\r`.

## .the consequence

**any nvim bind that wants ctrl+j must be declared THREE times**, once per arrival form:

| bind | fires when |
|---|---|
| `<C-j>` | a terminal that passes ctrl+j through untouched |
| `<S-CR>` | kitty, with no multiplexer |
| 🔴 `<CR>` | kitty through tmux — **the one that actually fires daily** |

a bind that declares only `<C-j>` looks correct, tests fine outside kitty, and is silently
dead. a bind that declares `<C-j>` + `<S-CR>` looks thorough, passes a headless check, and is
**still** silently dead in the daily terminal. that is the whole hazard.

`ctrl+k` is untouched by kitty, so it needs no twin. only ctrl+j is rewritten.

## 📜 .measured 2026-09-16 — live kitty → tmux → nvim, via a key logger

the three diff-boundary input forms, as bytes:

```
form 1  (ctrl lifted between):  04  0d  04  0d
form 2  (ctrl held, d+j):       04  0d  04  0d      — byte-identical to form 1
form 3  (ctrl held, j repeats): 04  0d  0d  0d  0d
```

no `0a` and no `80 fc 02 0d` appears anywhere. **every `<S-CR>` bind was unreachable**, and
had been since tmux entered the path.

## 🛑 .the false ✔ this brief itself carried

a prior draft closed with a verification block headed *"confirmed headless"*:

```
<C-D><S-CR>  -> Next diff boundary
<S-CR>       -> <C-d>zz  noremap=1
```

every line of it was true, and it was evidence for a claim it could not reach.

> **headless nvim has no kitty and no tmux.** `maparg` reports what nvim RESOLVED, which is a
> fact about the map table — never about which bytes arrive.

⇒ the config was correct the whole time. the chain was the broken link, and the check was
pointed at the half that worked. a `cmp` of the live file, a `:verbose map`, and a `timeoutlen`
read share the defect: each reports on **nvim's side of the wire**.

## .how to verify a bind actually fires

🛑 **do not reach for a headless `maparg`.** it answers a different question, in a shape that
reads like an answer to this one.

put a key logger in front of the chain and press the physical key:
`howto.probe-the-key-chain-with-a-live-logger`.

`maparg` still has one honest use — **after** the probe names the bytes, ask nvim whether that
form is bound:

```sh
nvim --headless -u src/grove.provision/4.terminal/4.5.nvim/init.lua \
  -c 'lua local m=vim.fn.maparg("<C-D><CR>","n",false,true); print((m and (m.desc or m.rhs)) or "UNMAPPED")' \
  -c 'qa'
```

note the uppercase form — `maparg` wants `<C-J>`, not `<C-j>`.

## .the live sites

in `src/grove.provision/4.terminal/4.5.nvim/init.lua`, all normal mode:

| site | binds | action |
|---|---|---|
| scroll | `<C-j>` + `<S-CR>` | half page down (`<C-d>zz`) |
| gitsigns diff nav | `<C-d><C-j>` + `<C-d><S-CR>` + `<C-d><CR>` | next diff boundary |
| codediff diff nav | same three, buffer-local | next diff boundary |
| repeat vocabulary | `<C-d>` `<C-j>` `<C-k>` `<S-CR>` `<CR>` | keeps a ctrl-held repeat armed |

⚠️ the scroll row carries **no `<CR>` twin, deliberately.** a bare Enter must keep its default
sense — a next-line motion, a quickfix jump, a prompt submit. so `<CR>` diverts **only while a
boundary repeat is armed**, and hands the key back otherwise. see the `<CR>` map's own 🛑 block.

## 🛑 .a map whose job is to MOVE may never be `expr`

📜 measured 2026-09-16, and it cost a round. the `<CR>` map was first written as an `expr` map
that returned `<CR>` when unarmed — tidy, and wrong: an `expr` map evaluates under a
**textlock**, so it may not move the cursor, change a buffer, or jump a window.

the armed branch is a cursor jump. it **died silently on every repeat** while the first jump
(from the ordinary `<C-d><CR>` map) worked — which reads exactly like a disarm and is not one.

⇒ use an ordinary function map, and feed the default key back with
`nvim_feedkeys(vim.keycode('<CR>'), 'n', false)` for the fallthrough.

## .the tradeoff this buys

shift+enter is spent in nvim normal mode. that is the price of home-row ctrl+j, and it was
accepted knowingly — the kitty rewrite exists so apps that treat shift+enter specially
(newline vs submit) can be driven from ctrl+j.

⚠️ under tmux that tradeoff buys **less than it was sold for**: the rewrite converts a
perfectly distinct `0a` into an ambiguous `0d`, so the app on the far side cannot tell ctrl+j
from Enter either. the rewrite earns its keep only where kitty talks to the app directly.

## .see also

- `howto.probe-the-key-chain-with-a-live-logger` — the only instrument that reads this
- `howdoes.a-key-event-reaches-nvim` — the chain, and the two measured walls
- `src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/kitty.conf` — the rewrite itself
- `desktop/nvim/inventory.of=behaviors.via=nvim.case=diff-boundary-nav.md` — the diff-nav consumer
- `shell/pref.shell-keybinds.md` — the keybind preferences
