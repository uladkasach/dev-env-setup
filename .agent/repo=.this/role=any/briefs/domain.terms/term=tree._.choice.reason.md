# domain.term.choice.reason: tree

## .etymology
the work domain is a forest metaphor: a **forest** of **groves** (machines), each grove
holds **trees** (branch workspaces). a tree is what grows on a grove — one branch, rooted
in its own worktree directory, with its own session.

chosen over:
- `worktree` — that is git's own primitive (the checkout mechanism); a tree is the
  worktree *plus* its session, and `worktree` breaks the forest metaphor. we keep
  `worktree` for the base git object, `tree` for our domain concept
- `workspace` / `checkout` — generic, and blind to the machine-level structure above

## .the pair it completes — `main | tree`

itemized 2026-07-28 (human: *"we use main | tree ubiquitously already"*). `tree` alone
names a cell; the axis needs both cells to be enforceable, so `main` was itemized beside
it. the full argument, and the `--version local|global` flag it retired, live at
`term=main._.choice.reason.md`.

that round also caught a live defect in THIS file's value: a proposed flag
`--from worktree|checkout` reached for `checkout`, which is listed above under
`term.synonyms.forbidden` for exactly the reason recorded there. the cluster caught it.

## .disputes
none yet — but see `term=main._.choice.reason.md` for an OPEN dispute on the pair's flag
values (`this` vs `tree`), which touches this term.

## .evidence
- built precedent: `git tree get|set|del|status` already exists (`git_alias_tree` in
  `src/bash_aliases.sh`), trees rooted at `@gitroot/../_worktrees/$reponame.$branch/`
- narrative: a developer runs `git tree set feat/auth`, which carves a worktree and a
  session; that unit is the tree. many trees sit on one machine
- decomposition: the where-does-work-happen axis has three orthogonal levels — branch
  workspace (tree) ⊂ machine (grove) ⊂ fleet (forest); tree is the narrowest cell
- dreams: `.dream/2026_06_17.git-forest.dream.md` uses `tree` as the per-branch unit
