# domain.term: tree

term.chosen   = tree
term.kind     = noun
term.synonyms.forbidden:
- workspace
- checkout
- branch-dir
- this          # retired 2026-07-29 as a `--from` value; see .reason

## .what
a branch workspace on a grove: one git worktree plus its terminal/tmux session.

## .its pair — `main | tree`
`tree` is half of the where-does-this-code-live axis on one machine: `main` is the trunk
checkout, `tree` is a worktree carved from it. see `term=main._.choice._.md`.

every `--from` flag in this repo takes exactly this pair, because they all ask the one
question: *which of the two places on this machine?*

| command | `--from` |
|---------|----------|
| `git tree set <branch>` | `main` \| `tree` |
| `rhx grove.provision` | `main` \| `tree` |

`this` once served as the second value of `git tree set --from`. it is now an ERROR that
names the fix, not a silent alias — an alias would keep the synonym alive forever, since no
run would ever teach the canonical word.

## .refs
where the term is declared / used:
- src/bash_aliases.sh                       # git_alias_tree, and `--from main|tree`
- src/grove.provision/2.shell/2.2.git/configure.upsert.sh  # alias.tree registration
- .agent/repo=.this/role=any/skills/grove.provision.sh   # `--from main|tree`
- .agent/repo=.this/role=any/briefs/grove/reach/define.git-forest-grove-tree.md

## .reason
see the ref-level cluster beside this choice:
- `term=tree._.choice.reason.md` — etymology, disputes, evidence
