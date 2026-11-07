# inventory.of=fulcrums

risk: `risky` = the taken path touches a credential or a prod write; `safe` = it touches neither.
each entry's `.risk` section carries the why.

| case | title | rework | risk | status | confidence |
|------|-------|--------|------|--------|------------|
| [F1](./inventory.of=fulcrums.case=F1-bucket-name-reaches-the-box.md) | infra declares the bucket name on the box | dirty | safe | ruled A (director); halt before B | 55% |
| [F2](./inventory.of=fulcrums.case=F2-restore-is-an-rhx-skill-on-the-box.md) | the human surface is `rhx grove.backup.*`, run on the box | clean | safe | best-guessed | 80% |
| [F3](./inventory.of=fulcrums.case=F3-laptop-git-backup-alias-stays.md) | the laptop `git backup` alias stays, unchanged | clean | safe | best-guessed | 85% |
| [F4](./inventory.of=fulcrums.case=F4-the-grove-name-is-declared-on-the-box.md) | infra declares the grove name at `/etc/grove/name` | clean | safe | open — wisher | 70% |
| [F5](./inventory.of=fulcrums.case=F5-backup-health-reads-in-grove-stats.md) | this repo writes `status.json`; infra's `git.grove.stats` renders its line | clean | safe | best-guessed | 80% |
| [F6](./inventory.of=fulcrums.case=F6-backup-is-its-own-term.md) | `backup` names this concept, apart from snapshot and park | clean | safe | best-guessed | 85% |
| [F7](./inventory.of=fulcrums.case=F7-a-clone-restore-grafts-into-a-live-clone.md) | a clone restore grafts into the fresh grove's own clone | clean | safe | best-guessed | 75% |
| [F8](./inventory.of=fulcrums.case=F8-skip-against-the-latest-object-not-today.md) | the skip compares against a unit's latest object, not today's | clean | safe | best-guessed | 85% |
| [F9](./inventory.of=fulcrums.case=F9-restore-names-its-repo-with-of.md) | the restore names its repo with `--of`, since rhachet owns `--repo` | clean | safe | best-guessed | 90% |
