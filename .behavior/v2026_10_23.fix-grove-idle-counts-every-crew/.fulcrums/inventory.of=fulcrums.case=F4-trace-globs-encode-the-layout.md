# F4 — crew trace globs encode the clone layout

## .the fork
- **globs** — `/home/*/git/*/_worktrees/*/.agent/.actors/*/brain/.claude/projects` and
  `/home/*/git/*/*/.agent/.actors/*/brain/.claude/projects`
- **a path walk** — `find /home -path '*/.agent/.actors/*/brain/.claude/projects/*' -name '*.jsonl'`

## .taken — globs
infra split the trace into `under` + `named` so the shell expands a cheap prefix and bounds the walk;
a `-path` walk descends every `node_modules` under `/home`, every 5 minutes, forever.

## .the roots, as they stand
- the human's `~/.claude/projects`, each worktree's and each main clone's actors, and each codex
  session under `~/.codex/sessions` (`5.3.brains` installs codex as the second brain; 34 sessions
  on this box, 2026-10-17 to 11-02)
- the trace walk runs `find -H`, so a root that is itself a symlink is walked, never read as one
  link and zero traces (clamp arm `linkedroot`)
- the drift play's `layouttie` arm ties the worktree root to `_git_tree_worktrees_dir`, which puts
  each worktree in the `_worktrees` dir beside the main clone — one convention, two holders

## .the fork left open — discover each live crew's root from its process
- the r011 i007 ask: as root, read each live `claude` process's `/proc/<pid>/environ` for
  `CLAUDE_CONFIG_DIR`, add `$CLAUDE_CONFIG_DIR/projects` to the sweep, and hold loud on a live
  process whose root it cannot derive — a trace analog of `guard_uncounted`
- **held, not taken, at 5.1.** that `CLAUDE_CONFIG_DIR` sits in a live crew's environment is
  unmeasured, and a guard built on an unmeasured fact can cry wolf on every tick (a crew that
  inherits the default root has no variable to read) or go blind (a crew that sets it some other
  way). the measure rides with F10's at 5.3: one live crew's environ, read from the ground seat
- if the measure holds, the rework is clean: one reader and one guard in the check, one arm

## .rework — clean
one row per layout in the trace list.

## .confidence — 85%, and why it is not higher
a clone outside `/home/*/git/<org>/` is invisible until the process-root guard lands. measured
here: 128 worktree actor dirs match, 0 main-clone dirs.

## .where
the trace heredoc in the check.

## .verdict
open
