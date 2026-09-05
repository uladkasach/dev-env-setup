# domain.term: gap

term.chosen   = gap
term.kind     = noun
term.synonyms.forbidden:
- hole         (implies damage — that a piece fell out and the tree is worse for it. a gap is
                the tree in good order)
- vacancy      (implies a slot waits to be refilled. no bundle is owed at `2.4`)
- reserved     (states the opposite of the truth: the number is claimed by nobody, and the
                next bundle that genuinely depends on `2.3` may take it)
- skip         (names an ACT — what a run does to a bundle it declines. a gap is a fact about
                the TREE, and `bundle.upgrade` never sees one)
- missing      (a word for something owed and absent; also forbidden repo-wide as vague)
- placeholder  (no file exists, so no place is held)

## .what
a bundle number no directory uses, left open after the bundle that held it moved away.

`src/grove.provision/2.shell/` runs `2.1 · 2.2 · 2.3 · 2.5 · 2.6 · 2.7 · 2.8`. `2.4` is a gap.

⚠️ **this word is reserved for the TREE.** it does NOT mean "an unmet precondition" — say
that in plain words, or point at the `·` marker the plays already use. the two senses have
opposite polarity: a gap here is CORRECT and never debt, while an unmet precondition IS debt
and a **bundle** exists to close it. a `diagnose` used `gap` for the second sense on
2026-08-09; see the dispute in `.reason`.

## .why a gap is CORRECT, and not debt to repay

a bundle's number is an **ordinal dependency claim** — *"each thing this bundle needs is
already done"* (`term=bundle`). it is never a census of the section.

so contiguity carries no information. to close a gap is to renumber bundles that no dependency
asked to move, and to drag every brief, alias, playbook, and `--what` a human has typed along
with them — for a tidier column of digits.

that is a rename with a real cost and no claim behind it, which is the same trade
`rule.require.bundle-names-name-their-subject` warns about from the other side: a number
should move when a DEPENDENCY moves, and at no other time.

## .the gap is a record, so it gets a note

a gap with no explanation reads as a lost file. so the section's `_.sh` says why:

```sh
# ⚠️ .why 2.4 is a GAP, and stays one
#         `2.4.gh` sat here until 2026-08-02, inherited from an old layout that
#         treated shell tools as one lump. gh's real dependency is a CREDENTIAL…
```

a reader who wonders where `2.4` went finds the answer beside the numbers, not in git log.

## .refs
- src/grove.provision/2.shell/_.sh                 # the gap at 2.4, and its note
- .agent/repo=.this/role=any/briefs/domain.terms/term=bundle._.choice._.md   # the number as a dependency claim

## .reason
see the ref-level cluster beside this choice:
- `term=gap._.choice.reason.md` — etymology, the rejected alternatives, and why `sort -V`
  makes contiguity free
