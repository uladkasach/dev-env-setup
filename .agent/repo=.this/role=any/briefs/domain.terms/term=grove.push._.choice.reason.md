# domain.term.choice.reason: push

## .etymology
from git's own vocabulary — `git push` moves content from here to there. the repo already
speaks it (`git.commit.push`), so `git.grove.push` reads as the same motion aimed at a grove
instead of a remote. it also pairs symmetrically with `pull`
(`rule.prefer.symmetric-term-pairs`), which is why the two were settled together.

chosen over:
- `upload` — http/web jargon; implies a server and a protocol we do not mean
- `copy-to` — mechanical, and breaks the push/pull symmetry
- `deploy` / `ship` — imply a release with a target environment; a grove push is a plain
  content transfer that may carry unmerged, unvalidated work

## .disputes
none yet.

## .evidence
- built precedent: `git.commit.push` already uses the verb in this repo's skill vocabulary
- symmetry: `push` / `pull` name one motion in two directions — the pair reads at a glance,
  which is the whole point of `rule.prefer.symmetric-term-pairs`
- narrative: a developer with an unmerged worktree wants their `src/` on the grove *now*, to
  validate before a merge. "push it to the grove" is exactly what they say
