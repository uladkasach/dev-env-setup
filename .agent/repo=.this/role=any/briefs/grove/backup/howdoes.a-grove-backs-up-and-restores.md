# howdoes: a grove backs up and restores

## .what

every cloud grove backs up camper's work to the camp backup bucket, on a timer, with no human
step. a dead grove's work comes back onto any grove with `rhx grove.backup.restore`.

- **who**: the camper seat alone. only camper holds work; ground and the other seats hold none
- **what**: `~/git` (every clone, worktree, orphan, and set-aside), `~/.claude`, `~/.rhachet`
- **where**: the bucket infra names in `/etc/grove/backup.bucket` (from `CAMP_GROVE_BUCKET_NAME`).
  this repo is public, so the literal never appears here
- **how it lands**: bundle `5.devtools/5.26.backup`. ground installs the agent and its timer;
  the agent runs as camper, through camper's own aws config

```sh
rhx git.grove.provision boot <grove> --what 5.26.backup --mode apply   # enroll, from a laptop
```

## .the unit — one tree, one atomic object

a backup is a set of UNITS. a unit is one tree (a clone, a worktree, an orphan, or a set-aside)
or one global home dir, packed as ONE object:

```
grove=<grove>/user=camper/org=<org>/repo=<repo>/tree=<dir>/date=<YYYY-MM-DD>.tar.gz
grove=<grove>/user=camper/org=<org>/orphan=<dir>/date=<YYYY-MM-DD>.tar.gz
grove=<grove>/user=camper/org=<org>/repo=<repo>/setaside=<name>/date=<YYYY-MM-DD>.tar.gz
grove=<grove>/user=camper/home=<.claude|.rhachet>/date=<YYYY-MM-DD>.tar.gz
```

- a clone's `tree` is its repo dir; a worktree's is its `_worktrees/<dir>`
- `date=` is the day the unit last CHANGED, never the day of the run
- the bucket is versioned, so an earlier put of the same day survives as a prior version

**a tree's unit is self-contained.** it restores onto a box that holds no other unit of that
repo: a clone from origin, then the unit laid over it.

## .what a tree's unit carries

a tree carries exactly what origin and its own HEAD cannot rebuild:

| part | how |
|---|---|
| **its git**: every commit, branch, stash entry, and reflog tip origin lacks | `.grove-backup/objects.pack` — a plain git pack of what its refs and reflogs reach, minus each sha `git ls-remote origin` answers; `.grove-backup/refs.txt` names each ref |
| **its checkout state**: HEAD, the index, its reflogs, a rebase or merge mid-flight | `.grove-backup/checkout/` — this tree's own copy of its git dir's per-tree files |
| **its staged copies**: the index's blob of each staged file | `.grove-backup/staged/<path>` — no ref reaches them, so they ride apart |
| **its repo config**: remotes, upstreams, `info/exclude`, edited hooks | `.grove-backup/repo/` — every url with its credential stripped |
| **its changed files**: modified, staged, renamed, and untracked | the files themselves, laid at their paths |
| **its brain transcripts**: every conversation a clone held in this tree | `.agent/.actors/*/brain/.claude/` — the transcripts live IN the tree, so they ride in its unit |
| **its other git-ignored files** worth a keep: local env, local config | the files themselves |
| **its manifest** | `.grove-backup/meta.json`: kind, origin url, HEAD sha and branch, the deletes, the staged paths, and whether origin answered and the pack was still. no host, no seat, no date |

⚠️ **a plain pack, never a `git bundle`.** a bundle refuses to exist when every ref tip is already
on origin, yet a commit only a reflog reaches still owes a ride.

⚠️ **"on origin" is asked of origin NOW**, by `ls-remote`, never of this box's own remote refs. a
branch origin dropped by a force-push since the last fetch still looks present here, and its
commits would be left out.

🛑 **the transcripts weigh as much as the code.** they are the record each crew learns from, and
that loop is how the crews improve. so a transcript gets every guarantee a commit gets, and a test
clamps that it comes back byte for byte from its tree's unit alone.

never in a tree's unit:

- a tracked file that matches HEAD — HEAD rebuilds it. a file git flags `assume-unchanged` or
  `skip-worktree` is packed whole, since git would vouch for it falsely
- the rebuilt dirs: `node_modules` at any depth; `dist` `build` `coverage` `.next` where git
  ignores them
- a commit origin already holds

a repo with no origin packs every commit it holds, so naught depends on a remote that is not
there. an origin that does not answer is read from this box's own view of it, and the unit packs
again the next pass.

## .the trees that hold no git — orphans and set-asides

two shapes under `~/git` hold transcripts but no git state of their own. each rides as a
plain-file unit: every file, packed whole, with no git part.

| unit | the tree | key |
|---|---|---|
| **orphan** | a `_worktrees/<dir>` with no `.git`: git dropped the worktree, the dir stayed | `org=<org>/orphan=<dir>` |
| **set-aside** | `<clone>/.git/tree-del-setaside/<dir>`, a tree moved into its clone's git dir; or `_setaside/<repo>/<dir>`, where a restore laid one | `org=<org>/repo=<repo>/setaside=<name>` |

📌 no writer of `tree-del-setaside/` lives in this repo or the ehmpathy org. the walk reads the dir
name as found on the ec2 grove; a tool that renames it would leave its trees uncovered, and the
coverage claim below is what would go red.

⚠️ **a set-aside's name carries the hour it was set aside.** the key cuts that suffix and puts 8 hex
of a hash over this box's machine-id and the name in its place, so the hour never reaches the
bucket and cannot be read back without the box.

🛑 **every transcript under `~/git` sits inside some unit.** a walk that skips a shape loses that
shape's conversations in silence; both proofs clamp it with a coverage claim.

## .the two global units

only two units hold what is global to the seat:

| unit | holds |
|---|---|
| `home=.claude` | the seat-wide brain config: settings, plugins, keybindings, sessions, history |
| `home=.rhachet` | the seat-wide rhachet config: role storage, meters, the sealed keyrack |

never in either: `~/.claude/.credentials.json` and `~/.rhachet/keyrack/vault/os.direct/`. a
plaintext credential in a bucket every grove reads is a credential every grove holds; log in again
after a restore.

naught else in the home rides. dotfiles come back from this repo's own bundles, and `~/.ssh` and
`~/.aws` are a box's own identity, never copied between boxes.

## .when

- the timer fires every 15 minutes; `Persistent=true`, so a run missed while the box was down
  fires on wake or boot
- **a run takes the stalest unit first.** each unit records its own mark the moment it lands or is
  found quiet, so a run that stops early hands its tail to the front of the next
- **a quiet unit costs a metadata read.** a unit whose refs, HEAD, index, and reflog did not move,
  and in which no file's ctime moved since its mark, is skipped with no pack and no aws call
- one run at a time: systemd never starts a second copy of an active oneshot, and the agent holds
  a lock
- the agent runs at idle priority for cpu and disk, so a clone's own build or test outranks it

## .the guarantees

- **a put is atomic.** one unit is one object; a restore reads the old unit or the new one, never
  half of either. a stopped run loses at most the unit in flight
- **a unit is one point in time.** its git state and its files are read, then checked: a pack that
  saw its refs, HEAD, or index move, or a file's ctime move under it, packs again, twice at most,
  then lands flagged in its manifest
- **a live conversation is captured up to the moment it is read.** a `.jsonl` a brain still
  appends to lands as a whole prefix of itself
- **✓ means every unit landed.** a run that put 11 of 12 units is a run that lost one, so its line
  is ✗, and names the unit
- **the window at risk** is the work since that unit's last put: about one timer interval. pushed
  commits are already safe in git

## .read it

```sh
rhx grove.backup.get                          # this grove's last run, one line
rhx grove.backup.get --list                   # every grove the bucket holds
rhx grove.backup.get --from <grove> --list    # every unit a grove left, with date and class
```

the line every surface prints (this skill, the verify, infra's `git.grove.stats`):

| line | means |
|---|---|
| `✓ 20m ago · 3 put · 9 skipped` | every unit is current as of that run |
| `⏳ the first run is at work` | enrolled; the first pass has not yet written its status |
| `✗ FAILED · <cause> · 3h` | the last run failed; the cause names the fix |
| `✗ STALE · last ok 3h ago` | no good run in two hours |
| `✗ NOT ENROLLED` | the timer is absent: apply the bundle |

## .restore it

on any grove, as camper. it never overwrites: a present clone takes the unit's branches
fast-forward only, a present worktree is kept, and a home dir keeps each file already there.

```sh
rhx grove.backup.restore --from <grove> --all                                  # every unit; a resume
rhx grove.backup.restore --from <grove> --of <org/repo> --tree <dir>           # one tree, clone or worktree
rhx grove.backup.restore --from <grove> --home .claude                         # one global unit
rhx grove.backup.restore --from <grove> --orphan <org>/<dir>                  # a dropped worktree's files
rhx grove.backup.restore --from <grove> --of <org/repo> --setaside <name>      # a set-aside tree
rhx grove.backup.restore --from <grove> --of <org/repo> --tree <dir> --into <dir>   # a clone of its own, aside
```

a tree restores in four moves: clone origin (or reuse the clone already here), index the unit's
commits, check out its HEAD with its index, then lay its files and apply its deletes. a worktree
links into the clone already here, or brings its own clone up from origin first.

an orphan lands at `_worktrees/<dir>`; a set-aside lands at `_setaside/<repo>/<name>`, outside
any `.git`. `--all` lays clones first, then worktrees, then orphans and set-asides, then homes.

`--all` is a resume: a tree already here is kept, and the rest land. a diverged branch is never
moved; the unit's copy lands beside it as `<grove>/<branch>`.

an object older than 180 days sits in deep archive; the restore asks s3 to thaw it, says how long
it waits (12–48h), and finishes once the copy reads.

## .see also

- `prove.grove-backup-round-trip` — every code path, against a dir that stands in for the bucket
- `prove.grove-backup-live` — a live grove: the ✓, the bucket's units, a restore `--into` compared
  byte for byte
- `prove.grove-backup-scope-matches-infra` — the scope, clamped to infra's `GROVE_BACKUP_SCOPE`
- `rule.forbid.dox-in-public-repo` — why the bucket name is a pointer, never a literal
