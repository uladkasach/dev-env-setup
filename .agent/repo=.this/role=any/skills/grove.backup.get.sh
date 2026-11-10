#!/usr/bin/env bash
######################################################################
# .what = read the grove backup: this box's last run, every grove the bucket
#         holds, or every unit one grove left behind
#
# .why
#   - "did my work make it off the box?" is the question a crew asks before a
#     risky act, and a commander asks the day a grove dies. both deserve one verb
#   - the aha of the restore is that the commander never has to remember what was
#     on the dead grove: `--from <grove> --list` tells him, dated to its last hour
#
# usage:
#   rhx grove.backup.get                          # this box's status line
#   rhx grove.backup.get --list                   # every grove prefix, with its latest backup
#   rhx grove.backup.get --from grove-1 --list    # every unit grove-1 left, with date and class
#
# 🛑 .why a list that cannot reach the bucket prints NO list
#   an empty list reads "this grove left naught". a commander who reads that
#   restores naught, and the work was there all along (case=3 [t5])
#
# guarantee:
#   - READ-ONLY: it writes no object and no file
#   - exit 0 = the read completed · 2 = constraint (bad args, no reach, no such grove)
######################################################################
set -uo pipefail

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "grove.backup.get — read the grove backup"
  echo ""
  echo "usage:"
  echo "  rhx grove.backup.get                          this box's last run, as one line"
  echo "  rhx grove.backup.get --list                   every grove the bucket holds, latest backup each"
  echo "  rhx grove.backup.get --from <grove> --list    every unit that grove left, with date and class"
  echo ""
  echo "options:"
  echo "  --list            list, rather than read this box's status"
  echo "  --from <grove>    the grove whose units to list (implies --list)"
  echo ""
  echo "to restore a unit:  rhx grove.backup.restore --help"
  exit 0
fi

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
# shellcheck source=../../../src/grove.provision/5.devtools/5.24.backup/grove.backup.operations.sh
source "$REPO/src/grove.provision/5.devtools/5.24.backup/grove.backup.operations.sh"

LIST=0
FROM=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list) LIST=1; shift ;;
    --from) FROM="${2:-}"; LIST=1; shift 2 ;;
    # rhachet injects these three into every skill it runs
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "✋ ConstraintError: unknown argument '$1'" >&2
       echo "   └─ see: rhx grove.backup.get --help" >&2; exit 2 ;;
  esac
done

if [[ -n "$FROM" && ! "$FROM" =~ $GROVE_BACKUP_SLUG_PATTERN ]]; then
  echo "✋ ConstraintError: '$FROM' is not a grove slug" >&2
  echo "   └─ list the groves: rhx grove.backup.get --list" >&2
  exit 2
fi

######################################################################
# 1. this box's status — the same line the verify and infra's stats print
######################################################################
if [[ "$LIST" -eq 0 ]]; then
  echo "🐢 lets read the backup..."
  echo ""
  echo "🗄️ grove.backup.get"
  grove="$(grove_backup_decl_read "$(grove_backup_name_file)" "$GROVE_BACKUP_SLUG_PATTERN")" || grove="（undeclared）"
  echo "   ├─ grove: $grove"

  status="$(grove_backup_status_file)"
  enrolled=""
  systemctl is-enabled grove-backup.timer >/dev/null 2>&1 && enrolled=enrolled
  line="$(grove_backup_status_line "$enrolled")"
  if [[ ! -f "$status" ]]; then
    echo "   └─ backup: $line"
    [[ -z "$enrolled" ]] && echo "      └─ fix: rhx grove.provision --what 5.24.backup --mode apply"
    exit 0
  fi

  echo "   ├─ backup: $line"
  echo "   │  └─ last run: $(jq -r '"\(.at) · \(.units) units · \(.put) put · \(.skipped) skipped · \(.failed) failed"' "$status")"
  fix="$(jq -r '.fix // empty' "$status")"
  failures="$(jq -r '.failures[]? | "\(.unit): \(.why)"' "$status")"
  if [[ -z "$fix" && -z "$failures" ]]; then
    echo "   └─ last ok: $(jq -r '.last_ok // "never"' "$status")"
    exit 0
  fi
  echo "   ├─ last ok: $(jq -r '.last_ok // "never"' "$status")"
  echo "   └─ why"
  [[ -n "$fix" ]] && echo "      ├─ $fix"
  [[ -n "$failures" ]] && while IFS= read -r f; do echo "      ├─ $f"; done <<<"$failures"
  echo "      └─ journalctl -u grove-backup -n 50"
  exit 0
fi

######################################################################
# 2. the reach — a list that cannot be read is never printed as empty
######################################################################
fail_reach() {
  echo "✋ ConstraintError: cannot reach the backup bucket · $GROVE_BACKUP_CAUSE" >&2
  echo "   └─ $GROVE_BACKUP_FIX" >&2
  exit 2
}
grove_backup_reach_check no || fail_reach

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# .what = print each grove prefix with its latest backup, as one tree
print_groves() {
  local own lines=() g lm
  grove_backup_s3_prefixes "$tmp/prefixes"
  case $? in 0) ;; 3) grove_backup_cause_denied; fail_reach ;;
              *) GROVE_BACKUP_CAUSE="the list failed"; GROVE_BACKUP_FIX="$GROVE_BACKUP_AWS_ERR"; fail_reach ;; esac

  while IFS= read -r g; do
    g="${g#grove=}"; g="${g%/}"
    grove_backup_s3_list "grove=$g/" "$tmp/keys" || { grove_backup_cause_denied; fail_reach; }
    lm="$(cut -f2 "$tmp/keys" | sort | tail -n 1)"
    lm="$(date -u -d "$lm" +%Y-%m-%dT%H:%MZ 2>/dev/null || echo "$lm")"
    lines+=("$(printf '%-24s %s' "$g" "$lm")")
  done <"$tmp/prefixes"

  own="$(grove_backup_decl_read "$(grove_backup_name_file)" "$GROVE_BACKUP_SLUG_PATTERN")" \
    && ! grep -qxF "grove=$own/" "$tmp/prefixes" \
    && lines+=("$(printf '%-24s %s' "$own" "(none yet)")")

  local i
  for i in "${!lines[@]}"; do echo "   ├─ ${lines[$i]}"; done
  echo "   └─ ${#lines[@]} groves"
}

######################################################################
# 3. --list alone: every grove prefix
######################################################################
if [[ -z "$FROM" ]]; then
  echo "🐢 lets see who left what..."
  echo ""
  echo "🗄️ grove.backup.get --list"
  print_groves
  exit 0
fi

######################################################################
# 4. --from <grove>: every unit it left, its latest date and class
######################################################################
grove_backup_s3_list "grove=$FROM/" "$tmp/keys"
case $? in 0) ;; 3) grove_backup_cause_denied; fail_reach ;;
            *) GROVE_BACKUP_CAUSE="the list failed"; GROVE_BACKUP_FIX="$GROVE_BACKUP_AWS_ERR"; fail_reach ;; esac

if [[ ! -s "$tmp/keys" ]]; then
  echo "✋ ConstraintError: no backups under grove=$FROM" >&2
  echo "   └─ the groves the bucket does hold:" >&2
  print_groves >&2
  exit 2
fi

# one row per unit: its LATEST date (date= sorts as text) and that object's class
#   "user<TAB>rank<TAB>unit<TAB>date<TAB>class", rank puts clones + worktrees before home dirs
while IFS=$'\t' read -r key _ class; do
  unit="$(grove_backup_key_unit "$key")"
  day="${key##*/date=}"; day="${day%.tar.gz}"
  user="$(grove_backup_unit_field "$unit" user)"
  rank=1; [[ "$unit" == */home=* ]] && rank=2
  printf '%s\t%s\t%s\t%s\t%s\n' "$user" "$rank" "${unit#user=*/}" "$day" "${class:-STANDARD}"
done <"$tmp/keys" | sort -t$'\t' -k1,1 -k2,2 -k3,3 -k4,4 \
  | awk -F'\t' '{ latest[$1 FS $2 FS $3] = $0 } END { for (k in latest) print latest[k] }' \
  | sort -t$'\t' -k1,1 -k2,2 -k3,3 >"$tmp/units"

echo "🐢 lets see what $FROM left..."
echo ""
echo "🗄️ grove.backup.get --from $FROM --list"
echo "   ├─ $FROM"
total=0
mapfile -t users < <(cut -f1 "$tmp/units" | uniq)
for u in "${users[@]}"; do
  echo "   │  ├─ user=$u"
  mapfile -t rows < <(awk -F'\t' -v u="$u" '$1 == u { printf "%-56s %s %s\n", $3, $4, $5 }' "$tmp/units")
  for i in "${!rows[@]}"; do
    glyph="├─"; [[ "$i" -eq $(( ${#rows[@]} - 1 )) ]] && glyph="└─"
    echo "   │  │  $glyph ${rows[$i]}"
  done
  total=$(( total + ${#rows[@]} ))
done
echo "   └─ $total units"
echo ""
echo "🥥 restore one: rhx grove.backup.restore --from $FROM --of <org/repo> --tree <dir>"
echo "   or all of this seat's: rhx grove.backup.restore --from $FROM --all"
exit 0
