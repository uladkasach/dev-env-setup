#!/usr/bin/env bash
######################################################################
# .what = back up a fixture grove, then restore it onto a fresh one —
#         the real agent, the real restore, a local dir for a bucket
#
# .why
#   - the round trip is the whole promise: a tree with an unpushed commit and a
#     conversation on the dead grove is whole on the new one
#   - the live proof needs a bucket, two groves, and infra's declarations, and
#     several are still owed. the LOGIC needs none of them: the s3 seam is six
#     functions, and a dir stands in for the bucket. every tar, hash, git
#     fetch, and file lay above that seam runs for real
#
# .the claims
#   back up · each unit puts once · a second run skips each (the tar hashes the
#     same) · one edit re-puts one unit · the plaintext credentials and
#     node_modules never ride along · a git-ignored `build` is cut, a tracked
#     one rides · the reach fails in its written order, with its cause
#   restore · a clone grafts into a fresh clean clone: a new branch, a
#     fast-forward of the checked-out branch, the stash, a detached worktree
#     HEAD · a worktree relinks with its unpushed commits and its uncommitted
#     edit · a home dir keeps the present file and lays the absent ones ·
#     keyrack/ is never laid · a second worktree restore refuses
#
# guarantee:
#   - writes only inside its own mktemp dir, removed on exit
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE="$HERE/src/grove.provision/5.devtools/5.24.backup"

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
ME="$(id -un)"

failed=0
pass() { echo "   • $1 ✔"; }
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }
claim() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }

echo "🌲 prove.grove-backup-round-trip"

######################################################################
# the seams — box facts point at the fixture; the bucket is a dir
######################################################################
# shellcheck source=/dev/null
source "$BUNDLE/grove-backup"
# shellcheck source=/dev/null
source "$HERE/.agent/repo=.this/role=any/skills/grove.backup.restore.sh"

BUCKET="$fixture/bucket"
mkdir -p "$BUCKET" "$fixture/etc" "$fixture/state"
grove_backup_name_file()   { printf '%s' "$fixture/etc/name"; }
grove_backup_bucket_file() { printf '%s' "$fixture/etc/bucket"; }
grove_backup_home_root()   { printf '%s' "$HOME_ROOT"; }
grove_backup_state_dir()   { printf '%s' "$fixture/state"; }

STUB_CRED=0 STUB_PUT=0
grove_backup_s3_whoami() { return "$STUB_CRED"; }
grove_backup_s3_list() {
  local prefix="$1" out="$2" f key
  : >"$out"
  while IFS= read -r f; do
    key="${f#"$BUCKET"/}"
    [[ "$key" == "$prefix"* ]] || continue
    printf '%s\t%s\t%s\n' "$key" "$(date -u -r "$f" +%FT%T+00:00)" "$(cat "$f.class" 2>/dev/null || echo STANDARD)" >>"$out"
  done < <(find "$BUCKET" -type f -name '*.tar.gz' | sort)
}
grove_backup_s3_prefixes() {
  find "$BUCKET" -mindepth 1 -maxdepth 1 -type d -printf '%f/\n' | sort >"$1"
}
grove_backup_s3_head() {
  [[ -f "$BUCKET/$1" ]] || return 6
  printf '%s\t%s\tNone\n' "$(cat "$BUCKET/$1.sha")" "$(cat "$BUCKET/$1.class" 2>/dev/null || echo STANDARD)" >"$2"
}
grove_backup_s3_put() {
  [[ "$STUB_PUT" -ne 0 ]] && { GROVE_BACKUP_AWS_VERB=s3:PutObject; return "$STUB_PUT"; }
  mkdir -p "$(dirname "$BUCKET/$2")" && cp "$1" "$BUCKET/$2" && printf '%s\n' "$3" >"$BUCKET/$2.sha"
}
grove_backup_s3_get()  { cp "$BUCKET/$1" "$2"; }
grove_backup_s3_thaw() { return 0; }

######################################################################
# the dead grove: one seat, one clone, two worktrees, two home dirs
######################################################################
HOME_ROOT="$fixture/dead"
seat="$HOME_ROOT/$ME"
clone="$seat/git/acme/widget"
g() { git -c user.name=t -c user.email=t@example.com -c init.defaultBranch=main "$@"; }

mkdir -p "$clone"
g -C "$clone" init -q
printf 'build/\n' >"$clone/.gitignore"
mkdir -p "$clone/pkg/build" "$clone/src/build" "$clone/node_modules/dep"
printf 'tracked\n' >"$clone/src/build/keep.txt"
printf 'rebuilt\n' >"$clone/pkg/build/out.js"
printf 'dep\n'     >"$clone/node_modules/dep/index.js"
g -C "$clone" add .gitignore && g -C "$clone" add -f src/build/keep.txt
g -C "$clone" commit -qm base

# the fresh grove's clone is taken HERE, at base — so every later commit is one
#   the fresh box lacks, as `5.10.repos` clones origin and origin never saw them
fresh_root="$fixture/fresh"
fresh_seat="$fresh_root/$ME"
mkdir -p "$fresh_seat/git/acme"
g clone -q "$clone" "$fresh_seat/git/acme/widget"

g -C "$clone" commit -q --allow-empty -m 'main ahead'
g -C "$clone" branch feat-x
g -C "$clone" worktree add -q "$seat/git/acme/_worktrees/widget.feat-x" feat-x
wt="$seat/git/acme/_worktrees/widget.feat-x"
g -C "$wt" commit -q --allow-empty -m 'unpushed one'
g -C "$wt" commit -q --allow-empty -m 'unpushed two'
printf 'an edit nobody committed\n' >"$wt/draft.md"
g -C "$clone" worktree add -q --detach "$seat/git/acme/_worktrees/widget.spike"
g -C "$seat/git/acme/_worktrees/widget.spike" commit -q --allow-empty -m 'detached work'
printf 'stashed\n' >"$clone/stash-me.txt"
g -C "$clone" add stash-me.txt && g -C "$clone" stash -q

mkdir -p "$seat/.claude/projects/p" "$seat/.rhachet/keyrack/vault/os.direct" "$seat/.rhachet/meter"
printf '{"line":1}\n' >"$seat/.claude/projects/p/session.jsonl"
printf '{"dead":true}\n' >"$seat/.claude/settings.json"
printf 'SECRET\n' >"$seat/.claude/.credentials.json"
printf 'SECRET\n' >"$seat/.rhachet/keyrack/vault/os.direct/keys.json"
printf 'sealed\n' >"$seat/.rhachet/keyrack/host.age"
printf '3\n' >"$seat/.rhachet/meter/uses"

printf 'grove-1\n' >"$fixture/etc/name"
printf 'fixture-bucket\n' >"$fixture/etc/bucket"

status() { jq -r "$1" "$fixture/state/status.json"; }

######################################################################
# back up — the first run puts each unit, the second skips each
######################################################################
( grove_backup_run ) >"$fixture/run1" 2>&1; rc=$?
claim "run 1 · exits 0" test "$rc" -eq 0
[[ "$rc" -ne 0 ]] && sed 's/^/      │ /' "$fixture/run1" >&2
claim "run 1 · verdict ok" test "$(status .verdict)" == ok
claim "run 1 · 5 units, 5 put" test "$(status '"\(.units) \(.put)"')" == "5 5"
claim "run 1 · the status line reads ✓" test "$(grove_backup_status_line)" == "✓ 0m ago · 5 put · 0 skipped"

key_of() { find "$BUCKET" -name '*.tar.gz' -path "*$1/date=*" | head -n 1; }
claim "key · a clone's tree is its repo" test -n "$(key_of 'user='"$ME"'/org=acme/repo=widget/tree=widget')"
claim "key · a worktree names its repo from its link" test -n "$(key_of 'repo=widget/tree=widget.feat-x')"

# 🛑 each cut claim first proves its object EXISTS: over an absent key, "the
#   member is not in the tar" is true of an empty list, and the claim passes
#   with no backup at all (measured on this play's first run)
# ⚠️ the member list is taken WHOLE, never piped into `grep -q`: the agent this
#   play sources sets `pipefail`, so a grep that exits early lets tar die on
#   SIGPIPE, and the claim fails at random (measured: one red in three runs)
members_of() {
  local key; key="$(key_of "$1")"
  [[ -n "$key" ]] || { echo "      │ no object for $1" >&2; return 1; }
  tar -tzf "$key"
}
holds() {
  local all; all="$(members_of "$1")" || return 1
  [[ "$all" == *"$2"* ]] && return 0
  sed 's/^/      │ /' <<<"$all" >&2; return 1
}
lacks() {
  local all; all="$(members_of "$1")" || return 1
  [[ "$all" != *"$2"* ]] && return 0
  sed 's/^/      │ /' <<<"$all" >&2; return 1
}
claim "cut · .credentials.json never rides" lacks home=.claude credentials
claim "cut · keyrack os.direct never rides" lacks home=.rhachet os.direct
claim "keep · the sealed keyrack rides" holds home=.rhachet keyrack/host.age
claim "keep · the conversation rides" holds home=.claude projects/p/session.jsonl
claim "cut · node_modules never rides" lacks tree=widget node_modules
claim "cut · a git-ignored build dir is cut" lacks tree=widget pkg/build
claim "keep · a tracked build dir rides" holds tree=widget src/build/keep.txt

( grove_backup_run >/dev/null 2>&1 )
claim "run 2 · naught changed, so naught is put" test "$(status '"\(.put) \(.skipped)"')" == "0 5"

printf 'one more edit\n' >>"$wt/draft.md"
( grove_backup_run >/dev/null 2>&1 )
claim "run 3 · one edit re-puts one unit" test "$(status '"\(.put) \(.skipped)"')" == "1 4"

######################################################################
# the reach — its written order, its cause
######################################################################
reach_cause() { ( grove_backup_run >/dev/null 2>&1 ); status .cause; }

mv "$fixture/etc/name" "$fixture/etc/name.off"; mv "$fixture/etc/bucket" "$fixture/etc/bucket.off"
claim "reach · both absent → the grove name is the cause" test "$(reach_cause)" == "grove name undeclared"
mv "$fixture/etc/name.off" "$fixture/etc/name"
claim "reach · bucket absent → its cause" test "$(reach_cause)" == "bucket name undeclared"
mv "$fixture/etc/bucket.off" "$fixture/etc/bucket"
STUB_CRED=4
claim "reach · no credential → its cause" test "$(reach_cause)" == "no aws credential"
STUB_CRED=0
printf 'still more\n' >>"$wt/draft.md"
STUB_PUT=3
claim "reach · a refused put → the verb named" test "$(reach_cause)" == "access denied: s3:PutObject"
claim "reach · last_ok survives a failed run" test "$(status '.last_ok != null')" == true
STUB_PUT=0
HOME_ROOT="$fixture/empty"; mkdir -p "$HOME_ROOT"
claim "reach · zero units is never ✓" test "$(reach_cause)" == "no units found under $fixture/empty/*"
HOME_ROOT="$fixture/dead"
( grove_backup_run >/dev/null 2>&1 )

######################################################################
# restore — onto the fresh grove, whose own clone sits at base
######################################################################
mkdir -p "$fresh_seat/.claude"
printf '{"fresh":true}\n' >"$fresh_seat/.claude/settings.json"
restore() { ( HOME="$fresh_seat"; restore_main "$@" ) >"$fixture/out" 2>&1; }
live="$fresh_seat/git/acme/widget"

restore --from grove-1 --of acme/widget --tree widget; rc=$?
claim "clone · exits 0" test "$rc" -eq 0
snap_clone="$(sed -e "s#$fixture#<fixture>#g" -e 's#[0-9a-f]\{8\}\b#<sha>#g' "$fixture/out")"
has_ref() { git -C "$1" rev-parse -q --verify "$2" >/dev/null; }
claim "clone · the unpushed branch lands" has_ref "$live" refs/heads/feat-x
claim "clone · the checked-out main fast-forwards on its clean tree" \
  test "$(g -C "$live" rev-parse main)" == "$(g -C "$clone" rev-parse main)"
claim "clone · the stash lands aside" has_ref "$live" refs/heads/grove-1/stash
claim "clone · a detached worktree HEAD lands aside" has_ref "$live" refs/heads/grove-1/wt/widget.spike
claim "clone · no hidden ref is left behind" test -z "$(g -C "$live" for-each-ref refs/grove-backup/)"
claim "clone · the live files are untouched" test ! -e "$live/stash-me.txt"

restore --from grove-1 --of acme/widget --tree widget.feat-x; rc=$?
fwt="$fresh_seat/git/acme/_worktrees/widget.feat-x"
claim "worktree · exits 0" test "$rc" -eq 0
snap_worktree="$(sed -e "s#$fixture#<fixture>#g" "$fixture/out")"
claim "worktree · its two unpushed commits are there" \
  test "$(g -C "$fwt" log --format=%s -2 | tr '\n' ,)" == "unpushed two,unpushed one,"
claim "worktree · its uncommitted edit is there" grep -q 'an edit nobody committed' "$fwt/draft.md"
claim "worktree · git sees it as linked" bash -c "git -C '$live' worktree list | grep -q widget.feat-x"

restore --from grove-1 --of acme/widget --tree widget.feat-x; rc=$?
claim "worktree · a second restore refuses, exit 2" test "$rc" -eq 2

restore --from grove-1 --home .claude; rc=$?
claim "home · exits 0" test "$rc" -eq 0
snap_home="$(sed -e "s#$fixture#<fixture>#g" "$fixture/out")"
claim "home · the conversation lands" test -f "$fresh_seat/.claude/projects/p/session.jsonl"
claim "home · the present settings file is kept" grep -q fresh "$fresh_seat/.claude/settings.json"
claim "home · no credential lands" test ! -e "$fresh_seat/.claude/.credentials.json"
claim "home · it names the brain login" grep -q 'rhx brains.auth.set' "$fixture/out"

restore --from grove-1 --home .rhachet
claim "home · keyrack/ is never laid" test ! -e "$fresh_seat/.rhachet/keyrack"
claim "home · role storage lands" test -f "$fresh_seat/.rhachet/meter/uses"

restore --from grove-9 --all; rc=$?
claim "absent grove · exit 2, never an empty success" test "$rc" -eq 2

######################################################################
# the texts a human reads after a restore — every byte snapped
#   masked: the fixture dir, the seat name, and each sha (they differ per run)
######################################################################
# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
snapdir="$HERE/.play/permanent/prove.grove-backup-round-trip.snap"
mask_seat() { sed -e "s#user=$ME/#user=<seat>/#g" -e "s#/$ME/#/<seat>/#g" -e 's#[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}#<date>#g'; }
play_snap_verify dir="$snapdir" name=restore.clone    actual="$(mask_seat <<<"$snap_clone")"    || failed=1
play_snap_verify dir="$snapdir" name=restore.worktree actual="$(mask_seat <<<"$snap_worktree")" || failed=1
play_snap_verify dir="$snapdir" name=restore.home     actual="$(mask_seat <<<"$snap_home")"     || failed=1

[[ "$failed" -ne 0 ]] && exit 1
echo "🌲 all claims held ✔"
exit 0
