# gotcha: tmux carries no SUPER modifier, so a super key dies at the duct

## .what

tmux's key model holds exactly three modifiers:

| tmux prefix | modifier |
|---|---|
| `C-` | ctrl |
| `M-` | meta / alt |
| `S-` | shift |

**there is no super / cmd / windows modifier — in any version.** so any key that
carries super reaches an app inside tmux with that modifier gone.

⚠️ and it does not arrive as "the key, minus super". the whole modifier set is
discarded: `ctrl+super+r` reaches nvim as a **bare `r`**.

## .why that last part is the dangerous half

a key that vanishes is a nuisance. a key that arrives as a DIFFERENT key is a
defect, because the receiver acts on it:

- `r` in nvim NORMAL mode is the **replace-char operator**
- so `ctrl+super+r` inside a duct leaves nvim one keystroke from a stray edit,
  in a buffer the human believes they only copied a path from

⇒ the symptom a human reports is *"the key does not work"*. the truth is
*"the key does something else"*.

## .the measurement — 2026-09-03, a cloud duct, tmux 3.2a + nvim 0.12.3

two independent reads, one synthetic and one with a human's finger:

| how the key was delivered | what nvim received |
|---|---|
| `CSI 114;13u` fed to a real tmux client | `r` `[72]` |
| a human pressed `ctrl+super+r` over ssh | `r` `[72]` |

and the control, in the same run:

| key | mods param | crossed tmux? |
|---|---|---|
| `ctrl+shift+c` → `CSI 99;6u` | 6 | ✔ arrived as `<C-S-C>` |
| `ctrl+super+r` → `CSI 114;13u` | **13** | ✋ arrived as `r` |

the kitty-protocol modifier param is `1 + bitmask`, with shift=1, alt=2, ctrl=4,
**super=8**. so params 1..8 are the combinations tmux understands, and anything
with the super bit set lands at 9..16 — outside it.

⇒ **this is the super BIT, never CSI-u as such.** a check that concluded "tmux
drops extended keys" would be wrong, and would send the next traveler to fix a
relay that already works.

## 🛑 .no tmux option and no tmux upgrade fixes this

the tempting search result is `extended-keys-format csi-u` (tmux ≥ 3.5). it does
not apply:

- it changes the form tmux **emits** to an app; it hands tmux no super to emit
- a `bind` cannot reach it either — by the time any bind could match, tmux has
  already discarded a modifier it never parsed

⇒ so the fix must sit **upstream of tmux**, at the last layer that can still see
super. in this repo that is kitty (`rule.require.solve-at-cause`).

## .the fix — kitty rewrites the key before it enters the pipe

```
map ctrl+super+r send_key ctrl+alt+r
```

`ctrl+alt+r` is `C-` + `M-`, both of which tmux carries, so it crosses intact.

⚠️ **`send_key`, never `send_text`.** the kitty keyboard protocol is negotiated
per APP, so ctrl+alt+r has no single wire form: nvim gets CSI-u, a shell gets the
legacy form. `send_key` re-encodes per receiver; `send_text` writes one fixed
byte string, which would be right for nvim and literal garbage at a prompt.

`send_key` needs kitty ≥ 0.33; this repo pins 0.47.4.

## .the general rule

> **a key that carries SUPER cannot be delivered through tmux. if a duct must
> receive it, rewrite it upstream into a `ctrl`/`alt`/`shift` key.**

this bounds every future keymap: a super binding is a LOCAL-only key unless
kitty translates it.

## 🛑 .the instrument trap — `vim.on_key` cannot see a MAPPED key

this took two failed probes, and the shape generalizes past nvim.

`vim.on_key(fn)` calls `fn(key, typed)`. **the first argument is the key AFTER
mappings are applied.** a key bound to a lua callback produces an empty `key`, so
a reader that logs only argument 1 reports the mapped key as ABSENT.

the probes here filtered `k == ''` as noise, so:

- `<C-S-c>` — UNMAPPED in normal mode → logged ✔
- `<C-r>`, `<C-A-r>` — MAPPED to `copy_relpath` → logged as absent ✋ **false**
- `ctrl+super+r` — arrives as bare `r`, unmapped → logged ✔

⇒ the reader was structurally blind to **exactly the keys under test**, and its
one green row came from the only key nobody had mapped.

### and the noise filter hid it

nvim emits `K_EVENT` (`80 fd 67`, rendered `<t_g>`) to drive its own event loop,
dozens of times per second at idle. the first probe logged it as if it were the
key — so three different inputs read as one result, and a plain legacy `0x12`
reported a value it could not possibly have produced.

the second probe filtered that noise **and the signal with it**, because both
render as an absent entry.

⇒ two lessons, and the second is the durable one:

1. read `typed` (argument 2), never `key`, when the question is *what arrived*
2. **a filter tuned to remove noise can remove the signal, and the result reads
   identical to a clean negative.** so a filter needs its own control arm — a
   case known to produce output, that must survive the filter

## .the test, for any "this key does not work" report

1. **name the modifiers** — does any of them fall outside `C-`/`M-`/`S-`? if so,
   stop: tmux is the wall, and no config crosses it
2. **read what ARRIVED, not what failed** — a key that silently becomes another
   key is the expensive case, and only a byte-level read separates them
3. **check your reader against a MAPPED key and an UNMAPPED one** — a reader
   that can only see one of the two will confidently report the wrong link

## .see also

- `define.kitty-tmux-nvim-copy` — the full kitty → ssh → tmux → nvim architecture
- `kitty.hazard.copy-forward-regressions` — the sibling hazard on the same chain
- `gotcha.a-check-that-cries-wolf-gets-silenced` — q1 (evidence must agree with
  the verdict) is what caught both failed probes here
- `rule.require.solve-at-cause` — why the rewrite belongs in kitty, not tmux
- `src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/kitty.conf` — the map,
  with this measurement inline
- tmux/tmux wiki, "Modifier Keys" — the authority for the three-modifier claim
