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
  echo "exit:"
  echo "  0  the read completed — a ✗ FAILED or ✗ STALE status included: the verdict is the line, not the exit"
  echo "  1  the bucket gave no answer; a retry may cure it"
  echo "  2  a constraint: bad args, a credential or grant, no such grove"
  echo ""
  echo "to restore a unit:  rhx grove.backup.restore --help"
  echo "on a grove, run each from this repo's checkout: cd ~/git/more/dev-env-setup"
}

# the root is four dirs above this skill, never `git rev-parse`: a grove's checkout
#   is pushed with no .git, so git finds no repo there and the source path collapses
#   to /src/… (📜 2026-11-20, both groves: the restore died before its first row)
GET_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../../.." && pwd)"
# shellcheck source=../../../../src/grove.provision/5.devtools/5.27.backup/grove.backup.operations.sh
source "$GET_ROOT/src/grove.provision/5.devtools/5.27.backup/grove.backup.operations.sh" || {
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
  # the bundle enrolls a camp grove alone; off one, a fix that names it would decline
  if [[ ! -f "$status" && -z "$enrolled" && "${GROVE_ENV_SERVER:-}" != cloud@* ]]; then
    echo "   └─ backup: 🌙 not on this box: the grove backup runs on camp groves (cloud@*); this is ${GROVE_ENV_SERVER:-an undeclared server}"
    echo "      └─ a laptop's own work rides by its git remotes, and \`git backup\` by hand"
    return 0
  fi
  if [[ ! -f "$status" ]]; then
    echo "   └─ backup: $line"
    # the enroll writes root units: a seat with no sudo (camper) cannot make it
    if [[ -z "$enrolled" ]]; then
      local seat_note=""
      sudo -n true 2>/dev/null || seat_note=", from the seat with sudo (ground); this seat holds none"
      echo "      └─ fix: rhx grove.provision --what 5.27.backup --mode apply$seat_note"
    fi
    return 0
  fi

  echo "   ├─ backup: $line"
  # a pass refused before its units (a denied grant) reaches none of them: the counts add up
  #   only with that remainder named, else `✗ FAILED` sits over `0 failed`
  echo "   │  └─ last run: $(jq -r '
    ((.units // 0) - (.put // 0) - (.skipped // 0) - (.failed // 0)) as $unreached
    | "\(.at) · \(.units) units · \(.put) put · \(.skipped) skipped · \(.failed) failed"
      + (if $unreached > 0 then " · \($unreached) not reached" else "" end)' "$status")"
  fix="$(jq -r '.fix // empty' "$status")"
  failures="$(jq -r '.failures[]? | "\(.unit): \(.why)"' "$status")"
  # a ✓ line needs no why; a ✗ line with no stored cause (a STALE one) still names the journal
  if [[ -z "$fix" && -z "$failures" && "$line" != ✗* ]]; then
    echo "   └─ last ok: $(jq -r '.last_ok // "never"' "$status")"
    return 0
  fi
  echo "   ├─ last ok: $(jq -r '.last_ok // "never"' "$status")"
  echo "   └─ why"
  [[ -n "$fix" ]] && echo "      ├─ $fix"
  [[ -n "$failures" ]] && while IFS= read -r f; do echo "      ├─ $f"; done <<<"$failures"
  echo "      └─ the run's full text, as ground (camper cannot read the journal): sudo journalctl -u grove-backup -n 50"
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
  local own names=() dates=() g lm rc i scoped=""
  grove_backup_s3_prefixes "$GET_TMP/prefixes"; rc=$?
  # a grant scoped per grove refuses the fleet-wide list (S8): list the groves this box
  #   reaches, and name who holds the rest
  if [[ "$rc" -eq 3 ]]; then
    scoped=true
    grove_backup_groves_in_reach >"$GET_TMP/reach"; rc=$?
    [[ "$rc" -eq 2 ]] && { GROVE_BACKUP_CAUSE="unreadable: $GROVE_BACKUP_DECL_BROKEN"; GROVE_BACKUP_FIX="owed by ahbode/infrastructure: one grove slug on its first line"; fail_reach; }
    sed 's|.*|grove=&/|' "$GET_TMP/reach" >"$GET_TMP/prefixes"
  fi
  [[ "$rc" -eq 0 ]] || fail_list "$rc"

  while IFS= read -r g; do
    grove_backup_s3_list "grove=$g/" "$GET_TMP/keys"; rc=$?
    [[ "$rc" -eq 0 ]] || fail_list "$rc"
    lm="$(grove_backup_latest_object_time "$GET_TMP/keys")"
    names+=("$g"); dates+=("${lm:-(none yet)}")
  done < <(grove_backup_groves_of_prefixes <"$GET_TMP/prefixes")

  # this box's own grove, before its first backup lands, reads `(none yet)`
  own="$(grove_backup_decl_read "$(grove_backup_name_file)" "$GROVE_BACKUP_SLUG_PATTERN")" || own=""
  if [[ -n "$own" ]] && ! grep -qxF "grove=$own/" "$GET_TMP/prefixes"; then
    names+=("$own"); dates+=("(none yet)")
  fi

  # .why the date leads: its width is fixed (a stamp, or `(none yet)` padded to one), so every
  #   date and every name share a column, and no long name widens another row
  for i in "${!names[@]}"; do printf '   ├─ %-17s %s\n' "${dates[$i]}" "${names[$i]}"; done
  [[ -z "$scoped" ]] && { echo "   └─ $(grove_backup_plural "${#names[@]}" grove)"; return 0; }
  echo "   ├─ $(grove_backup_plural "${#names[@]}" grove) in this box's reach"
  echo "   └─ the grant reaches this grove and its declared predecessor alone; the admin tier lists the fleet"
}

# .what = one seat's rows from the units file ("user<TAB>rank<TAB>unit<TAB>date<TAB>class"),
#   each as `<date> <class, padded> <unit>`
# .why the fixed-width fields lead: a tree name runs to ~90 chars, so a name-first row padded to
#   the longest would widen every row past a narrow terminal. date-first aligns with no name pad
unit_rows_of_seat() {
  awk -F'\t' -v u="$1" '
    NR == FNR { if (length($5) > w) w = length($5); next }
    $1 == u { printf "%s %-" w "s %s\n", $4, $5, $3 }
  ' "$GET_TMP/units" "$GET_TMP/units"
}

# .what = the distinct seats in the units file, in its sorted order (the seat is column 1)
units_seats() { cut -f1 "$GET_TMP/units" | uniq; }

######################################################################
# .what = every unit one grove left, its latest date and class, grouped by seat
######################################################################
print_units() {
  local from="$1" rc total=0 u i j trunk glyph unit key class
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
  #   a key any box may write is untrusted: an id outside the shapes a pass writes prints
  #   with each byte outside a plain name as `?`, flagged as one no restore lays
  grove_backup_units_latest <"$GET_TMP/keys" | while IFS=$'\t' read -r unit key class; do
    if ! grove_backup_unit_is_valid "$unit"; then
      printf '%s\t9\t%s\t%s\t%s\n' "?" "${unit//[^A-Za-z0-9._@+=\/-]/?}" "$(grove_backup_key_day "$key" | tr -c 'A-Za-z0-9-' '?')" "✋ refused: no shape a pass writes"
      continue
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$(grove_backup_unit_field "$unit" user)" "$(grove_backup_unit_rank "$unit")" \
      "$(grove_backup_unit_without_seat "$unit")" "$(grove_backup_key_day "$key")" "$class"
  done | sort -t$'\t' -k1,1 -k2,2 -k3,3 >"$GET_TMP/units"

  echo "🐢 lets see what $from left..."
  echo ""
  echo "🗄️ grove.backup.get --from $from --list"
  echo "   ├─ $from"
  mapfile -t users < <(units_seats)
  for j in "${!users[@]}"; do
    u="${users[$j]}"
    # the last seat closes its branch, so its rows hang under a blank, never a `│`
    trunk="│  "
    [[ "$j" -eq $(( ${#users[@]} - 1 )) ]] && trunk="   "
    echo "   │  $(grove_backup_tree_glyph "$j" "${#users[@]}") user=$u"
    mapfile -t rows < <(unit_rows_of_seat "$u")
    for i in "${!rows[@]}"; do
      echo "   │  $trunk$(grove_backup_tree_glyph "$i" "${#rows[@]}") ${rows[$i]}"
    done
    total=$(( total + ${#rows[@]} ))
  done
  echo "   └─ $total units"
  echo ""
  echo "🥥 restore, as the row's seat, from this repo's checkout (cd ~/git/more/dev-env-setup)"
  echo "   ├─ org=<o>/repo=<r>/tree=<t>       rhx grove.backup.restore --from $from --of <o>/<r> --tree <t>"
  echo "   ├─ org=<o>/orphan=<d>              rhx grove.backup.restore --from $from --orphan <o>/<d>"
  echo "   ├─ org=<o>/repo=<r>/setaside=<s>   rhx grove.backup.restore --from $from --of <o>/<r> --setaside <s>"
  echo "   ├─ home=<h>                        rhx grove.backup.restore --from $from --home <h>"
  echo "   └─ every unit of the seat          rhx grove.backup.restore --from $from --all"
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
  # an unmade scratch dir would root every path below at /, so it halts here
  GET_TMP="$(mktemp -d)" && [[ -d "$GET_TMP" ]] || {
    echo "💥 MalfunctionError: could not make a scratch dir" >&2
    echo "   └─ check the disk and \$TMPDIR: df -h \"\${TMPDIR:-/tmp}\"" >&2
    exit 1; }
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
