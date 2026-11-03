# F007 — where "a known camp grove" is read from

- **fork:** the grove registry `git.grove.*` keeps · the ssh alias in `~/.ssh/config` · a rack entry
- **taken, why:** none yet — the commander settled the check (q4), the blueprint picks the source; no tailnet name may be tracked (dox)
- **rework:** clean — one read in one verify
- **confidence 60%, why low:** a laptop with no grove registered has no name to look for; the fallback for that cell is unsettled
- **where:** vision awkward §4

## .verdict — 5.1.execution, 2026-10-26

read from the node itself: a peer whose `Tags` holds `tag:camp` in `tailscale status --json`. the acl makes that tag mean a camp grove, so the repo tracks no grove name and no tailnet name (`rule.forbid.dox-in-public-repo`). no camp peer on a joined laptop ✋s with two named causes: another tailnet, or an acl that grants this login no grove.