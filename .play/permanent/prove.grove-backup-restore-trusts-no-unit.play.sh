#!/usr/bin/env bash
######################################################################
# .what = a restore lays naught a unit names outside the shapes a backup writes
#
# .why  every grove's role may write every grove's prefix (infra's grant), so a
#   unit is untrusted input. a probe planted `home=.ssh` under a grove, and
#   `--all` laid `~/.ssh/authorized_keys`; a unit's `config.list` set
#   `alias.*`, `core.sshCommand`, and `core.fsmonitor` (peer i005, measured)
#
# .the cases
#   1. a unit id outside the four shapes (`home=.ssh`, a `..` field) is refused,
#      named, and lays no file — under `--all` and when named
#   2. only an allowed config key, with a value of the shape a pass writes, is set; each
#      other is dropped and named (peer i008: a forged origin url, a `+` push refspec, a
#      url upstream). a live clone keeps its own keys and exclude, and gains only what it lacks
#   3. a hook lands NOT executable, named, with the command that arms it
#   4. GNU tar never writes a member through a symlink the same archive laid
#   5. a tree unit's own paths and fields (peer i006): a file under `.git/`, a delete
#      that leaves the tree, a head_sha or head_ref of no git shape, an origin that reads
#      as a flag, and a file that would lay through a link HEAD's checkout put down —
#      each refused, named, before a byte lays
#   6–9. a files unit's door, a dead origin, refs.txt's grammar, git-run code laid inert
#   10. a member of .grove-backup is a plain file or dir, asked by the reader and the writer
#      alike (peer i012): a link there is refused; a linked hook packs as its content; a
#      token in a hook is cut, named; one sink strips control bytes; the digest gathers every
#      pack function by name; latest is the object the bucket received last
#   11–14. the defuse, git's pointers, a failed git-state copy, a guard held in both lanes
#   15. a lay forks no subshell per path depth: its dir read agrees with dirname, and the
#      per-path steps hold no command substitution (an 8 GiB `.claude` outran 600s at ~15
#      forks a file)
######################################################################
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE="$HERE/src/grove.provision/5.devtools/5.27.backup"

fixture="$(mktemp -d)"
# a planted 0555 dir must not leak this play's fixture: lift write before the remove
trap 'chmod -R u+rwX "$fixture" 2>/dev/null; rm -rf "$fixture"' EXIT
ME="$(id -un)"

failed=0
pass() { echo "   • $1 ✔"; }
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }
claim() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }

echo "🌲 prove.grove-backup-restore-trusts-no-unit"

# shellcheck source=/dev/null
source "$BUNDLE/grove-backup"
# shellcheck source=/dev/null
source "$HERE/.agent/repo=.this/role=any/skills/grove.backup.restore.sh"

# the box facts and the s3 seam, pointed at a fixture
BUCKET="$fixture/bucket"
mkdir -p "$BUCKET" "$fixture/etc"
grove_backup_name_file()   { printf '%s' "$fixture/etc/name"; }
grove_backup_bucket_file() { printf '%s' "$fixture/etc/bucket"; }
GROVE_BACKUP_DISK_FLOOR_KB=0
grove_backup_s3_whoami() { return 0; }
grove_backup_s3_list() {
  local prefix="$1" out="$2" f key
  : >"$out"
  while IFS= read -r f; do
    key="${f#"$BUCKET"/}"
    [[ "$key" == "$prefix"* ]] || continue
    printf '%s\t%s\t%s\n' "$key" "$(date -u -r "$f" +%FT%T+00:00)" STANDARD >>"$out"
  done < <(find "$BUCKET" -type f -name '*.tar.gz' | sort)
}
grove_backup_s3_get() { cp "$BUCKET/$1" "$2"; }
printf 'grove-1\n' >"$fixture/etc/name"
printf 'fixture-bucket\n' >"$fixture/etc/bucket"

# a planted object: any tar, under any key
plant_unit() {
  local key="grove=grove-1/$1/date=2026-11-21.tar.gz" src="$fixture/plant.$RANDOM"
  mkdir -p "$src" "$(dirname "$BUCKET/$key")"
  printf 'ssh-ed25519 AAAA attacker\n' >"$src/authorized_keys"
  tar -czf "$BUCKET/$key" -C "$src" .
}

######################################################################
# 1. a unit id outside the shapes a backup writes
######################################################################
plant_unit "user=$ME/home=.ssh"
plant_unit "user=$ME/org=acme/repo=../tree=.."
fresh="$fixture/fresh/$ME"; mkdir -p "$fresh"
( HOME="$fresh"; restore_main --from grove-1 --all ) >"$fixture/out" 2>&1; rc=$?
claim "--all · a home unit outside the backed-up home dirs lays no file" test ! -e "$fresh/.ssh/authorized_keys"
claim "--all · a unit with a .. field lays no file outside ~/git" test ! -e "$fresh/authorized_keys" -a ! -e "$fresh/git/authorized_keys"
claim "--all · each is refused, named, and the run exits 2" \
  test "$rc" -eq 2 -a "$(grep -c "outside every shape a backup writes" "$fixture/out")" -eq 2
( HOME="$fresh"; restore_main --from grove-1 --of acme/.. --tree .. ) >"$fixture/out.named" 2>&1; rc=$?
claim "named · a .. field is refused before any read, exit 2" \
  test "$rc" -eq 2 -a "$(grep -c "names no unit a backup writes" "$fixture/out.named")" -eq 1
plant_unit "user=$ME/org=acme/repo=x"$'\e'"[31m/tree=y"
s3def="$(declare -f grove_backup_s3_list grove_backup_s3_whoami)"
( source "$HERE/.agent/repo=.this/role=any/skills/grove.backup.get.sh"; eval "$s3def"
  GET_TMP="$fixture/get"; mkdir -p "$GET_TMP"; print_units grove-1 ) >"$fixture/out.get" 2>&1
claim "get · each id outside the shapes is listed as refused" \
  test "$(grep -c 'refused: no shape a pass writes' "$fixture/out.get")" -eq 3
claim "get · no raw control byte from a key reaches the terminal" bash -c "! grep -q \$'\\e' '$fixture/out.get'"
# the refused rows, every byte a human reads: the seat and the fixture masked
# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.grove-backup-restore-trusts-no-unit.snap" name=get.refused \
  actual="$(sed -e "s#$fixture#<fixture>#g" -e "s#user=$ME/#user=<seat>/#g" "$fixture/out.get")" || failed=1
claim "valid · each of the four shapes a pass writes reads valid" bash -c '
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  grove_backup_unit_is_valid "user=camper/home=.claude" &&
  grove_backup_unit_is_valid "user=camper/org=acme/orphan=widget.feat-y" &&
  grove_backup_unit_is_valid "user=camper/org=acme/repo=widget/setaside=widget.0a1b2c3d" &&
  grove_backup_unit_is_valid "user=camper/org=acme/repo=widget/tree=widget.feat-x"'

######################################################################
# 2. the repo config: only an allowed key is set
######################################################################
WORK="$fixture/work"; mkdir -p "$WORK"
u="$fixture/u"; mkdir -p "$u/.grove-backup/repo/hooks"
jq -n '{ origin: "https://example.com/acme/widget.git" }' >"$u/.grove-backup/meta.json"
printf '%s\n' 'branch.main.remote origin' 'branch.main.merge refs/heads/main' \
  'remote.origin.url https://example.com/acme/widget.git' \
  'alias.pwn !echo pwned' 'core.sshCommand sh -c id' 'core.fsmonitor /bin/true' 'remote.origin.uploadpack sh -c id' \
  'remote.origin.url https://evil.example/acme/widget.git' 'remote.origin.push +refs/heads/*:refs/heads/*' \
  'branch.feat.remote https://evil.example/y.git' 'remote.upstream.url ext::sh -c id' \
  >"$u/.grove-backup/repo/config.list"
printf 'unit-line\n' >"$u/.grove-backup/repo/exclude"
printf '#!/bin/sh\necho hooked\n' >"$u/.grove-backup/repo/hooks/pre-commit"
chmod +x "$u/.grove-backup/repo/hooks/pre-commit"
r="$fixture/r"; git init -q "$r"
ROWS=()
restore_tree_repo_state "$u" "$r" "$r/.git"
rows="$(printf '%s\n' "${ROWS[@]}")"
claim "config · an allowed key is set" test "$(git -C "$r" config --get branch.main.remote)" == origin
claim "config · no key that runs a command is set" bash -c "[[ -z \"\$(git -C '$r' config --get alias.pwn)\" && -z \"\$(git -C '$r' config --get core.sshCommand)\" && -z \"\$(git -C '$r' config --get core.fsmonitor)\" && -z \"\$(git -C '$r' config --get remote.origin.uploadpack)\" ]]"
claim "config · origin's url is the unit's own origin, and only that" \
  test "$(git -C "$r" config --get-all remote.origin.url)" == https://example.com/acme/widget.git
claim "config · no push refspec, no url upstream, no ext:: remote is set" bash -c "[[ -z \"\$(git -C '$r' config --get remote.origin.push)\" && -z \"\$(git -C '$r' config --get branch.feat.remote)\" && -z \"\$(git -C '$r' config --get remote.upstream.url)\" ]]"
claim "config · the eight dropped keys are named" grep -q '8 config keys dropped' <<<"$rows"

# a live clone the human already holds: their config and exclude are kept
rl="$fixture/rl"; git init -q "$rl"
git -C "$rl" config remote.origin.url https://mine.example/own.git
git -C "$rl" config branch.main.remote mine
printf 'mine-only\n' >"$rl/.git/info/exclude"
ROWS=()
restore_tree_repo_state "$u" "$rl" "$rl/.git" present
claim "live · its own origin url is kept" test "$(git -C "$rl" config --get-all remote.origin.url)" == https://mine.example/own.git
claim "live · its own upstream is kept" test "$(git -C "$rl" config --get-all branch.main.remote)" == mine
claim "live · a key it lacks is added" test "$(git -C "$rl" config --get branch.main.merge)" == refs/heads/main
claim "live · its exclude keeps its own line and gains the unit's" bash -c "grep -qx mine-only '$rl/.git/info/exclude' && grep -qx unit-line '$rl/.git/info/exclude'"

######################################################################
# 3. a hook lands, never armed
######################################################################
claim "hook · it lands" test -f "$r/.git/hooks/pre-commit"
claim "hook · it is NOT executable" test ! -x "$r/.git/hooks/pre-commit"
claim "hook · it is named, with the command that arms it" grep -q "hook pre-commit laid, NOT executable: read it, then arm it: chmod +x $r/.git/hooks/pre-commit" <<<"$rows"

######################################################################
# 4. GNU tar never writes THROUGH a symlink the same archive laid
######################################################################
victim="$fixture/victim"; mkdir -p "$victim" "$fixture/t/a" "$fixture/t/b"
ln -s "$victim" "$fixture/t/a/sym"
printf 'x\n' >"$fixture/t/b/pwn"
tar -cf "$fixture/evil.tar" -C "$fixture/t/a" sym
tar -rf "$fixture/evil.tar" -C "$fixture/t/b" --transform 's,^pwn,sym/pwn,' pwn
mkdir -p "$fixture/x"
tar -xf "$fixture/evil.tar" -C "$fixture/x" 2>/dev/null
claim "tar · a member is not written through a symlink the archive laid" test ! -e "$victim/pwn"

######################################################################
# 5. a tree unit's own paths and manifest fields
######################################################################
gx() { git -c user.name=t -c user.email=t@example.com -c init.defaultBranch=main "$@"; }
# an origin whose HEAD tracks a link out of the tree: `evil -> <victim>`
origin="$fixture/origin/widget.git"; gx init -q --bare "$origin"
seed="$fixture/seed"; gx clone -q "$origin" "$seed" 2>/dev/null
printf 'readme\n' >"$seed/README.md"; ln -s "$victim" "$seed/evil"
gx -C "$seed" add -A && gx -C "$seed" commit -qm base && gx -C "$seed" push -q origin main 2>/dev/null
head_sha="$(gx -C "$seed" rev-parse HEAD)"
# a planted tree unit: <tree> <meta overrides as jq> <files to lay, rel=content ...>
plant_tree() {
  local tree="$1" patch="$2" src="$fixture/tree.$RANDOM" kv
  local key="grove=grove-1/user=$ME/org=acme/repo=widget/tree=$tree/date=2026-11-21.tar.gz"
  shift 2
  mkdir -p "$src/.grove-backup" "$(dirname "$BUCKET/$key")"
  jq -n --arg o "$origin" --arg h "$head_sha" "{ version: 2, kind: \"worktree\", head_sha: \$h, head_ref: \"refs/heads/main\",
     origin: \$o, origin_checked: true, deletes: [], staged: [], cut: [], point_in_time: true } | $patch" \
    >"$src/.grove-backup/meta.json"
  # what a pass writes beside the manifest: a pack (empty: origin holds HEAD) and its refs
  git pack-objects -q --stdout </dev/null >"$src/.grove-backup/objects.pack"
  : >"$src/.grove-backup/refs.txt"
  for kv in "$@"; do mkdir -p "$(dirname "$src/${kv%%=*}")"; printf '%s\n' "${kv#*=}" >"$src/${kv%%=*}"; done
  tar -czf "$BUCKET/$key" -C "$src" .
}
tree_refused() { # <tree> <why>
  local seat="$fixture/t5.$1/$ME"; mkdir -p "$seat"
  ( HOME="$seat"; restore_main --from grove-1 --of acme/widget --tree "$1" ) >"$fixture/out.$1" 2>&1
  grep -q "$2" "$fixture/out.$1" || { sed 's/^/      │ /' "$fixture/out.$1" >&2; return 1; }
}
printf 'keep me\n' >"$fixture/keep.txt"
plant_tree widget.githook '.' '.git/hooks/pre-commit=echo pwned'
# the worktree lays at <fixture>/t5.widget.escape/<me>/git/acme/_worktrees/widget.escape: six up is the fixture
plant_tree widget.escape ".deletes = [\"../../../../../../keep.txt\"]"
plant_tree widget.badsha '.head_sha = "HEAD~1"'
plant_tree widget.badref '.head_ref = "refs/remotes/../../x"'
plant_tree widget.badorigin '.origin = "--upload-pack=touch /tmp/pwn"'
plant_tree widget.throughlink '.' 'evil/pwn=x'
claim "unit · a file under .git is refused" tree_refused widget.githook "a file it lays reaches .git"
claim "unit · a delete that leaves the tree is refused" tree_refused widget.escape "a delete leaves the tree or reaches .git"
claim "unit · the file outside the tree is untouched" test -f "$fixture/keep.txt"
claim "unit · a head_sha that is no commit id is refused" tree_refused widget.badsha "head_sha is no commit id"
claim "unit · a head_ref that is no branch is refused" tree_refused widget.badref "head_ref is no branch ref"
claim "unit · an origin that reads as a flag is refused" tree_refused widget.badorigin "origin is no plain git url"
claim "unit · a file that would lay through a link HEAD laid is refused" tree_refused widget.throughlink "would lay through a link in this checkout"
claim "unit · naught lands through that link" test ! -e "$victim/pwn"
# this shell drove restore_tree_repo_state by hand above, and left its rows: a run prints only its own
claim "rows · a run never prints rows a caller left behind" \
  test "$(grep -c '8 config keys dropped' "$fixture/out.widget.githook")" -eq 0

######################################################################
# 6. a files unit opens through the same door (peer i008): an orphan with a `.git`
######################################################################
marker="$fixture/uploadpack.ran"
psrc="$fixture/orphan.plant"; mkdir -p "$psrc/.git/objects" "$psrc/.git/refs/heads"
printf 'ref: refs/heads/main\n' >"$psrc/.git/HEAD"
printf '[remote "origin"]\n\turl = /nowhere\n\tuploadpack = touch %s\n[core]\n\tsshCommand = touch %s\n' "$marker" "$marker" >"$psrc/.git/config"
printf 'note\n' >"$psrc/notes.md"
okey="grove=grove-1/user=$ME/org=acme/orphan=widget.planted/date=2026-11-21.tar.gz"
mkdir -p "$(dirname "$BUCKET/$okey")"; tar -czf "$BUCKET/$okey" -C "$psrc" .
oseat="$fixture/t6/$ME"; mkdir -p "$oseat"
( HOME="$oseat"; restore_main --from grove-1 --orphan acme/widget.planted ) >"$fixture/out.orphan" 2>&1
claim "orphan · a unit with a top-level .git is refused, named" grep -q "a file it lays reaches .git" "$fixture/out.orphan"
claim "orphan · naught of it is laid" test ! -e "$oseat/git/acme/_worktrees/widget.planted"
( HOME="$oseat"; grove_backup_units_walk ) >"$fixture/walk.orphan" 2>/dev/null
claim "orphan · the next walk finds no repo to run git in, and the marker never ran" \
  bash -c "! grep -q widget.planted '$fixture/walk.orphan' && test ! -e '$marker'"

# the walk: a clone of its own under _worktrees rides as a clone, every branch with it
wseat="$fixture/t7/$ME"; mkdir -p "$wseat/git/acme/_worktrees"
gx clone -q "$origin" "$wseat/git/acme/_worktrees/widget.copy" 2>/dev/null
gx -C "$wseat/git/acme/_worktrees/widget.copy" branch side
( HOME="$wseat"; grove_backup_units_walk ) >"$fixture/walk.clone" 2>/dev/null
claim "walk · a .git dir under _worktrees rides as a clone, never repo=_unlinked" \
  bash -c "grep -qP '^clone\t.*\tuser=$ME/org=acme/repo=widget.copy/tree=widget.copy\$' '$fixture/walk.clone' && ! grep -q _unlinked '$fixture/walk.clone'"
mkdir -p "$wseat/git/acme/_worktrees/widget.lost"
printf 'gitdir: %s/git/acme/widget/.git/worktrees/widget.lost\n' "$wseat" >"$wseat/git/acme/_worktrees/widget.lost/.git"
( HOME="$wseat"; grove_backup_units_walk ) >"$fixture/walk.lost" 2>/dev/null
claim "walk · a link of the right shape whose clone is gone rides as an orphan" \
  grep -qP "^orphan\t.*\tuser=$ME/org=acme/orphan=widget.lost\$" "$fixture/walk.lost"
claim "walk · a clone of its own keeps every branch, not HEAD's alone" bash -c '
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  grove_backup_tree_refs "'"$wseat"'/git/acme/_worktrees/widget.copy" clone | grep -q refs/heads/side'

######################################################################
# 7. a cut restore's mark never wipes a tree it did not lay (peer i009)
######################################################################
plant_tree widget '.origin = "/nonexistent/none.git"'
mseat="$fixture/t8/$ME"; mkdir -p "$mseat"
mclone="$mseat/git/acme/widget"
( HOME="$mseat"; restore_main --from grove-1 --of acme/widget --tree widget ) >"$fixture/out.markfail" 2>&1
claim "mark · a clone that fails clears its mark with its dir" test ! -e "$mclone.grove-restore.unfinished" -a ! -e "$mclone"
claim "clone · a dead origin is named, with its rerun" bash -c "grep -q 'origin could not be cloned: /nonexistent/none.git' '$fixture/out.markfail' && grep -q 'rerun once origin answers' '$fixture/out.markfail'"
# a private origin with no credential: git asks for a login it may not prompt for. the unit
#   names that same https origin, so the header and git's own words cite one url
plant_tree widget '.origin = "https://example.com/acme/widget.git"'
( HOME="$mseat"; timeout() { if [[ "$*" == *" clone "* ]]; then echo "fatal: could not read Username for 'https://example.com': terminal prompts disabled" >&2; return 128; fi; command timeout "$@"; }
  restore_main --from grove-1 --of acme/widget --tree widget ) >"$fixture/out.authfail" 2>&1
claim "clone · a credential that did not answer names the creds check, not a bare rerun" \
  grep -q "this grove's git credential did not answer: from the laptop, rhx git.grove.ready.verify grove-1 --from 5" "$fixture/out.authfail"
claim "clone · the auth refusal names the one origin the unit holds" \
  bash -c '! grep -q "/nonexistent/none.git" "$1" && grep -q "https://example.com/acme/widget.git" "$1"' _ "$fixture/out.authfail"
plant_tree widget '.origin = "/nonexistent/none.git"'
# a human clones by hand where it failed, and works there; a stale mark sits beside it
gx clone -q "$origin" "$mclone" 2>/dev/null
printf 'mine\n' >"$mclone/human.txt"
gx -C "$mclone" add human.txt && gx -C "$mclone" commit -qm 'human work'
printf 'grove=grove-1/x deadbeef\n' >"$mclone.grove-restore.unfinished"
( HOME="$mseat"; grove_backup_units_walk ) >"$fixture/walk.mark" 2>"$fixture/walk.mark.err"
claim "mark · the walk rides a tree whose mark it never laid, and says so" \
  bash -c "grep -q 'repo=widget/tree=widget\$' '$fixture/walk.mark' && grep -q 'not what that restore laid' '$fixture/walk.mark.err'"
( HOME="$mseat"; restore_main --from grove-1 --of acme/widget --tree widget ) >"$fixture/out.markstale" 2>&1
claim "mark · a rerun keeps the human's clone, its unpushed commit whole" \
  bash -c "[[ \"\$(git -C '$mclone' log --format=%s -1)\" == 'human work' && -f '$mclone/human.txt' ]]"
claim "mark · the stale mark is cleared, and named" \
  bash -c "test ! -e '$mclone.grove-restore.unfinished' && grep -q 'which that restore did not lay' '$fixture/out.markstale'"

######################################################################
# 8. refs.txt is admitted by its grammar, before any lay reads it (peer i011)
######################################################################
upmark="$fixture/refs.uploadpack.ran"
plant_refs() { # <tree> <the refs.txt body>
  local tree="$1" key="grove=grove-1/user=$ME/org=acme/repo=widget/tree=$1/date=2026-11-21.tar.gz" src="$fixture/refs.$RANDOM"
  mkdir -p "$src/.grove-backup" "$(dirname "$BUCKET/$key")"
  jq -n --arg o "$origin" --arg h "$head_sha" '{ version: 2, kind: "clone", head_sha: $h, head_ref: "refs/heads/main",
     origin: $o, origin_checked: true, deletes: [], staged: [], cut: [], point_in_time: true }' >"$src/.grove-backup/meta.json"
  git pack-objects -q --stdout </dev/null >"$src/.grove-backup/objects.pack"
  printf '%s\n' "$2" >"$src/.grove-backup/refs.txt"
  tar -czf "$BUCKET/$key" -C "$src" .
}
# shellcheck disable=SC2016 # the ${IFS} is the attack's own text, never this shell's
plant_refs widget.refopt '--upload-pack=touch${IFS}'"$upmark"';true refs/heads/x'
plant_refs widget.refesc "$head_sha refs/heads/x"$'\e'"[31m"
plant_refs widget.refdash "$head_sha refs/heads/--upload-pack=x"
claim "refs · a sha that reads as an option is refused, named" tree_refused widget.refopt "is no '<sha> <ref>' pair"
claim "refs · its --upload-pack never ran" test ! -e "$upmark"
claim "refs · a ref with a control byte is refused, named" tree_refused widget.refesc "names a ref no pass writes"
claim "refs · no raw control byte reaches the terminal" bash -c "! grep -q \$'\\e' '$fixture/out.widget.refesc'"
claim "refs · a ref part that opens with '-' is refused, named" tree_refused widget.refdash "names a ref no pass writes"
claim "refs · each ref a pass writes reads valid" bash -c '
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  for r in HEAD refs/stash refs/heads/main refs/heads/feat/x-1 refs/tags/v1.2.3 refs/heads/ünï; do
    grove_backup_unit_ref_is_valid "$r" || exit 1
  done
  for r in refs/heads/-x refs/heads/a..b refs/heads/.x refs/heads/x.lock refs/remotes/o/x "refs/heads/a b" refs/heads/a~1; do
    grove_backup_unit_ref_is_valid "$r" && exit 1
  done
  exit 0'

claim "url · a credential leaves each url, and an ssh login stays" bash -c '
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  while IFS="|" read -r given want; do
    [[ "$(grove_backup_url_clean "$given")" == "$want" ]] || { echo "      │ $given → $(grove_backup_url_clean "$given")" >&2; exit 1; }
  done <<TABLE
https://user:tok@example.com/o/r.git|https://example.com/o/r.git
https://tok@example.com/o/r.git|https://example.com/o/r.git
git://u@example.com/o/r|git://example.com/o/r
ssh://git@example.com/o/r.git|ssh://git@example.com/o/r.git
ssh://git:pw@example.com/o/r.git|ssh://git@example.com/o/r.git
ssh://example.com/o/r.git|ssh://example.com/o/r.git
git@example.com:o/r.git|git@example.com:o/r.git
/srv/o/r.git|/srv/o/r.git
TABLE'
# the digest is the library's own text: an edit to ANY rule in it, a cut or an admit, moves it
#   (peer i014). each edit lands in a copy, so the claim reads the text the agent would source
digest_after_edit() { # <function whose body gains a no-op line>
  local copy="$fixture/lib.edit.$1.sh"
  sed "s/^$1() {\$/&\\n  :/" "$BUNDLE/grove.backup.operations.sh" >"$copy"
  grep -qx '  :' "$copy" || { echo "      │ $1 holds no line to edit" >&2; return 1; }
  bash -c 'source "$1"; grove_backup_pack_rules_digest' _ "$copy"
}
digest_moves_on_each_edit() {
  local base f after
  base="$(bash -c 'source "$1"; grove_backup_pack_rules_digest' _ "$BUNDLE/grove.backup.operations.sh")"
  [[ -n "$base" ]] || return 1
  for f in grove_backup_url_clean grove_backup_unit_rel_is_valid grove_backup_unit_manifest_is_valid \
           grove_backup_unit_ref_is_valid grove_backup_dir_is_rebuilt grove_backup_staged_secret_cuts; do
    after="$(digest_after_edit "$f")" || return 1
    [[ -n "$after" && "$after" != "$base" ]] || { echo "      │ an edit to $f did not move the digest" >&2; return 1; }
  done
}
claim "digest · an edit to a cut rule, an admit rule, or a ref rule moves it" digest_moves_on_each_edit

######################################################################
# 9. git-run code a unit carries lands inert: a rebase todo's exec, a nested git dir (peer i011)
######################################################################
execmark="$fixture/rebase.exec.ran"
nestmark="$fixture/nested.fsmonitor.ran"
hookmark="$fixture/nested.hook.ran"
# a real mid-rebase state: stopped at `break`, with a pick and an `exec` still to run
rb="$fixture/rb"; gx clone -q "$origin" "$rb" 2>/dev/null
printf 'two\n' >"$rb/two.txt"; gx -C "$rb" add two.txt && gx -C "$rb" commit -qm two && gx -C "$rb" push -q origin main 2>/dev/null
GIT_SEQUENCE_EDITOR="sed -i '1i break'" gx -C "$rb" rebase -q -i --exec "touch $execmark" HEAD~1 >/dev/null 2>&1
rb_head="$(gx -C "$rb" rev-parse HEAD)"
rsrc="$fixture/rebase.plant"; mkdir -p "$rsrc/.grove-backup/checkout" "$rsrc/sub/.git/refs/heads" "$rsrc/sub/.git/objects" "$rsrc/sub/.git/hooks"
cp -a "$rb/.git/rebase-merge" "$rsrc/.grove-backup/checkout/rebase-merge"
printf '%s\n' "$rb_head" >"$rsrc/.grove-backup/checkout/HEAD"
jq -n --arg o "$origin" --arg h "$rb_head" '{ version: 2, kind: "clone", head_sha: $h, head_ref: null,
   origin: $o, origin_checked: true, deletes: [], staged: [], cut: [], point_in_time: true }' >"$rsrc/.grove-backup/meta.json"
git pack-objects -q --stdout </dev/null >"$rsrc/.grove-backup/objects.pack"
: >"$rsrc/.grove-backup/refs.txt"
# a nested repo in the tree's files, whose config and hook would run on its first git act
printf 'ref: refs/heads/main\n' >"$rsrc/sub/.git/HEAD"
printf '[core]\n\trepositoryformatversion = 0\n\tfsmonitor = touch %s\n[remote "origin"]\n\turl = https://example.com/acme/sub.git\n' "$nestmark" >"$rsrc/sub/.git/config"
printf '#!/bin/sh\ntouch %s\n' "$hookmark" >"$rsrc/sub/.git/hooks/post-checkout"; chmod +x "$rsrc/sub/.git/hooks/post-checkout"
rkey="grove=grove-1/user=$ME/org=acme/repo=widget/tree=widget/date=2026-11-21.tar.gz"
rm -rf "$(dirname "$BUCKET/$rkey")"; mkdir -p "$(dirname "$BUCKET/$rkey")"; tar -czf "$BUCKET/$rkey" -C "$rsrc" .
rseat="$fixture/t9/$ME"; mkdir -p "$rseat"
( HOME="$rseat"; restore_main --from grove-1 --of acme/widget --tree widget ) >"$fixture/out.defuse" 2>&1
rlaid="$rseat/git/acme/widget"
claim "rebase · the dead tree's mid-rebase state lands" test -d "$rlaid/.git/rebase-merge"
( cd "$rlaid" && GIT_EDITOR=true gx rebase --continue ) >/dev/null 2>&1
claim "rebase · --continue runs no exec line the unit carried" test ! -e "$execmark"
claim "rebase · the held line is named, with the act that restores it" grep -q "2 exec lines of a rebase held as a comment.*git rebase --edit-todo" "$fixture/out.defuse"
( cd "$rlaid/sub" && gx status ) >/dev/null 2>&1
( cd "$rlaid/sub" && gx checkout -q -b probe ) >/dev/null 2>&1
claim "nested · its config runs no command on a git act" test ! -e "$nestmark"
claim "nested · its hook lands NOT executable, and never runs" test ! -x "$rlaid/sub/.git/hooks/post-checkout" -a ! -e "$hookmark"
claim "nested · its own origin is kept" test "$(gx -C "$rlaid/sub" config --get remote.origin.url)" == https://example.com/acme/sub.git
claim "nested · it is named, with the act that arms a hook" bash -c "grep -q '1 nested git dir laid inert: 1 config key cut' '$fixture/out.defuse' && grep -q '1 hook of a nested git dir laid NOT executable: read each, then arm it' '$fixture/out.defuse'"
# a home unit opens through the same defuse: a plugin's clone under ~/.claude
hsrc="$fixture/home.plant"; mkdir -p "$hsrc/plugins/x/.git/refs" "$hsrc/plugins/x/.git/objects"
printf 'ref: refs/heads/main\n' >"$hsrc/plugins/x/.git/HEAD"
printf '[core]\n\tfsmonitor = touch %s\n' "$nestmark" >"$hsrc/plugins/x/.git/config"
hkey="grove=grove-1/user=$ME/home=.claude/date=2026-11-21.tar.gz"
mkdir -p "$(dirname "$BUCKET/$hkey")"; tar -czf "$BUCKET/$hkey" -C "$hsrc" .
hseat="$fixture/t10/$ME"; mkdir -p "$hseat"
( HOME="$hseat"; restore_main --from grove-1 --home .claude ) >"$fixture/out.homedefuse" 2>&1
( cd "$hseat/.claude/plugins/x" && gx status ) >/dev/null 2>&1
claim "home · a nested repo's config runs no command" test -d "$hseat/.claude/plugins/x/.git" -a ! -e "$nestmark"

######################################################################
# 10. a member of .grove-backup is admitted by its TYPE, on both sides (peer i012)
######################################################################
# camper's keys, which a link member would copy into the clone for the next pass to carry
secret="$fixture/secret"; mkdir -p "$secret"; printf 'CANARY-KEY\n' >"$secret/id_ed25519"
plant_link() { # <tree> <member under .grove-backup> <link target>
  local key="grove=grove-1/user=$ME/org=acme/repo=widget/tree=$1/date=2026-11-21.tar.gz" src="$fixture/link.$RANDOM"
  mkdir -p "$src/.grove-backup/repo" "$(dirname "$BUCKET/$key")"
  jq -n --arg o "$origin" --arg h "$head_sha" '{ version: 2, kind: "worktree", head_sha: $h, head_ref: "refs/heads/main",
     origin: $o, origin_checked: true, deletes: [], staged: [], cut: [], point_in_time: true }' >"$src/.grove-backup/meta.json"
  git pack-objects -q --stdout </dev/null >"$src/.grove-backup/objects.pack"
  : >"$src/.grove-backup/refs.txt"
  ln -s "$3" "$src/.grove-backup/$2"
  tar -czf "$BUCKET/$key" -C "$src" .
}
plant_link widget.hooklink repo/hooks "$secret"
plant_link widget.excludelink repo/exclude "$secret/id_ed25519"
claim "type · a hooks dir planted as a link is refused, named" tree_refused widget.hooklink "repo/hooks is a link or a special file"
claim "type · an exclude planted as a link is refused, named" tree_refused widget.excludelink "repo/exclude is a link or a special file"
claim "type · camper's key reaches no laid tree" bash -c "! grep -rqs CANARY-KEY '$fixture/t5.widget.hooklink' '$fixture/t5.widget.excludelink'"
plant_tree widget.headdash '.head_ref = "refs/heads/--detach"'
claim "type · a head_ref that reads as an option is refused, as refs.txt's are" tree_refused widget.headdash "head_ref is no branch ref"

# the writer: a clone whose hook is a link (a shared hooks dir) packs its CONTENT, never a link
hc="$fixture/hookclone"; gx clone -q "$origin" "$hc" 2>/dev/null
printf '#!/bin/sh\necho shared\n' >"$fixture/shared-hook"
ln -s "$fixture/shared-hook" "$hc/.git/hooks/pre-push"
token="ghp_$(printf 'a%.0s' {1..36})"
printf '#!/bin/sh\nexport GH=%s\n' "$token" >"$hc/.git/hooks/pre-commit"
mkdir -p "$fixture/hcwork"
grove_backup_pack_tree clone "$hc" "$fixture/hc.tar.gz" "$fixture/hcwork" true; rc=$?
claim "writer · a clone with a linked hook packs" test "$rc" -eq 0
claim "writer · the linked hook rides as a plain file, its content" bash -c "
  tar -tvzf '$fixture/hc.tar.gz' .grove-backup/repo/hooks/pre-push 2>/dev/null | grep -q '^-' &&
  tar -xOzf '$fixture/hc.tar.gz' .grove-backup/repo/hooks/pre-push | grep -qx 'echo shared'"
claim "writer · a hook that holds a token never rides" bash -c "! tar -tzf '$fixture/hc.tar.gz' | grep -q 'repo/hooks/pre-commit\$'"
claim "writer · its manifest names the cut" bash -c "
  tar -xOzf '$fixture/hc.tar.gz' .grove-backup/meta.json | jq -e '.cut | index(\".grove-backup/repo/hooks/pre-commit\")' >/dev/null"
hkey2="grove=grove-1/user=$ME/org=acme/repo=widget/tree=widget/date=2026-11-21.tar.gz"
rm -rf "$(dirname "$BUCKET/$hkey2")"; mkdir -p "$(dirname "$BUCKET/$hkey2")"; cp "$fixture/hc.tar.gz" "$BUCKET/$hkey2"
hcseat="$fixture/t11/$ME"; mkdir -p "$hcseat"
( HOME="$hcseat"; restore_main --from grove-1 --of acme/widget --tree widget ) >"$fixture/out.hookpack" 2>&1
claim "writer · that unit restores, its hook laid NOT executable" bash -c "
  grep -qx 'echo shared' '$hcseat/git/acme/widget/.git/hooks/pre-push' && test ! -x '$hcseat/git/acme/widget/.git/hooks/pre-push'"

# a files unit's pack asks the reader's own question: prove.grove-backup-round-trip drives it
#   through the agent's own pass, over a seat (admit · …)

# the one sink: a row a unit fed prints with no control byte, its glyphs kept
ROWS=($'kept: a\e[2K\e[1A✓ forged' $'c1: a\xc2\x9b2K forged' '🌙 a real warn')
rows_flush >"$fixture/out.sink"
claim "sink · no raw control byte from a row reaches the terminal" bash -c "! grep -q \$'\\e' '$fixture/out.sink'"
claim "sink · no C1 control (U+0080–U+009F) from a row reaches the terminal" \
  bash -c "! LC_ALL=C grep -q \$'\\xc2[\\x80-\\x9f]' '$fixture/out.sink'"
claim "sink · its glyphs survive" grep -q '🌙 a real warn' "$fixture/out.sink"

# the digest reads the library's file, so the agent that sources it hashes alike
claim "digest · the agent and the library alone hash alike" bash -c '
  [[ "$(bash -c "source \"'"$BUNDLE"'/grove.backup.operations.sh\"; grove_backup_pack_rules_digest")" == \
     "$(bash -c "source \"'"$BUNDLE"'/grove-backup\"; grove_backup_pack_rules_digest")" ]]'
claim "digest · a rule list a caller widens at run time is a new rule" bash -c '
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  before="$(grove_backup_pack_rules_digest)"
  GROVE_BACKUP_UNIT_GIT_STATE+=(planted)
  [[ "$(grove_backup_pack_rules_digest)" != "$before" ]] || { echo "      │ the git-state list did not move the digest" >&2; exit 1; }'

# latest is the object the bucket received last, never the key text a writer chose
claim "latest · a key dated ahead loses to the newer put" bash -c '
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  u="grove=grove-1/user=camper/org=acme/repo=widget/tree=widget"
  got="$(printf "%s\t%s\t%s\n" "$u/date=2099-01-01.tar.gz" 2026-11-01T00:00:00+00:00 STANDARD \
                                "$u/date=2026-11-21.tar.gz" 2026-11-21T00:00:00+00:00 STANDARD \
         | grove_backup_units_latest | cut -f2)"
  [[ "$got" == "$u/date=2026-11-21.tar.gz" ]] || { echo "      │ latest read $got" >&2; exit 1; }'

######################################################################
# 11. the defuse reads the laid DESTINATION, by git's own test of a git dir (peer i013)
#   a symlink HEAD is a HEAD to git; a git dir a commit lays is a git dir too
######################################################################
lnmark="$fixture/symhead.fsmonitor.ran"; lnhook="$fixture/symhead.hook.ran"
tbmark="$fixture/committed.fsmonitor.ran"; tbhook="$fixture/committed.hook.ran"
hlmark="$fixture/homesym.fsmonitor.ran"
# a nested repo at <dir>, whose HEAD is a symlink, with a command in its config and an armed hook
plant_symhead_repo() { # <dir> <config marker> <hook marker>
  mkdir -p "$1/refs/heads" "$1/objects" "$1/hooks"
  ln -s refs/heads/main "$1/HEAD"
  printf '[core]\n\trepositoryformatversion = 0\n\tfsmonitor = touch %s\n' "$2" >"$1/config"
  printf '#!/bin/sh\ntouch %s\n' "$3" >"$1/hooks/post-checkout"; chmod +x "$1/hooks/post-checkout"
}
plant_whole_tree() { # <src> <head sha> <head ref> <refs.txt body>
  local key="grove=grove-1/user=$ME/org=acme/repo=widget/tree=widget/date=2026-11-21.tar.gz"
  mkdir -p "$1/.grove-backup"
  jq -n --arg o "$origin" --arg h "$2" --arg r "$3" '{ version: 2, kind: "clone", head_sha: $h, head_ref: $r,
     origin: $o, origin_checked: true, deletes: [], staged: [], cut: [], point_in_time: true }' >"$1/.grove-backup/meta.json"
  [[ -f "$1/.grove-backup/objects.pack" ]] || git pack-objects -q --stdout </dev/null >"$1/.grove-backup/objects.pack"
  printf '%s' "$4" >"$1/.grove-backup/refs.txt"
  rm -rf "$(dirname "$BUCKET/$key")"; mkdir -p "$(dirname "$BUCKET/$key")"; tar -czf "$BUCKET/$key" -C "$1" .
}
# trace A: a symlink HEAD, in the unit's own files
lsrc="$fixture/symhead.plant"; plant_symhead_repo "$lsrc/sub/.git" "$lnmark" "$lnhook"
plant_whole_tree "$lsrc" "$head_sha" refs/heads/main ""
lseat="$fixture/t12/$ME"; mkdir -p "$lseat"
( HOME="$lseat"; restore_main --from grove-1 --of acme/widget --tree widget ) >"$fixture/out.symhead" 2>&1
llaid="$lseat/git/acme/widget"
claim "symhead · a nested repo whose HEAD is a link lands" test -L "$llaid/sub/.git/HEAD"
( cd "$llaid/sub" && gx status && gx checkout -q -b probe ) >/dev/null 2>&1
claim "symhead · its config runs no command on a git act" test ! -e "$lnmark"
claim "symhead · its hook lands NOT executable, and never runs" test ! -x "$llaid/sub/.git/hooks/post-checkout" -a ! -e "$lnhook"
# trace B: a git dir a commit lays, which a gitfile in the unit points at
tb="$fixture/tb"; gx clone -q "$origin" "$tb" 2>/dev/null
mkdir -p "$tb/sub/gd/hooks" "$tb/sub/gd/refs/heads" "$tb/sub/gd/objects"
printf 'ref: refs/heads/main\n' >"$tb/sub/gd/HEAD"
printf '[core]\n\trepositoryformatversion = 0\n\tfsmonitor = touch %s\n' "$tbmark" >"$tb/sub/gd/config"
printf '#!/bin/sh\ntouch %s\n' "$tbhook" >"$tb/sub/gd/hooks/post-checkout"; chmod +x "$tb/sub/gd/hooks/post-checkout"
: >"$tb/sub/gd/refs/heads/.keep"; : >"$tb/sub/gd/objects/.keep"
gx -C "$tb" add -A && gx -C "$tb" commit -qm 'a git dir, committed'
tb_sha="$(gx -C "$tb" rev-parse HEAD)"
bsrc="$fixture/committed.plant"; mkdir -p "$bsrc/.grove-backup" "$bsrc/sub"
printf '%s\n^%s\n' "$tb_sha" "$head_sha" | gx -C "$tb" pack-objects -q --revs --stdout >"$bsrc/.grove-backup/objects.pack"
printf 'gitdir: gd\n' >"$bsrc/sub/.git"
plant_whole_tree "$bsrc" "$tb_sha" refs/heads/tb "$tb_sha refs/heads/tb
"
bseat="$fixture/t13/$ME"; mkdir -p "$bseat"
( HOME="$bseat"; restore_main --from grove-1 --of acme/widget --tree widget ) >"$fixture/out.committed" 2>&1
blaid="$bseat/git/acme/widget"
( cd "$blaid/sub" && gx status && gx checkout -q -b probe ) >/dev/null 2>&1
claim "committed · the commit's git dir lands, with the unit's gitfile" test -f "$blaid/sub/gd/HEAD" -a -f "$blaid/sub/.git"
claim "committed · its config runs no command on a git act" test ! -e "$tbmark"
claim "committed · its hook lands NOT executable, and never runs" test ! -x "$blaid/sub/gd/hooks/post-checkout" -a ! -e "$tbhook"
# a home unit: the same symlink HEAD under ~/.claude
hlsrc="$fixture/homesym.plant"; plant_symhead_repo "$hlsrc/plugins/y/.git" "$hlmark" "$hlmark"
hlkey="grove=grove-1/user=$ME/home=.claude/date=2026-11-21.tar.gz"
rm -rf "$(dirname "$BUCKET/$hlkey")"; mkdir -p "$(dirname "$BUCKET/$hlkey")"; tar -czf "$BUCKET/$hlkey" -C "$hlsrc" .
hlseat="$fixture/t14/$ME"; mkdir -p "$hlseat"
( HOME="$hlseat"; restore_main --from grove-1 --home .claude ) >"$fixture/out.homesym" 2>&1
( cd "$hlseat/.claude/plugins/y" && gx status && gx checkout -q -b probe ) >/dev/null 2>&1
claim "home · a nested repo whose HEAD is a link runs no command" test -L "$hlseat/.claude/plugins/y/.git/HEAD" -a ! -e "$hlmark"
# an unborn repo may never reach its fsmonitor, so read the laid state itself
claim "home · that repo's command key is cut, and its hook laid NOT executable" bash -c "
  test -z \"\$(git config --file '$hlseat/.claude/plugins/y/.git/config' --get core.fsmonitor)\" &&
  test -f '$hlseat/.claude/plugins/y/.git/hooks/post-checkout' -a ! -x '$hlseat/.claude/plugins/y/.git/hooks/post-checkout'"

# a clone whose submodules are initialized: their commits ride in no unit, so the walk names a gap
sseat="$fixture/t15/$ME"; mkdir -p "$sseat/git/acme"
gx clone -q "$origin" "$sseat/git/acme/widget" 2>/dev/null
mkdir -p "$sseat/git/acme/widget/.git/modules/lib/objects"
( HOME="$sseat"; grove_backup_units_walk ) >"$fixture/walk.submods" 2>/dev/null
claim "walk · a clone with initialized submodules raises a gap row, named" \
  grep -qP "^gap\t.*\tuser=$ME/org=acme/repo=widget/tree=widget\tits submodules' commits ride in no unit" "$fixture/walk.submods"
claim "walk · the clone itself still rides" grep -qP "^clone\t.*\tuser=$ME/org=acme/repo=widget/tree=widget\$" "$fixture/walk.submods"

######################################################################
# 12. git's pointers are followed, no lay writes through a link, the restore runs no hook (peer i014)
######################################################################
cdmark="$fixture/commondir.fsmonitor.ran"; cdhook="$fixture/commondir.hook.ran"
hcdmark="$fixture/homecommondir.fsmonitor.ran"
# a git dir whose config and hooks sit in the dir its `commondir` names, which holds no HEAD
plant_commondir_repo() { # <dir that holds .git> <config marker> <hook marker>
  printf 'gitdir: ./gd\n' >"$1/.git"
  mkdir -p "$1/gd" "$1/common/objects" "$1/common/refs/heads" "$1/common/hooks"
  printf 'ref: refs/heads/main\n' >"$1/gd/HEAD"
  printf '../common\n' >"$1/gd/commondir"
  printf '[core]\n\trepositoryformatversion = 0\n\tfsmonitor = touch %s\n' "$2" >"$1/common/config"
  printf '#!/bin/sh\ntouch %s\n' "$3" >"$1/common/hooks/post-checkout"; chmod +x "$1/common/hooks/post-checkout"
}
csrc="$fixture/commondir.plant"; mkdir -p "$csrc/sub" "$csrc/esc/gd"
plant_commondir_repo "$csrc/sub" "$cdmark" "$cdhook"
# and a commondir that leaves the tree: git would read a config the unit never held
printf 'ref: refs/heads/main\n' >"$csrc/esc/gd/HEAD"; printf '/etc\n' >"$csrc/esc/gd/commondir"; mkdir -p "$csrc/esc/gd/refs"
plant_whole_tree "$csrc" "$head_sha" refs/heads/main ""
cseat="$fixture/t16/$ME"; mkdir -p "$cseat"
( HOME="$cseat"; restore_main --from grove-1 --of acme/widget --tree widget ) >"$fixture/out.commondir" 2>&1
claid="$cseat/git/acme/widget"
( cd "$claid/sub" && gx status && gx checkout -q -b probe ) >/dev/null 2>&1
claim "commondir · the dir it names lands inert: no command on a git act" test -d "$claid/sub/common" -a ! -e "$cdmark"
claim "commondir · that dir's hook lands NOT executable, and never runs" test ! -x "$claid/sub/common/hooks/post-checkout" -a ! -e "$cdhook"
claim "commondir · one that leaves the tree is dropped, named" \
  bash -c "test ! -e '$claid/esc/gd/commondir' && grep -q '1 commondir pointer dropped: each named a dir outside the tree' '$fixture/out.commondir'"
# the same, under ~/.claude
hcsrc="$fixture/homecommondir.plant"; mkdir -p "$hcsrc/plugins/z"
plant_commondir_repo "$hcsrc/plugins/z" "$hcdmark" "$hcdmark"
hckey="grove=grove-1/user=$ME/home=.claude/date=2026-11-21.tar.gz"
rm -rf "$(dirname "$BUCKET/$hckey")"; mkdir -p "$(dirname "$BUCKET/$hckey")"; tar -czf "$BUCKET/$hckey" -C "$hcsrc" .
hcseat="$fixture/t17/$ME"; mkdir -p "$hcseat"
( HOME="$hcseat"; restore_main --from grove-1 --home .claude ) >"$fixture/out.homecommondir" 2>&1
( cd "$hcseat/.claude/plugins/z" && gx status && gx checkout -q -b probe ) >/dev/null 2>&1
claim "home · a commondir's dir lands inert: its command key cut, its hook NOT executable" bash -c "
  test ! -e '$hcdmark' && test -z \"\$(git config --file '$hcseat/.claude/plugins/z/common/config' --get core.fsmonitor)\" &&
  test -f '$hcseat/.claude/plugins/z/common/hooks/post-checkout' -a ! -x '$hcseat/.claude/plugins/z/common/hooks/post-checkout'"

# one --all run: a worktree's commit lays `evil -> <victim>`, then an orphan of that dir's name
#   holds `evil/pwn2`. its own bucket, so no other planted unit joins the run
saved_bucket="$BUCKET"; BUCKET="$fixture/bucket.lay"; mkdir -p "$BUCKET"
plant_whole_tree "$fixture/lay.clone.plant" "$head_sha" refs/heads/main ""
plant_tree widget.D '.'
osrc="$fixture/lay.orphan.plant"; mkdir -p "$osrc/evil"; printf 'planted\n' >"$osrc/evil/pwn2"
okey2="grove=grove-1/user=$ME/org=acme/orphan=widget.D/date=2026-11-21.tar.gz"
mkdir -p "$(dirname "$BUCKET/$okey2")"; tar -czf "$BUCKET/$okey2" -C "$osrc" .
lyseat="$fixture/t18/$ME"; mkdir -p "$lyseat"
( HOME="$lyseat"; restore_main --from grove-1 --all ) >"$fixture/out.laylink" 2>&1
claim "lay · the worktree's commit laid its link" test -L "$lyseat/git/acme/_worktrees/widget.D/evil"
claim "lay · no file of the next unit lands through that link" test ! -e "$victim/pwn2"
claim "lay · the file is kept, named: its dir here is a link" grep -q 'evil/pwn2 (kept: its dir here is a link)' "$fixture/out.laylink"
( HOME="$lyseat"; restore_main --from grove-1 --all ) >"$fixture/out.laylink2" 2>&1
claim "lay · a rerun, with the link already here, lands naught through it" test ! -e "$victim/pwn2"
BUCKET="$saved_bucket"

# the restore's own checkout runs no hook: a present clone whose hooksPath names a dir the
#   unit's own commit lays
hkmark="$fixture/husky.ran"
hk="$fixture/hk"; gx clone -q "$origin" "$hk" 2>/dev/null
mkdir -p "$hk/.husky" && printf '#!/bin/sh\ntouch %s\n' "$hkmark" >"$hk/.husky/post-checkout" && chmod +x "$hk/.husky/post-checkout"
gx -C "$hk" add -A && gx -C "$hk" commit -qm husky && gx -C "$hk" push -q origin HEAD:refs/heads/hk 2>/dev/null
hk_sha="$(gx -C "$hk" rev-parse HEAD)"
hkseat="$fixture/t19/$ME"; mkdir -p "$hkseat/git/acme"
gx clone -q "$origin" "$hkseat/git/acme/widget" 2>/dev/null
gx -C "$hkseat/git/acme/widget" config core.hooksPath .husky
plant_tree widget.hk ".head_sha = \"$hk_sha\" | .head_ref = \"refs/heads/hk\""
( HOME="$hkseat"; restore_main --from grove-1 --of acme/widget --tree widget.hk ) >"$fixture/out.husky" 2>&1
claim "hook · the unit's commit lands" test -f "$hkseat/git/acme/_worktrees/widget.hk/.husky/post-checkout"
claim "hook · the restore's own checkout ran none of its hooks" test ! -e "$hkmark"

# a home unit's .credentials.json is never laid: no backup carries one, so this one is planted
csseat="$fixture/t20/$ME"; mkdir -p "$csseat"
cssrc="$fixture/creds.plant"; mkdir -p "$cssrc/projects"; printf '{"token":"planted"}\n' >"$cssrc/.credentials.json"; printf '{}\n' >"$cssrc/projects/s.jsonl"
cskey="grove=grove-1/user=$ME/home=.claude/date=2026-11-21.tar.gz"
rm -rf "$(dirname "$BUCKET/$cskey")"; mkdir -p "$(dirname "$BUCKET/$cskey")"; tar -czf "$BUCKET/$cskey" -C "$cssrc" .
( HOME="$csseat"; restore_main --from grove-1 --home .claude ) >"$fixture/out.creds" 2>&1
claim "scope · a planted .credentials.json is not laid" test ! -e "$csseat/.claude/.credentials.json" -a -f "$csseat/.claude/projects/s.jsonl"
claim "scope · it is named" grep -q '.credentials.json not laid: a backup never carries it' "$fixture/out.creds"

# the list seam: a key's tab cannot forge its last-modified, and no raw prefix reaches a row
claim "list · a key with tab-forged columns is dropped, and never wins latest" bash -c '
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  u="grove=grove-1/user=camper/org=acme/repo=widget/tree=widget"
  printf "%s" "[[\"$u/date=2026-11-21.tar.gz\",\"2026-11-21T00:00:00+00:00\",\"STANDARD\"],
                [\"$u/date=2026-11-20.tar.gz\\t2099-01-01T00:00:00+00:00\\tSTANDARD\",\"2026-11-01T00:00:00+00:00\",\"STANDARD\"],
                [\"$u/date=2026-11-19.tar.gz\",\"2099-01-01T00:00:00+00:00\",\"STAND\\u001bARD\"]]" >"$1/list.json"
  grove_backup_s3_list_rows "$1/list.json" "$1/list.rows" 2>"$1/list.err" || exit 1
  [[ "$(wc -l <"$1/list.rows")" -eq 1 ]] || { cat "$1/list.rows" >&2; exit 1; }
  got="$(grove_backup_units_latest <"$1/list.rows" | cut -f2)"
  [[ "$got" == "$u/date=2026-11-21.tar.gz" ]] || { echo "      │ latest read $got" >&2; exit 1; }
  grep -q "2 listed rows dropped" "$1/list.err" && ! grep -qP "[\x00-\x08\x0b-\x1f]" "$1/list.err"' _ "$fixture"
claim "list · a prefix no --from accepts names no grove" bash -c '
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  [[ "$(printf "grove=ok-1/\ngrove=x\033[31m/\ngrove=Up/\n" | grove_backup_groves_of_prefixes | paste -sd,)" == ok-1 ]]'

# a unit with a dir that denies its owner write leaves no scratch that poisons the next
claim "scratch · an admit over a 0555 dir clears its scratch, and the next admit at that path runs" bash -c '
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  mkdir -p "$1/ro.src/locked" && printf "x\n" >"$1/ro.src/locked/f" && chmod 0555 "$1/ro.src/locked"
  tar -cf "$1/ro.tar" -C "$1/ro.src" . && chmod 0755 "$1/ro.src/locked"
  grove_backup_pack_admit "$1/ro.tar" "$1/ro.scratch" files || { echo "      │ first: $GROVE_BACKUP_PACK_WHY" >&2; exit 1; }
  [[ ! -e "$1/ro.scratch" ]] || { echo "      │ the scratch survived" >&2; exit 1; }
  grove_backup_pack_admit "$1/ro.tar" "$1/ro.scratch" files || { echo "      │ second: $GROVE_BACKUP_PACK_WHY" >&2; exit 1; }' _ "$fixture"

######################################################################
# 13. a git-state copy that fails fails the run, by name, on both sides (peer i015)
######################################################################
# a planted tree unit whose one checkout member lands at mode 0000, so no copy of it can read
plant_tree_unreadable() { # <tree> <member under the unit>
  local tree="$1" rel="$2" src="$fixture/tree.$RANDOM"
  local key="grove=grove-1/user=$ME/org=acme/repo=widget/tree=$tree/date=2026-11-21.tar.gz"
  mkdir -p "$src/.grove-backup/checkout" "$(dirname "$BUCKET/$key")"
  jq -n --arg o "$origin" --arg h "$head_sha" '{ version: 2, kind: "worktree", head_sha: $h, head_ref: "refs/heads/main",
     origin: $o, origin_checked: true, deletes: [], staged: [], cut: [], point_in_time: true }' >"$src/.grove-backup/meta.json"
  git pack-objects -q --stdout </dev/null >"$src/.grove-backup/objects.pack"
  : >"$src/.grove-backup/refs.txt"
  printf 'x\n' >"$src/$rel"
  tar -cf "$src.tar" -C "$src" --exclude="./$rel" . \
    && tar -rf "$src.tar" -C "$src" --mode=0000 "./$rel" \
    && gzip -c "$src.tar" >"$BUCKET/$key"
}
unread_restore() { # <tree>; sets UNREAD_RC and UNREAD_WT
  local seat="$fixture/t13.$1/$ME"; mkdir -p "$seat"
  UNREAD_WT="$seat/git/acme/_worktrees/$1"
  ( HOME="$seat"; restore_main --from grove-1 --of acme/widget --tree "$1" ) >"$fixture/out.$1" 2>&1
  UNREAD_RC=$?
}
plant_tree_unreadable widget.unreadhead .grove-backup/checkout/HEAD
plant_tree_unreadable widget.unreadindex .grove-backup/checkout/index
unread_restore widget.unreadhead
# a HEAD no read can open is refused at the door, before any lay begins
claim "state · an unreadable HEAD is refused before a byte lays, named" \
  bash -c '[[ "$1" -ne 0 ]] && grep -q "its checkout HEAD cannot be read" "$2"' _ "$UNREAD_RC" "$fixture/out.widget.unreadhead"
claim "state · no raw tool stderr breaks the tree" \
  bash -c '! grep -qE "^(head|cp): " "$1" "$2"' _ "$fixture/out.widget.unreadhead" "$fixture/out.widget.unreadindex"
claim "state · no tree is laid for it" test ! -e "$UNREAD_WT"
unread_restore widget.unreadindex
claim "state · an unreadable index fails the restore, named" \
  bash -c '[[ "$1" -ne 0 ]] && grep -q "the unit.s index could not be laid" "$2"' _ "$UNREAD_RC" "$fixture/out.widget.unreadindex"
claim "state · that tree stays marked laid in part" test -f "$(restore_unfinished_path "$UNREAD_WT")"
claim "state · the tree keeps the index its checkout made" test -f "$(git -C "$UNREAD_WT" rev-parse --absolute-git-dir)/index"

# the writer: each stage step reports a copy it could not make, and the pack asks
claim "pack · an index the stage cannot copy fails the step, named" bash -c '
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  g="$1/pk"; git init -q "$g" && printf "x\n" >"$g/f" && git -C "$g" add f && chmod 0 "$g/.git/index"
  mkdir -p "$1/pk.gb/checkout"
  grove_backup_stage_checkout "$g/.git" "$g/.git" "$1/pk.gb" clone ""; rc=$?
  chmod 0644 "$g/.git/index"
  [[ "$rc" -eq 2 && "$GROVE_BACKUP_PACK_WHY" == *index* ]] || { echo "      │ rc=$rc why=${GROVE_BACKUP_PACK_WHY:-}" >&2; exit 1; }' _ "$fixture"
claim "pack · a repo config the stage cannot write fails the step, named" bash -c '
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  g="$1/pk"; mkdir -p "$1/pc.gb/repo" && chmod 0555 "$1/pc.gb/repo"
  grove_backup_stage_repo_config "$g" "$g/.git" "$1/pc.gb" ""; rc=$?
  chmod 0755 "$1/pc.gb/repo"
  [[ "$rc" -eq 2 && "$GROVE_BACKUP_PACK_WHY" == *config* ]] || { echo "      │ rc=$rc why=${GROVE_BACKUP_PACK_WHY:-}" >&2; exit 1; }' _ "$fixture"
claim "pack · a repo with no remote or upstream key stages its config, under the agent's pipefail" bash -c '
  set -o pipefail
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  g="$1/pk"; mkdir -p "$1/pn.gb/repo"
  grove_backup_stage_repo_config "$g" "$g/.git" "$1/pn.gb" "" || { echo "      │ why=${GROVE_BACKUP_PACK_WHY:-}" >&2; exit 1; }' _ "$fixture"
claim "pack · a staged copy the stage cannot write fails the step, named" bash -c '
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  g="$1/pk"; mkdir -p "$1/ps.gb/staged" && chmod 0555 "$1/ps.gb/staged"
  grove_backup_stage_staged "$g" "$1/ps.gb" ""; rc=$?
  chmod 0755 "$1/ps.gb/staged"
  [[ "$rc" -eq 2 && "$GROVE_BACKUP_PACK_WHY" == *staged* ]] || { echo "      │ rc=$rc why=${GROVE_BACKUP_PACK_WHY:-}" >&2; exit 1; }' _ "$fixture"

######################################################################
# 14. a guard one lane holds, its peer lane holds too (peer i015)
######################################################################
# a files unit is asked its manifest's version, as a tree unit is
vsseat="$fixture/t14.version/$ME"; mkdir -p "$vsseat"
vssrc="$fixture/v99.plant"; mkdir -p "$vssrc/.grove-backup" "$vssrc/projects"
jq -n '{ version: 99, kind: "files", cut: [] }' >"$vssrc/.grove-backup/meta.json"; printf '{}\n' >"$vssrc/projects/s.jsonl"
vskey="grove=grove-1/user=$ME/home=.claude/date=2026-11-21.tar.gz"
rm -rf "$(dirname "$BUCKET/$vskey")"; mkdir -p "$(dirname "$BUCKET/$vskey")"; tar -czf "$BUCKET/$vskey" -C "$vssrc" .
( HOME="$vsseat"; restore_main --from grove-1 --home .claude ) >"$fixture/out.v99" 2>&1
claim "version · a files unit of a version this restore does not read is refused, named" \
  grep -q "this unit's manifest is version '99'" "$fixture/out.v99"
claim "version · naught of it is laid" test ! -e "$vsseat/.claude/projects/s.jsonl"

# a commit inside a nested repo moves the unit, though no file outside its .git changed
claim "change · a commit in a nested repo reads as a move" bash -c '
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  t="$1/nest"; git init -q "$t" && git init -q "$t/sub" && printf "x\n" >"$t/sub/x"
  git -C "$t/sub" -c user.name=t -c user.email=t@example.com add x && git -C "$t/sub" -c user.name=t -c user.email=t@example.com commit -qm a
  touch "$1/nest.stamp"
  git -C "$t/sub" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m b
  grove_backup_unit_moved_since "$t" "$1/nest.stamp"' _ "$fixture"
claim "change · the top .git alone still reads as no move" bash -c '
  source "'"$BUNDLE"'/grove.backup.operations.sh"
  t="$1/nest"; touch "$1/nest.stamp2"
  git -C "$t" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m top
  ! grove_backup_unit_moved_since "$t" "$1/nest.stamp2"' _ "$fixture"

######################################################################
# 15. a lay forks no subshell per path depth (peer 5.3 i001): an 8 GiB `.claude` of ~40k
#     files outran the live proof's 600s bound on the ec2 grove at ~15 forks a file
######################################################################
# the fork-free dir read agrees with dirname on every shape a lay asks it
dirof_ok=1
for p in a a/b a/b/c -sub/inner.md .hidden/x /abs/leaf /leaf "with space/f" "d/-e/f"; do
  restore_dir_of got "$p"
  [[ "$got" == "$(dirname -- "$p")" ]] || { dirof_ok=0; echo "      │ $p → $got, dirname says $(dirname -- "$p")" >&2; }
done
claim "lay · the fork-free dir read agrees with dirname on every path shape" test "$dirof_ok" -eq 1
# each per-path step of a lay holds no command substitution, so none forks per depth
claim "lay · the per-path steps hold no subshell" bash -c '! grep -qF "\$(" <<<"$1"' _ \
  "$(declare -f restore_path_crosses_a_link restore_dir_of restore_lay_path restore_top_group restore_dirs_prune_empty)"

######################################################################
# the texts a human reads as each untrusted unit is refused, cut, or laid inert — every byte
#   snapped, so a drift in a refusal's words reddens here and not only where a grep misses it.
#   masked: the fixture, the seat, each sha, each date, each scratch dir's random tail
######################################################################
untrusted_mask() {
  sed -E -e "s#$fixture#<fixture>#g" -e "s#user=$ME\b#user=<seat>#g" -e "s#/$ME/#/<seat>/#g" -e "s#\b$ME\b#<seat>#g" \
         -e 's#\b[0-9a-f]{40}\b#<sha>#g' -e 's#\b[0-9a-f]{7,12}\b#<sha>#g' -e 's#[0-9]{4}-[0-9]{2}-[0-9]{2}#<date>#g' \
         -e 's#\b(restore|unit)\.[A-Za-z0-9]{6}\b#\1.<tmp>#g' -e 's#\.grove-restore\.stage\.[0-9]+\.[0-9]+#.grove-restore.stage.<tmp>#g'
}
snap_untrusted=""
for case_out in \
  "every id outside the shapes, under --all:out" "a named unit with a .. field:out.named" \
  "a file it lays reaches .git:out.widget.githook" "a delete leaves the tree:out.widget.escape" \
  "a head_sha that is no commit id:out.widget.badsha" "a head_ref that is no branch:out.widget.badref" \
  "an origin that reads as a flag:out.widget.badorigin" "a file through a link HEAD laid:out.widget.throughlink" \
  "a planted orphan:out.orphan" "a dead origin, its mark cleared with its dir:out.markfail" "an origin that asks for auth:out.authfail" \
  "a stale mark:out.markstale" "a sha that reads as an option:out.widget.refopt" "a ref with a control byte:out.widget.refesc" \
  "a ref part that opens with a dash:out.widget.refdash" "a mid-rebase exec and a nested git dir:out.defuse" \
  "a nested repo under a home unit:out.homedefuse" "a hooks dir planted as a link:out.widget.hooklink" \
  "an exclude planted as a link:out.widget.excludelink" "a head_ref that reads as an option:out.widget.headdash" \
  "a hook in the pack:out.hookpack" "a nested HEAD that is a link:out.symhead" "a committed nested repo:out.committed" \
  "a nested HEAD link under a home unit:out.homesym" "a commondir in and out of the tree:out.commondir" \
  "a commondir under a home unit:out.homecommondir" "a lay through a link, first:out.laylink" \
  "a lay through a link, again:out.laylink2" "a husky hooks path:out.husky" "a credential under a home unit:out.creds" \
  "an unreadable checkout HEAD:out.widget.unreadhead" "an unreadable index:out.widget.unreadindex" \
  "a files unit of an unread version:out.v99"; do
  snap_untrusted+=$'\n'"## ${case_out%%:*}"$'\n'"$(cat "$fixture/${case_out##*:}" 2>/dev/null || echo '（no output was written）')"$'\n'
done
snap_untrusted+=$'\n'"## the repo config and hook rows of a planted unit"$'\n'"$rows"$'\n'
play_snap_verify dir="$HERE/.play/permanent/prove.grove-backup-restore-trusts-no-unit.snap" name=restore.untrusted \
  actual="$(untrusted_mask <<<"$snap_untrusted")" || failed=1

if [[ "$failed" -ne 0 ]]; then
  sed 's/^/      │ /' "$fixture/out" "$fixture/out.named" "$fixture/out.defuse" "$fixture/out.homedefuse" >&2
  sed 's/^/      │ /' "$fixture/out.commondir" "$fixture/out.homecommondir" "$fixture/out.laylink" "$fixture/out.husky" "$fixture/out.creds" >&2
  sed 's/^/      │ /' "$fixture/out.symhead" "$fixture/out.committed" "$fixture/out.homesym" >&2
  sed 's/^/      │ /' "$fixture/out.widget.unreadhead" "$fixture/out.widget.unreadindex" "$fixture/out.v99" >&2
  printf '      │ %s\n' "${ROWS[@]}" >&2
  echo "💥 MalfunctionError: a claim failed" >&2
  exit 1
fi
