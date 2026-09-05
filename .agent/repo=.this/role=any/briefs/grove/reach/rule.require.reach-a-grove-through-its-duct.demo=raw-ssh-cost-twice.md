# demo: reach-a-grove-through-its-duct — what a raw ssh cost, twice

## .what

`rule.require.reach-a-grove-through-its-duct.md` states the law: every command to a grove
rides a `git.grove.*` skill, never a raw `ssh <grove> "<cmd>"`. these are the two dated
incidents that moved the ban from prose to a `deny` entry.

## m1 — three raw ssh calls, one dead tunnel, no named fix — 2026-07-28

- a robot diagnosed a failed grove step with three raw `ssh grove-1 "…"` calls
- two died on a dropped tunnel with `Connection refused` — a failure that names no fix,
  where `git.grove.wake` is the declared cure
- ⇒ the raw path was slower AND less legible than the skill it bypassed

## m2 — ~15 raw ssh calls despite an in-context rule, plus a chained one-liner — 2026-07-30

- a robot proved eight bundles with roughly 15 raw `ssh grove-1 '…'` calls
- this brief already existed, already named the trap, and was in context — the robot typed
  ssh anyway, because the allowlist waved every call through and no friction ever appeared
- several calls chained multiple steps in one line:
  ```sh
  ssh grove-1 'cd … && for m in plan apply apply; do bash …; done'   # both violations
  ```
- `git.grove.send --what` refuses `;`, `&&`, `||`, and newlines precisely so a multi-step
  command becomes a reviewed `--play` file — the raw ssh bypass reached the machine with no
  review, no diff, no record
- ⇒ a bypass is never a single bypass. it takes with it every guard downstream of the
  surface it skipped
- ⇒ a rule that lives only in prose competes with convenience, and convenience wins — the
  ban is now a `deny` entry in `.claude/settings.json`, not another paragraph

## .see also

- `rule.require.reach-a-grove-through-its-duct.md` — the rule these measurements back
- `rule.require.wrap-cli-in-skills` — the general rule this specializes
