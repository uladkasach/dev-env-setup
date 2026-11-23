#!/usr/bin/env bash
######################################################################
# .what = a tree whose dead checkout swapped a tracked dir for a symlink restores whole
#
# .why  a clone moved its tracked `.claude/` into `.agent/.actors/<actor>/brain/.claude`
#   and left a `.claude` symlink in its place. HEAD still tracks `.claude/<file>`, so the
#   unit carries the link AND a delete of each file under the old dir. the restore laid
#   the files over HEAD's checkout, then tar refused the link over HEAD's real dir, and a
#   delete applied after would reach THROUGH the new link into the brain dir (measured
#   live on the hetzner grove, 2026-11-21: `Cannot create symlink …: File exists`)
#
# .the cases
#   1. a fresh restore lays the link where HEAD held the dir, and the brain files behind it
#   2. no delete reaches through the link: every brain file comes back byte for byte
#   3. a graft into a present clone that still holds the dir keeps that dir, named
#   4. a DIR named like a secret shape (`credentials/`) is source and rides, in a tree and a
#      home unit; only a FILE of that shape is cut, and named (peer i006: a shape glob in tar
#      cut the dir whole, silently, under a ✓)
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

echo "🌲 prove.grove-backup-restore-type-swap"

# shellcheck source=/dev/null
source "$BUNDLE/grove-backup"
# shellcheck source=/dev/null
source "$HERE/.agent/repo=.this/role=any/skills/grove.backup.restore.sh"

# the box facts and the s3 seam, pointed at a fixture
BUCKET="$fixture/bucket"; STATE="$fixture/state"
mkdir -p "$BUCKET" "$STATE" "$fixture/etc"
grove_backup_name_file()   { printf '%s' "$fixture/etc/name"; }
grove_backup_bucket_file() { printf '%s' "$fixture/etc/bucket"; }
grove_backup_state_dir()   { printf '%s' "$STATE"; }
grove_backup_seat_home()   { printf '%s' "$fixture/dead/$ME"; }
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
grove_backup_s3_head() { [[ -f "$BUCKET/$1" ]] || return 6; printf '%s\tSTANDARD\tNone\n' "$(cat "$BUCKET/$1.sha")" >"$2"; }
grove_backup_s3_put()  { mkdir -p "$(dirname "$BUCKET/$2")" && cp "$1" "$BUCKET/$2" && printf '%s\n' "$3" >"$BUCKET/$2.sha"; }
grove_backup_s3_get()  { cp "$BUCKET/$1" "$2"; }
printf 'grove-1\n' >"$fixture/etc/name"
printf 'fixture-bucket\n' >"$fixture/etc/bucket"

gx() { git -c user.name=t -c user.email=t@example.com -c init.defaultBranch=main "$@"; }

######################################################################
# origin tracks `.claude/` as a dir; the dead clone swapped it for a link
######################################################################
origin="$fixture/origin/swap.git"
gx init -q --bare "$origin"
seed="$fixture/seed"; gx clone -q "$origin" "$seed" 2>/dev/null
mkdir -p "$seed/.claude"
printf '{"old":true}\n' >"$seed/.claude/settings.json"
printf 'readme\n' >"$seed/README.md"
gx -C "$seed" add -A && gx -C "$seed" commit -qm base && gx -C "$seed" push -q origin main 2>/dev/null

dead="$fixture/dead/$ME/git/acme/swap"
mkdir -p "$(dirname "$dead")"
gx clone -q "$origin" "$dead" 2>/dev/null
brain=".agent/.actors/a/brain/.claude"
rm -rf "$dead/.claude"
mkdir -p "$dead/$brain/projects/p"
printf '{"new":true}\n' >"$dead/$brain/settings.json"
printf '{"turn":1}\n{"turn":2}\n' >"$dead/$brain/projects/p/talk.jsonl"
ln -s "$brain" "$dead/.claude"
# 4. a DIR named like a secret shape is source: it rides; a FILE of that shape is cut
mkdir -p "$dead/src/credentials" "$fixture/dead/$ME/.claude/credentials"
printf 'export const login = 1;\n' >"$dead/src/credentials/login.ts"
printf 'secret\n' >"$dead/src/site.pem"
printf 'notes\n' >"$fixture/dead/$ME/.claude/credentials/notes.md"
printf 'secret\n' >"$fixture/dead/$ME/.claude/host.key"

( grove_backup_run ) >"$fixture/run.out" 2>&1; rc=$?
claim "pass · the swapped tree lands" test "$rc" -eq 0

######################################################################
# 1 + 2. a fresh restore
######################################################################
fresh="$fixture/fresh/$ME"; mkdir -p "$fresh"
( HOME="$fresh"; restore_main --from grove-1 --of acme/swap --tree swap ) >"$fixture/out" 2>&1; rc=$?
live="$fresh/git/acme/swap"
claim "fresh · the restore exits 0" test "$rc" -eq 0
claim "fresh · .claude is the link the dead tree held" test -L "$live/.claude" -a "$(readlink "$live/.claude")" == "$brain"
claim "fresh · the settings behind the link are the dead tree's" test "$(cat "$live/.claude/settings.json" 2>/dev/null)" == '{"new":true}'
claim "fresh · the conversation, byte for byte" cmp -s "$dead/$brain/projects/p/talk.jsonl" "$live/$brain/projects/p/talk.jsonl"
claim "fresh · no delete reached through the link" test -f "$live/$brain/settings.json"
claim "shape · a source dir named credentials rides" test "$(cat "$live/src/credentials/login.ts" 2>/dev/null)" == 'export const login = 1;'
claim "shape · a file of a secret shape is cut" test ! -e "$live/src/site.pem"
claim "shape · the cut is named, the dir is not" \
  bash -c 'grep -q "src/site.pem" "$1" && ! grep -q "src/credentials" "$1"' _ "$fixture/out"
( HOME="$fresh"; restore_main --from grove-1 --home .claude --into "$fixture/home.into" ) >"$fixture/out.home" 2>&1; rc=$?
claim "shape · a home dir named credentials rides" test "$rc" -eq 0 -a -f "$fixture/home.into/credentials/notes.md"
claim "shape · a home file of a secret shape is cut" test ! -e "$fixture/home.into/host.key"

######################################################################
# 3. a graft into a present clone that still holds the dir
######################################################################
graft="$fixture/graft/$ME"; mkdir -p "$graft/git/acme"
gx clone -q "$origin" "$graft/git/acme/swap" 2>/dev/null
( HOME="$graft"; restore_main --from grove-1 --of acme/swap --tree swap ) >"$fixture/out.graft" 2>&1; rc=$?
claim "graft · the restore exits 0" test "$rc" -eq 0
claim "graft · the present clone's dir is kept, never removed" \
  test -d "$graft/git/acme/swap/.claude" -a ! -L "$graft/git/acme/swap/.claude" -a -f "$graft/git/acme/swap/.claude/settings.json"
claim "graft · the kept dir is named" grep -q '= .claude (kept: a dir here, the dead tree held a link)' "$fixture/out.graft"
claim "graft · the conversation lands behind it" cmp -s "$dead/$brain/projects/p/talk.jsonl" "$graft/git/acme/swap/$brain/projects/p/talk.jsonl"

if [[ "$failed" -ne 0 ]]; then
  sed 's/^/      │ /' "$fixture/run.out" "$fixture/out" "$fixture/out.graft" >&2
  echo "💥 MalfunctionError: a claim failed" >&2
  exit 1
fi
echo ""
echo "🌲 all claims held ✔"
