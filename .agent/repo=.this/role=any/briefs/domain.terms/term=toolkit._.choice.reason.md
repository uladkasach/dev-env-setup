# domain.term.choice.reason: toolkit

## .etymology
`toolkit` is ordinary english for a named collection of tools a person owns and carries. it was
reached for because the concept needed a SUBJECT, and every candidate that came first named some other
thing than the set itself.

the word arrived on 2026-07-30, when `install_cli_deps` was decomposed into a bundle and the old name
could not survive the move.

## .disputes

### dispute: cli_deps  —  raised 2026-07-30  —  status: RESOLVED (adopt `toolkit`)
- raised.by  = mechanic (self), mid-conversion
- claim      = `cli_deps` is the extant name and describes the set accurately: these ARE the cli
               dependencies other steps rely on. a rename costs churn for no capability.
- counter    = it names a **relationship**, not a subject — "things other steps depend on". a name
               shaped like that has no membership test, so any package can be argued into it, and the
               set had in fact become a junk drawer: it held `tmux`, whose CONFIG lived in a different
               function entirely (`configure_tmux`). that split is exactly what
               `rule.require.bundle-as-sole-declaration` forbids, and the vague parent name is what
               let it in — the tell was that every OTHER name in the list had no config at all.
               `rule.require.bundle-names-name-their-subject` states the general form: a bundle must
               name what it IS, never a quality, an outcome, or a relation.
- resolution = adopt `toolkit`; record `cli_deps` and `deps` as forbidden synonyms. `tmux` was moved
               out to `2.8.tmux` in the same change, which is the dispute's own evidence.

### dispute: essentials / basics  —  raised 2026-07-30  —  status: RESOLVED (keep `toolkit`)
- raised.by  = mechanic (self)
- claim      = the bundle's own body splits its list into "essential" and "comfort", so `essentials`
               names the important half directly.
- counter    = it names a JUDGMENT about the members rather than the members, and the judgment is not
               even uniform — half the bundle is explicitly not essential, and its failure is
               tolerated on purpose. `basics` fails a second way: it names a LEVEL (foundational vs
               advanced), which is the same defect as the deleted `1.4.performance`, whose name was an
               outcome.
- resolution = keep `toolkit`. the essential/comfort split stays as a distinction INSIDE the bundle,
               where it governs which failures are loud — not as the bundle's name.

## .evidence

### discovery — the membership test the name has to support
the bundle needed a rule for "does this tool belong here?", and the name had to make that rule
answerable. two candidate rules were weighed:

| rule | what it admits | verdict |
|------|----------------|---------|
| "other steps depend on it" (`cli_deps`) | any package at all, since each is depended on by some caller | unbounded — the junk drawer |
| "a tool with no config this repo writes" (`toolkit`) | a closed, checkable set | adopted |

the second rule is what makes the bundle's boundary auditable: a reader can ask, for any tool, "does
this repo write a file for it?" and get one answer. it also enforces itself — the moment the answer
flips, the tool must leave.

### the two departures, which are the rule in action
- **starship** left before this term existed (2026-07-29). it has a `starship.toml`.
- **tmux** left with this term (2026-07-30). it has a `~/.tmux.conf`, a plugin manager, and a plugin
  list. its binary had sat in `cli_deps` while its conf sat in `configure_tmux` — one concern, two
  homes, for as long as the vague name allowed it.

### invariants
- a member of the toolkit has NO file written by this repo. if it gains one, it leaves the same day.
- the toolkit therefore has no `configure` phase at all, and that absence is a declaration — not an
  omission. `fzf`'s keybinds ARE declared, but inside the zshrc that `2.5.zsh` writes, as part of
  that one file.
- an essential's absence fails the phase loud; a comfort's absence reports 🌙 and the run continues.
  a verify may never be stricter than its upsert on this point, or a red line stands on every run
  forever.
