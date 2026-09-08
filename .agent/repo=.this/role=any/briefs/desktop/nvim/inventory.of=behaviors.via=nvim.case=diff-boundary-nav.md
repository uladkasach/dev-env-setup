# inventory.of=behaviors.via=nvim.case=diff-boundary-nav

## .what

navigate git chunk boundaries with `ctrl+d` + `j`/`k`, in three input forms — so
the human may hold ctrl, lift it, or hold `d`, and the jump lands either way.

## .the three forms

the same jump is reachable three ways. they differ only in what the fingers do
between emits.

| form | fingers | keystream nvim receives |
|------|---------|-------------------------|
| **1. full chord, ctrl released** | `(ctrl+d, ctrl+j)` → emit, `(ctrl+d, ctrl+j)` → emit, … | `<C-d><C-j>` `<C-d><C-j>` … |
| **2. ctrl held, d+j re-tapped** | `ctrl+( (d,j)→emit, (d,j)→emit, … )` | `<C-d><C-j>` `<C-d><C-j>` … |
| **3. ctrl+d armed, j repeats** | `ctrl+d+( j→emit, j→emit, … )` | `<C-d><C-j>` then `<C-j>` `<C-j>` … |

**forms 1 and 2 are one behavior.** nvim reads keycodes, not finger state — a
ctrl lift between two chords leaves no trace. both arrive as `<C-d><C-j>`, so
both worked from the start.

**form 3 is the added one.** the first `<C-d><C-j>` **arms** a transient state;
each further ctrl-held `j` emits another jump instead of its usual half-page
scroll.

## .behaviors

| given | when | then |
|-------|------|------|
| a buffer with git chunks | `<C-d>j` / `<C-d>k` | jump to next / prev boundary |
| ctrl held throughout | `<C-d><C-j>` (kitty: `<C-d><S-CR>`) | jump to next boundary; **arm** repeat |
| repeat armed, ctrl still held | `<C-j>` (kitty: `<S-CR>`) | jump to next boundary; stay armed |
| repeat armed, ctrl still held | `<C-k>` | jump to prev boundary; stay armed |
| repeat armed | ctrl lifted, plain `j` | `j` moves down one line as always; **disarm** |
| repeat armed | any key outside `{<C-d> <C-j> <C-k> <S-CR>}` | **disarm**, and that key acts as always |
| repeat armed | no key at all, for any duration | **stays armed** — there is no clock |
| repeat armed | `<C-j>` in ANOTHER buffer | half page down — the arm is INERT there |
| repeat disarmed | `<C-j>` / `<S-CR>` / `<C-k>` | half page down / up (the extant bind) |
| a codediff buffer | all of the above | same, against diff highlights rather than gitsigns |

## .why the ctrl lift is detectable

the disarm-on-ctrl-lift is not a guess about finger state — it falls out of the
keycodes:

- ctrl **held** + `j` → `<C-j>`, which kitty rewrites to `<S-CR>`
- ctrl **lifted** + `j` → plain `j`

plain `j` is never rebound, so a ctrl lift restores normal motion with no code
at all. only the ctrl-held forms are transiently re-pointed.

## .boundaries

what this deliberately does NOT do:

- 🛑 **a ctrl RELEASE is unreachable, and NVIM is what drops it — not tmux.**
  measured 2026-09-06 (`howdoes.a-key-event-reaches-nvim`): tmux relays
  `CSI 57442;1:3u` byte for byte, nvim decodes that key's PRESS to `U+E062`, and
  nvim yields **no key at all** for any `:3u`. so the arm cannot end on the lift.
  `d` **taps to arm**; a key outside the vocabulary ends it. under the fingers
  this is indistinguishable
- **a bare `j` never repeats a jump.** `<C-d> j j j` moves one boundary, then
  two lines down. the repeat rides the ctrl-held key only — that is what makes
  the ctrl lift a clean disarm
- **while armed, `<C-j>` does not scroll.** the half-page scroll is LENT to the
  repeat, and any key outside the vocabulary returns it

- **the buffer test SCOPES the arm; it never CANCELS it.** `boundary_repeat_armed`
  asks *"am i in the buffer that armed this?"*, so the arm is inert elsewhere — and
  a move that costs a keystroke (`<C-w>w`, `:e`) disarms via the vocabulary anyway
  📜 measured 2026-09-06: this row read *"move to another buffer → disarm"* until a
  probe walked away and back in one pass — `100 → 102`, the jump, not a scroll. the
  word `disarm` claimed a cancellation the buffer test never performs

- 🛑 **there is NO clock.** a `1500ms` idle timeout stood here until 2026-09-06 and
  is gone. it was a proxy for *"did the hold end?"*, and a proxy is what a wall-clock
  guess buys you. the vocabulary is the deterministic answer to the same question
  📜 the retired timer produced two wrong verdicts of its own: it let a stray `w`
  keep the arm live, and it killed a live hold that merely paused

- ⚠️ **the residual ambiguity, named.** these two produce an IDENTICAL keystream, so
  no nvim-side code can tell them apart:
  ```
  ctrl↓ d j j j ctrl↑        →  <C-d> <C-j> <C-j> <C-j>
  ctrl↓ d ctrl↑ … ctrl↓ j    →  <C-d> <C-j>
  ```
  ⇒ so a re-held ctrl+j, with NO key struck in between, still jumps. to close this
  needs the bare-ctrl PRESS (`U+E062`), which needs kitty flag 8, which tmux 3.4
  refuses to negotiate — see `howdoes.a-key-event-reaches-nvim`

## .lives in

every site below is in `src/grove.provision/4.terminal/4.5.nvim/init.lua`, except the last.

⚠️ the line numbers are a CONVENIENCE and they rot — they already did once, when the
4.5.nvim bundle gained ~150 lines above this code. cite the NAME; use the number as a hint,
and re-grep if it misses.

| piece | site |
|-------|------|
| repeat arm | `:489` `boundary_repeat_arm` / `:497` `boundary_repeat_armed` |
| boundary walk | `:503` `navigate_diff_boundary` |
| gitsigns chunk source | `:917` `boundary_down` / `:922` `boundary_up` (+ `:930` the `_arm` pair) |
| codediff chunk source | `:1803` `boundary_down` / `:1808` `boundary_up` (buffer-local) |
| the scroll binds, arm-aware | `:2307` `half_page` |
| kitty `ctrl+j` rewrite | `src/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/kitty.conf:217` |

## .verified — 2026-09-06, against a HERMETIC fixture

⚠️ the fixture is the load-bear half. a probe pointed at this repo's own tree measures
whatever today happens to be dirty — and on the first attempt that tree carried **zero**
chunks, so the probe measured no world at all. it said so, rather than pass.

so the fixture is built inside the probe: 400 lines committed clean, then edits at three
DECLARED places, and the probe prints the chunks it found beside the chunks it expects.

```
fixture chunks: 3  [100..102, 200..200, 300..305]
expected:       3  [100..102, 200..200, 300..305]
```

| case | keys | cursor | verdict |
|------|------|--------|---------|
| form 3 repeat | `<C-d><C-j>` `<C-j>` `<C-j>` | 1 → 100 → 102 → 200 | three boundary jumps, one `d` tap |
| disarm on ctrl lift | `<C-d><C-j>` then plain `j` | 100 → 101 | normal one-line motion |
| **disarm on a stray key** | `<C-d><C-j>`, then `w`, then `<C-j>` | **100 → 111** | **half page — `w` ended the arm** |
| **NO clock** | `<C-d><C-j>`, wait 2500ms, `<C-j>` | **100 → 102** | **the jump — the arm outlives any wait** |
| inert in another buffer | armed, then `<C-j>` in a NEW buffer | 1 → 12 | half page |
| scroll when disarmed | `<C-j>` on a plain buffer | 1 → 12 | half page down |

⚠️ rows 3 and 4 are a MATCHED PAIR, and they are the whole point. the retired timer got
**both** wrong, in opposite directions: it let the stray `w` keep the arm live, and it
killed an arm that merely paused.

## ✔ .the clamp BITES — proven both directions

green proves the property holds; it proves no part of whether the arm can SEE the property
absent (`rule.require.clamp-edge-cases`). so the vocabulary walk was neutered in a copy of
`init.lua` and the same probe re-run:

```
disarm LIVE      →  100 -> 111   (delta 11, a half page)
disarm NEUTERED  →  100 -> 102   (delta  2, the boundary jump)
```

⇒ row 3 reddens with the property absent. it tests what it names.

## 📜 .the two draft defects this round, both caught by a setup guard

| draft | what it would have reported |
|---|---|
| `nvim_feedkeys(…, 'x')` — no `t` flag | on_key gets `typed=''`, so the watch sees no key. **the disarm was unmeasurable**, and its absence read as a code defect |
| the watch fell back to `key` when `typed` was empty | a Lua keymap makes on_key report `key = 80 fd 67` (**K_LUA**), never the struck key — so it disarmed on every mapped key and broke the very repeat it serves |

⇒ the second is the sharper one: the "more robust" fallback WAS the defect, and it was
introduced by the repair for the first. `gotcha.a-check-that-cries-wolf-gets-silenced` m.10 —
a correction that reproduces the defect it records.

## .verify

ask nvim what it resolved — never trust a read of the config:

```sh
nvim --headless -u src/grove.provision/4.terminal/4.5.nvim/init.lua -c 'lua for _,k in ipairs({"<C-D><C-J>","<C-D><S-CR>","<C-D>j","<C-D><C-K>","<S-CR>","<C-J>"}) do local m=vim.fn.maparg(k,"n",false,true); print(k.." -> "..((m and (m.desc or m.rhs)) or "UNMAPPED")) end' -c 'qa'
```

⚠️ that reads the MAP TABLE, so it proves each key resolves and says none of what the arm
does. the behavior needs the hermetic probe above — a fixture with known chunks, keys fed,
cursor read.

## .see also

- `diff-boundary-nav.md` — why boundary nav beats chunk-to-chunk
- `gotcha.kitty-rewrites-ctrl-j.md` — why every ctrl+j bind needs an `<S-CR>` twin
- `rule.require.crystallize-behaviors.md` — the rule this file demonstrates
