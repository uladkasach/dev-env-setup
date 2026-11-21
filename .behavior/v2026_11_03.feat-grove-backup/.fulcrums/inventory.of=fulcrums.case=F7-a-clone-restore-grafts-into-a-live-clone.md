# F7 — a clone restore grafts into a live clone

## .the fork

a fresh grove's provision clones every repo of each org (`5.10.repos/provision.upsert.sh:3`). so
the clone target of a restore is present on nearly every fresh grove. #169 says "refuse a present
target", which would refuse the common case.

- **A (taken)** — graft: fetch the backed-up clone's local branches into the live clone ff-only; a
  diverged branch lands as `<grove>/<branch>` and is named; files are never overwritten. worktree
  and home-dir restores still refuse a present target
- **B** — refuse, and ask the commander to delete the fresh clone first
- **C** — overwrite the fresh clone, since it holds naught that `origin` lacks

the same holds for home dirs: a fresh grove's provision lays `~/.claude` and `~/.rhachet`. so a home
restore lays absent files and keeps present ones, named — and never lays `keyrack/`, which is sealed
to the dead grove's own key.

## .why A

- B adds a hand step to the critipath, and a delete of a clone is the act a human gets wrong
- C overwrites, which a restore must never do; "holds naught" is a guess about live state
- A matches #169's own worktree-beside-a-live-clone rule, extended to the clone

## .risk — safe

- no credential: the graft is a local `git fetch` from a laid-aside copy, with no remote auth
- no prod write: it writes refs in the fresh grove's own clone, fast-forward only, never a push to
  `origin`; a diverged branch lands beside the live one, never over it

## .rework — clean

restore semantics only; the backup format is the same either way.

## .confidence — 75%

uncommitted edits in the clone's own checkout do not graft (r7). they need `--into`. the
checked-out branch cannot take a fetch; it moves by `git merge --ff-only` on a clean tree only (r4,
r5).

## .verdict

—
