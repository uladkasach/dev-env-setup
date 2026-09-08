# gotcha: kitty rewrites ctrl+j, so nvim never sees it

## .what

kitty rewrites `ctrl+j` into `shift+enter` **before any app sees it**:

```
src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/kitty.conf:217
map ctrl+j send_key shift+enter
```

so inside kitty, a bare `ctrl+j` reaches nvim as `<S-CR>` — never as `<C-j>`.

`<S-CR>` is nvim's notation for shift+enter (`S-` = shift, `CR` = carriage return).

## .the consequence

**any nvim bind that wants ctrl+j must be declared twice**, once per arrival form:

| bind | fires when |
|------|-----------|
| `<C-j>` | terminals that pass ctrl+j through untouched |
| `<S-CR>` | kitty — the one that actually fires on this machine |

a single `<C-j>` bind looks correct, tests fine outside kitty, and is **silently dead** in the
daily terminal. that is the whole hazard.

`ctrl+k` is untouched by kitty, so it needs no twin. only ctrl+j is rewritten.

## .why `<C-j>` alone cannot be made to work

`<C-j>` keytrans to `<NL>` (byte 0x0a). the rewritten key arrives as `<S-CR>`, a **distinct
keycode** under the kitty keyboard protocol (nvim 0.10+). they are not two spellings of one input —
they are two different keys as far as nvim is concerned. no `keytrans` or `nowait` option collapses
them; the second bind is mandatory, not belt-and-braces.

## .the live sites

three binds in `src/grove.provision/4.terminal/4.5.nvim/init.lua` depend on this, all normal mode:

| site | bind | action |
|------|------|--------|
| scroll | `<C-j>` + `<S-CR>` | half page down (`<C-d>zz`) |
| gitsigns diff nav | `<C-d><C-j>` + `<C-d><S-CR>` | next diff boundary |
| codediff diff nav | `<C-d><C-j>` + `<C-d><S-CR>` | next diff boundary (buffer-local) |

the two diff-nav sites exist because with **ctrl held down** through `ctrl+d ctrl+j`, the second
keypress is still rewritten — so the chord arrives as `<C-d><S-CR>`.

## .the collision that is not a collision

`<S-CR>` now carries two live senses: standalone it scrolls, after `<C-d>` it jumps a diff
boundary. these do **not** conflict — nvim resolves the `<C-d>` prefix as its own map before the
standalone key is considered. confirmed headless:

```
<C-D>j       -> Next diff boundary
<C-D><C-J>   -> Next diff boundary
<C-D><S-CR>  -> Next diff boundary
<C-J>        -> <C-d>zz  noremap=1
<S-CR>       -> <C-d>zz  noremap=1
```

## .how to verify a bind actually fires

do not trust a read of the config. ask nvim what it resolved:

```sh
nvim --headless -u src/grove.provision/4.terminal/4.5.nvim/init.lua \
  -c 'lua local m=vim.fn.maparg("<S-CR>","n",false,true); print(m.rhs or "UNMAPPED")' \
  -c 'qa'
```

note the uppercase form — `maparg` wants `<C-J>`, not `<C-j>`.

## .the tradeoff this buys

shift+enter is spent in nvim normal mode. that is the price of home-row ctrl+j, and it was accepted
knowingly — the kitty rewrite exists so apps that treat shift+enter specially (newline vs submit)
can be driven from ctrl+j.

## .see also

- `src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/kitty.conf` — the rewrite itself, with its rationale
- `.agent/repo=.this/role=any/briefs/desktop/nvim/diff-boundary-nav.md` — the diff-nav consumer
- `.agent/repo=.this/role=any/briefs/shell/pref.shell-keybinds.md` — the keybind preferences
