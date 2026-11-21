#!/usr/bin/env bash
######################################################################
# .what = back up a fixture grove, then restore it onto a fresh one —
#         the real agent, the real restore, a local dir for a bucket and
#         a local bare repo for origin
#
# .why
#   - the round trip is the whole promise: a tree with an unpushed commit and a
#     conversation on the dead grove is whole on the new one
#   - the s3 seam is six functions, and a dir stands in for the bucket. every
#     git pack, tar, hash, clone, and file lay above that seam runs for real
#
# .the claims
#   a tree's unit · self-contained: its commits origin lacks, its checkout, its
#     changed, untracked, and ignored-but-kept files, its transcripts · lean: no
#     commit origin holds, no file equal to HEAD, no node_modules, no ignored
#     build dir · a commit origin dropped since the last fetch still rides ·
#     a repo with no origin rides whole · no host, no seat, no date inside it
#   a pass · a quiet tree costs no pack · one edit packs one tree · an edit that
#     lands mid-pack repacks, and a tree in constant motion lands flagged · a pass
#     cut short resumes with the units it never landed, first · the reach fails
#     in its written order, with its cause
#   restore · a worktree lands alone on a box with no clone: origin, then its
#     unit · its transcripts byte for byte, its unpushed commits, its staged and
#     unstaged edits, its deletes · a clone grafts into the present one · `--all`
#     lays what is absent and keeps what is here · a home dir keeps the present
#     file · keyrack/ is never laid
#
# guarantee:
#   - writes only inside its own mktemp dir, removed on exit
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE="$HERE/src/grove.provision/5.devtools/5.26.backup"

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
# shellcheck source=/dev/null
source "$HERE/.agent/repo=.this/role=any/skills/grove.backup.get.sh"

BUCKET="$fixture/bucket"
STATE="$fixture/state"
mkdir -p "$BUCKET" "$fixture/etc" "$STATE"
grove_backup_name_file()   { printf '%s' "$fixture/etc/name"; }
grove_backup_bucket_file() { printf '%s' "$fixture/etc/bucket"; }
grove_backup_seat_home()   { printf '%s/%s' "$HOME_ROOT" "$ME"; }
grove_backup_state_dir()   { printf '%s' "$STATE"; }
MACHINE_ID_FILE="$fixture/etc/machine-id"
printf '%s\n' 0123456789abcdef0123456789abcdef >"$MACHINE_ID_FILE"
grove_backup_machine_id_file() { printf '%s' "$MACHINE_ID_FILE"; }

STUB_CRED=0 STUB_PUT=0 STUB_PUT_LIMIT=-1
grove_backup_s3_whoami() { return "$STUB_CRED"; }
grove_backup_s3_list() {
  local prefix="$1" out="$2" f key
  : >"$out"
  while IFS= read -r f; do
    key="${f#"$BUCKET"/}"
    [[ "$key" == "$prefix"* ]] || continue
    printf '%s\t%s\t%s\n' "$key" "$(date -u -r "$f" +%FT%T+00:00)" "STANDARD" >>"$out"
  done < <(find "$BUCKET" -type f -name '*.tar.gz' | sort)
}
grove_backup_s3_prefixes() { find "$BUCKET" -mindepth 1 -maxdepth 1 -type d -printf '%f/\n' | sort >"$1"; }
grove_backup_s3_head() {
  [[ -f "$BUCKET/$1" ]] || return 6
  printf '%s\tSTANDARD\tNone\n' "$(cat "$BUCKET/$1.sha")" >"$2"
}
grove_backup_s3_put() {
  [[ "$STUB_PUT" -ne 0 ]] && { GROVE_BACKUP_AWS_VERB=s3:PutObject; return "$STUB_PUT"; }
  if [[ "$STUB_PUT_LIMIT" -ge 0 && "$(wc -l <"$fixture/puts" 2>/dev/null || echo 0)" -ge "$STUB_PUT_LIMIT" ]]; then
    GROVE_BACKUP_AWS_ERR="the stub cut the pass"; return 5
  fi
  mkdir -p "$(dirname "$BUCKET/$2")" && cp "$1" "$BUCKET/$2" && printf '%s\n' "$3" >"$BUCKET/$2.sha" \
    && printf '%s\n' "$(grove_backup_key_unit "$2")" >>"$fixture/puts"
}
grove_backup_s3_get()  { cp "$BUCKET/$1" "$2"; }
grove_backup_s3_thaw() { return 0; }

# a count of tree packs, and a hook that edits a tree as it is packed
eval "orig_$(declare -f grove_backup_pack_tree)"
EDIT_DURING_PACK=""   # a path: append to it after each pack, while edits.left > 0
grove_backup_pack_tree() {
  echo x >>"$fixture/packs"
  orig_grove_backup_pack_tree "$@" || return $?
  if [[ -n "$EDIT_DURING_PACK" && -f "$fixture/edits.left" && "$(cat "$fixture/edits.left")" -gt 0 ]]; then
    sleep 0.1
    echo "moved" >>"$EDIT_DURING_PACK"
    echo $(( $(cat "$fixture/edits.left") - 1 )) >"$fixture/edits.left"
  fi
}
# the order a pass takes its units in
eval "orig_$(declare -f grove_backup_unit_once)"
grove_backup_unit_once() { printf '%s\n' "$3" >>"$fixture/order"; orig_grove_backup_unit_once "$@"; }
packs() { wc -l <"$fixture/packs" 2>/dev/null || echo 0; }
packs_reset() { : >"$fixture/packs"; : >"$fixture/puts"; : >"$fixture/order"; }

######################################################################
# origin, and the dead grove: one seat, two clones, two worktrees, two home dirs
######################################################################
# .why `gx` and never `g`: the restore skill this play sources owns `g`
gx() { git -c user.name=t -c user.email=t@example.com -c init.defaultBranch=main -c advice.detachedHead=false "$@"; }
origin="$fixture/origin/widget.git"
gx init -q --bare "$origin"

HOME_ROOT="$fixture/dead"
seat="$HOME_ROOT/$ME"
clone="$seat/git/acme/widget"
mkdir -p "$seat/git/acme"
gx clone -q "$origin" "$clone" 2>/dev/null
printf 'build/\nnode_modules/\n.agent/.actors/\n' >"$clone/.gitignore"
mkdir -p "$clone/src/build"
printf 'tracked\n' >"$clone/src/build/keep.txt"
printf 'readme\n'  >"$clone/README.md"
gx -C "$clone" add .gitignore README.md && gx -C "$clone" add -f src/build/keep.txt
gx -C "$clone" commit -qm base
gx -C "$clone" push -q origin main 2>/dev/null
base_sha="$(gx -C "$clone" rev-parse HEAD)"

# a branch origin held, then dropped by a force-push the dead clone never fetched
gx -C "$clone" checkout -q -b gone && gx -C "$clone" commit -q --allow-empty -m 'on origin, then not'
gx -C "$clone" push -q origin gone 2>/dev/null
gx -C "$clone" checkout -q main
gone_sha="$(gx -C "$clone" rev-parse gone)"
gx -C "$origin" update-ref -d refs/heads/gone

# work origin never saw
gx -C "$clone" commit -q --allow-empty -m 'main ahead'
mkdir -p "$clone/pkg/build" "$clone/node_modules/dep"
printf 'rebuilt\n' >"$clone/pkg/build/out.js"
printf 'dep\n'     >"$clone/node_modules/dep/index.js"
gx -C "$clone" branch feat-x
wt="$seat/git/acme/_worktrees/widget.feat-x"
gx -C "$clone" worktree add -q "$wt" feat-x
gx -C "$wt" commit -q --allow-empty -m 'unpushed one'
gx -C "$wt" commit -q --allow-empty -m 'unpushed two'
printf 'an edit nobody committed\n' >"$wt/draft.md"
printf 'staged copy\n' >"$wt/staged.txt" && gx -C "$wt" add staged.txt
printf 'worktree copy\n' >"$wt/staged.txt"
gx -C "$wt" rm -q README.md
transcript_rel=".agent/.actors/a/brain/.claude/projects/p/s.jsonl"
mkdir -p "$wt/$(dirname "$transcript_rel")"
printf '{"line":1}\n{"line":2,"text":"what we learn from"}\n' >"$wt/$transcript_rel"
spike="$seat/git/acme/_worktrees/widget.spike"
gx -C "$clone" worktree add -q --detach "$spike"
gx -C "$spike" commit -q --allow-empty -m 'detached work'
# a worktree git dropped: its dir stays with no `.git`, and its transcript in it
dropped="$seat/git/acme/_worktrees/widget.dropped"
mkdir -p "$dropped/$(dirname "$transcript_rel")"
printf '{"line":1,"text":"a dropped tree still talks"}\n' >"$dropped/$transcript_rel"
# a tree a clone set aside, inside its `.git`, its dir name stamped with an hour
setaside="$clone/.git/tree-del-setaside/widget.old.20261119T063248Z"
mkdir -p "$setaside/$(dirname "$transcript_rel")"
printf '{"line":1,"text":"a set-aside tree still talks"}\n' >"$setaside/$transcript_rel"
printf 'stashed\n' >"$clone/stash-me.txt"
gx -C "$clone" add stash-me.txt && gx -C "$clone" stash -q
# after the stash, which would take it
printf 'tracked, edited\n' >"$clone/src/build/keep.txt"
printf 'dead notes\n' >"$clone/notes.txt"

# a repo with no origin at all
solo="$seat/git/acme/solo"
mkdir -p "$solo" && gx -C "$solo" init -q && printf 'solo\n' >"$solo/a.txt" && gx -C "$solo" add a.txt && gx -C "$solo" commit -qm solo

mkdir -p "$seat/.claude/projects/p" "$seat/.rhachet/keyrack/vault/os.direct" "$seat/.rhachet/meter"
printf '{"line":1}\n' >"$seat/.claude/projects/p/session.jsonl"
printf '{"dead":true}\n' >"$seat/.claude/settings.json"
printf 'SECRET\n' >"$seat/.claude/.credentials.json"
printf 'SECRET\n' >"$seat/.rhachet/keyrack/vault/os.direct/keys.json"
printf 'sealed\n' >"$seat/.rhachet/keyrack/host.age"
printf '3\n' >"$seat/.rhachet/meter/uses"

printf 'grove-1\n' >"$fixture/etc/name"
printf 'fixture-bucket\n' >"$fixture/etc/bucket"

status() { jq -r "$1" "$STATE/status.json"; }
run() { ( grove_backup_run ) >"$fixture/run.out" 2>&1; }
units=8

######################################################################
# a pass — the first puts each unit, the second packs none
######################################################################
packs_reset
run; rc=$?
claim "pass 1 · exits 0" test "$rc" -eq 0
[[ "$rc" -ne 0 ]] && sed 's/^/      │ /' "$fixture/run.out" >&2
claim "pass 1 · verdict ok" test "$(status .verdict)" == ok
claim "pass 1 · $units units, $units put" test "$(status '"\(.units) \(.put)"')" == "$units $units"
claim "pass 1 · the status line reads ✓" test "$(grove_backup_status_line)" == "✓ 0m ago · $units put · 0 skipped"

key_of() { find "$BUCKET" -name '*.tar.gz' -path "*$1/date=*" | head -n 1; }
claim "key · a clone's tree is its repo" test -n "$(key_of 'user='"$ME"'/org=acme/repo=widget/tree=widget')"
claim "key · a worktree names its repo from its link" test -n "$(key_of 'repo=widget/tree=widget.feat-x')"
claim "list · a prefix not shaped grove=<slug>/ is no grove" \
  test "$(printf 'grove=alpha/\nprobe/\ngrove=/\ngrove=beta/\n' | grove_backup_groves_of_prefixes | paste -sd,)" == "alpha,beta"

# 🛑 each claim first proves its object EXISTS: over an absent key, "the member
#   is not in the tar" is true of an empty list, and the claim passes with no
#   backup at all
# ⚠️ the member list is taken WHOLE, never piped into `grep -q`: the agent this
#   play sources sets `pipefail`, so a grep that exits early lets tar die on SIGPIPE
members_of() {
  local key; key="$(key_of "$1")"
  [[ -n "$key" ]] || { echo "      │ no object for $1" >&2; return 1; }
  tar -tzf "$key"
}
holds() {
  local all; all="$(members_of "$1")" || return 1
  [[ $'\n'"$all"$'\n' == *$'\n'"$2"$'\n'* ]] && return 0
  sed 's/^/      │ /' <<<"$all" >&2; return 1
}
lacks() {
  local all; all="$(members_of "$1")" || return 1
  [[ "$all" != *"$2"* ]] && return 0
  sed 's/^/      │ /' <<<"$all" >&2; return 1
}
unit_dir() { local d="$fixture/peek.$RANDOM"; mkdir -p "$d" && tar -xzf "$(key_of "$1")" -C "$d" && printf '%s' "$d"; }
pack_holds() { # <unit> <sha> → does the unit's pack carry that commit?
  local d r; d="$(unit_dir "$1")" || return 1; r="$fixture/r.$RANDOM"
  git init -q "$r" && git -C "$r" index-pack --stdin <"$d/.grove-backup/objects.pack" >/dev/null \
    && git -C "$r" cat-file -e "$2^{commit}" 2>/dev/null
}
FEAT=tree=widget.feat-x
claim "home · .credentials.json never rides" lacks home=.claude credentials
claim "home · keyrack os.direct never rides" lacks home=.rhachet os.direct
claim "home · the sealed keyrack rides" holds home=.rhachet ./keyrack/host.age
claim "home · the global conversation rides" holds home=.claude ./projects/p/session.jsonl
claim "tree · its manifest rides" holds "$FEAT" .grove-backup/meta.json
claim "tree · its transcript rides in its own unit" holds "$FEAT" "$transcript_rel"
claim "tree · its uncommitted edit rides" holds "$FEAT" draft.md
claim "tree · its staged copy rides" holds "$FEAT" .grove-backup/staged/staged.txt
claim "tree · its unpushed commits ride" pack_holds "$FEAT" "$(gx -C "$wt" rev-parse HEAD)"
pack_lacks() { ! pack_holds "$@"; }
claim "tree · a commit origin holds never rides" pack_lacks tree=widget "$base_sha"
claim "tree · a commit origin dropped since the last fetch rides" pack_holds tree=widget "$gone_sha"
claim "tree · a file equal to HEAD never rides" lacks tree=widget .gitignore
claim "tree · a changed file in a tracked build dir rides" holds tree=widget src/build/keep.txt
claim "tree · a git-ignored build dir is cut" lacks tree=widget pkg/build
claim "tree · node_modules never rides" lacks tree=widget node_modules
claim "tree · a repo with no origin rides whole" pack_holds tree=solo "$(gx -C "$solo" rev-parse HEAD)"
meta_of() { local d; d="$(unit_dir "$1")" && cat "$d/.grove-backup/meta.json"; }
no_dox() {
  local all d; d="$(unit_dir "$FEAT")" || return 1
  all="$(cat "$d/.grove-backup/meta.json" "$d/.grove-backup/refs.txt" "$d/.grove-backup/repo/config.list")"
  [[ "$all" != *"$(hostname)"* && "$all" != *"$ME"* ]] || { echo "      │ a host or seat name" >&2; return 1; }
  ! grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{2}:[0-9]{2}' <<<"$all" || { echo "      │ a date or time" >&2; return 1; }
}
claim "tree · its manifest holds no host, no seat, no date" no_dox

# every transcript under ~/git sits inside a unit the walk names
uncovered() {
  local walk c n=0
  walk="$(grove_backup_units_walk)"
  while IFS= read -r c; do
    awk -F'\t' -v c="$c" '$1 != "home" && index(c, $3 "/") == 1 { hit = 1 } END { exit !hit }' <<<"$walk" \
      || { echo "      │ outside every unit: ${c#"$seat/"}" >&2; n=$((n + 1)); }
  done < <(find "$seat/git" -path '*/.agent/.actors/*.jsonl' -type f)
  [[ "$n" -eq 0 ]]
}
claim "coverage · every transcript under ~/git sits inside a unit" uncovered
claim "orphan · a dropped worktree's transcript rides" holds orphan=widget.dropped "./$transcript_rel"
claim "setaside · a set-aside tree's transcript rides" holds 'setaside=widget.old.*' "./$transcript_rel"
claim "setaside · its key carries no hour" test -z "$(find "$BUCKET" -name '*.tar.gz' -path '*T063248Z*')"
# no machine-id: the hour is cut and NO hash stands in, since an unsalted one reads back to the hour
sa_name_salted="$(grove_backup_setaside_name widget.old.20261119T063248Z 2>/dev/null)"
MACHINE_ID_FILE="$fixture/etc/machine-id.absent"
sa_name_bare="$(grove_backup_setaside_name widget.old.20261119T063248Z 2>"$fixture/sa.err")"
MACHINE_ID_FILE="$fixture/etc/machine-id"
claim "setaside · with a machine-id, a box-salted hash stands in for the hour" \
  test "${sa_name_salted%.*}" == widget.old -a "${#sa_name_salted}" -eq $((${#sa_name_bare} + 9))
claim "setaside · with no machine-id, the hour is cut and no hash stands in" test "$sa_name_bare" == widget.old
claim "setaside · with no machine-id, the fault is named" grep -q 'MalfunctionError: .*machine-id.* absent or empty' "$fixture/sa.err"
claim "tree · its manifest is a still capture" test "$(meta_of "$FEAT" | jq -r .point_in_time)" == true

packs_reset
run
claim "pass 2 · naught changed, so naught is put" test "$(status '"\(.put) \(.skipped)"')" == "0 $units"
claim "pass 2 · and naught is packed" test "$(packs)" -eq 0

packs_reset
printf 'one more edit\n' >>"$wt/draft.md"
run
claim "pass 3 · one edit re-puts one unit" test "$(status '"\(.put) \(.skipped)"')" == "1 $((units - 1))"
claim "pass 3 · and packs one tree" test "$(packs)" -eq 1

packs_reset
printf 'brand new\n' >"$spike/new.txt"
EDIT_DURING_PACK="$spike/new.txt"; echo 1 >"$fixture/edits.left"
run
claim "mid-pack edit · the tree is packed again" test "$(packs)" -eq 2
claim "mid-pack edit · the landed unit holds the edit" test "$(tar -xzOf "$(key_of tree=widget.spike)" new.txt | tail -n 1)" == moved
claim "mid-pack edit · still a point-in-time capture" test "$(meta_of tree=widget.spike | jq -r .point_in_time)" == true

packs_reset
echo again >>"$spike/new.txt"
echo 5 >"$fixture/edits.left"
run
claim "constant motion · three packs, no more" test "$(packs)" -eq 3
claim "constant motion · it lands, flagged" test "$(meta_of tree=widget.spike | jq -r .point_in_time)" == false
EDIT_DURING_PACK=""

######################################################################
# a pass cut short — the next one resumes with what it never landed
######################################################################
BUCKET="$fixture/bucket.cut"; STATE="$fixture/state.cut"; mkdir -p "$BUCKET" "$STATE"
packs_reset
STUB_PUT_LIMIT=2
run
claim "cut · the cut pass fails, named" test "$(status .verdict)" == failed
sort "$fixture/puts" >"$fixture/landed.first"
STUB_PUT_LIMIT=-1
packs_reset
run
sort "$fixture/puts" >"$fixture/landed.second"
claim "resume · it puts the $((units - 2)) the cut pass left" test "$(status .put)" -eq $((units - 2))
claim "resume · it never re-puts what landed" test -z "$(comm -12 "$fixture/landed.first" "$fixture/landed.second")"
claim "resume · the never-landed go first" \
  test "$(head -n $((units - 2)) "$fixture/order" | sort | paste -sd,)" == "$(paste -sd, "$fixture/landed.second")"
BUCKET="$fixture/bucket"; STATE="$fixture/state"

######################################################################
# the reach — its written order, its cause
######################################################################
reach_cause() { run; status .cause; }

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
HOME_ROOT="$fixture/empty"; mkdir -p "$HOME_ROOT/$ME"
claim "reach · zero units is never ✓" test "$(reach_cause)" == "no units found under $fixture/empty/$ME"
HOME_ROOT="$fixture/dead"
run

######################################################################
# restore — onto a fresh grove that holds NO clone yet
######################################################################
fresh_seat="$fixture/fresh/$ME"
mkdir -p "$fresh_seat/.claude"
printf '{"fresh":true}\n' >"$fresh_seat/.claude/settings.json"
restore() { ( HOME="$fresh_seat"; restore_main "$@" ) >"$fixture/out" 2>&1; }
live="$fresh_seat/git/acme/widget"
fwt="$fresh_seat/git/acme/_worktrees/widget.feat-x"
fg() { git -C "$fwt" "$@"; }

restore --from grove-1 --of acme/widget --tree widget.feat-x; rc=$?
claim "worktree alone · exits 0" test "$rc" -eq 0
[[ "$rc" -ne 0 ]] && sed 's/^/      │ /' "$fixture/out" >&2
snap_worktree="$(cat "$fixture/out")"
claim "worktree alone · its clone came from origin" test -d "$live/.git"
claim "worktree alone · git sees it as linked" bash -c "git -C '$live' worktree list | grep -q widget.feat-x"
claim "worktree alone · its transcript, byte for byte" cmp -s "$wt/$transcript_rel" "$fwt/$transcript_rel"
claim "worktree alone · its two unpushed commits" \
  test "$(fg log --format=%s -2 | tr '\n' ,)" == "unpushed two,unpushed one,"
claim "worktree alone · its uncommitted edit" cmp -s "$wt/draft.md" "$fwt/draft.md"
claim "worktree alone · its staged copy, in the index" test "$(fg show :staged.txt)" == "staged copy"
claim "worktree alone · its unstaged copy, in the tree" test "$(cat "$fwt/staged.txt")" == "worktree copy"
claim "worktree alone · its delete, still staged" test "$(fg status --porcelain -- README.md)" == "D  README.md"
claim "worktree alone · git status reads as the dead tree did" \
  test "$(fg status --porcelain | sort)" == "$(git -C "$wt" status --porcelain | sort)"

printf 'live notes\n' >"$live/notes.txt"
restore --from grove-1 --of acme/widget --tree widget; rc=$?
claim "clone graft · exits 0" test "$rc" -eq 0
snap_clone="$(cat "$fixture/out")"
has_ref() { git -C "$1" rev-parse -q --verify "$2" >/dev/null; }
claim "clone graft · the branch origin dropped lands" has_ref "$live" refs/heads/gone
claim "clone graft · the checked-out main fast-forwards on its clean tree" \
  test "$(git -C "$live" rev-parse main)" == "$(git -C "$clone" rev-parse main)"
claim "clone graft · the stash is here" test "$(git -C "$live" stash list | wc -l)" -eq 1
claim "clone graft · the dead checkout's edit lands, on the same HEAD" \
  test "$(cat "$live/src/build/keep.txt")" == "tracked, edited"
claim "clone graft · a file this clone holds of its own is kept, and named" \
  test "$(cat "$live/notes.txt")" == "live notes" -a "$(grep -c 'notes.txt (kept' "$fixture/out")" -eq 1

restore --from grove-1 --of acme/solo --tree solo --into "$fixture/aside/solo"; rc=$?
claim "no origin · lands whole, aside" test "$rc" -eq 0 -a "$(cat "$fixture/aside/solo/a.txt" 2>/dev/null)" == solo

restore --from grove-1 --all; rc=$?
claim "--all · exits 0" test "$rc" -eq 0
[[ "$rc" -ne 0 ]] && sed 's/^/      │ /' "$fixture/out" >&2
snap_all="$(cat "$fixture/out")"
claim "--all · the present worktree is kept" grep -q 'already here' "$fixture/out"
claim "--all · the detached worktree lands" test "$(git -C "$fresh_seat/git/acme/_worktrees/widget.spike" log --format=%s -1 2>/dev/null)" == "detached work"
claim "--all · a dropped worktree's transcript lands where it sat, byte for byte" \
  cmp -s "$dropped/$transcript_rel" "$fresh_seat/git/acme/_worktrees/widget.dropped/$transcript_rel"
fsa="$(find "$fresh_seat/git/acme/_setaside/widget" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n 1)"
claim "--all · a set-aside tree's transcript lands under _setaside, byte for byte" \
  cmp -s "$setaside/$transcript_rel" "$fsa/$transcript_rel"
claim "--all · the set-aside lands with no hour in its name" test -n "$fsa" -a "${fsa##*T063248Z}" == "$fsa"
restore --from grove-1 --orphan acme/widget.dropped --into "$fixture/aside/dropped"; rc=$?
claim "--orphan · one dropped worktree, aside: its transcript byte for byte" \
  test "$rc" -eq 0 -a -f "$fixture/aside/dropped/$transcript_rel"
claim "--orphan · the aside copy matches the dead one" cmp -s "$dropped/$transcript_rel" "$fixture/aside/dropped/$transcript_rel"
restore --from grove-1 --of acme/widget --setaside "${fsa##*/}" --into "$fixture/aside/setaside"; rc=$?
claim "--setaside · one set-aside tree by its listed name, aside: its transcript byte for byte" \
  cmp -s "$setaside/$transcript_rel" "$fixture/aside/setaside/$transcript_rel"
# the next backup of the restored seat names each plain-file tree under the SAME unit, so a
#   restore never forks a set-aside or an orphan under a new key
rewalk="$( grove_backup_seat_home() { printf '%s' "$fresh_seat"; }; grove_backup_units_walk )"
# exact: the unit id's tail must EQUAL the name, so a re-hashed `<name>.<more>` never passes
walk_names() {
  awk -F'\t' -v t="/$1" 'length($4) >= length(t) && substr($4, length($4) - length(t) + 1) == t { hit = 1 } END { exit !hit }' <<<"$rewalk"
}
claim "rewalk · the restored set-aside keeps its unit, its name not hashed twice" \
  walk_names "org=acme/repo=widget/setaside=${fsa##*/}"
claim "rewalk · the restored orphan keeps its unit" walk_names "org=acme/orphan=widget.dropped"
claim "home · the conversation lands" test -f "$fresh_seat/.claude/projects/p/session.jsonl"
claim "home · the present settings file is kept" grep -q fresh "$fresh_seat/.claude/settings.json"
claim "home · no credential lands" test ! -e "$fresh_seat/.claude/.credentials.json"
claim "home · keyrack/ is never laid" test ! -e "$fresh_seat/.rhachet/keyrack"
claim "home · role storage lands" test -f "$fresh_seat/.rhachet/meter/uses"

restore --from grove-1 --all; rc=$?
claim "--all again · a resume: exits 0, lays naught twice" test "$rc" -eq 0 -a "$(grep -c 'already here' "$fixture/out")" -ge 2

restore --from grove-1 --of acme/widget --tree widget.feat-x; rc=$?
claim "worktree · a named restore over a present one refuses, exit 2" test "$rc" -eq 2

restore --from grove-9 --all; rc=$?
claim "absent grove · exit 2, never an empty success" test "$rc" -eq 2

######################################################################
# grove.backup.get — the list surfaces a commander reads before a restore
######################################################################
get() { ( get_main "$@" ) >"$fixture/out" 2>&1; }
out_has() { grep -qF -- "$1" "$fixture/out"; }

get --list; rc=$?; snap_get_list="$(cat "$fixture/out")"
claim "get --list · exits 0" test "$rc" -eq 0
claim "get --list · names grove-1" out_has "grove-1"

get --from grove-1 --list; rc=$?; snap_get_units="$(cat "$fixture/out")"
claim "get --from · exits 0" test "$rc" -eq 0
claim "get --from · lists a clone" out_has "org=acme/repo=widget/tree=widget "
claim "get --from · lists a dropped worktree" out_has "/orphan="
claim "get --from · lists a set-aside" out_has "/setaside="
claim "get --from · lists a home dir" out_has "home=.claude"
claim "get --from · a clone before its home dir, as --all lays them" \
  test "$(grep -n 'tree=widget ' "$fixture/out" | head -n 1 | cut -d: -f1)" -lt "$(grep -n 'home=.claude' "$fixture/out" | head -n 1 | cut -d: -f1)"

get --from grove-9 --list; rc=$?; snap_get_absent="$(cat "$fixture/out")"
claim "get --from an absent grove · exit 2, never an empty list" test "$rc" -eq 2
claim "get --from an absent grove · names the groves held" out_has "grove-1"

STUB_CRED=4; get --list; rc=$?; snap_get_nocred="$(cat "$fixture/out")"; STUB_CRED=0
claim "get · no credential · exit 2, its owner named" test "$rc" -eq 2
STUB_CRED=5; get --list; rc=$?; STUB_CRED=0
claim "get · no answer from aws · exit 1, a retry may cure it" test "$rc" -eq 1

######################################################################
# the texts a human reads after a restore — every byte snapped
#   masked: the fixture dir, the seat name, each sha, each date
######################################################################
# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
snapdir="$HERE/.play/permanent/prove.grove-backup-round-trip.snap"
mask() {
  sed -e "s#$fixture#<fixture>#g" -e "s#user=$ME\b#user=<seat>#g" -e "s#/$ME/#/<seat>/#g" \
      -e 's#[0-9a-f]\{8\}\b#<sha>#g' -e 's#[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}#<date>#g' \
      -e 's#T[0-9]\{2\}:[0-9]\{2\}Z#T<hh:mm>Z#g'
}
play_snap_verify dir="$snapdir" name=restore.worktree-alone actual="$(mask <<<"$snap_worktree")" || failed=1
play_snap_verify dir="$snapdir" name=restore.clone-graft    actual="$(mask <<<"$snap_clone")"    || failed=1
play_snap_verify dir="$snapdir" name=restore.all            actual="$(mask <<<"$snap_all")"      || failed=1
play_snap_verify dir="$snapdir" name=get.list               actual="$(mask <<<"$snap_get_list")"   || failed=1
play_snap_verify dir="$snapdir" name=get.from-list          actual="$(mask <<<"$snap_get_units")"  || failed=1
play_snap_verify dir="$snapdir" name=get.from-absent        actual="$(mask <<<"$snap_get_absent")" || failed=1
play_snap_verify dir="$snapdir" name=get.no-credential      actual="$(mask <<<"$snap_get_nocred")" || failed=1

[[ "$failed" -ne 0 ]] && exit 1
echo "🌲 all claims held ✔"
exit 0
