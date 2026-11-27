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
| [F10](./inventory.of=fulcrums.case=F10-grove-sync-reads-the-platform-with-no-host-key.md) | `git grove sync` reads a new box's platform with no host key check | clean | risky | disputed (r007 nitpick.2) | 80% |
| [F11](./inventory.of=fulcrums.case=F11-boot-what-skips-are-proven-live.md) | the boot's `--what` step skips are proven live, never by a hermetic drive | clean | safe | disputed (i003 r008 nitpick.2) | 80% |
| [F12](./inventory.of=fulcrums.case=F12-restore-splits-streams-by-what-refused.md) | the restore splits its streams by what refused: the call to stderr, a unit in the tree | clean | safe | disputed (i003 r009 nitpick.3) | 85% |
| [F13](./inventory.of=fulcrums.case=F13-one-pr-carries-the-backup-and-its-paved-road.md) | one pr carries the backup and the road it was proven over | dirty | safe | disputed (i004 r011 blocker.4); the wisher may rule B | 70% |
| [F14](./inventory.of=fulcrums.case=F14-the-backup-library-lives-in-its-bundle.md) | the backup library lives in its bundle dir, whole; its format literals declared once | clean | safe | disputed (i004 r011 blocker.5) | 75% |
| [F15](./inventory.of=fulcrums.case=F15-all-lays-every-unit-ever-landed.md) | `--all` lays every unit the grove ever landed; the list is its preview; no unit retires | clean | safe | disputed (i004 r011 nitpick.6, r010 o8 + `--all` preview) | 75% |
| [F16](./inventory.of=fulcrums.case=F16-the-nitpicks-this-pr-holds-past-its-release.md) | the nitpicks this pr holds past its release, each with its reason | clean | safe | disputed (i005 r010 nitpicks, r011 nitpick.6; i008 r011 nitpicks 5–7; 5.3 i004 r010 nitpick.6, r011 nitpick.7, r012 nitpick.1) | 80% |
| [F17](./inventory.of=fulcrums.case=F17-a-clone-under-worktrees-rides-as-a-clone.md) | a clone of its own under `_worktrees/` rides as a clone, laid back at `~/git/<org>/<dir>` | clean | safe | best-guessed (i008 r011 blocker.1) | 75% |
| [F18](./inventory.of=fulcrums.case=F18-the-laptop-imagemagick-fence-is-the-humans-root-step.md) | the laptop's imagemagick fence is the human's root step, named in the yield, not this stone's halt | clean | safe | disputed (5.3 i001 r001 blocker.2) | 75% |
| [F19](./inventory.of=fulcrums.case=F19-the-backup-agent-is-the-paved-tool-on-a-grove.md) | the backup agent is the paved tool on a grove; the howto calls it, not an rhx wrapper | clean | safe | disputed (5.3 i001 r001 nitpick.1) | 70% |
| [F20](./inventory.of=fulcrums.case=F20-the-scope-read-runs-from-the-laptop.md) | the infra scope read runs from the laptop; the s3 contract alone needs a grove | clean | safe | disputed (5.3 i001 r004 nitpick.2) | 90% |