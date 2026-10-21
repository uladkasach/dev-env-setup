# domain.term.choice.reason: arrow

## .etymology
`arrow` came in from the wish's own read of the defect: a tree's settings file "is an arrow to the
home file". it was kept over `link` because the defect is one of direction — a write that enters at
the tree end exits at the home end — and `link` is symmetric in plain speech.

## .disputes
### dispute: `link` — raised 2026-10-20 — status: RESOLVED (keep `arrow`)
- raised.by  = the vision draft, `v2026_10_20.fix-home-claude-settings-lock`
- claim      = `link` is the unix word, and every reader knows it
- counter    = the chain measured on this laptop is two hops (tree → `settings.of.grove.json` →
               home), and the hazard is that a write follows it to the far end. `link` names the
               mechanism; `arrow` names the direction the write travels, the property the lock
               exists for
- resolution = keep `arrow`; `link` forbidden as the name for this concept (it stays legal for the
               unix mechanism itself, as in `readlink -f`)

## .evidence
- discovery: `readlink -f` on the tree's `.claude/settings.json` and on the actor dir's, both
  2026-10-20 — each resolves to `~/.claude/settings.json`
- the vision's dimension table holds `arrow: present · absent` as a fold row; the present row is
  demoed by the clamp's fixture
- invariants:
  - the bundle writes the file an arrow resolves to, never the arrow (a rename over a symlink
    would replace the link and leave its target writable)
  - the boot gate runs only where the checkout's settings path is an arrow to home; elsewhere it
    declines 🌙
