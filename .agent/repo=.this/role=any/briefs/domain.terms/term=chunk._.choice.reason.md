# domain.term: chunk — the reason

## .etymology

**chunk** — english, c. 1690, likely a variant of *chuck* ("a lump, a block of wood"). the sense is
**a solid piece cut from a larger whole**. neutral as to what the whole is, and neutral as to who
cut it.

**hunk** — english, c. 1810, from dutch *homp* ("a lump, a hunch of bread"). near-identical in
literal sense — which is exactly why the choice between them cannot rest on meaning. it rests on
**provenance**.

`hunk` arrived in software through unix `diff` and was fixed as vocabulary by the unified diff
format (`@@ -a,b +c,d @@` blocks are "hunks" in git's own docs). the word therefore *carries git
with it*. `chunk` does not — it stays neutral, which is what a term must be when it must describe
data from a non-git source too.

## .the evidence — two sources, one shape

the decisive fact is that this repo derives chunks from **two** producers, and they were verified
directly in `src/init.lua`:

| producer | call site | vendor vocabulary |
|----------|-----------|-------------------|
| gitsigns | `get_gitsigns_chunks()` → `gs.get_hunks()` | says `hunk` |
| vim diff highlights | `get_diff_hl_chunks()` → `diff_hlID()` per line | no word — returns highlight ids |

both cast into the same shape, which is the actual contract:

```lua
{ start = <first line>, fin = <last line> }
```

`navigate_diff_boundary(direction, get_chunks, fallback)` accepts either producer through that
shape. it never learns which one it got. a shared consumer with a source-agnostic contract cannot
carry one source's vocabulary — so the internal word had to be the neutral one.

**had `hunk` won:** `get_diff_hl_hunks()` would name gitsigns data that gitsigns never produced,
and the reader would go hunt a git hunk that is absent from a codediff buffer.

## .the count that settles it empirically

a scan of `src/init.lua` for both words:

- `chunk` — 30+ uses, **all** in repo-declared code: locals, params, the `{start, fin}` shape, the
  `print('chunk N bot')` echoes
- `hunk` — appears **only** where gitsigns is addressed: `gs.get_hunks()`, `gs.next_hunk()`,
  `gs.prev_hunk()`, and the comment that documents the cast

that distribution is not drift. it is a **clean boundary**, and it was already correct before this
term was itemized. the itemization records the discipline rather than imposes it.

## .why each synonym is forbidden

| forbidden | why |
|-----------|-----|
| `hunk` (internally) | carries git provenance into code that also serves a non-git source. legal only at the gitsigns call site |
| `block` | catastrophically overloaded in this repo — lua blocks, config blocks, `do...end`, code paragraphs |
| `region` | vim already owns this word for visual/selection regions (`:h v_`), a different concept in the same editor |
| `diff section` | compound and vague; "section" implies authored structure, but a chunk is computed |

## .disputes

none open.

## .sources

- [etymonline: chunk](https://www.etymonline.com/word/chunk) — variant of *chuck*, "a lump"
- [etymonline: hunk](https://www.etymonline.com/word/hunk) — from dutch *homp*
- [git diff docs — unified format "hunks"](https://git-scm.com/docs/git-diff) — where `hunk` became
  software vocabulary
- `src/init.lua` — the two producers and the shared `{start, fin}` contract
