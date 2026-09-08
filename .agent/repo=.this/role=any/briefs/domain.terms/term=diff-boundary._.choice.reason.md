# domain.term.choice.reason: diff boundary

## .etymology

**boundary** — from middle english *bounde* (a limit, a landmark), via old french *bodne*, from
medieval latin *bodina* (a boundary marker). the root sense is **a marker you arrive at**, not the
territory it holds.

that is precisely the split this repo needs:

| latin sense | our term |
|-------------|----------|
| *bodina* — the marker you arrive at | **diff boundary** (a line number) |
| the territory it holds | **chunk** (a span) |

the word already carries "a stop on a traversal" in its oldest sense. it was chosen for that fit,
not for novelty.

⚠️ the **`diff`** qualifier is not decoration — bare `boundary` names a different concept in this
repo, and the two share only this latin root. the dispute below settles it.

## .the evidence — why span-stops were not enough

the coinage answers a measured friction, recorded in `diff-boundary-nav.md`:

> standard `]c`/`[c` jumps to top of next chunk. problem: if chunk is 50 lines, you land at line 1
> and must scroll to see the rest.

vendor nav (`]c`, `[c`, `gs.next_hunk`) offers **one stop per span, always the top**. for a large
span that stop is the least useful position — you see where the change begins and no more of where
it ends.

with two stops per span the traversal becomes:

```
chunk A (10-25), chunk B (40-60), chunk C (80-85)
cursor at 15 (inside A):
  ctrl+d j → 25   (bottom of A — full context before you leave)
  ctrl+d j → 40   (top of B)
  ctrl+d j → 60   (bottom of B)
```

the invariant this buys: **you never land mid-chunk unsure where it ends.** every stop is a
boundary, so every stop has full visibility of the span you are in or leave.

## .why each synonym is forbidden

| forbidden | why |
|-----------|-----|
| `edge` | too generic, and already spent — window edges appear in the same config (`at_edge = 'stop'` in the smart-splits setup). `ctrl+d j` at an "edge" would be ambiguous between a chunk end and a window end |
| `chunk edge` / `hunk edge` | correct in meaning but compound, and it buries the term as a mere attribute of the span. the boundary is the unit the traversal counts, so it earns a name of its own |
| `border` | implies a shared frontier *between* two things. a boundary here belongs to exactly one chunk; two adjacent chunks have four boundaries, not one shared border |

## .the vendor-word discipline

`boundary` is ours; `hunk` is gitsigns'. the two meet at one line and are cast immediately:

```lua
-- get chunks from gitsigns hunks
local hunks = gs.get_hunks()
```

see `term=chunk._.choice.reason.md` for that cast and why it is a conform rather than a drift.

## .disputes

### dispute: boundary (the bare word) — raised 2026-09-05 — status: RESOLVED (keep `diff boundary`)

⚠️ **an ambiguous overload, not a synonym.** `origin/main` independently coined `boundary` for a
different concept while this cluster sat uncommitted. both clusters add the same two files, so the
rebase surfaces it as an add/add collision.

| holder | kind | sense | refs |
|--------|------|-------|------|
| this cluster | noun, a **position** | an endpoint of a chunk (`start` / `fin`) — the unit diff-nav counts | `init.lua` → `navigate_diff_boundary`, `boundary_down` / `boundary_up` |
| origin/main | noun, a **declared operation** | the ONE op every call of a kind routes through, so a guarantee is declared once | `grove.web.sh` (wire), `grove.pkg.sh` (package) |

- raised.by  = diagnosis of the grove.provision restructure rebase
- claim      = each sense is independently well-evidenced; neither drifted toward the other. the
               two share the latin *bodina* root, not a sense
- counter    = one word, two senses is the exact overload `rule.forbid.domain-term-ambiguity`
               forbids. main's cluster explicitly claims the **bare** word — it argues the sense
               "spans contexts rather than belongs to one". this cluster claims a qualified sense
               and already concedes half the ground: see `.the qualifier` — in prose it reads
               **diff boundary**, and bare `boundary` is correct only inside the nav code
- resolution = **main keeps the bare word; this cluster re-homed to `diff boundary`.** applied
               2026-09-06 in the rebase onto the grove.provision restructure. main's sense spans
               the wire, the package manager, kitty's IPC, and infra's lifecycle split, so it
               takes the bare word by the same allowance `bare` / `declared` / `live` take. this
               sense belongs to one surface, so it carries the qualifier. `boundary` (bare) is now
               a forbidden synonym here

⛔ the two clusters were NOT merged. they are distinct concepts, and a merge would fuse two
senses into one entry and lose both. `term=boundary._.choice._.md` holds main's sense untouched.

⚠️ **the code was left at `boundary_down` / `boundary_up`.** a rename to `diff_boundary_*` is a
clean rework (a local rename inside one lua block, no caller outside it), deferred to the human
rather than smuggled into a rebase. the qualifier binds the PROSE today; the code's bare word is
unambiguous only because the operation that wraps it supplies the diff context.

## .the collision, for the next traveler

the lesson is not about this word. two travelers coined one word for two concepts because neither
could see the other's uncommitted glossary. a term cluster held outside a commit is invisible to
the very check that exists to catch overload — so an itemization guards the vocabulary only once
it lands.

## .sources

- [etymonline: bound (n.)](https://www.etymonline.com/word/bound) — *bodne* / *bodina*
- `.agent/repo=.this/role=any/briefs/desktop/nvim/diff-boundary-nav.md` — the friction that motivated the coinage
- `:h ]c` — vim's native span-to-span nav, the baseline this improves on