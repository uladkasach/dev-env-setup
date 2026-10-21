# domain.term.choice.reason: role-hook

## .etymology
`role` + `hook`: both words already hold their senses here — a **role** is a rhachet role
(`repo=<org>/role=<role>`), and a **hook** is a claude settings hook entry. the compound names the
author, which is the one fact the strip decides on. the author is read off the stamp rhachet
writes, so the word names what the file itself records, never a guess at provenance.

## .disputes
### dispute: `repo hook` — raised 2026-10-20 — status: RESOLVED (keep `role hook`)
- raised.by  = the vision draft, `v2026_10_20.fix-home-claude-settings-lock`
- claim      = these hooks belong to a repo, so `repo hook` names where they should live
- counter    = the defect is WHO wrote them, not where they belong. the commander may write a hook
               into a repo's settings by hand, and it would be a repo hook and not a role hook. the
               strip keys on the author stamp, so the term must too
- resolution = keep `role hook`; `repo hook` forbidden

## .evidence
- discovery: a read of the live file, 2026-10-20 — 22 entries, every one stamped
  `repo=<org>/role=<role>`, five roles across three org repos; no entry with an author outside
  that shape
- decomposition: the selector's boundary was a fulcrum (F2 — `author` begins `repo=`, versus an
  allowlist of known roles). an allowlist goes stale as roles ship; the prefix is the shape rhachet
  stamps on every role, so it holds for roles not yet written. ruled: stands
- invariants:
  - home `~/.claude/settings.json` holds zero role hooks after an apply
  - a hook with no `author` is never removed by the strip
  - a non-string `author` is not a role hook (the selector checks the type before `startswith`)
