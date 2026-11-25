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
| **its git**: every commit, branch, stash entry, and reflog tip origin's default branch and tags lack | `.grove-backup/objects.pack` — a plain git pack of what its refs and reflogs reach, minus each sha `git ls-remote origin HEAD 'refs/tags/*'` answers; `.grove-backup/refs.txt` names each ref |
| **its checkout state**: HEAD, the index, its reflogs, a rebase or merge mid-flight | `.grove-backup/checkout/` — this tree's own copy of its git dir's per-tree files |
| **its staged copies**: the index's blob of each staged file | `.grove-backup/staged/<path>` — no ref reaches them, so they ride apart |
| **its repo config**: remotes, upstreams, `info/exclude`, edited hooks | `.grove-backup/repo/` — every url with its credential stripped |
| **its changed files**: modified, staged, renamed, and untracked | the files themselves, laid at their paths |
| **its brain transcripts**: every conversation a clone held in this tree | `.agent/.actors/*/brain/.claude/` — the transcripts live IN the tree, so they ride in its unit |
| **its other git-ignored files** worth a keep: local notes, local config — never a credential | the files themselves |
| **its manifest** | `.grove-backup/meta.json`: kind, origin url, HEAD sha and branch, the deletes, the staged paths, each path cut as a credential, and whether origin answered and the pack was still. no host, no seat, no date |

⚠️ **a plain pack, never a `git bundle`.** a bundle refuses to exist when every ref tip is already
on origin, yet a commit only a reflog reaches still owes a ride.

⚠️ **"on origin" is asked of origin NOW**, by `ls-remote`, never of this box's own remote refs. a
branch origin dropped by a force-push since the last fetch still looks present here, and its
commits would be left out.

🛑 **a unit leans on origin's default branch and its tags, never on a branch.** a quiet unit never
asks origin again, so what it leans on must outlive the pass. a pr branch is deleted at merge, and
a squash merge leaves its commits on no branch: a unit that leaned on one lost each commit above it
with its status ✓. so a commit only a pr branch holds rides in the unit. a force-push to the default
branch is the one residual; the restore asks origin for each absent sha by name before it gives up.

🛑 **the transcripts weigh as much as the code.** they are the record each crew learns from, and
that loop is how the crews improve. so a transcript gets every guarantee a commit gets, and a test
clamps that it comes back byte for byte from its tree's unit alone.

never in a tree's unit:

- a tracked file that matches HEAD — HEAD rebuilds it. a file git flags `assume-unchanged` or
  `skip-worktree` is packed whole, since git would vouch for it falsely
- the rebuilt dirs: `node_modules` at any depth; `dist` `build` `coverage` `.next` where git
  ignores them
- a commit origin's default branch or a tag already holds
- 🛑 a plaintext credential, at any depth: each path of a credential's SHAPE
  (`GROVE_BACKUP_SECRET_SHAPES` — `.env*`, `*.pem`, `*.key`, `.npmrc`, `*.tfstate`, …), and each
  plain file whose CONTENT holds a private key or a token prefix (`GROVE_BACKUP_SECRET_CONTENT`).
  the manifest names each cut path, and the restore names each one, so the owner re-derives it
  through keyrack. the cut is of FILES by exact path: a dir named `credentials/` is source, and
  rides. every lane copied outside tar is cut by content too: the staged copies, and the repo
  lane (its hooks, its exclude, its config list). three residuals are named, never scanned: a `.jsonl` transcript (a cut would drop the
  conversation), the blobs of a commit only a reflog reaches (a secret committed, then amended
  away), and a nested repo's own `.git/config`

a repo with no origin packs every commit it holds, so naught depends on a remote that is not
there. an origin no restore reads (a relative path, an unknown scheme) packs the same way, named
on the journal, so the unit never fails over its url. an origin that does not answer is read from
this box's own view of it, and the unit packs again the next pass.

🛑 **every cut rule is folded into each unit's mark.** a quiet unit is never packed again, so a
widened list (a new shape, a new scope exclude) would reach only the trees that change. a mark made
under other rules reads as not quiet: each unit packs once under the new rules, and only one whose
bytes changed is put. the rules are the library's whole text plus the lists' live values: every
pack rule and every admit check lives in that one file, so membership is the file, never a name.
an edit there repacks each unit once, which fails toward the repack: a missed one would keep a cut
file, or an object the restore now refuses, on every quiet unit.

🛑 **a unit's latest object is the one the bucket received last** (its last-modified, which s3
stamps), never the key text a writer chose: a key dated ahead, from a wrong clock or another
writer, would otherwise win forever. a mark vouches for a unit only while it names that latest
object, so a unit whose latest is another's packs again, and its put becomes the latest.

⚠️ **a cut reaches only the objects put after it.** the bucket keeps every unit's prior keys, and
no grove's grant holds a delete. an object put before a cut rule landed may still hold the file it
cuts, until a human with delete rights lists the keys older than that day and purges each one
that holds a credential.

## .the trees that hold no git — orphans and set-asides

two shapes under `~/git` hold transcripts but no git state of their own. each rides as a
plain-file unit: every file, packed whole, with no git part. a plain-file unit takes the same
credential cut a tree takes, by shape and by content, and its manifest (`.grove-backup/meta.json`:
version, kind, the cut paths) lets the restore name each cut.

| unit | the tree | key |
|---|---|---|
| **orphan** | a `_worktrees/<dir>` with no `.git`, or a link git cannot read: git dropped the worktree, the dir stayed | `org=<org>/orphan=<dir>` |
| **set-aside** | `<clone>/.git/tree-del-setaside/<dir>`, a tree moved into its clone's git dir; or `_setaside/<repo>/<dir>`, where a restore laid one | `org=<org>/repo=<repo>/setaside=<name>` |

a `_worktrees/<dir>` whose `.git` is a DIR is a clone of its own (a `git clone` or a `restore
--into` pointed there). it rides as a clone, every branch with it, and a restore lays it at
`~/git/<org>/<dir>`. where a clone of that name already sits there, the two would share one key: its
files ride as an orphan, its commits ride in no unit, and the pass is ✗ and names the dir until it
is renamed.

a clone with initialized submodules rides, but each submodule's git dir sits at `.git/modules/<x>`,
which no unit carries. so the walk raises a gap row for it, and the pass is ✗ and names the clone
while one stands.

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

never in either: `~/.claude/.credentials.json`, `~/.rhachet/keyrack/vault/os.direct/`, and any
file the credential cut names. a plaintext credential in a bucket every grove reads is a credential
every grove holds; log in again after a restore.

naught else in the home rides. dotfiles come back from this repo's own bundles, and `~/.ssh` and
`~/.aws` are a box's own identity, never copied between boxes.

## .when

- the timer fires every 3 hours (`OnCalendar=0/3:00`); `Persistent=true`, so a run missed while
  the box was down fires on wake or boot. a dead grove is rare, so the 3-hour window at risk is
  worth eight quiet passes a day saved per box
- **a run takes the stalest unit first.** each unit records its own mark the moment it lands or is
  found quiet, so a run that stops early hands its tail to the front of the next
- **a quiet unit costs a metadata read.** a unit whose refs, HEAD, index, and reflog did not move,
  and in which no file's ctime moved since its mark, is skipped with no pack and no aws call. the
  ctime check skips the unit's top `.git` alone (the fingerprint reads it): a nested repo's
  `.git` is watched, so a commit there moves the unit
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
- **the window at risk** is the work since that unit's last put: one timer interval plus the
  pass's own length, which on a box that packs many trees runs past an hour. pushed commits are
  already safe in git
- **the disk is asked per unit**, of that unit's own bytes: a quiet unit stages naught, so a
  near-full disk still runs a quiet pass to ✓, and a unit whose bytes do not fit fails alone, named
- **a rebuild that keeps its name never shadows the dead grove.** a box writes a prefix that
  already holds objects only once it claimed it: its first pass on such a name is ✗, writes naught,
  and names the fix — as camper, restore `--from <name> --all`, then `grove-backup --adopt`. a fresh
  name, or a box that once ran a GOOD pass, passes straight through; a failed status never counts,
  since every early exit writes one

## .who reaches the bucket

🛑 **the grant enforces reach; this repo's conduct never does.** a box that misbehaves must be
stopped by aws, so each row below names what the grant allows, not what the agent chooses.

| principal | the bar (S8) | infra main today |
|---|---|---|
| a grove, as camper | put + read its own `grove=<slug>/` alone, for objects up to 90 days old; overwrite a key only on the day it names; never delete | ✗ one shared role reads, lists, and puts every grove's prefix |
| a grove, past 90 days | locked out: archived, and no restore-from-archive grant | ✗ archive at 180 days; groves hold `RestoreObject` |
| a replacement grove | read-only on its declared predecessor's prefix, to restore | ✗ reads it only through the shared role |
| the everyday sso tier | no read | ✗ PowerUserAccess reads |
| the admin tier | read, list, thaw, delete — all of it | ✓ |
| a laptop (`local@*`) | holds no grant, writes no unit | ✓ the bundle runs on `cloud@*` alone |

⇒ until infra lands its half, **any camp robot can read and list every grove's backups.** that
half is ahbode/infrastructure's: a per-grove identity, a prefix-scoped grant, a bucket policy, a
90-day archive with no grove thaw, and noncurrent versions kept by days, never by count.

this repo's half, built to the bar:

- the agent puts only `date=<today>` keys, under its own prefix
- a live unit whose latest object nears 90 days is put again, so a live tree stays self-restorable
- `restore --from` and `get --list` read only this grove's prefix and its declared predecessor; the
  fleet view and an archive thaw belong to the admin tier
- an `AccessDenied` reads as the grant's line, named; never as a fault of the box

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
| `⏳ a pass is at work · last ok 9h ago` | a long pass runs now; the age is the safe copy's |
| `✗ FAILED · <cause> · 4m · last ok 5d ago` | the last run failed; the cause names the fix, and `last ok` says how old the safe copy is |
| `✗ STALE · last ok 9h ago` | no good run in seven hours: two missed passes, plus an hour |
| `✗ STALE · never` | enrolled past its grace, and no pass has ever landed |
| `✗ NOT ENROLLED` | the timer is absent: apply the bundle |

## .restore it

on any grove, as camper, from this repo's checkout (`rhx` finds the skill there). it never
overwrites: a present clone takes the unit's branches fast-forward only, a present worktree is
kept, and a home dir keeps each file already there.

```sh
cd ~/git/more/dev-env-setup
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

a restore cut mid-lay leaves two marks that must agree: one beside its target, and its twin inside
the target's own git dir, which git lays at its first act. a rerun wipes and lays again only a
target that holds the twin; a mark beside a tree it never laid (a failed clone a human then cloned
by hand) is cleared, named, and the tree kept. ⚠️ the residual: a worktree cut in the instant between
`git worktree add` and its twin reads as present, and is kept hollow.

`--all` is a resume: a tree already here is kept, and the rest land. a diverged branch is never
moved; the unit's copy lands beside it as `<grove>/<branch>`.

⚠️ a conversation lists in `claude --resume` only from the dir it was held in, since each
`projects/` dir is keyed by that path. a tree restored in place keeps its path, so its
conversations list there. one laid aside (`--into`, or a set-aside under `_setaside/`) holds them
byte for byte, under the dead tree's path key, so they read as files but do not list from the
aside dir.

⚠️ the bucket keeps every object it is given: no current object expires, each changed day adds a
key per unit, and `home=.claude` re-puts whole. no grove's grant may prune, so growth is infra's to
bound (owed in the pr body).

an archived object (deep archive at 180 days today; at 90 under infra's S8 grant) takes a thaw.
where the grant lets this box thaw, the restore asks s3, says how long it waits (12–48h), and
finishes once the copy reads. where the grant refuses, the restore stops with a ✋ that names the
admin tier's `restore-object` command; once the admin runs it, the same restore lays the unit. a
quiet unit is put again before it ages 80 days, so its latest copy stays in reach.

### .prove a restore came back whole

lay it aside (`--into`), never over a live tree, then fingerprint both:

```sh
rhx grove.backup.restore --from <grove> --of <org/repo> --tree <dir> --into ~/restore-check/<dir>
rhx grove.backup.tree.fingerprint --path ~/restore-check/<dir>   # here
rhx grove.backup.tree.fingerprint --path ~/git/<…>/<dir>         # on the grove that wrote it
```

equal digests = the tree came back whole: its HEAD, its checked-out branch, and each uncommitted
file by content (a symlink by its target, since a link to `~/.claude/settings.json` reaches each
box's own file). branches and stash print beside it, outside the digest, since a clone shares them
across its worktrees. three differences are expected, and none is a loss:

- a file the live tree changed after the pass that packed it: run the pass first, and read its
  age with `/usr/local/lib/grove-backup/grove-backup --line`
- a cut credential file: absent by design; the restore names each one
- an ignored build dir outside the kept list: never packed

🛑 **a unit is untrusted input.** every grove's role may write every grove's prefix, so the restore
validates what a unit names before it lays one byte:

- a unit id outside the four shapes a pass writes, or a field that is `.`, `..`, or no plain name,
  is refused and named — so no unit lays outside `~/git` or a backed-up home dir
- a tree unit's own paths and fields are checked too (`grove_backup_unit_manifest_is_valid`): no
  file under `.git/`, no delete that leaves the tree, a `head_sha` and `head_ref` of git's own
  shape, an `origin` that cannot read as a flag; and no file lays through a link HEAD's checkout
  put down
- `refs.txt` is admitted by its grammar, since each ref reaches git as an argument: a 40- or
  64-hex sha, then `HEAD`, `refs/stash`, or a plain branch or tag (no part opens with `-` or `.`,
  no `..`, no control byte). a planted `--upload-pack=…` there ran a command, measured, before
  this check; the one fetch by sha also carries `--end-of-options`. `head_ref` meets the same
  grammar, and `worktree add` ends its options with `--`
- every member of `.grove-backup` is a plain file or dir (`grove_backup_unit_members_are_plain`),
  since each step that reads one follows a link. a planted `repo/hooks` link to `~/.ssh` laid
  camper's key into the clone's hooks, measured, for the next pass to carry to the bucket. the
  writer copies each hook's and exclude's CONTENT, so a linked hook still rides, as its bytes, and
  asks the same check of its own stage before the put
- every row passes one sink that strips control bytes, C0 and C1 alike (`rows_flush`), so no text
  a unit carries (a kept path, an origin, a branch) can forge a row or move the cursor
- every unit opens through one door (`restore_unit_open`), so a files unit (home, orphan,
  set-aside) is checked as a tree unit is: no path leaves its dir, and none sits under a top-level
  `.git`. an orphan lands where the walk reads `.git` as a repo, so a planted one would run its
  config on the next pass
- writer and reader ask one question of one set (`grove_backup_unit_admit`): the pack unpacks the
  tar it built and admits it before the put, so a ✓ never stands on a unit the restore would
  refuse. a name with a newline, under any dir, fails its pack, named. the disk ask counts that
  third copy
- only a branch upstream or remote key is set, and only with the value a pass writes
  (`grove_backup_config_entry_is_carried`): origin's url equals the unit's own origin, a remote url
  is a plain url, an upstream is a remote name, a fetch refspec lands under `refs/remotes/`. a key
  that runs a command (`core.sshCommand`, `core.fsmonitor`, `alias.*`, `remote.*.uploadpack`) or
  turns a push into a force-push (`remote.*.push`) is dropped and named
- a clone already here is the human's own: a worktree restore adds only a config key it lacks and
  an exclude line it lacks, and changes none it holds
- every other git dir a unit holds — a nested repo, a worktree's admin dir, a bare-shaped dir,
  found by shape and never by name — lands inert (`restore_unit_defuse`): its config keeps the
  format keys and the remote facts above, held to its own origin; each hook lands NOT executable;
  a linked config or hook is dropped. a nested repo still opens and fetches
- the shape is git's own: a `HEAD` that is a file OR a link, since git reads a link `HEAD`. the
  defuse runs twice, on the unit's stage and then on the laid DESTINATION after checkout, pruned
  of the tree's own `.git`, since a commit can lay a git dir a gitfile in the unit points at
- the set is closed over git's own pointer: each `commondir` is followed where git follows it,
  and the dir it names (where git reads config and hooks, with no `HEAD` of its own) is made inert
  too; a `commondir` that leaves the tree is dropped and named
- every file a unit lays goes through one step (`restore_lay_path`): it asks, as it writes,
  whether a dir on the way is a link, and keeps the file, named, if so; then it stages the copy
  beside the leaf and renames it in. a link one unit laid (a planted commit, a prior run) carries
  no later unit's file out of the tree. the checkout lay asks the same check of the whole unit
  before its one `tar`
- every git-state entry a unit lays (`HEAD`, `index`, a reflog, a rebase dir, `info/exclude`)
  goes through one step (`restore_lay_git_state`): it holds the copy before the prior entry
  goes, so a copy that fails (an unreadable member, a full disk) leaves the tree's own `HEAD` and
  `index` in place, fails the unit by name, and keeps its laid-in-part mark. the pack asks each
  of its stage copies the same, and a copy it cannot make fails the pack, named
- the restore's own git acts run no hook (`core.hooksPath=/dev/null`): a checkout, a merge, a
  fetch would otherwise run a hook a present clone's `hooksPath` names in the unit's own commit
- a files unit never lays a scope exclude (`~/.claude/.credentials.json`): no backup carries one,
  so a unit that holds one was planted; it is named, and this box's own is placed by a login
- the bucket list is read as json and admitted row by row (`grove_backup_s3_list_rows`): a key
  with a control byte, a last-modified or a class outside its shape, is dropped and named, so no
  key can forge the column latest is chosen by; a prefix lists as a grove only if `--from` would
  accept its slug
- every scratch dir is cleared by one step that lifts a `0555` dir's write first, and fails
  named if aught survives, so one read-only dir never poisons each later unit
- a mid-rebase tree's `exec` lines land as comments, named, since `git rebase --continue` runs
  each; `git rebase --edit-todo` restores the ones a human trusts
- a hook lands NOT executable, named, with the `chmod +x` that arms it once a human has read it
- a unit version this restore cannot read is refused, never guessed, for a files unit's manifest
  as for a tree unit's; every version a pass ever wrote stays readable (`GROVE_BACKUP_UNIT_VERSIONS_READ`, each held by a golden object)

## .see also

- `prove.grove-backup-round-trip` — every code path, against a dir that stands in for the bucket
- `prove.grove-backup-live` — a live grove: the ✓, the bucket's units, a restore `--into` compared
  byte for byte
- `prove.grove-backup-scope-matches-infra` — the scope, clamped to infra's `GROVE_BACKUP_SCOPE`
- `rule.forbid.dox-in-public-repo` — why the bucket name is a pointer, never a literal
