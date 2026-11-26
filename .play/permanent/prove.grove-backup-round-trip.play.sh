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
BUNDLE="$HERE/src/grove.provision/5.devtools/5.27.backup"

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

# the disk floor, pinned open: the play must not read this box's own disk as a verdict
GROVE_BACKUP_DISK_FLOOR_KB=0
STUB_CRED=0 STUB_PUT=0 STUB_PUT_LIMIT=-1
STUB_CLASS=STANDARD STUB_RESTORE=None   # an object's storage class, and its thaw state
STUB_LIST=0 STUB_GET=0                  # a nonzero rc for the list or the object read: 3 is a refused grant
grove_backup_s3_whoami() { return "$STUB_CRED"; }
grove_backup_s3_list() {
  local prefix="$1" out="$2" f key
  [[ "$STUB_LIST" -ne 0 ]] && { GROVE_BACKUP_AWS_VERB=s3:ListBucket; return "$STUB_LIST"; }
  : >"$out"
  while IFS= read -r f; do
    key="${f#"$BUCKET"/}"
    [[ "$key" == "$prefix"* ]] || continue
    printf '%s\t%s\t%s\n' "$key" "$(date -u -r "$f" +%FT%T+00:00)" "$STUB_CLASS" >>"$out"
  done < <(find "$BUCKET" -type f -name '*.tar.gz' | sort)
}
STUB_PREFIXES=0 STUB_THAW=0                # 3: a grant scoped per grove refuses the fleet list, or the thaw (S8)
grove_backup_s3_prefixes() {
  [[ "$STUB_PREFIXES" -ne 0 ]] && { GROVE_BACKUP_AWS_VERB=s3:ListBucket; return "$STUB_PREFIXES"; }
  find "$BUCKET" -mindepth 1 -maxdepth 1 -type d -printf '%f/\n' | sort >"$1"
}
grove_backup_predecessor_file() { printf '%s' "$fixture/etc/predecessor"; }
grove_backup_s3_head() {
  [[ -f "$BUCKET/$1" ]] || return 6
  printf '%s\t%s\t%s\n' "$(cat "$BUCKET/$1.sha")" "$STUB_CLASS" "$STUB_RESTORE" >"$2"
}
grove_backup_s3_put() {
  [[ "$STUB_PUT" -ne 0 ]] && { GROVE_BACKUP_AWS_VERB=s3:PutObject; return "$STUB_PUT"; }
  if [[ "$STUB_PUT_LIMIT" -ge 0 && "$(wc -l <"$fixture/puts" 2>/dev/null || echo 0)" -ge "$STUB_PUT_LIMIT" ]]; then
    GROVE_BACKUP_AWS_ERR="the stub cut the pass"; return 5
  fi
  mkdir -p "$(dirname "$BUCKET/$2")" && cp "$1" "$BUCKET/$2" && printf '%s\n' "$3" >"$BUCKET/$2.sha" \
    && printf '%s\n' "$(grove_backup_key_unit "$2")" >>"$fixture/puts"
}
grove_backup_s3_get()  {
  [[ "$STUB_GET" -ne 0 ]] && { GROVE_BACKUP_AWS_VERB=s3:GetObject; return "$STUB_GET"; }
  cp "$BUCKET/$1" "$2"
}
grove_backup_s3_thaw() { [[ "$STUB_THAW" -ne 0 ]] && { GROVE_BACKUP_AWS_VERB=s3:RestoreObject; return "$STUB_THAW"; }; return 0; }

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

# a branch the live clone will hold too, on a commit of its own: the graft must land it aside
gx -C "$clone" checkout -q -b topic && gx -C "$clone" commit -q --allow-empty -m 'dead topic'
gx -C "$clone" checkout -q main
topic_sha="$(gx -C "$clone" rev-parse topic)"

# work origin never saw
gx -C "$clone" commit -q --allow-empty -m 'main ahead'
mkdir -p "$clone/pkg/build" "$clone/node_modules/dep"
printf 'rebuilt\n' >"$clone/pkg/build/out.js"
printf 'dep\n'     >"$clone/node_modules/dep/index.js"
# a python env, which this clone alone ignores
printf '.venv/\n' >>"$clone/.git/info/exclude"
mkdir -p "$clone/.venv/lib" && printf 'env\n' >"$clone/.venv/lib/site.py"
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
# the clone's own conversation, which git ignores
mkdir -p "$clone/$(dirname "$transcript_rel")"
printf '{"line":1,"text":"the clone itself talks"}\n' >"$clone/$transcript_rel"
# plaintext credentials a tree holds: loose, inside an untracked dir, and staged
printf 'TOKEN=fixture\n' >"$clone/.env"
mkdir -p "$clone/certs" && printf 'fixture key\n' >"$clone/certs/site.pem" && printf 'keep\n' >"$clone/certs/readme.txt"
printf 'S=fixture\n' >"$wt/.env.local" && gx -C "$wt" add -f .env.local
# a credential by CONTENT, under a name no shape knows; each built at run time, so no
#   scanner reads this play itself as a key
printf -- '-----BEGIN %s PRIVATE KEY-----\nfixture\n' OPENSSH >"$clone/deploy.txt"
printf 'token=ghp_%s\n' "$(printf 'a%.0s' {1..36})" >"$clone/token.txt"
# a transcript that holds a token rides whole: a cut would drop the conversation
mkdir -p "$clone/scratch" && printf '{"text":"ghp_%s"}\n' "$(printf 'b%.0s' {1..36})" >"$clone/scratch/chat.jsonl"

# a repo with no origin at all
solo="$seat/git/acme/solo"
mkdir -p "$solo" && gx -C "$solo" init -q && printf 'solo\n' >"$solo/a.txt" && gx -C "$solo" add a.txt && gx -C "$solo" commit -qm solo
# a file of a shape the cut rules do not name yet: it rides until a rule widens
printf 'keystore\n' >"$solo/store.jks"

# plaintext credentials in the plain-file units: by shape and by content, as a tree holds them
printf 'TOKEN=fixture\n' >"$dropped/.env"
printf 'token=ghp_%s\n' "$(printf 'c%.0s' {1..36})" >"$dropped/notes.txt"
printf 'token=ghp_%s\n' "$(printf 'd%.0s' {1..36})" >"$setaside/notes.txt"

mkdir -p "$seat/.claude/projects/p" "$seat/.rhachet/keyrack/vault/os.direct" "$seat/.rhachet/meter"
printf '{"line":1}\n' >"$seat/.claude/projects/p/session.jsonl"
printf '{"dead":true}\n' >"$seat/.claude/settings.json"
printf 'SECRET\n' >"$seat/.claude/.credentials.json"
printf 'SECRET\n' >"$seat/.rhachet/keyrack/vault/os.direct/keys.json"
printf 'sealed\n' >"$seat/.rhachet/keyrack/host.age"
printf '3\n' >"$seat/.rhachet/meter/uses"
printf 'token=ghp_%s\n' "$(printf 'e%.0s' {1..36})" >"$seat/.rhachet/meter/notes.txt"

printf 'grove-1\n' >"$fixture/etc/name"
printf 'fixture-bucket\n' >"$fixture/etc/bucket"

status() { jq -r "$1" "$STATE/status.json"; }
run() { ( grove_backup_run ) >"$fixture/run.out" 2>&1; }
# .what = keep the agent's own pass text, the one a human reads in the journal, for run.passes.snap
snap_run=""
keep_run() { snap_run+=$'\n'"## $1 ($2)"$'\n'"$(cat "$fixture/run.out")"$'\n'; }
units=8

######################################################################
# a pass — the first puts each unit, the second packs none
######################################################################
packs_reset
run; rc=$?
claim "pass 1 · exits 0" test "$rc" -eq 0
keep_run "the first pass, each unit put" "exit $rc"
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
claim "tree · an ignored .venv never rides" lacks tree=widget .venv
claim "tree · an untracked .env never rides" lacks tree=widget .env
claim "tree · a key inside an untracked dir never rides" lacks tree=widget site.pem
claim "tree · the rest of that dir rides" holds tree=widget certs/readme.txt
claim "tree · a staged .env.local never rides, as a file or a staged copy" lacks "$FEAT" .env.local
claim "tree · a file whose content holds a private key never rides" lacks tree=widget deploy.txt
claim "tree · a file whose content holds a token never rides" lacks tree=widget token.txt
claim "tree · a transcript is never scanned: it rides whole" holds tree=widget scratch/chat.jsonl
claim "tree · a repo with no origin rides whole" pack_holds tree=solo "$(gx -C "$solo" rev-parse HEAD)"
meta_of() { local d; d="$(unit_dir "$1")" && cat "$d/.grove-backup/meta.json"; }
claim "tree · the manifest names each cut path, by shape and by content" \
  test "$(meta_of tree=widget | jq -c '.cut')" == '[".env","certs/site.pem","deploy.txt","token.txt"]'
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
# a plain-file unit takes the cut a tree takes: by shape, by content, each named in its manifest
claim "orphan · a token by content never rides" lacks orphan=widget.dropped notes.txt
claim "orphan · an .env never rides" lacks orphan=widget.dropped ./.env
claim "orphan · its manifest names each cut" test "$(meta_of orphan=widget.dropped | jq -c .cut)" == '[".env","notes.txt"]'
claim "setaside · a token by content never rides" lacks 'setaside=widget.old.*' notes.txt
claim "setaside · its manifest names the cut" test "$(meta_of 'setaside=widget.old.*' | jq -c .cut)" == '["notes.txt"]'
claim "home · a token by content in .rhachet never rides" lacks home=.rhachet notes.txt
claim "home · its manifest names the cut, never a path in the vault" \
  test "$(meta_of home=.rhachet | jq -c .cut)" == '["meter/notes.txt"]'
claim "home · a files unit's manifest holds no seat" bash -c '! grep -q "$1" <<<"$2"' _ "$ME" "$(meta_of home=.claude)"
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
run; rc=$?
keep_run "a quiet pass, naught changed" "exit $rc"
claim "pass 2 · naught changed, so naught is put" test "$(status '"\(.put) \(.skipped)"')" == "0 $units"
claim "pass 2 · and naught is packed" test "$(packs)" -eq 0

# the refresh age: a quiet unit whose latest object nears the grant's 90-day archive is put
#   again, so a live tree stays restorable by its own box (S8). on a copy, so the moved clock
#   never dates an object later claims read
cp -a "$BUCKET" "$fixture/bucket.refresh"; cp -a "$STATE" "$fixture/state.refresh"
BUCKET="$fixture/bucket.refresh"; STATE="$fixture/state.refresh"
grove_backup_now() { echo $(( $(date -u +%s) + 79 * 86400 )); }
packs_reset
run
claim "refresh · a quiet unit one day short of the refresh age is skipped" test "$(status '"\(.put) \(.skipped)"')" == "0 $units"
grove_backup_now() { echo $(( $(date -u +%s) + 81 * 86400 )); }
refresh_day="$(grove_backup_today)"
packs_reset
run
claim "refresh · at the refresh age, every quiet unit is put again" test "$(status '"\(.put)"')" == "$units"
claim "refresh · each new object is dated the day it was put" \
  test "$(find "$BUCKET" -name "date=$refresh_day.tar.gz" | wc -l)" -eq "$units"
grove_backup_now() { date -u +%s; }
BUCKET="$fixture/bucket"; STATE="$fixture/state"

# a widened cut rule reaches the quiet units too: each packs once under it, and only the one
#   whose bytes change is put (peer i010: a quiet skip that never reads the rules)
claim "rules · a shape no rule names rides" holds tree=solo store.jks
GROVE_BACKUP_SECRET_SHAPES+=('*.jks')
packs_reset
run
claim "rules · a widened cut list packs every tree again" test "$(packs)" -eq 4
claim "rules · only the unit whose bytes changed is put" test "$(status '"\(.put)"')" == 1 -a "$(cat "$fixture/puts")" == "user=$ME/org=acme/repo=solo/tree=solo"
claim "rules · its latest object lacks the newly cut file, and names it" \
  bash -c '! tar -tzf "$1" | grep -q store.jks && [[ "$2" == *store.jks* ]]' _ "$(key_of tree=solo)" "$(meta_of tree=solo | jq -c .cut)"
packs_reset
run
claim "rules · the next pass is quiet again" test "$(packs)" -eq 0 -a "$(status .put)" -eq 0

# a rebuild writes only where the unit never reaches, so the tree stays quiet
packs_reset
printf 'rebuilt again\n' >"$clone/pkg/build/out.js"
printf 'env again\n' >"$clone/.venv/lib/site.py"
run
claim "rebuild · a write in an ignored rebuilt dir packs naught" test "$(packs)" -eq 0

# the unit carries the repo's config, so an edit to it alone is a change
: >"$fixture/puts"
gx -C "$clone" config branch.main.description "the trunk"
run
claim "config · an edit to the repo config alone re-puts the clone" grep -qx "user=$ME/org=acme/repo=widget/tree=widget" "$fixture/puts"

# an origin that does not answer (a lapsed credential reads the same): counted, named, every pass
live_origin="$(gx -C "$clone" remote get-url origin)"
gx -C "$clone" remote set-url origin "$fixture/dead/widget.git"
run
run
claim "silent origin · the status counts each tree whose origin did not answer (the clone and its two worktrees)" test "$(status .origin_unchecked)" -eq 3
claim "silent origin · a pass that puts naught still names it" grep -q "repo=widget/tree=widget · origin did not answer; packs again next pass" "$fixture/run.out"
gx -C "$clone" remote set-url origin "$live_origin"
run
claim "silent origin · once origin answers, naught is counted" test "$(status .origin_unchecked)" -eq 0

# a mark is a claim about the bucket: when the object it vouches for is gone, the
# unit is put again, however quiet the tree
rm -f "$(key_of tree=solo)"
run
claim "lost object · the one unit whose object was deleted is put again" test "$(status '"\(.put) \(.skipped)"')" == "1 $((units - 1))"
claim "lost object · it is in the bucket once more" test -n "$(key_of tree=solo)"
find "$BUCKET" -name '*.tar.gz' -delete
run
claim "emptied bucket · every unit is put again" test "$(status '"\(.put) \(.skipped)"')" == "$units 0"
# a mark from before marks kept their key vouches for naught
find "$STATE/marks" -name '*.json' -exec sh -c 'jq "del(.key)" "$1" >"$1.t" && mv "$1.t" "$1"' _ {} \;
packs_reset
: >"$fixture/puts"
run
claim "keyless mark · every tree is packed again" test "$(packs)" -gt 0
[[ "$(status .put)" -eq 0 ]] || sed 's/^/      │ put again: /' "$fixture/puts" >&2
claim "keyless mark · same bytes as the bucket's latest, so naught is put" test "$(status .put)" -eq 0
claim "keyless mark · and the marks now hold their key" test -z "$(find "$STATE/marks" -name '*.json' -exec jq -r 'select(.key == null or .key == "") | .unit' {} \;)"

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

# a live conversation appends as a matter of course: it never forces a repack, and the
#   unit still reads as one still capture (the transcript lands as a prefix of itself)
packs_reset
printf '{"line":3}\n' >>"$wt/$transcript_rel"
EDIT_DURING_PACK="$wt/$transcript_rel"; echo 1 >"$fixture/edits.left"
run
claim "live transcript · an append mid-pack packs once, no repack" test "$(packs)" -eq 1
claim "live transcript · still a point-in-time capture" test "$(meta_of "$FEAT" | jq -r .point_in_time)" == true
# the append that landed mid-pack rides the next pass, as its stamp says
EDIT_DURING_PACK=""
packs_reset
run
claim "live transcript · the mid-pack append lands on the next pass" test "$(packs)" -eq 1
EDIT_DURING_PACK="$spike/new.txt"

packs_reset
echo again >>"$spike/new.txt"
echo 5 >"$fixture/edits.left"
run
claim "constant motion · three packs, no more" test "$(packs)" -eq 3
claim "constant motion · it lands, flagged" test "$(meta_of tree=widget.spike | jq -r .point_in_time)" == false
mkdir -p "$fixture/pit_seat/$ME"
( HOME="$fixture/pit_seat/$ME"; restore_main --from grove-1 --of acme/widget --tree widget.spike --into "$fixture/aside/pit" ) >"$fixture/out.pit" 2>&1; rc=$?
claim "constant motion · its restore names that its files may span a few seconds" grep -q "moved through each pack of its last pass" "$fixture/out.pit"
# every --into success text a human reads, one section per unit kind, snapped as restore.into
snap_into="## a worktree, aside, its pass in constant motion"$'\n'"rc=$rc"$'\n'"$(cat "$fixture/out.pit")"$'\n'
claim "--into · a worktree lands aside as a clone of its own, named" grep -q '+ laid aside at .*/aside/pit, a clone of its own' "$fixture/out.pit"
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

# .what = keep the status a failed pass just wrote, so `get` renders it in get.surfaces below
keep_status() { cp "$STATE/status.json" "$fixture/kept.$1.json"; }

######################################################################
# a rebuild that kept its name — it never shadows the dead grove's latest units
######################################################################
STATE="$fixture/state.rebuilt"; mkdir -p "$STATE"
objects_before="$(find "$BUCKET" -name '*.tar.gz' | sort | xargs cat | sha256sum)"
packs_reset
# its first pass fails before the guard (no credential yet), and writes a failed status
STUB_CRED=1; run; STUB_CRED=0
claim "rebuild · a first pass with no reach writes a failed status" test "$(status .verdict)" == failed
run; rc=$?
claim "rebuild · a box that never wrote its name's prefix writes naught to it" \
  test "$rc" -eq 1 -a "$(find "$BUCKET" -name '*.tar.gz' | sort | xargs cat | sha256sum)" == "$objects_before"
claim "rebuild · it fails, named, never a ✓" \
  test "$(status .cause)" == "grove=grove-1 holds a backup this box never wrote"
claim "rebuild · the fix names the seat, the restore, then the adopt" \
  bash -c '[[ "$1" == *"as camper"*"rhx grove.backup.restore --from grove-1 --all"*"grove-backup --adopt" ]]' _ "$(status .fix)"
keep_status rebuild
run; rc=$?
claim "rebuild · its own failed status never unlocks the next pass" \
  test "$rc" -eq 1 -a "$(find "$BUCKET" -name '*.tar.gz' | sort | xargs cat | sha256sum)" == "$objects_before"
grove_backup_prefix_claim "$STATE"
run; rc=$?
claim "rebuild · once adopted, the pass lands" test "$rc" -eq 0 -a "$(status .verdict)" == ok
keep_status ok
empty_prefix_is_ours() { grove_backup_prefix_is_ours "$fixture/state.empty" /dev/null; }
claim "first pass · an empty prefix needs no adopt" empty_prefix_is_ours
BUCKET="$fixture/bucket"; STATE="$fixture/state"

######################################################################
# the reach — its written order, its cause
######################################################################
reach_cause() { run; status .cause; }

mv "$fixture/etc/name" "$fixture/etc/name.off"; mv "$fixture/etc/bucket" "$fixture/etc/bucket.off"
claim "reach · both absent → the grove name is the cause" test "$(reach_cause)" == "grove name undeclared"
keep_status grove-name
mv "$fixture/etc/name.off" "$fixture/etc/name"
claim "reach · bucket absent → its cause" test "$(reach_cause)" == "bucket name undeclared"
mv "$fixture/etc/bucket.off" "$fixture/etc/bucket"
STUB_CRED=4
claim "reach · no credential → its cause" test "$(reach_cause)" == "no aws credential"
STUB_CRED=0
printf 'still more\n' >>"$wt/draft.md"
STUB_PUT=3
claim "reach · a refused put → the verb named" test "$(reach_cause)" == "access denied: s3:PutObject"
keep_run "a pass whose put the bucket denied" "verdict $(status .verdict)"
claim "reach · last_ok survives a failed run" test "$(status '.last_ok != null')" == true
STUB_PUT=0
HOME_ROOT="$fixture/empty"; mkdir -p "$HOME_ROOT/$ME"
claim "reach · zero units is never ✓" test "$(reach_cause)" == "no units found under $fixture/empty/$ME"
keep_status zero-units
HOME_ROOT="$fixture/dead"
# the disk is asked per unit, of its own bytes: a quiet unit stages naught, so a disk
#   with no room left still runs a quiet pass to ✓, and one moved unit fails alone
run
GROVE_BACKUP_DISK_FLOOR_KB=$((1024 * 1024 * 1024 * 1024))
run
claim "disk · a quiet pass on a disk with no room stages naught, so it reads ✓" test "$(status .verdict)" == ok
printf 'disk\n' >>"$wt/draft.md"
run; rc=$?
keep_run "a failed pass, one unit with no room on the disk" "exit $rc"
claim "disk · a unit whose bytes do not fit fails, named with what it needs" \
  bash -c '[[ "$1" == *"/tree=widget.feat-x disk · "*" MiB free; this needs "*" MiB and keeps "*" MiB free" ]]' _ \
  "$(jq -r '.failures[] | "\(.unit) \(.why)"' "$STATE/status.json")"
claim "disk · only that unit fails; every quiet one is skipped" \
  test "$(status '"\(.failed) \(.skipped)"')" == "1 $(( $(status .units) - 1 ))"
claim "disk · the pass is ✗, and its fix names the disk" bash -c '[[ "$1" == "free space on the disk that holds "* ]]' _ "$(status .fix)"
keep_status disk-unit
GROVE_BACKUP_DISK_FLOOR_KB=0
run
claim "disk · once it fits, the unit lands" test "$(status '"\(.verdict) \(.put)"')" == "ok 1"

# a clone of its own under _worktrees, named as a clone already in ~/git: its commits ride in
#   no unit, so the pass is ✗ and names it until the dir is renamed (peer i010)
#   its own bucket and state, so the twin's unit never reaches the restore below
BUCKET="$fixture/bucket.gap"; STATE="$fixture/state.gap"; mkdir -p "$BUCKET" "$STATE"
gx clone -q "$clone" "$seat/git/acme/_worktrees/widget" 2>/dev/null
gx -C "$seat/git/acme/_worktrees/widget" commit -q --allow-empty -m 'unpushed in the twin'
run
claim "gap · a tree whose commits ride in no unit fails the pass" test "$(status .verdict)" == failed
claim "gap · the cause names it" test "$(status .cause)" == "1 tree's commits ride in no unit"
claim "gap · its failure names the dir and the fix" \
  bash -c '[[ "$1" == "user=$2/org=acme/orphan=widget walk "*"rename the dir" ]]' _ \
  "$(jq -r '.failures[] | "\(.unit) \(.kind) \(.why)"' "$STATE/status.json")" "$ME"
keep_status gap
claim "gap · its files still ride" test -n "$(key_of org=acme/orphan=widget)"
rm -rf "$seat/git/acme/_worktrees/widget"
run
claim "gap · once renamed away, the pass is ✓" test "$(status .verdict)" == ok
BUCKET="$fixture/bucket"; STATE="$fixture/state"

# a worktree git cannot name apart from its clone rides as plain files, never as a
#   tree unit that collides with the clone or fails its pack each pass
walk_seat="$fixture/walkseat/$ME"
mkdir -p "$walk_seat/git/acme/_worktrees/broken"
gx -C "$clone" worktree add -q --detach "$walk_seat/git/acme/_worktrees/widget"
printf 'gitdir: %s\n' "$fixture/nowhere" >"$walk_seat/git/acme/_worktrees/broken/.git"
walk_kind() { ( grove_backup_seat_home() { printf '%s' "$walk_seat"; }; grove_backup_units_walk ) | awk -F'\t' -v p="$1" '$3 == p { print $1 "\t" $4 }'; }
claim "walk · a worktree named as its repo rides as an orphan, apart from the clone" \
  test "$(walk_kind "$walk_seat/git/acme/_worktrees/widget")" == "orphan	user=$ME/org=acme/orphan=widget"
claim "walk · a worktree with a broken link rides as an orphan" \
  test "$(walk_kind "$walk_seat/git/acme/_worktrees/broken" | cut -f1)" == orphan
gx -C "$clone" worktree remove --force "$walk_seat/git/acme/_worktrees/widget"

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
# the staged secret is the one row that differs: it never left the dead grove
claim "worktree alone · git status reads as the dead tree did, but for its staged secret" \
  test "$(fg status --porcelain | sort)" == "$(git -C "$wt" status --porcelain | grep -v ' \.env\.local$' | sort)"
claim "worktree alone · the staged secret is unstaged, and named" \
  test -z "$(fg ls-files -- .env.local)" -a "$(grep -c '1 staged path of a secret shape left unstaged' "$fixture/out")" -eq 1

printf 'live notes\n' >"$live/notes.txt"
# the live clone's own topic: neither it nor the dead one holds the other
live_topic="$(gx -C "$live" commit-tree -p "$base_sha" -m 'live topic' "$base_sha^{tree}")"
gx -C "$live" update-ref refs/heads/topic "$live_topic"
# before the graft: each file the live clone changed of its own, by digest, and its refs
live_own_paths="$(git -C "$live" ls-files -m -o --exclude-standard)"
live_own_digest() { local p; while IFS= read -r p; do [[ -n "$p" ]] && sha256sum -- "$live/$p" 2>/dev/null || echo "absent $p"; done <<<"$live_own_paths"; }
live_own_before="$(live_own_digest)"
live_refs() { git -C "$live" for-each-ref --format='%(refname)' | sort; }
live_refs_before="$(live_refs)"
restore --from grove-1 --of acme/widget --tree widget; rc=$?
claim "clone graft · exits 0" test "$rc" -eq 0
snap_clone="$(cat "$fixture/out")"
has_ref() { git -C "$1" rev-parse -q --verify "$2" >/dev/null; }
claim "clone graft · the branch origin dropped lands" has_ref "$live" refs/heads/gone
claim "clone graft · the checked-out main fast-forwards on its clean tree" \
  test "$(git -C "$live" rev-parse main)" == "$(git -C "$clone" rev-parse main)"
claim "clone graft · a diverged branch is never moved" test "$(git -C "$live" rev-parse topic)" == "$live_topic"
claim "clone graft · a diverged branch lands aside as <grove>/<branch>, at the dead sha" \
  test "$(git -C "$live" rev-parse -q --verify refs/heads/grove-1/topic)" == "$topic_sha"
claim "clone graft · the diverged branch is named in the report" grep -q 'topic.*diverged.*landed as grove-1/topic' "$fixture/out"
claim "clone graft · the stash is here" test "$(git -C "$live" stash list | wc -l)" -eq 1
claim "clone graft · the stash's contents stay in the stash, never laid on the live tree" test ! -e "$live/stash-me.txt"
claim "clone graft · the dead checkout's edit lands, on the same HEAD" \
  test "$(cat "$live/src/build/keep.txt")" == "tracked, edited"
claim "clone graft · a file this clone holds of its own is kept, and named" \
  test "$(cat "$live/notes.txt")" == "live notes" -a "$(grep -c 'notes.txt (kept' "$fixture/out")" -eq 1
claim "clone graft · every file the live clone changed of its own is byte for byte as it was" \
  test -n "$live_own_paths" -a "$(live_own_digest)" == "$live_own_before"
# the refs after are exactly the refs before plus what the report names: the dropped branch,
#   the diverged one aside, the stash. no stray ref, in any namespace
claim "clone graft · the live refs are exactly the refs before, plus the three the report names" \
  test "$(live_refs)" == "$(printf '%s\n' "$live_refs_before" refs/heads/gone refs/heads/grove-1/topic refs/stash | sort -u)"
claim "clone graft · each path cut as a credential is named, never laid" \
  test "$(grep -c '4 files cut as a credential never left grove-1' "$fixture/out")" -eq 1 -a ! -e "$live/deploy.txt"

# a live clone whose own stash differs: the dead stash lands aside as <grove>/stash, and the
#   live stash is never moved. the state is put back after, so the claims below read the graft
dead_stash="$(git -C "$clone" rev-parse refs/stash)"
live_stash="$(gx -C "$live" commit-tree -p HEAD -m 'live stash' "HEAD^{tree}")"
gx -C "$live" update-ref refs/stash "$live_stash"
restore --from grove-1 --of acme/widget --tree widget; rc=$?
claim "stash differs · exits 0" test "$rc" -eq 0
claim "stash differs · the dead stash lands aside as grove-1/stash" \
  test "$(git -C "$live" rev-parse -q --verify refs/heads/grove-1/stash)" == "$dead_stash"
claim "stash differs · the live stash is never moved" test "$(git -C "$live" rev-parse refs/stash)" == "$live_stash"
claim "stash differs · the report names where it landed" grep -q 'grove-1/stash' "$fixture/out"
gx -C "$live" update-ref refs/stash "$dead_stash"
gx -C "$live" update-ref -d refs/heads/grove-1/stash

restore --from grove-1 --of acme/solo --tree solo --into "$fixture/aside/solo"; rc=$?
claim "no origin · lands whole, aside" test "$rc" -eq 0 -a "$(cat "$fixture/aside/solo/a.txt" 2>/dev/null)" == solo
snap_into+=$'\n'"## a clone with no origin, aside"$'\n'"rc=$rc"$'\n'"$(cat "$fixture/out")"$'\n'

# 🛑 every unit version a pass ever wrote stays readable: an object never expires, and a
#   dead grove's agent is never upgraded. each version holds one committed golden object,
#   the solo clone as that version's pack wrote it; a reader that drops a version reddens here.
#   the current version's golden is minted once when absent, and read back on every run after.
#   "committed" reads the git index, never the disk: a golden this run just minted is on disk
#   and reds until a human stages it, so a checkout that never tracked one cannot pass
goldendir="$HERE/.play/permanent/prove.grove-backup-round-trip.golden"
for v in "${GROVE_BACKUP_UNIT_VERSIONS_READ[@]}"; do
  golden="$goldendir/v$v.solo.tar.gz"
  if [[ ! -f "$golden" && "$v" == "$GROVE_BACKUP_UNIT_VERSION" ]]; then
    mkdir -p "$goldendir" && cp "$(key_of tree=solo)" "$golden"
    echo "   🌱 golden v$v minted: $golden — stage it, then rerun"
  fi
  claim "golden v$v · committed" bash -c 'git -C "$1" ls-files --error-unmatch -- "$2" >/dev/null 2>&1' _ "$HERE" "$golden"
  # this repo is public: the committed bytes name no seat and no path of the box that minted them
  claim "golden v$v · names no seat, no host path" \
    bash -c '! gzip -dc "$1" | grep -aq -e "$2" -e /tmp/ -e /home/' _ "$golden" "$ME"
  gkey="grove=golden/user=$ME/org=acme/repo=solo/tree=solo/date=2026-01-01.tar.gz"
  mkdir -p "$(dirname "$BUCKET/$gkey")" && cp "$golden" "$BUCKET/$gkey" 2>/dev/null
  restore --from golden --of acme/solo --tree solo --into "$fixture/golden/v$v"; rc=$?
  claim "golden v$v · this restore reads it, whole" \
    test "$rc" -eq 0 -a "$(cat "$fixture/golden/v$v/a.txt" 2>/dev/null)" == solo \
         -a "$(git -C "$fixture/golden/v$v" log -1 --format=%s 2>/dev/null)" == solo
  rm -rf "$BUCKET/grove=golden"
done

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
snap_into+=$'\n'"## an orphan, aside"$'\n'"rc=$rc"$'\n'"$(cat "$fixture/out")"$'\n'
claim "--orphan · one dropped worktree, aside: its transcript byte for byte" \
  test "$rc" -eq 0 -a -f "$fixture/aside/dropped/$transcript_rel"
claim "--orphan · the aside copy matches the dead one" cmp -s "$dropped/$transcript_rel" "$fixture/aside/dropped/$transcript_rel"
restore --from grove-1 --of acme/widget --setaside "${fsa##*/}" --into "$fixture/aside/setaside"; rc=$?
snap_into+=$'\n'"## a set-aside tree, aside"$'\n'"rc=$rc"$'\n'"$(cat "$fixture/out")"$'\n'
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
claim "home · it names the brain login the seat owes" grep -q 'rhx brains.auth.set' <<<"$snap_all"
claim "home · keyrack/ is never laid" test ! -e "$fresh_seat/.rhachet/keyrack"
claim "home · role storage lands" test -f "$fresh_seat/.rhachet/meter/uses"
claim "files · a cut credential is never laid" \
  test ! -e "$fresh_seat/.rhachet/meter/notes.txt" -a ! -e "$fresh_seat/git/acme/_worktrees/widget.dropped/notes.txt"
claim "files · the manifest is never laid as a file of the home" \
  test ! -e "$fresh_seat/.rhachet/.grove-backup" -a ! -e "$fresh_seat/git/acme/_worktrees/widget.dropped/.grove-backup"
claim "files · each unit's cuts are named" \
  bash -c 'grep -q "2 files cut as a credential never left grove-1" <<<"$1" && grep -q "meter/notes.txt" <<<"$1"' _ "$snap_all"

restore --from grove-1 --all; rc=$?
claim "--all again · a resume: exits 0, lays naught twice" test "$rc" -eq 0 -a "$(grep -c 'already here' "$fixture/out")" -ge 2

# one home dir, in place, alone: a second fresh seat, so the --all lay above stays the one it read
home2_seat="$fixture/fresh-home/$ME"
mkdir -p "$home2_seat"
( HOME="$home2_seat"; restore_main --from grove-1 --home .rhachet ) >"$fixture/out" 2>&1; rc=$?
claim "--home in place · exits 0" test "$rc" -eq 0
claim "--home in place · role storage lands in the seat's own home" test -f "$home2_seat/.rhachet/meter/uses"
claim "--home in place · keyrack/ is never laid" test ! -e "$home2_seat/.rhachet/keyrack"
claim "--home in place · lays naught else" test ! -e "$home2_seat/.claude" -a ! -e "$home2_seat/git"
snap_into+=$'\n'"## one home dir, in place"$'\n'"rc=$rc"$'\n'"$(cat "$fixture/out")"$'\n'

# a restore cut mid-lay: the checkout never ran. the rerun must wipe the half-laid
#   target and lay it whole — never graft into it, nor keep it as `already here`
cut_seat="$fixture/cut/$ME"
mkdir -p "$cut_seat/git"
cut_restore() { ( HOME="$cut_seat"; restore_tree_checkout() { return 1; }; restore_main "$@" ) >"$fixture/out" 2>&1; }
uncut_restore() { ( HOME="$cut_seat"; restore_main "$@" ) >"$fixture/out" 2>&1; }
cut_live="$cut_seat/git/acme/widget"
cut_wt="$cut_seat/git/acme/_worktrees/widget.feat-x"
cut_restore --from grove-1 --of acme/widget --tree widget.feat-x; rc=$?
claim "cut · a worktree cut mid-lay is no success" test "$rc" -ne 0
claim "cut · it leaves its sentinel beside the target" test -f "$cut_wt.grove-restore.unfinished"
# a pass over a half-laid tree would pack a hollow checkout as its truth: the walk skips it, named
cut_walk="$( grove_backup_seat_home() { printf '%s' "$cut_seat"; }; grove_backup_units_walk 2>"$fixture/walk.err" )"
claim "cut · the walk passes over the half-laid worktree" bash -c '! grep -q "tree=widget.feat-x$" <<<"$1"' _ "$cut_walk"
claim "cut · and names it as laid in part" grep -q 'widget.feat-x · a restore is laid in part here' "$fixture/walk.err"
uncut_restore --from grove-1 --of acme/widget --tree widget.feat-x; rc=$?
claim "cut · the rerun lays the worktree whole" test "$rc" -eq 0 -a "$(git -C "$cut_wt" log --format=%s -1 2>/dev/null)" == "unpushed two"
claim "cut · its transcript, byte for byte" cmp -s "$wt/$transcript_rel" "$cut_wt/$transcript_rel"
claim "cut · the rerun names the wipe" grep -q 'a prior restore was cut as it laid' "$fixture/out"
claim "cut · and clears the sentinel" test ! -e "$cut_wt.grove-restore.unfinished"
mv "$cut_live" "$fixture/cut/live.aside"
cut_restore --from grove-1 --of acme/widget --tree widget; rc=$?
claim "cut · a clone cut mid-lay leaves its sentinel" test "$rc" -ne 0 -a -f "$cut_live.grove-restore.unfinished"
uncut_restore --from grove-1 --of acme/widget --tree widget; rc=$?
claim "cut · the rerun lays the clone whole, never a graft" \
  test "$rc" -eq 0 -a "$(grep -c 'graft into' "$fixture/out")" -eq 0 -a "$(cat "$cut_live/src/build/keep.txt" 2>/dev/null)" == "tracked, edited"
claim "cut · the clone's conversation, byte for byte" cmp -s "$clone/$transcript_rel" "$cut_live/$transcript_rel"

# a live clone behind the dead one, with main checked out on a dirty tree: the dead main
#   lands aside, and the live tree is never touched
dirty_seat="$fixture/dirty/$ME"
dirty_live="$dirty_seat/git/acme/widget"
mkdir -p "$dirty_seat/git/acme"
gx clone -q "$origin" "$dirty_live" 2>/dev/null
printf 'a live edit\n' >"$dirty_live/README.md"
( HOME="$dirty_seat"; restore_main --from grove-1 --of acme/widget --tree widget ) >"$fixture/out" 2>&1; rc=$?
snap_dirty="$(cat "$fixture/out")"
claim "dirty main · exits 0" test "$rc" -eq 0
claim "dirty main · the dead main lands aside as grove-1/main" \
  test "$(git -C "$dirty_live" rev-parse -q --verify refs/heads/grove-1/main)" == "$(git -C "$clone" rev-parse main)"
claim "dirty main · the live main never moves, its edit kept" \
  test "$(git -C "$dirty_live" rev-parse main)" == "$base_sha" -a "$(cat "$dirty_live/README.md")" == "a live edit"
claim "dirty main · names the merge once clean" grep -q 'once the tree is clean: git -C .* merge --ff-only grove-1/main' "$fixture/out"

# a fresh grove whose clone of origin sits on a commit of its own: the HEADs differ, as on
#   a real fresh grove, so the dead checkout's edits have no base — and its conversation still lands
other_seat="$fixture/other/$ME"
other_live="$other_seat/git/acme/widget"
mkdir -p "$other_seat/git/acme"
gx clone -q "$origin" "$other_live" 2>/dev/null
gx -C "$other_live" commit -q --allow-empty -m 'the live clone moved on'
( HOME="$other_seat"; restore_main --from grove-1 --of acme/widget --tree widget ) >"$fixture/out" 2>&1; rc=$?
snap_other_head="$(cat "$fixture/out")"
claim "another HEAD · exits 0" test "$rc" -eq 0
claim "another HEAD · the clone's conversation lands, byte for byte" cmp -s "$clone/$transcript_rel" "$other_live/$transcript_rel"
claim "another HEAD · an untracked file absent here lands" test "$(cat "$other_live/notes.txt" 2>/dev/null)" == "dead notes"
claim "another HEAD · a tracked edit is held, never laid" test "$(cat "$other_live/src/build/keep.txt")" == "tracked"
claim "another HEAD · the held count is named" grep -q 'held: the dead checkout sat on another HEAD' "$fixture/out"

# an old backup in DEEP_ARCHIVE: a thaw is asked, then awaited — never a raw failure
STUB_CLASS=DEEP_ARCHIVE
restore --from grove-1 --orphan acme/widget.dropped --into "$fixture/aside/thaw"; rc=$?
snap_thaw="## the first ask"$'\n'"rc=$rc"$'\n'"$(cat "$fixture/out")"$'\n'
claim "thaw · the first ask exits 0, a wait and no failure" test "$rc" -eq 0
claim "thaw · names the thaw and the resume" grep -q 'thaw requested' "$fixture/out"
claim "thaw · tallies the unit as one that awaits" grep -q '1 await a thaw' "$fixture/out"
claim "thaw · lays naught while it waits" test ! -e "$fixture/aside/thaw"
# s3's own field for a thaw in flight
STUB_RESTORE='ongoing-request="true"'
restore --from grove-1 --orphan acme/widget.dropped --into "$fixture/aside/thaw"; rc=$?
snap_thaw+=$'\n'"## the resume, while it thaws"$'\n'"rc=$rc"$'\n'"$(cat "$fixture/out")"$'\n'
claim "thaw · the resume reads the thaw in progress" grep -q 'its thaw is in progress' "$fixture/out"
claim "thaw · the resume names when it was asked" grep -q 'asked .* ago' "$fixture/out"
# s3's own field once the thaw is done: the copy is readable, and the resume lays it
STUB_RESTORE='ongoing-request="false", expiry-date="Fri, 27 Nov 2026 00:00:00 GMT"'
restore --from grove-1 --orphan acme/widget.dropped --into "$fixture/aside/thaw"; rc=$?
snap_thaw+=$'\n'"## the resume, once thawed"$'\n'"rc=$rc"$'\n'"$(cat "$fixture/out")"$'\n'
claim "thaw · the resume once thawed lays the unit, its transcript byte for byte" \
  test "$rc" -eq 0 -a -f "$fixture/aside/thaw/$transcript_rel"
claim "thaw · the landed copy matches the dead one" cmp -s "$dropped/$transcript_rel" "$fixture/aside/thaw/$transcript_rel"
claim "thaw · once landed, it tallies as restored, never as one that awaits" grep -q '1 restored' "$fixture/out"
STUB_CLASS=STANDARD STUB_RESTORE=None

# each refusal a human can meet: its exit, and its text into one snap
snap_refusals=""
refusal() {
  local label="$1" want="$2" rc; shift 2
  restore "$@"; rc=$?
  snap_refusals+=$'\n'"## $label"$'\n'"rc=$rc"$'\n'"$(cat "$fixture/out")"$'\n'
  claim "$label · exit $want" test "$rc" -eq "$want"
}
refusal "worktree · a named restore over a present one refuses" 2 --from grove-1 --of acme/widget --tree widget.feat-x
refusal "absent grove · never an empty success"                2 --from grove-9 --all
refusal "help"                                                 0 --help
refusal "no --from"                                            2 --all
refusal "a --from that is no grove slug"                       2 --from 'grove 1' --all
refusal "no unit named"                                        2 --from grove-1
refusal "two units named"                                      2 --from grove-1 --all --home .claude
refusal "--of with no org/repo pair"                           2 --from grove-1 --of widget --tree widget
refusal "--home of a dir never backed up"                      2 --from grove-1 --home .ssh
refusal "--into with --all"                                    2 --from grove-1 --all --into "$fixture/aside/x"
refusal "an unknown argument"                                  2 --from grove-1 --bogus
refusal "--orphan with no org/dir pair"                        2 --from grove-1 --orphan widget.dropped
refusal "--into onto a present dir"                            2 --from grove-1 --of acme/widget --tree widget --into "$fixture/aside/solo"
# a refused grant, at the list and at one unit's object: each a ✋ with the owed grant named
STUB_LIST=3
refusal "the bucket list denied"                               2 --from grove-1 --all
claim "denied list · names the verb and the isolation line" \
  bash -c 'grep -q "access denied: s3:ListBucket" "$1" && grep -q "its declared predecessor alone" "$1"' _ "$fixture/out"
STUB_LIST=0 STUB_GET=3
refusal "one unit's object denied"                             2 --from grove-1 --orphan acme/widget.dropped --into "$fixture/aside/denied"
claim "denied object · a ✋ with the grant's line, never a fixless malfunction" \
  bash -c 'grep -q "✋ ConstraintError: access denied: s3:GetObject" "$1" && grep -q "fix: the grant refused it" "$1" && ! grep -q "💥" "$1"' _ "$fixture/out"
claim "denied object · naught is laid" test ! -e "$fixture/aside/denied"
STUB_GET=0
# past the 90-day reach: the object sits archived, and the grant refuses this box its thaw (S8)
STUB_CLASS=DEEP_ARCHIVE STUB_RESTORE=None STUB_THAW=3
refusal "an archived unit past the 90-day reach"               2 --from grove-1 --orphan acme/widget.dropped --into "$fixture/aside/locked"
claim "locked · a ✋ that names the reach and the admin thaw, never a camper retry" \
  bash -c 'grep -q "past this box.s 90-day reach" "$1" && grep -q "aws s3api restore-object" "$1" && ! grep -q "thaw requested" "$1"' _ "$fixture/out"
claim "locked · naught is laid" test ! -e "$fixture/aside/locked"
STUB_CLASS=STANDARD STUB_THAW=0
# no bucket declared on this box: the cause names the declaration, never an empty list
mv "$fixture/etc/bucket" "$fixture/etc/bucket.off"
refusal "no bucket declared"                                   2 --from grove-1 --all
claim "no bucket · names the undeclared bucket" grep -q 'bucket name undeclared' "$fixture/out"
mv "$fixture/etc/bucket.off" "$fixture/etc/bucket"
refusal "a tree the grove never backed up"                     2 --from grove-1 --of acme/widget --tree widget.nosuch
# the seat that provisions is the one a commander lands on first: each refusal names how to switch
seat_refusal() {
  local label="$1" want="$2" rc; shift 2
  mkdir -p "$fixture/ground/ground"
  ( HOME="$fixture/ground/ground"; id() { [[ "$1" == -un ]] && { echo ground; return 0; }; command id "$@"; }; restore_main "$@" ) >"$fixture/out" 2>&1; rc=$?
  snap_refusals+=$'\n'"## $label"$'\n'"rc=$rc"$'\n'"$(cat "$fixture/out")"$'\n'
  claim "$label · exit $want" test "$rc" -eq "$want"
  claim "$label · names how to become the seat" grep -q 'become that seat and rerun (from ground: sudo -iu ' "$fixture/out"
}
seat_refusal "another seat · --all holds no unit of this seat"  2 --from grove-1 --all
seat_refusal "another seat · a named unit of another seat"      2 --from grove-1 --of acme/widget --tree widget
# the disk refusals name this box's own free MiB: each figure is masked, the shape snapped
disk_snap() { sed -E 's/[0-9]+ MiB/<n> MiB/g' "$fixture/out"; }
GROVE_BACKUP_DISK_FLOOR_KB=$((1024 * 1024 * 1024 * 1024))
restore --from grove-1 --all; rc=$?
snap_refusals+=$'\n'"## no room on the disk, before any unit"$'\n'"rc=$rc"$'\n'"$(disk_snap)"$'\n'
claim "no room on the disk · exit 2, named, naught laid" \
  test "$rc" -eq 2 -a "$(grep -c 'no room to lay a restore' "$fixture/out")" -eq 1
GROVE_BACKUP_DISK_FLOOR_KB=0
# a unit whose own bytes do not fit, on a disk the opener passes: the real check runs, with the
#   floor raised only for a nonzero need, so the opener (need 0) passes and the unit refuses
eval "$(declare -f grove_backup_disk_fits | sed '1s/^grove_backup_disk_fits/grove_backup_disk_fits_real/')"
grove_backup_disk_fits() {
  [[ "${2:-0}" -gt 0 ]] || { grove_backup_disk_fits_real "$@"; return; }
  GROVE_BACKUP_DISK_FLOOR_KB=$((1024 * 1024 * 1024 * 1024)) grove_backup_disk_fits_real "$@"
}
restore --from grove-1 --of acme/widget --tree widget --into "$fixture/aside/nofit"; rc=$?
snap_refusals+=$'\n'"## no room for this unit's own bytes"$'\n'"rc=$rc"$'\n'"$(disk_snap)"$'\n'
claim "no room for one unit · the unit refuses, named with what it needs" \
  grep -q 'no room to lay this unit: .* MiB free; this needs .* MiB' "$fixture/out"
claim "no room for one unit · naught of it laid" test ! -e "$fixture/aside/nofit"
eval "$(declare -f grove_backup_disk_fits_real | sed '1s/^grove_backup_disk_fits_real/grove_backup_disk_fits/')"
STUB_CRED=4
refusal "no credential to read the bucket"                     2 --from grove-1 --all
STUB_CRED=5
refusal "aws gave no answer · a retry may cure it"             1 --from grove-1 --all
claim "aws gave no answer · the restore reads it as a malfunction" \
  grep -q '💥 MalfunctionError: cannot reach the backup bucket' "$fixture/out"
STUB_CRED=0
# a second restore on the seat, while one holds the lock
mkdir -p "$fresh_seat/.cache/grove-backup"
exec 9>"$fresh_seat/.cache/grove-backup/restore.lock"
flock -n 9 || { echo "💥 MalfunctionError: the play could not hold the restore lock" >&2; exit 1; }
refusal "a restore is active on this seat"                     2 --from grove-1 --all
exec 9>&-

######################################################################
# grove.backup.get — the list surfaces a commander reads before a restore
######################################################################
get() { ( get_main "$@" ) >"$fixture/out" 2>&1; }
out_has() { grep -qF -- "$1" "$fixture/out"; }

get --list; rc=$?; snap_get_list="$(cat "$fixture/out")"
claim "get --list · exits 0" test "$rc" -eq 0
claim "get --list · names grove-1" out_has "grove-1"
# a real grove name outruns a short one, and a stamp outruns `(none yet)`: this box names itself
#   long before its first backup, so the list holds `<date> grove-1` and `(none yet) <long>`.
#   each row's date and name must start where every other row's do
mv "$fixture/etc/name" "$fixture/etc/name.short"; printf 'grove-with-a-name-past-twenty-four\n' >"$fixture/etc/name"
get --list; rc=$?
snap_get_list+=$'\n\n'"## this box's own grove, named before its first backup"$'\n'"$(cat "$fixture/out")"
mv "$fixture/etc/name.short" "$fixture/etc/name"
claim "get --list · this box's own grove, with no backup yet, reads (none yet)" \
  grep -qE '\(none yet\) +grove-with-a-name-past-twenty-four' "$fixture/out"
grove_cols() {
  awk '/├─/ {
    d = match($0, /([0-9][0-9][0-9][0-9]-|\(none yet\))/) ? RSTART : 0
    n = match($0, / grove-/) ? RSTART : 0
    print d ":" n
  }' "$fixture/out" | sort -u | wc -l
}
claim "get --list · a long grove name and a short one share one date column and one name column" \
  test "$rc" -eq 0 -a "$(grep -c '├─' "$fixture/out")" -eq 2 -a "$(grove_cols)" -eq 1

# a grant scoped per grove refuses the fleet list (S8): the box lists the groves it reaches —
#   its own, then its declared predecessor — and names who holds the rest
printf 'grove-0\n' >"$fixture/etc/predecessor"
STUB_PREFIXES=3; get --list; rc=$?; STUB_PREFIXES=0
snap_get_list+=$'\n\n'"## a grant scoped per grove, with a declared predecessor"$'\n'"$(cat "$fixture/out")"
claim "get --list · scoped · exit 0, its own grove and its predecessor alone" \
  bash -c '[[ "$1" -eq 0 ]] && grep -q "grove-1$" "$2" && grep -q "(none yet) *grove-0$" "$2"' _ "$rc" "$fixture/out"
claim "get --list · scoped · names the admin tier for the fleet" out_has "the admin tier lists the fleet"
printf 'Grove_0\n' >"$fixture/etc/predecessor"
STUB_PREFIXES=3; get --list; rc=$?; STUB_PREFIXES=0
claim "get --list · scoped · a broken predecessor declaration is a fault, named" \
  bash -c '[[ "$1" -eq 2 ]] && grep -q "unreadable: .*predecessor" "$2"' _ "$rc" "$fixture/out"
rm -f "$fixture/etc/predecessor"

get --from grove-1 --list; rc=$?; snap_get_units="$(cat "$fixture/out")"
claim "get --from · exits 0" test "$rc" -eq 0
claim "get --from · lists a clone" grep -qE 'org=acme/repo=widget/tree=widget$' "$fixture/out"
claim "get --from · lists a dropped worktree" out_has "/orphan="
claim "get --from · lists a set-aside" out_has "/setaside="
claim "get --from · lists a home dir" out_has "home=.claude"
claim "get --from · a clone before its home dir, as --all lays them" \
  test "$(grep -nE 'tree=widget$' "$fixture/out" | head -n 1 | cut -d: -f1)" -lt "$(grep -n 'home=.claude' "$fixture/out" | head -n 1 | cut -d: -f1)"
# read raw, before the mask: the mask shortens a sha, so only the raw rows show the true columns.
#   date-first: each row's date and its unit name start where every other row's do, and a row
#   is no wider than its own name needs — a long tree never widens a short one
unit_cols() {
  awk '/ STANDARD / {
    d = match($0, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] /) ? RSTART : 0
    n = match($0, / (org|home)=/) ? RSTART : 0
    print d ":" n
  }' "$fixture/out" | sort -u | wc -l
}
claim "get --from · every unit's date and name share their columns" test "$(unit_cols)" -eq 1
claim "get --from · a short unit's row is as wide as its name, never padded to the longest" \
  bash -c '[[ "$(grep "home=.claude" "$1")" == *"home=.claude" ]]' _ "$fixture/out"

get --from grove-9 --list; rc=$?; snap_get_absent="$(cat "$fixture/out")"
claim "get --from an absent grove · exit 2, never an empty list" test "$rc" -eq 2
claim "get --from an absent grove · names the groves held" out_has "grove-1"

STUB_CRED=4; get --list; rc=$?; snap_get_nocred="$(cat "$fixture/out")"; STUB_CRED=0
claim "get · no credential · exit 2, its owner named" test "$rc" -eq 2
STUB_CRED=5; get --list; rc=$?; snap_get_nocred+=$'\n\n'"## aws gave no answer (rc $rc)"$'\n'"$(cat "$fixture/out")"; STUB_CRED=0
claim "get · no answer from aws · exit 1, a retry may cure it" test "$rc" -eq 1
claim "get · no answer from aws · reads as a malfunction" out_has "💥 MalfunctionError: cannot reach the backup bucket"
claim "get · no answer from aws · names the retry" out_has "or retry now: sudo systemctl start grove-backup.service"

# the bare status tree, its help, and its refusals: one snap. systemctl is a stub, so the
#   enrolment a human reads is the fixture's, never this box's
snap_get_surfaces=""
STUB_ENROLLED=1 STUB_ACTIVE=0
systemctl() {
  # a oneshot unit at work reads `activating`
  [[ "$1" == show ]] && { [[ "$STUB_ACTIVE" == 1 ]] && echo activating || echo inactive; return 0; }
  [[ "$1" == is-enabled && "$STUB_ENROLLED" == 1 ]]
}
surface() {
  local label="$1" want="$2" rc; shift 2
  get "$@"; rc=$?
  snap_get_surfaces+=$'\n'"## $label"$'\n'"rc=$rc"$'\n'"$(cat "$fixture/out")"$'\n'
  claim "get $label · exit $want" test "$rc" -eq "$want"
}
surface "· status, the last run ok"      0
claim "get · status, ok · reads ✓"       out_has "backup: ✓"
claim "get · status, ok · names its last ok" out_has "last ok:"
STUB_PUT=3; printf 'one more\n' >>"$wt/draft.md"; run; STUB_PUT=0
surface "· status, the last run failed"  0
claim "get · status, failed · reads ✗ FAILED" out_has "✗ FAILED"
claim "get · status, failed · names the cause and the journal" out_has "journalctl -u grove-backup"
claim "get · status, failed · the counts add up: the units the refusal never reached are named" out_has "not reached"
run
STUB_ENROLLED=0; mv "$STATE/status.json" "$STATE/status.json.off"
GROVE_ENV_SERVER=cloud@hetzner.hetzbot
# sudo is a stub here, so the seat a human reads is the fixture's, never this box's
STUB_SUDO=1; sudo() { [[ "$STUB_SUDO" == 1 ]]; }
surface "· status, never enrolled, the ground seat"  0
claim "get · status, never enrolled · names the bundle that enrolls" out_has "--what 5.27.backup"
claim "get · status, never enrolled, ground · asks no other seat" test "$(grep -c 'from the seat with sudo' "$fixture/out")" -eq 0
STUB_SUDO=0
surface "· status, never enrolled, the camper seat"  0
claim "get · status, never enrolled, camper · names the seat with sudo" out_has "from the seat with sudo (ground); this seat holds none"
unset -f sudo
GROVE_ENV_SERVER=local@unix
surface "· status, on a laptop"          0
claim "get · status, on a laptop · names camp groves, never a fix that declines" \
  test "$(grep -c -- '--what 5.27.backup' "$fixture/out")" -eq 0 -a "$(grep -c 'runs on camp groves' "$fixture/out")" -eq 1
GROVE_ENV_SERVER=cloud@hetzner.hetzbot
STUB_ENROLLED=1
surface "· status, enrolled, no run has written yet" 0
claim "get · status, enrolled with no status · reads ✗ STALE · never" out_has "✗ STALE · never"
STUB_ACTIVE=1
surface "· status, the first run at work" 0
claim "get · status, a first run at work · reads ⏳, never a ✗" \
  test "$(grep -c '⏳ the first run is at work' "$fixture/out")" -eq 1 -a "$(grep -c '✗' "$fixture/out")" -eq 0
STUB_ACTIVE=0
jq --arg t "$(date -u -d '-3 days' +%FT%TZ)" '.last_ok = $t' "$STATE/status.json.off" >"$STATE/status.json"
surface "· status, the last ok run is old" 0
claim "get · status, an old last ok · reads ✗ STALE · last ok … ago" out_has "✗ STALE · last ok 3d ago"
claim "get · status, an old last ok · names the journal" out_has "journalctl -u grove-backup"
mv "$STATE/status.json.off" "$STATE/status.json"
# each failed pass a human reads, as get renders its kept status: the cause, its fix, each failed unit
surface_kept() { cp "$fixture/kept.$1.json" "$STATE/status.json"; surface "· status, failed: $2" 0; }
cp "$STATE/status.json" "$STATE/status.json.off"
surface_kept grove-name "the grove name undeclared"
claim "get · failed, no grove name · names the owed item" out_has "owed item 2"
surface_kept zero-units "zero units"
claim "get · failed, zero units · names it" out_has "no units found under"
surface_kept rebuild "a rebuilt box that kept a dead grove's name"
claim "get · failed, a rebuild · names the restore, then the adopt" \
  bash -c 'grep -q "grove.backup.restore --from grove-1 --all" "$1" && grep -q "grove-backup --adopt" "$1"' _ "$fixture/out"
surface_kept disk-unit "one unit with no room on the disk"
claim "get · failed, one unit · draws its unit and why as a row" out_has "/tree=widget.feat-x: disk · "
surface_kept gap "a tree whose commits ride in no unit"
claim "get · failed, a gap · draws the dir and its fix as a row" out_has "/org=acme/orphan=widget: "
mv "$STATE/status.json.off" "$STATE/status.json"
# a box whose grove name is not yet declared: the header says so, never a blank or a guess
mv "$fixture/etc/name" "$fixture/etc/name.off"
surface "· status, the grove name undeclared" 0
claim "get · status, no grove name · the header reads undeclared" out_has "grove: （undeclared）"
mv "$fixture/etc/name.off" "$fixture/etc/name"
surface "--help"                         0 --help
surface "· a --from that is no slug"     2 --from 'grove 1'
surface "· an unknown argument"          2 --bogus
unset -f systemctl

######################################################################
# admit — the writer asks the reader's own question, of the reader's own set (peer i013)
#   the agent's own pass over a seat, never a pack call with a path no pass would hand it:
#   each unit either lands and lays, or its pack refuses, named
######################################################################
admit_failed_before="$failed"
BUCKET="$fixture/bucket.odd"; STATE="$fixture/state.odd"; mkdir -p "$BUCKET" "$STATE"
HOME_ROOT="$fixture/odd"; odd="$HOME_ROOT/$ME"
nl_name=$'line\nbreak.txt'
# a home unit that holds a name with a newline: the restore would refuse it whole
mkdir -p "$odd/.claude/projects/p" && printf '{"line":1}\n' >"$odd/.claude/projects/p/s.jsonl"
printf 'odd\n' >"$odd/.claude/projects/p/$nl_name"
# a home unit that holds a name whose first byte is a dash: it lays
mkdir -p "$odd/.rhachet/meter" && printf 'dash\n' >"$odd/.rhachet/meter/-dash.txt"
# a clone whose untracked dir holds a name with a newline: the file list names the dir alone
odd_clone="$odd/git/acme/widget"
gx clone -q "$origin" "$odd_clone" 2>/dev/null
mkdir -p "$odd_clone/scratch" && printf 'odd\n' >"$odd_clone/scratch/$nl_name"
# a set-aside tree that keeps its gitfile, and a dash-first name
odd_sa="$odd_clone/.git/tree-del-setaside/widget.old.20261119T063248Z"
mkdir -p "$odd_sa/$(dirname "$transcript_rel")"
printf 'gitdir: %s\n' "$odd_clone/.git/worktrees/widget.old" >"$odd_sa/.git"
printf '{"line":1,"text":"a set-aside with its gitfile"}\n' >"$odd_sa/$transcript_rel"
printf 'dash\n' >"$odd_sa/-dash.md"
# a dash-first DIR: the restore's link guard walks each parent of a path, so a parent that reads
#   as a flag must still be walked, never skipped as an unparseable name
mkdir -p "$odd_sa/-sub" && printf 'inner\n' >"$odd_sa/-sub/inner.md"
# an orphan whose gitfile names a dir git dropped
odd_or="$odd/git/acme/_worktrees/widget.broken"
mkdir -p "$odd_or/$(dirname "$transcript_rel")"
printf 'gitdir: %s\n' "$fixture/nowhere" >"$odd_or/.git"
printf '{"line":1,"text":"an orphan with its gitfile"}\n' >"$odd_or/$transcript_rel"
run
odd_why() { jq -r --arg u "$1" '.failures[] | select(.unit | endswith($u)) | .why' "$STATE/status.json"; }
claim "admit · a home unit with a newline name: the pack refuses it, named" \
  bash -c '[[ "$1" == "a restore would refuse this unit: "*newline* ]]' _ "$(odd_why home=.claude)"
claim "admit · a refused home unit is never put" test -z "$(key_of home=.claude)"
claim "admit · a tree with a newline name under an untracked dir: the pack refuses it, named" \
  bash -c '[[ "$1" == "a restore would refuse this unit: "*newline* ]]' _ "$(odd_why repo=widget/tree=widget)"
claim "admit · a refused tree is never put" test -z "$(key_of repo=widget/tree=widget)"
claim "admit · exactly those two fail" test "$(status .failed)" -eq 2
claim "admit · a home unit with a dash-first name lands" test -n "$(key_of home=.rhachet)"
claim "admit · a set-aside with its gitfile lands" test -n "$(key_of 'setaside=widget.old*')"
claim "admit · an orphan with its gitfile lands" test -n "$(key_of orphan=widget.broken)"
odd_fresh="$fixture/odd.fresh/$ME"; mkdir -p "$odd_fresh"
( HOME="$odd_fresh"; restore_main --from grove-1 --all ) >"$fixture/out.odd" 2>&1
odd_fsa="$(find "$odd_fresh/git/acme/_setaside/widget" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n 1)"
claim "admit · the dash-first home file lays" cmp -s "$odd/.rhachet/meter/-dash.txt" "$odd_fresh/.rhachet/meter/-dash.txt"
claim "admit · the set-aside's transcript lays" cmp -s "$odd_sa/$transcript_rel" "$odd_fsa/$transcript_rel"
claim "admit · the set-aside's dash-first file lays" cmp -s "$odd_sa/-dash.md" "$odd_fsa/-dash.md"
claim "admit · a file under a dash-first dir lays" cmp -s "$odd_sa/-sub/inner.md" "$odd_fsa/-sub/inner.md"
claim "admit · no path is read as a flag: the restore prints no 'invalid option'" \
  bash -c '! grep -q "invalid option" "$1"' _ "$fixture/out.odd"
claim "admit · the orphan's transcript lays" \
  cmp -s "$odd_or/$transcript_rel" "$odd_fresh/git/acme/_worktrees/widget.broken/$transcript_rel"
# the admit stage's own text, only when one of ITS claims missed: an earlier stage's miss is
#   named where it fell, and this dump beside it would point the reader at the wrong stage
if [[ "$failed" -ne 0 && "$admit_failed_before" -eq 0 ]]; then sed 's/^/      │ /' "$fixture/out.odd" >&2; jq . "$STATE/status.json" >&2; fi
BUCKET="$fixture/bucket"; STATE="$fixture/state"; HOME_ROOT="$fixture/dead"

######################################################################
# the texts a human reads after a restore — every byte snapped
#   masked: the fixture dir, the seat name, each sha, each date
######################################################################
# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
snapdir="$HERE/.play/permanent/prove.grove-backup-round-trip.snap"
mask() {
  sed -e "s#$fixture#<fixture>#g" -e "s#user=$ME\b#user=<seat>#g" -e "s#/$ME/#/<seat>/#g" -e "s#\b$ME\b#<seat>#g" \
      -e 's#[0-9]\+ MiB#<n> MiB#g' -e 's#[0-9a-f]\{8\}\b#<sha>#g' -e 's#[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}#<date>#g' \
      -e 's#T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}Z#T<hh:mm:ss>Z#g' -e 's#T[0-9]\{2\}:[0-9]\{2\}Z#T<hh:mm>Z#g' -e 's#\b[0-9]\+[smhd] ago#<age> ago#g' -e 's#· [0-9]\+[smhd]$#· <age>#' -e 's#· [0-9]\+[smhd] · #· <age> · #g'
}
play_snap_verify dir="$snapdir" name=restore.worktree-alone actual="$(mask <<<"$snap_worktree")" || failed=1
play_snap_verify dir="$snapdir" name=restore.clone-graft    actual="$(mask <<<"$snap_clone")"    || failed=1
play_snap_verify dir="$snapdir" name=restore.all            actual="$(mask <<<"$snap_all")"      || failed=1
play_snap_verify dir="$snapdir" name=get.list               actual="$(mask <<<"$snap_get_list")"   || failed=1
play_snap_verify dir="$snapdir" name=get.from-list          actual="$(mask <<<"$snap_get_units")"  || failed=1
play_snap_verify dir="$snapdir" name=get.from-absent        actual="$(mask <<<"$snap_get_absent")" || failed=1
play_snap_verify dir="$snapdir" name=get.no-credential      actual="$(mask <<<"$snap_get_nocred")" || failed=1
play_snap_verify dir="$snapdir" name=get.surfaces           actual="$(mask <<<"$snap_get_surfaces")" || failed=1
play_snap_verify dir="$snapdir" name=restore.refusals       actual="$(mask <<<"$snap_refusals")"     || failed=1
play_snap_verify dir="$snapdir" name=restore.thaw           actual="$(mask <<<"$snap_thaw")"         || failed=1
play_snap_verify dir="$snapdir" name=restore.another-head   actual="$(mask <<<"$snap_other_head")"   || failed=1
play_snap_verify dir="$snapdir" name=restore.into           actual="$(mask <<<"$snap_into")"         || failed=1
play_snap_verify dir="$snapdir" name=restore.graft-dirty    actual="$(mask <<<"$snap_dirty")"        || failed=1
# status.json is the seam infra reads: its shape is pinned, so a renamed field reddens here first
snap_status_shape="## ok"$'\n'"$(jq -S . "$fixture/kept.ok.json")"$'\n\n'"## failed, one unit"$'\n'"$(jq -S . "$fixture/kept.disk-unit.json")"
play_snap_verify dir="$snapdir" name=status.shape           actual="$(mask <<<"$snap_status_shape")"  || failed=1
play_snap_verify dir="$snapdir" name=run.passes             actual="$(mask <<<"$snap_run")"           || failed=1

[[ "$failed" -ne 0 ]] && exit 1
echo "🌲 all claims held ✔"
exit 0
