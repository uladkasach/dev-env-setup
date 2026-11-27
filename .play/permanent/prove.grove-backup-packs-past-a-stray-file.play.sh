#!/usr/bin/env bash
######################################################################
# .what = one stray file never fails a unit: a name a restore cannot lay is cut, and a file
#         deleted as tar reads it is skipped — each named, the rest of the unit lands
#
# .why  = 📜 2026-11-26, both groves. a tree held `.temp/tmp.<x>\n.temp` (a test's temp
#         name with a newline in it): the admit refused the whole unit, every pass, so its
#         unpushed work rode out on no pass for ~19h and the status read ✗ FAILED all day.
#         and a busy tree deletes as it is read: tar's "Cannot stat" failed 1-3 units on
#         many passes, since one retry raced the same churn
#
# .the arms (each bites: revert its fix and it goes red)
#   1. a tree with a newline-named file packs, admits, and restores, the file cut and named
#   2. a home unit with one does the same
#   3. a file listed, then gone before tar reads it, is skipped and named; the unit lands
#   4. a file still present that tar cannot read is still a fault (no failhide)
#   5. the vanish reader: each error shape it must tell apart
#
# guarantee:
#   - hermetic: a fixture origin, clone, seat, and bucket in mktemp; no s3, no root
######################################################################
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE="$HERE/src/grove.provision/5.devtools/5.27.backup"

fixture="$(mktemp -d)"
trap 'chmod -R u+rwX "$fixture" 2>/dev/null; rm -rf "$fixture"' EXIT
ME="$(id -un)"

failed=0
claim() { local label="$1"; shift; if "$@"; then echo "   • $label ✔"; else echo "   💥 MalfunctionError: $label" >&2; failed=1; fi; }

echo "🌲 prove.grove-backup-packs-past-a-stray-file"

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

gx() { git -c user.name=t -c user.email=t@example.com -c init.defaultBranch=main "$@"; }
origin="$fixture/origin/widget.git"; gx init -q --bare "$origin"
tree="$fixture/clone/widget"; gx clone -q "$origin" "$tree" 2>/dev/null
printf 'readme\n' >"$tree/README.md"
gx -C "$tree" add -A && gx -C "$tree" commit -qm base && gx -C "$tree" push -q origin main 2>/dev/null
# the work a pass exists to keep, beside the stray name
gx -C "$tree" commit -q --allow-empty -m 'unpushed work'
printf 'kept\n' >"$tree/notes.md"
mkdir -p "$tree/.temp"
printf 'junk\n' >"$tree/.temp/tmp.x9"$'\n'".temp"
printf 'kept too\n' >"$tree/.temp/peer.md"

######################################################################
# 1. a tree unit
######################################################################
mkdir -p "$fixture/w1"
grove_backup_pack_tree clone "$tree" "$fixture/t1.tar.gz" "$fixture/w1" true 2>"$fixture/t1.err"; rc=$?
claim "tree · the unit packs, past the stray name" test "$rc" -eq 0
claim "tree · the stray name is named, its newline shown as ?" \
  grep -qF "'.temp/tmp.x9?.temp' has a newline in its name" "$fixture/t1.err"
claim "tree · the stray name does not ride" bash -c "! tar -tzf '$fixture/t1.tar.gz' | grep -q 'tmp.x9'"
claim "tree · its peers ride" bash -c "tar -tzf '$fixture/t1.tar.gz' | grep -qx '.temp/peer.md' && tar -tzf '$fixture/t1.tar.gz' | grep -qx 'notes.md'"
key="grove=grove-1/user=$ME/org=acme/repo=widget/tree=widget/date=2026-11-27.tar.gz"
mkdir -p "$(dirname "$BUCKET/$key")"; cp "$fixture/t1.tar.gz" "$BUCKET/$key"
seat="$fixture/seat1/$ME"; mkdir -p "$seat"
( HOME="$seat"; restore_main --from grove-1 --of acme/widget --tree widget ) >"$fixture/r1.out" 2>&1; rc=$?
claim "tree · the unit restores" test "$rc" -eq 0
claim "tree · the restore lays the work and the unpushed commit" bash -c "
  grep -qx kept '$seat/git/acme/widget/notes.md' &&
  git -C '$seat/git/acme/widget' log -1 --format=%s | grep -qx 'unpushed work'"

######################################################################
# 2. a home unit
######################################################################
home="$fixture/home"; mkdir -p "$home/.claude/projects"
printf '{}\n' >"$home/.claude/projects/a.jsonl"
printf 'junk\n' >"$home/.claude/projects/b"$'\n'"c"
grove_backup_pack_home "$home" "$home/.claude" "$fixture/h1.tar.gz" home 2>"$fixture/h1.err"; rc=$?
claim "home · the unit packs, past the stray name" test "$rc" -eq 0
claim "home · the stray name is named" grep -qF "'projects/b?c' has a newline in its name" "$fixture/h1.err"
claim "home · the stray name does not ride, its peer does" bash -c "
  ! tar -tzf '$fixture/h1.tar.gz' | grep -q '/b\$' && tar -tzf '$fixture/h1.tar.gz' | grep -qx './projects/a.jsonl'"

######################################################################
# 3. a file listed, then gone before tar reads it
######################################################################
printf 'brief\n' >"$tree/gone.txt"
eval "orig_$(declare -f grove_backup_tree_files)"
grove_backup_tree_files() { orig_grove_backup_tree_files "$@"; rm -f "$tree/gone.txt"; }
mkdir -p "$fixture/w3"
grove_backup_pack_tree clone "$tree" "$fixture/t3.tar.gz" "$fixture/w3" true 2>"$fixture/t3.err"; rc=$?
claim "vanish · the unit lands though a listed file is gone" test "$rc" -eq 0
claim "vanish · the gone file is named" grep -qF "gone.txt was deleted as it was read" "$fixture/t3.err"
claim "vanish · the rest rides" bash -c "tar -tzf '$fixture/t3.tar.gz' | grep -qx 'notes.md'"
eval "$(declare -f orig_grove_backup_tree_files | sed 's/^orig_//')"

######################################################################
# 4. a file still present that tar cannot read stays a fault
######################################################################
if [[ "$(id -u)" -ne 0 ]]; then
  printf 'secret-ish\n' >"$tree/locked.txt"; chmod 000 "$tree/locked.txt"
  mkdir -p "$fixture/w4"
  grove_backup_pack_tree clone "$tree" "$fixture/t4.tar.gz" "$fixture/w4" true 2>"$fixture/t4.err"; rc=$?
  claim "denied · a file tar cannot read still fails the unit" test "$rc" -eq 2
  claim "denied · the why names tar's fault" bash -c '[[ "$1" == "tar failed: "*"Permission denied"* ]]' _ "${GROVE_BACKUP_PACK_WHY:-}"
  chmod 644 "$tree/locked.txt"; rm -f "$tree/locked.txt"
fi

######################################################################
# 5. the vanish reader, each shape (tar's own words, as it prints them)
######################################################################
base="$fixture/vb"; mkdir -p "$base"; printf 'here\n' >"$base/present"
refuses() { ! grove_backup_tar_err_is_vanish "$@" 2>/dev/null; }
e="$fixture/e"
tar_tail="tar: Exiting with failure status due to previous errors"
printf 'tar: gone: Cannot stat: No such file or directory\n%s\n' "$tar_tail" >"$e"
claim "reader · an absent file's Cannot stat is a vanish" grove_backup_tar_err_is_vanish "$base" "$e" t 2>/dev/null
printf 'tar: ./gone: Cannot open: No such file or directory\n' >"$e"
claim "reader · a ./-led Cannot open is a vanish" grove_backup_tar_err_is_vanish "$base" "$e" t 2>/dev/null
printf 'tar: present: Cannot stat: No such file or directory\n' >"$e"
claim "reader · a path still on disk is no vanish" refuses "$base" "$e" t
printf 'tar: gone: Cannot stat: No such file or directory\ntar: x: Cannot open: Permission denied\n' >"$e"
claim "reader · any other fault beside a vanish is no vanish" refuses "$base" "$e" t
printf '%s\n' "$tar_tail" >"$e"
claim "reader · no named path is no vanish" refuses "$base" "$e" t

echo
if [[ "$failed" -ne 0 ]]; then echo "💥 prove.grove-backup-packs-past-a-stray-file — a claim missed" >&2; exit 1; fi
echo "✨ prove.grove-backup-packs-past-a-stray-file — every claim held"
