#!/usr/bin/env bash
######################################################################
# .what = a unit's lean on origin outlives every pass: a pr branch that origin
#         deletes AFTER the pack takes no commit of the unit with it
#
# .why  a quiet unit never asks origin again. a unit that leaned on a pr branch
#   lost every commit above it the day origin squash-merged and deleted it, and
#   its status read ✓ throughout (peer i005, measured). a unit leans only on
#   origin's default branch and its tags, so a pr branch's commits ride in it
#
# .the case
#   C1 pushed on `feat`, D unpushed on top. pass 1 puts the unit. origin then
#   deletes `feat` and prunes C1, as a squash merge with branch delete does.
#   pass 2 is quiet, and a restore onto a fresh grove holds C1 and D whole
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

echo "🌲 prove.grove-backup-origin-drift"

# shellcheck source=/dev/null
source "$BUNDLE/grove-backup"
# shellcheck source=/dev/null
source "$HERE/.agent/repo=.this/role=any/skills/grove.backup.restore.sh"

# the box facts and the s3 seam, pointed at a fixture: a local dir stands in for the bucket
BUCKET="$fixture/bucket"
STATE="$fixture/state"
mkdir -p "$BUCKET" "$fixture/etc" "$STATE"
grove_backup_name_file()   { printf '%s' "$fixture/etc/name"; }
grove_backup_bucket_file() { printf '%s' "$fixture/etc/bucket"; }
grove_backup_seat_home()   { printf '%s/%s' "$HOME_ROOT" "$ME"; }
grove_backup_state_dir()   { printf '%s' "$STATE"; }
printf '%s\n' 0123456789abcdef0123456789abcdef >"$fixture/etc/machine-id"
grove_backup_machine_id_file() { printf '%s' "$fixture/etc/machine-id"; }
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
grove_backup_s3_prefixes() { find "$BUCKET" -mindepth 1 -maxdepth 1 -type d -printf '%f/\n' | sort >"$1"; }
grove_backup_s3_head() {
  [[ -f "$BUCKET/$1" ]] || return 6
  printf '%s\t%s\t%s\n' "$(cat "$BUCKET/$1.sha")" STANDARD None >"$2"
}
grove_backup_s3_put() { mkdir -p "$(dirname "$BUCKET/$2")" && cp "$1" "$BUCKET/$2" && printf '%s\n' "$3" >"$BUCKET/$2.sha"; }
grove_backup_s3_get()  { cp "$BUCKET/$1" "$2"; }
grove_backup_s3_thaw() { return 0; }

# a dead grove: one clone, its main on origin, a pr branch with one pushed and one unpushed commit
gx() { git -c user.name=t -c user.email=t@example.com -c init.defaultBranch=main -c advice.detachedHead=false "$@"; }
origin="$fixture/origin/widget.git"
gx init -q --bare "$origin"
HOME_ROOT="$fixture/dead"
seat="$HOME_ROOT/$ME"
clone="$seat/git/acme/widget"
mkdir -p "$seat/git/acme"
gx clone -q "$origin" "$clone" 2>/dev/null
printf 'readme\n' >"$clone/README.md"
gx -C "$clone" add README.md && gx -C "$clone" commit -qm base
gx -C "$clone" push -q origin main 2>/dev/null
gx -C "$clone" checkout -q -b feat
gx -C "$clone" commit -q --allow-empty -m 'C1 pushed'
gx -C "$clone" push -q origin feat 2>/dev/null
c1="$(gx -C "$clone" rev-parse HEAD)"
gx -C "$clone" commit -q --allow-empty -m 'D unpushed'
d="$(gx -C "$clone" rev-parse HEAD)"

printf 'grove-1\n' >"$fixture/etc/name"
printf 'fixture-bucket\n' >"$fixture/etc/bucket"
status() { jq -r "$1" "$STATE/status.json"; }
run() { ( grove_backup_run ) >"$fixture/run.out" 2>&1; }

run
claim "pass 1 · one unit put" test "$(status '"\(.units) \(.put)"')" == "1 1"

# origin squash-merges feat, deletes the branch, and prunes its commits
gx -C "$origin" update-ref -d refs/heads/feat
gx -C "$origin" gc -q --prune=now
claim "drift · origin no longer holds C1" bash -c "! git -C '$origin' cat-file -e '$c1^{commit}' 2>/dev/null"

run
claim "pass 2 · the unit is quiet: it leaned on naught origin could delete" test "$(status '"\(.put) \(.skipped)"')" == "0 1"

fresh_seat="$fixture/fresh/$ME"; mkdir -p "$fresh_seat"
( HOME="$fresh_seat"; restore_main --from grove-1 --of acme/widget --tree widget ) >"$fixture/out" 2>&1; rc=$?
claim "restore · exits 0" test "$rc" -eq 0
claim "restore · the pr branch's pushed commit C1 is whole on the new grove" \
  bash -c "git -C '$fresh_seat/git/acme/widget' cat-file -e '$c1^{commit}' 2>/dev/null"
claim "restore · the unpushed commit D is whole on the new grove" \
  bash -c "git -C '$fresh_seat/git/acme/widget' cat-file -e '$d^{commit}' 2>/dev/null"
claim "restore · feat sits at D" test "$(git -C "$fresh_seat/git/acme/widget" rev-parse -q --verify refs/heads/feat)" == "$d"

if [[ "$failed" -ne 0 ]]; then
  sed 's/^/      │ /' "$fixture/run.out" "$fixture/out" >&2
  echo "💥 MalfunctionError: a claim failed" >&2
  exit 1
fi
