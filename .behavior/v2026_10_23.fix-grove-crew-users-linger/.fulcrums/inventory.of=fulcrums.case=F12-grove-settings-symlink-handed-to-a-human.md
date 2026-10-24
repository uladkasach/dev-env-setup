# F12 — the `settings.of.grove.json` symlink retarget is handed to a human, not restored here

- fork: restore the symlink's `origin/main` target in this route's commit vs hand it to a human
  - `f459983` retargeted `.agent/.actors/actor.via.repo=ambient/brain/.claude/settings.of.grove.json`
    from one seat's home to this seat's home — a per-seat path unrelated to tmux, linger or coredump
- taken: hand it to a human
  - a restore in the checkout points this seat's live claude settings at a home that does not
    exist on this box, so the session that drives the route loses its settings mid-route
  - the other path — restore in the index only — is a write to the git index, which
    `rule.forbid.writes-to-the-git-index` forbids
  - its twin file, `settings.of.repo.json`, is under the director's order to leave alone and
    keep out of every commit; the two are one subject, so one owner decides both
- rework: clean — a one-line revert of a symlink, by whoever holds a seat where the old
  target resolves, or by a decision that the symlink should not be tracked per seat at all
- confidence 75%: the scope leak is real; the doubt is only whether the director wants it
  reverted in this PR or in a follow-up
- where: `.agent/.actors/actor.via.repo=ambient/brain/.claude/settings.of.grove.json`; ask:
  `git checkout origin/main -- .agent/.actors/actor.via.repo=ambient/brain/.claude/settings.of.grove.json`
  from a seat where the restored target resolves, then commit
