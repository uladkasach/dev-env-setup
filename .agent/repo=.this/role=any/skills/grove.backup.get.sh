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
#   - exit 0 = the read completed · 1 = the bucket gave no answer (a retry may
#     cure it) · 2 = constraint (bad args, a credential or grant, no such grove)
######################################################################
set -uo pipefail

get_help() {
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
}

# the root is four dirs above this skill, never `git rev-parse`: a grove's checkout
#   is pushed with no .git, so git finds no repo there and the source path collapses
#   to /src/… (📜 2026-11-20, both groves: the restore died before its first row)
GET_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../../.." && pwd)"
# shellcheck source=../../../../src/grove.provision/5.devtools/5.26.backup/grove.backup.operations.sh
source "$GET_ROOT/src/grove.provision/5.devtools/5.26.backup/grove.backup.operations.sh" || {
  echo "💥 MalfunctionError: could not load grove.backup.operations.sh under $GET_ROOT" >&2; exit 1; }

######################################################################
# .what = this box's status — the same line the verify and infra's stats print
######################################################################
get_status() {
  local grove status enrolled="" line fix failures f
  echo "🐢 lets read the backup..."
  echo ""
  echo "🗄️ grove.backup.get"
  grove="$(grove_backup_decl_read "$(grove_backup_name_file)" "$GROVE_BACKUP_SLUG_PATTERN")" || grove="（undeclared）"
  echo "   ├─ grove: $grove"

  status="$(grove_backup_status_file)"
  systemctl is-enabled grove-backup.timer >/dev/null 2>&1 && enrolled=enrolled
  line="$(grove_backup_status_line "$enrolled")"
  if [[ ! -f "$status" ]]; then
    echo "   └─ backup: $line"
    [[ -z "$enrolled" ]] && echo "      └─ fix: rhx grove.provision --what 5.26.backup --mode apply"
    return 0
  fi

  echo "   ├─ backup: $line"
  echo "   │  └─ last run: $(jq -r '"\(.at) · \(.units) units · \(.put) put · \(.skipped) skipped · \(.failed) failed"' "$status")"
  fix="$(jq -r '.fix // empty' "$status")"
  failures="$(jq -r '.failures[]? | "\(.unit): \(.why)"' "$status")"
  if [[ -z "$fix" && -z "$failures" ]]; then
    echo "   └─ last ok: $(jq -r '.last_ok // "never"' "$status")"
    return 0
  fi
  echo "   ├─ last ok: $(jq -r '.last_ok // "never"' "$status")"
  echo "   └─ why"
  [[ -n "$fix" ]] && echo "      ├─ $fix"
  [[ -n "$failures" ]] && while IFS= read -r f; do echo "      ├─ $f"; done <<<"$failures"
  echo "      └─ journalctl -u grove-backup -n 50"
  return 0
}

######################################################################
# .what = refuse a list that cannot be read, with the exit its cause earns
# .why a list that cannot be read is never printed as empty
######################################################################
fail_reach() {
  if grove_backup_cause_is_transient; then
    echo "💥 MalfunctionError: cannot reach the backup bucket · $GROVE_BACKUP_CAUSE" >&2
    echo "   └─ $GROVE_BACKUP_FIX" >&2
    exit 1
  fi
  echo "✋ ConstraintError: cannot reach the backup bucket · $GROVE_BACKUP_CAUSE" >&2
  echo "   └─ $GROVE_BACKUP_FIX" >&2
  exit 2
}

# .what = refuse on a failed list call: rc 3 is a refused grant, else no answer
fail_list() {
  [[ "$1" -eq 3 ]] && { grove_backup_cause_denied; fail_reach; }
  GROVE_BACKUP_CAUSE="the list failed"; GROVE_BACKUP_FIX="$GROVE_BACKUP_AWS_ERR"; fail_reach
}

######################################################################
# .what = print each grove prefix with its latest backup, as one tree
######################################################################
print_groves() {
  local own lines=() g lm rc i
  grove_backup_s3_prefixes "$GET_TMP/prefixes"; rc=$?
  [[ "$rc" -eq 0 ]] || fail_list "$rc"

  while IFS= read -r g; do
    grove_backup_s3_list "grove=$g/" "$GET_TMP/keys"; rc=$?
    [[ "$rc" -eq 0 ]] || fail_list "$rc"
    lm="$(cut -f2 "$GET_TMP/keys" | sort | tail -n 1)"
    lm="$(date -u -d "$lm" +%Y-%m-%dT%H:%MZ 2>/dev/null || echo "$lm")"
    lines+=("$(printf '%-24s %s' "$g" "$lm")")
  done < <(grove_backup_groves_of_prefixes <"$GET_TMP/prefixes")

  own="$(grove_backup_decl_read "$(grove_backup_name_file)" "$GROVE_BACKUP_SLUG_PATTERN")" \
    && ! grep -qxF "grove=$own/" "$GET_TMP/prefixes" \
    && lines+=("$(printf '%-24s %s' "$own" "(none yet)")")

  for i in "${!lines[@]}"; do echo "   ├─ ${lines[$i]}"; done
  echo "   └─ $(plural "${#lines[@]}" grove)"
}

######################################################################
# .what = every unit one grove left, its latest date and class, grouped by seat
######################################################################
print_units() {
  local from="$1" rc total=0 u i glyph unit key class
  local -a users rows
  grove_backup_s3_list "grove=$from/" "$GET_TMP/keys"; rc=$?
  [[ "$rc" -eq 0 ]] || fail_list "$rc"

  if [[ ! -s "$GET_TMP/keys" ]]; then
    echo "✋ ConstraintError: no backups under grove=$from" >&2
    echo "   └─ the groves the bucket does hold" >&2
    # nest the grove tree under that branch, one level down
    print_groves | sed 's/^   /      /' >&2
    exit 2
  fi

  # one row per unit, from its latest object: "user<TAB>rank<TAB>unit<TAB>date<TAB>class"
  #   rank lists units in the order `--all` lays them (grove_backup_unit_rank)
  grove_backup_units_latest <"$GET_TMP/keys" | while IFS=$'\t' read -r unit key class; do
    printf '%s\t%s\t%s\t%s\t%s\n' "$(grove_backup_unit_field "$unit" user)" "$(grove_backup_unit_rank "$unit")" \
      "$(grove_backup_unit_without_seat "$unit")" "$(grove_backup_key_day "$key")" "$class"
  done | sort -t$'\t' -k1,1 -k2,2 -k3,3 >"$GET_TMP/units"

  echo "🐢 lets see what $from left..."
  echo ""
  echo "🗄️ grove.backup.get --from $from --list"
  echo "   ├─ $from"
  mapfile -t users < <(cut -f1 "$GET_TMP/units" | uniq)
  for u in "${users[@]}"; do
    echo "   │  ├─ user=$u"
    mapfile -t rows < <(awk -F'\t' -v u="$u" '$1 == u { printf "%-56s %s %s\n", $3, $4, $5 }' "$GET_TMP/units")
    for i in "${!rows[@]}"; do
      glyph="├─"; [[ "$i" -eq $(( ${#rows[@]} - 1 )) ]] && glyph="└─"
      echo "   │  │  $glyph ${rows[$i]}"
    done
    total=$(( total + ${#rows[@]} ))
  done
  echo "   └─ $total units"
  echo ""
  echo "🥥 restore one: rhx grove.backup.restore --from $from --of <org/repo> --tree <dir>"
  echo "   or all of this seat's: rhx grove.backup.restore --from $from --all"
}

######################################################################
# main
######################################################################
get_main() {
  local list=0 from=""
  if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then get_help; return 0; fi
  while [[ $# -gt 0 ]]; do
    # a value flag with no value refuses: `shift 2` past the last arg shifts naught,
    # so the loop would read the same flag forever
    [[ "$1" =~ ^--(from|skill|repo|role)$ && $# -lt 2 ]] && {
      echo "✋ ConstraintError: $1 needs a value" >&2
      echo "   └─ see: rhx grove.backup.get --help" >&2; exit 2; }
    case "$1" in
      --list) list=1; shift ;;
      --from) from="${2:-}"; list=1; shift 2 ;;
      # rhachet injects these three into every skill it runs
      --skill|--repo|--role) shift 2 ;;
      --) shift ;;
      *) echo "✋ ConstraintError: unknown argument '$1'" >&2
         echo "   └─ see: rhx grove.backup.get --help" >&2; exit 2 ;;
    esac
  done

  if [[ -n "$from" && ! "$from" =~ $GROVE_BACKUP_SLUG_PATTERN ]]; then
    echo "✋ ConstraintError: '$from' is not a grove slug" >&2
    echo "   └─ list the groves: rhx grove.backup.get --list" >&2
    exit 2
  fi

  [[ "$list" -eq 0 ]] && { get_status; return 0; }

  grove_backup_reach_check no || fail_reach
  GET_TMP="$(mktemp -d)"
  trap 'rm -rf "$GET_TMP"' EXIT

  if [[ -z "$from" ]]; then
    echo "🐢 lets see who left what..."
    echo ""
    echo "🗄️ grove.backup.get --list"
    print_groves
    return 0
  fi
  print_units "$from"
}

# run only when executed — a play sources this file and calls get_main itself
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  get_main "$@"
  exit $?
fi
