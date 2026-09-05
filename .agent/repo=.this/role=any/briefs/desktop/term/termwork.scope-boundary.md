# termwork: scope boundary

## .what

termwork's domain is exactly two things:

| concept | what | address |
|---------|------|---------|
| **terminal** | a window with a slug | `--on <slug>` |
| **tab** | an identifier *within* one terminal's namespace | `--on <terminal> --tab <slug>` |

a tab slug need only be unique **within its terminal**. the full address of a tab is the pair `(terminal, tab-slug)`. the terminal *is* the namespace.

## .why

- keeps the model small and unambiguous — no global tab names, no cross-terminal collisions
- clean separation from the caller: termwork opens/addresses windows and tabs; the caller owns each layer above
- the terminal-as-namespace dissolves questions like "which window hosts this tab" and "how are tab slugs kept unique"

## .not termwork's concern

do NOT pull caller-side concepts into how you reason about or design termwork:

- **trees / worktrees** — a caller may map one terminal per worktree, but termwork does not know "tree"
- **roles** (e.g. mechanic / foreman) — those are caller labels, not termwork's
- **tmux session slugs** — how a tab's attached session is slugged is the caller's job

these belong to the caller (e.g. nheuron's `git.tree.duct`), not to `src/termwork.sh`.

## .the trap (why this brief exists)

a vision for termwork tabs was drafted, and the caller's "tree" frame leaked in — one window per worktree, mechanic as tab 0, foreman as tab 1 — and it even spawned a false open question about global-vs-tree-scoped tmux session slugs. the human corrected: termwork is only about terminals; each terminal has a slug, and each tab is an identifier within that terminal's slug namespace.

## .how to apply

- when you design or edit `src/termwork.sh`, keep the model to **terminals + tabs by slug**
- address a tab by `(--on <terminal>, --tab <slug>)` — no `--into <host>`, no numeric `--tab N`
- let the caller own session slugs and higher-level structure
- if you catch yourself with "tree" or "role" in a termwork design, stop — that concept lives one layer up
