# domain.term: chunk

term.chosen   = chunk
term.kind     = noun
term.synonyms.forbidden:
- hunk (except at the gitsigns call site — see below)
- block
- region
- diff section

## .what

a **contiguous span of changed lines**, held as `{ start, fin }` — the first and last line of the
run. two [diff boundaries](term=diff-boundary._.choice._.md) per chunk.

this repo's canonical word for the span, whatever the source that reported it.

## .why not `hunk`

`hunk` is **git's word, and gitsigns' word** — not ours. it is forbidden in repo-internal code for
one reason: this repo derives chunks from **two** sources, and only one of them speaks `hunk`.

| source | vendor word | how we get chunks |
|--------|-------------|-------------------|
| gitsigns (normal buffers) | `hunk` | `get_gitsigns_chunks()` — casts `gs.get_hunks()` |
| vim diff highlights (codediff buffers) | *(no word — `diff_hlID()` returns highlights)* | `get_diff_hl_chunks()` — derives runs from hl ids |

`navigate_diff_boundary` consumes both through one shape. if the internal word were `hunk`, the
codediff path would carry gitsigns vocabulary for data gitsigns never produced. `chunk` is the
neutral word that both sources cast into.

## .the one legal use of `hunk`

`hunk` is correct **only where gitsigns is addressed directly** — the vendor's api keeps its own
name:

```lua
-- get chunks from gitsigns hunks
local hunks = gs.get_hunks()      -- vendor word, at the vendor boundary
...
gs.next_hunk({ navigation_message = false })   -- vendor word, vendor call
```

this is the declastruct cast-at-the-boundary discipline applied to vocabulary: speak the vendor's
word at the vendor's door, ours everywhere inside.

## .refs

**the contract:**

- `src/init.lua` → `navigate_diff_boundary` — consumes `get_chunks()`, which yields `{ start, fin }[]`
- `src/init.lua` → `get_gitsigns_chunks()` — the gitsigns cast
- `src/init.lua` → `get_diff_hl_chunks()` — the diff-highlight derivation
- runtime echo: `print('chunk ' .. i .. ' bot')` — the word the human reads

**the briefs:**

- `.agent/repo=.this/role=any/briefs/desktop/nvim/diff-boundary-nav.md` — `[{start, fin}, ...]` contract + both
  chunk detection methods

## .reason

see the ref-level file beside this choice:

- `term=chunk._.choice.reason.md` — etymology, evidence, why each synonym is forbidden
