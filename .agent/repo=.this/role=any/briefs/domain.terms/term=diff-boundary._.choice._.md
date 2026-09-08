# domain.term: diff boundary

term.chosen   = diff boundary
term.kind     = noun
term.synonyms.forbidden:
- edge
- chunk edge
- hunk edge
- border
- boundary (bare — that word names a DIFFERENT concept; see .the qualifier)

## .what

an **endpoint of a chunk** — its first line (`start`) or its last line (`fin`). a chunk of n lines
contributes exactly two diff boundaries, so a file of 3 chunks has 6 navigable stops, not 3.

the term names a *position*, never a span. the span is a [chunk](term=chunk._.choice._.md).

## .why this is a term and not just english

gitsigns has no such concept. `gs.next_hunk` moves span-to-span and always lands on a span's
**top**. this repo coined `diff boundary` for the finer stop that makes the nav useful: land on
the bottom of the chunk you are in before you leave it, so a 50-line chunk is never entered blind.

`diff boundary` is therefore the word that distinguishes *our* nav from the vendor's. to call it
an "edge" is to lose that this is the unit the traversal counts.

## 🛑 .the qualifier is REQUIRED — bare `boundary` is taken

bare **`boundary`** already names an unrelated concept in this repo: the ONE declared operation
every call of a kind routes through — the wire boundary (`grove.web.sh`), the package boundary
(`grove.pkg.sh`). see `term=boundary._.choice._.md`.

two senses on one word is the overload `rule.forbid.domain-term-ambiguity` forbids, so this term
carries its qualifier **always** — in prose and in a contract alike. the qualifier costs one word
and buys an unambiguous read.

⚠️ the CODE still says bare `boundary` inside the nav block (`boundary_down`, `boundary_up`, and
`navigate_diff_boundary`'s locals). that is the one place the diff context is supplied by the
operation that wraps them, so no reader can reach the other sense there. a rename of those locals
to `diff_boundary_*` is a clean rework, deferred to the human — see the dispute in the `.reason`.

## .refs

**the contract:**

- `src/grove.provision/4.terminal/4.5.nvim/init.lua` → `navigate_diff_boundary(direction,
  get_chunks, fallback)` — the shared traversal
- `src/grove.provision/4.terminal/4.5.nvim/init.lua` → `boundary_down` / `boundary_up` — the two
  declared operations, bound twice (gitsigns buffers, codediff buffers)
- keymap descs: `'Next diff boundary'` / `'Prev diff boundary'` — the word the human reads, and
  the one place the qualified term was always spelled out

**the briefs:**

- `.agent/repo=.this/role=any/briefs/desktop/nvim/diff-boundary-nav.md` — the flow example that
  shows why boundary-stops beat span-stops
- `.agent/repo=.this/role=any/briefs/desktop/nvim/criteria/diff.boundary.nav.md` — the criteria

## .reason

see the ref-level file beside this choice:

- `term=diff-boundary._.choice.reason.md` — etymology, the collision with bare `boundary`, and
  why each synonym is forbidden
