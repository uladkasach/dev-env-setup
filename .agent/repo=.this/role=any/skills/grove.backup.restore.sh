#!/usr/bin/env bash
######################################################################
# .what = restore a dead grove's work onto this box, from its backup
#
# usage:
#   rhx grove.backup.restore --from grove-1 --of ahbode/svc-quotes --tree svc-quotes         # a clone
#   rhx grove.backup.restore --from grove-1 --of ahbode/svc-quotes --tree svc-quotes.feat-x  # a worktree
#   rhx grove.backup.restore --from grove-1 --home .claude                                   # a home dir
#   rhx grove.backup.restore --from grove-1 --all                    # every unit of this seat
#   rhx grove.backup.restore --from grove-1 --of … --tree … --into ~/aside/x   # lay it aside, raw
#
# 🛑 .why `--of` and never `--repo`
#   rhachet injects `--repo <registry>` into every skill it runs, so a skill
#   flag named `--repo` reads the registry slug as a repo name
#   (`git.grove.provision.test` measured it 2026-08-31, and took `--of`)
#
# 🛑 .it never overwrites
#   a fresh grove already holds a clean clone of each org repo (`5.10.repos`)
#   and the `~/.claude` its provision laid. so the restore works WITH them:
#   - a clone GRAFTS: the dead clone's branches, stash, and each worktree's
#     detached HEAD are fetched in, fast-forward only; a diverged one lands
#     beside the live one as `<grove>/<branch>`, named, and never forced
#   - the checked-out branch cannot take a fetch, so it fast-forwards with
#     `git merge --ff-only` on a clean tree only; a dirty tree is left alone
#     and the branch lands as `<grove>/<branch>`, with the merge to run named
#   - a home dir lays each absent file and keeps each present one, named
#   - a present worktree is refused, with its path and `--into`
#
# 🛑 .what it never lays
#   `~/.rhachet/keyrack/`: it is sealed to the dead grove's own key, which died
#   with it. the plaintext credentials never left the dead grove at all
#
# .why one seat at a time: a unit carries the seat that wrote it (`user=`), and
#   a restore writes only the caller's own home
#
# guarantee:
#   - one restore per seat at a time (a lock), so two racers never both see a
#     target as absent
#   - a unit in DEEP_ARCHIVE is thawed and named, never failed raw; the same
#     command resumes it once the thaw reads
#   - exit 0 = each unit landed, grafted, was kept, or awaits a thaw ·
#     1 = a unit failed at run time (named) · 2 = constraint (bad args, no
#     reach, no such unit, a present target)
######################################################################
set -uo pipefail

help() {
  echo "grove.backup.restore — restore a dead grove's work onto this box"
  echo ""
  echo "usage:"
  echo "  rhx grove.backup.restore --from <grove> --of <org/repo> --tree <dir> [--into <dir>]"
  echo "  rhx grove.backup.restore --from <grove> --home <.claude|.rhachet>   [--into <dir>]"
  echo "  rhx grove.backup.restore --from <grove> --all"
  echo ""
  echo "options:"
  echo "  --from <grove>     the grove whose backup to read (required)"
  echo "  --of <org/repo>    with --tree: one clone (--tree <repo>) or one worktree (--tree <dir>)"
  echo "  --home <dir>       one home dir"
  echo "  --all              every unit of this seat: clones, then worktrees, then home dirs"
  echo "  --into <dir>       lay the unit aside at <dir>, raw, rather than graft or link it"
  echo ""
  echo "it never overwrites: a clone grafts, a home dir keeps each present file."
  echo "see what a grove left first:  rhx grove.backup.get --from <grove> --list"
}

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then help; exit 0; fi

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
# shellcheck source=../../../src/grove.provision/5.devtools/5.24.backup/grove.backup.operations.sh
source "$REPO_ROOT/src/grove.provision/5.devtools/5.24.backup/grove.backup.operations.sh"

######################################################################
# the tree this run prints — rows gather per unit, then print with glyphs
######################################################################
#   a row that opens with `   ├─` or `   └─` is a CHILD of the row above it: it
#   takes no glyph of its own, and sits under its parent's trunk
ROWS=()
row() { ROWS+=("$1"); }
rows_flush() {
  local i j glyph trunk last
  for i in "${!ROWS[@]}"; do
    [[ "${ROWS[$i]}" == "   "[├└]* ]] && continue
    # the last PARENT closes the tree, whatever children follow it
    last=1
    for (( j = i + 1; j < ${#ROWS[@]}; j++ )); do
      [[ "${ROWS[$j]}" != "   "[├└]* ]] && { last=0; break; }
    done
    glyph="├─"; trunk="│  "
    [[ "$last" -eq 1 ]] && { glyph="└─"; trunk="   "; }
    echo "   │  $glyph ${ROWS[$i]}"
    for (( j = i + 1; j < ${#ROWS[@]}; j++ )); do
      [[ "${ROWS[$j]}" == "   "[├└]* ]] || break
      echo "   │  $trunk${ROWS[$j]#   }"
    done
  done
  ROWS=()
}

# .what = "1 commit", "3 commits" — a count with its noun, singular at one
plural() { [[ "$1" -eq 1 ]] && printf '1 %s' "$2" || printf '%s %ss' "$1" "$2"; }

constraint() {
  echo "✋ ConstraintError: $1" >&2
  shift
  local line
  for line in "$@"; do echo "   └─ $line" >&2; done
  exit 2
}

######################################################################
# .what = fetch one object into a file, or ask s3 to thaw it
# rc: 0 the file is here · 3 a thaw is requested or awaited (named) · 1 failed
######################################################################
restore_fetch() {
  local key="$1" class="$2" out="$3" facts restore rc stamp record since
  record="$HOME/.cache/grove-backup/thaw/$(printf '%s' "$key" | tr '/=' '__')"

  if [[ "$class" == DEEP_ARCHIVE || "$class" == GLACIER ]]; then
    facts="$WORK/head"
    grove_backup_s3_head "$key" "$facts"
    rc=$?
    [[ "$rc" -eq 3 ]] && { grove_backup_cause_denied; row "✗ $GROVE_BACKUP_CAUSE"; return 1; }
    [[ "$rc" -ne 0 ]] && { row "✗ its object could not be read: $GROVE_BACKUP_AWS_ERR"; return 1; }
    restore="$(cut -f3 "$facts")"

    if [[ "$restore" == *'request="true"'* ]]; then
      since="$(cat "$record" 2>/dev/null)"
      row "🌙 sits in $class; its thaw is in progress"
      [[ -n "$since" ]] && row "   ├─ asked $(grove_backup_age $(( $(grove_backup_now) - since ))) ago; eta 12–48h from the ask"
      row "   └─ resume with the same command, once it reads"
      return 3
    fi

    if [[ "$restore" != *'request="false"'* ]]; then
      grove_backup_s3_thaw "$key"
      rc=$?
      [[ "$rc" -eq 3 ]] && { grove_backup_cause_denied; row "✗ $GROVE_BACKUP_CAUSE"; return 1; }
      [[ "$rc" -ne 0 ]] && { row "✗ the thaw could not be asked: $GROVE_BACKUP_AWS_ERR"; return 1; }
      stamp="$(grove_backup_now)"
      mkdir -p "$(dirname "$record")" && printf '%s\n' "$stamp" >"$record"
      row "🌙 sits in $class"
      row "   ├─ thaw requested at $(grove_backup_iso "$stamp")"
      row "   ├─ eta: 12–48h"
      row "   └─ resume with the same command"
      return 3
    fi
  fi

  grove_backup_s3_get "$key" "$out"
  rc=$?
  [[ "$rc" -eq 0 ]] && { rm -f "$record"; return 0; }
  [[ "$rc" -eq 3 ]] && { grove_backup_cause_denied; row "✗ $GROVE_BACKUP_CAUSE"; return 1; }
  row "✗ its object could not be read: $GROVE_BACKUP_AWS_ERR"
  return 1
}

# .what = unpack one object into a fresh dir under the work dir; prints the dir
restore_unpack() {
  local file="$1" dir
  dir="$(mktemp -d "$WORK/unit.XXXXXX")"
  tar -xzf "$file" -C "$dir" || { rm -rf "$dir"; return 1; }
  printf '%s\n' "$dir"
}

######################################################################
# the graft — a dead clone's refs into the live clone, never a file touched
######################################################################

# .what = the worktree that has <branch> checked out in the live clone, if any
live_checkout_of() {
  local live="$1" branch="$2"
  git -C "$live" worktree list --porcelain \
    | awk -v want="branch refs/heads/$branch" '/^worktree / { wt = substr($0, 10) } $0 == want { print wt }'
}

# .what = land a sha as a new ref beside the live one; never move a present one
land_aside() {
  local live="$1" name="$2" sha="$3" have
  have="$(git -C "$live" rev-parse -q --verify "refs/heads/$name")"
  [[ -z "$have" ]] && { git -C "$live" update-ref "refs/heads/$name" "$sha" ""; return 0; }
  [[ "$have" == "$sha" ]] && return 0
  return 1
}

# .what = graft one dead ref into the live clone, fast-forward only, and say what moved
# usage: graft_ref <live> <grove> <name> <sha> <label> branch|aside
graft_ref() {
  local live="$1" grove="$2" name="$3" sha="$4" label="$5" role="$6"
  local have count wt pad
  pad="$(printf '%-28s' "$name")"
  have="$(git -C "$live" rev-parse -q --verify "refs/heads/$name")"

  if [[ -z "$have" ]]; then
    count="$(git -C "$live" rev-list --count "$sha" --not --exclude='refs/grove-backup/*' --all)"
    git -C "$live" update-ref "refs/heads/$name" "$sha" ""
    [[ "$role" == aside ]] && { row "$pad + $label, kept aside"; return 0; }
    row "$pad + new branch · $(plural "$count" commit) this clone lacked"
    return 0
  fi
  [[ "$have" == "$sha" ]] && { row "$pad = (already equal)"; return 0; }

  if git -C "$live" merge-base --is-ancestor "$sha" "$have"; then
    row "$pad = (live is ahead; kept)"
    return 0
  fi

  if [[ "$role" == aside ]]; then
    row "$pad ≠ differs from the live ref; left as it stands"
    return 0
  fi

  # diverged — never forced, never skipped silently
  if ! git -C "$live" merge-base --is-ancestor "$have" "$sha"; then
    if land_aside "$live" "$grove/$name" "$sha"; then
      row "$pad ≠ diverged (live ${have:0:8}, $grove ${sha:0:8}); landed as $grove/$name"
    else
      row "$pad ≠ diverged (live ${have:0:8}, $grove ${sha:0:8}); $grove/$name holds another sha, so neither moved"
    fi
    return 0
  fi

  # ahead — fast-forward, unless it is checked out on a dirty tree
  count="$(git -C "$live" rev-list --count "$have..$sha")"
  wt="$(live_checkout_of "$live" "$name")"
  if [[ -z "$wt" ]]; then
    git -C "$live" update-ref "refs/heads/$name" "$sha" "$have"
    row "$pad + fast-forward · $(plural "$count" commit)"
    return 0
  fi
  if [[ -z "$(git -C "$wt" status --porcelain)" ]]; then
    git -C "$wt" merge --ff-only --quiet "$sha" \
      && { row "$pad + fast-forward · $(plural "$count" commit) · checked out, its tree clean"; return 0; }
  fi
  land_aside "$live" "$grove/$name" "$sha"
  row "$pad ≠ $(plural "$count" commit) ahead, and checked out on a dirty tree; landed as $grove/$name"
  row "   └─ once the tree is clean: git -C $wt merge --ff-only $grove/$name"
  return 0
}

restore_clone_graft() {
  local live="$1" dead="$2" grove="$3" branch sha n wtname admin head name
  local extra="refs/grove-backup/extra"

  # the dead copy is ours to mark: name its stash entries and detached worktree
  #   HEADs as refs, so one fetch carries every object the graft needs
  n=0
  while sha="$(git -C "$dead" rev-parse -q --verify "stash@{$n}" 2>/dev/null)"; do
    git -C "$dead" update-ref "$extra/stash-$n" "$sha"
    n=$((n + 1))
  done
  for admin in "$dead"/.git/worktrees/*/; do
    [[ -f "$admin/HEAD" ]] || continue
    head="$(head -n 1 "$admin/HEAD")"
    [[ "$head" == ref:* ]] && continue
    wtname="$(basename "$(dirname "$(head -n 1 "$admin/gitdir" 2>/dev/null)")")"
    [[ -z "$wtname" || "$wtname" == . ]] && wtname="$(basename "$admin")"
    git -C "$dead" update-ref "$extra/wt-$wtname" "$head"
  done

  if ! git -C "$live" fetch --no-tags --quiet --no-write-fetch-head "$dead" \
         '+refs/heads/*:refs/grove-backup/heads/*' "+$extra/*:$extra/*"; then
    row "✗ the dead clone's refs could not be fetched into $live"
    return 1
  fi

  while read -r branch sha; do
    graft_ref "$live" "$grove" "$branch" "$sha" "" branch
  done < <(git -C "$live" for-each-ref --format='%(refname:lstrip=3) %(objectname)' refs/grove-backup/heads/)

  while read -r name sha; do
    case "$name" in
      stash-0) graft_ref "$live" "$grove" "$grove/stash" "$sha" "stash entry, from refs/stash" aside ;;
      stash-*) graft_ref "$live" "$grove" "$grove/$name" "$sha" "stash entry, from stash@{${name#stash-}}" aside ;;
      wt-*)    graft_ref "$live" "$grove" "$grove/wt/${name#wt-}" "$sha" "detached HEAD of worktree \`${name#wt-}\`" aside ;;
    esac
  done < <(git -C "$live" for-each-ref --format='%(refname:lstrip=3) %(objectname)' "$extra/")

  # the hidden refs go; the objects stay, held by the branches they landed as
  git -C "$live" for-each-ref --format='%(refname)' refs/grove-backup/ \
    | while read -r ref; do git -C "$live" update-ref -d "$ref"; done

  # a graft carries refs, never a checkout — say so when the dead one held edits
  if [[ -n "$(git -C "$dead" status --porcelain 2>/dev/null)" ]]; then
    row "🌙 the dead clone's own checkout held uncommitted edits; a graft carries refs only"
    row "   └─ to read them, lay it aside: rhx grove.backup.restore --from $grove --of $ORG/$REPO --tree $REPO --into <dir>"
  fi
  return 0
}

######################################################################
# one unit, by kind
######################################################################
restore_clone() {
  local unit="$1" key="$2" class="$3" target obj dead
  ORG="$(grove_backup_unit_field "$unit" org)"
  REPO="$(grove_backup_unit_field "$unit" repo)"
  target="${INTO:-$HOME/git/$ORG/$REPO}"

  if [[ -n "$INTO" && -e "$target" ]]; then
    row "✋ $target is present; --into lays a unit only where naught is"
    return 2
  fi

  obj="$WORK/obj.tar.gz"
  restore_fetch "$key" "$class" "$obj" || return $?
  dead="$(restore_unpack "$obj")" || { row "✗ the object did not unpack"; return 1; }

  # absent — the whole clone lands, with its .git
  if [[ ! -e "$target" ]]; then
    mkdir -p "$(dirname "$target")" && mv "$dead" "$target" || { row "✗ could not lay $target"; return 1; }
    row "+ laid whole at $target"
    [[ -n "$INTO" ]] && row "   └─ laid aside, raw; it is a full clone of its own"
    return 0
  fi

  if [[ ! -d "$target/.git" ]]; then
    row "✋ $target is present and is no clone; it is left as it stands"
    row "   └─ lay the unit aside instead: --into <dir>"
    return 2
  fi

  row "⇄ graft into $target (its files untouched)"
  restore_clone_graft "$target" "$dead" "$FROM"
}

restore_worktree() {
  local unit="$1" key="$2" class="$3" org repo tree target live clone_key clone_class obj wt admin_line admin
  org="$(grove_backup_unit_field "$unit" org)"
  repo="$(grove_backup_unit_field "$unit" repo)"
  tree="$(grove_backup_unit_field "$unit" tree)"
  live="$HOME/git/$org/$repo"
  target="${INTO:-$HOME/git/$org/_worktrees/$tree}"

  if [[ -e "$target" ]]; then
    row "✋ $target is present; a restore never lays over it"
    row "   └─ lay it aside instead: rhx grove.backup.restore --from $FROM --of $org/$repo --tree $tree --into <dir>"
    return 2
  fi
  if [[ -z "$INTO" && ! -d "$live/.git" ]]; then
    row "✋ its clone $live is absent; a worktree links into its clone"
    row "   └─ restore the clone first: rhx grove.backup.restore --from $FROM --of $org/$repo --tree $repo"
    return 2
  fi

  obj="$WORK/obj.tar.gz"
  restore_fetch "$key" "$class" "$obj" || return $?
  wt="$(restore_unpack "$obj")" || { row "✗ the object did not unpack"; return 1; }

  if [[ -n "$INTO" ]]; then
    mkdir -p "$(dirname "$target")" && mv "$wt" "$target" || { row "✗ could not lay $target"; return 1; }
    row "+ laid aside, raw, at $target — not linked to any clone"
    return 0
  fi

  # the admin dir comes from the clone's LATEST object: a commit in the worktree
  #   writes the clone's .git, so that object is never older than the worktree
  admin_line="$(head -n 1 "$wt/.git" 2>/dev/null)"
  admin="${admin_line##*/.git/worktrees/}"
  if [[ "$admin_line" != gitdir:*/.git/worktrees/* || -z "$admin" ]]; then
    row "✋ the backed-up worktree holds no link to its clone"
    row "   └─ lay it aside instead: --into <dir>"
    return 2
  fi
  if [[ -e "$live/.git/worktrees/$admin" ]]; then
    row "✋ the live clone already records a worktree named $admin"
    row "   └─ read it: git -C $live worktree list; prune a dead record: git -C $live worktree prune"
    return 2
  fi

  clone_key="$(awk -F'\t' -v u="user=$ME/org=$org/repo=$repo/tree=$repo" '$1 == u { print $2 }' "$WORK/latest")"
  clone_class="$(awk -F'\t' -v u="user=$ME/org=$org/repo=$repo/tree=$repo" '$1 == u { print $3 }' "$WORK/latest")"
  if [[ -z "$clone_key" ]]; then
    row "✋ $FROM holds no backup of its clone, so its admin dir cannot be found"
    row "   └─ lay it aside instead: --into <dir>"
    return 2
  fi
  restore_fetch "$clone_key" "$clone_class" "$WORK/clone.tar.gz" || return $?
  mkdir -p "$WORK/admin"
  if ! tar -xzf "$WORK/clone.tar.gz" -C "$WORK/admin" "./.git/worktrees/$admin" 2>/dev/null; then
    row "✋ the clone's backup holds no admin dir for $admin"
    row "   └─ lay it aside instead: --into <dir>"
    return 2
  fi

  mkdir -p "$live/.git/worktrees" "$(dirname "$target")" \
    && mv "$WORK/admin/.git/worktrees/$admin" "$live/.git/worktrees/$admin" \
    && mv "$wt" "$target" || { row "✗ could not lay $target"; return 1; }
  if ! git -C "$live" worktree repair "$target" >/dev/null 2>&1; then
    row "✗ laid at $target, and \`git worktree repair\` refused it"
    row "   └─ read why: git -C $live worktree repair $target"
    return 1
  fi

  row "+ laid at $target, linked by \`git worktree repair\`"
  local head ahead
  head="$(git -C "$target" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  ahead="$(git -C "$target" rev-list --count '@{u}..HEAD' 2>/dev/null)"
  [[ -n "$ahead" ]] && row "   └─ HEAD $head · $(plural "$ahead" commit) not on its upstream"
  [[ -z "$ahead" ]] && row "   └─ HEAD $head"
  return 0
}

restore_home() {
  local unit="$1" key="$2" class="$3" hd target obj src rel top laid=0 keyrack=0 i
  local -a kept=()
  local -A groups=()
  hd="$(grove_backup_unit_field "$unit" home)"
  target="${INTO:-$HOME/$hd}"

  obj="$WORK/obj.tar.gz"
  restore_fetch "$key" "$class" "$obj" || return $?
  src="$(restore_unpack "$obj")" || { row "✗ the object did not unpack"; return 1; }

  while IFS= read -r -d '' rel; do
    rel="${rel#./}"
    if [[ "$hd" == .rhachet && "$rel" == keyrack/* ]]; then keyrack=1; continue; fi
    if [[ -e "$target/$rel" || -L "$target/$rel" ]]; then kept+=("$rel"); continue; fi
    mkdir -p "$(dirname "$target/$rel")" && mv "$src/$rel" "$target/$rel" || { row "✗ could not lay $target/$rel"; return 1; }
    laid=$((laid + 1))
    top="${rel%%/*}"
    [[ "$top" != "$rel" ]] && top="$top/…"
    groups[$top]=$(( ${groups[$top]:-0} + 1 ))
  done < <(cd "$src" && find . -mindepth 1 \( -type f -o -type l \) -print0 | sort -z)

  for top in $(printf '%s\n' "${!groups[@]}" | sort); do
    [[ "${groups[$top]}" -eq 1 ]] && row "+ $top" || row "+ $top (${groups[$top]} files)"
  done
  for i in "${!kept[@]}"; do
    [[ "$i" -ge 8 ]] && { row "= … and $(( ${#kept[@]} - 8 )) more, each kept as this box has it"; break; }
    row "= ${kept[$i]} (kept: this box's copy)"
  done
  [[ "$laid" -eq 0 && "${#kept[@]}" -eq 0 ]] && row "= the backup held no file to lay"

  [[ "$hd" == .claude ]] \
    && row "🌙 the brain login never left $FROM; log in here: rhx brains.auth.set"
  [[ "$keyrack" -eq 1 ]] \
    && row "🌙 keyrack/ not laid: it is sealed to $FROM's own key, which died with it; set this grove's own: rhx git.grove.auth.keys.set"
  return 0
}

######################################################################
# main
######################################################################
restore_main() {
  local ask="$*"
  FROM="" ALL=0 OF="" TREE="" HOME_ARG="" INTO=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) FROM="${2:-}"; shift 2 ;;
      --all)  ALL=1; shift ;;
      --of)   OF="${2:-}"; shift 2 ;;
      --tree) TREE="${2:-}"; shift 2 ;;
      --home) HOME_ARG="${2:-}"; shift 2 ;;
      --into) INTO="${2:-}"; shift 2 ;;
      # rhachet injects these three into every skill it runs
      --skill|--repo|--role) shift 2 ;;
      --) shift ;;
      *) constraint "unknown argument '$1'" "see: rhx grove.backup.restore --help" ;;
    esac
  done
  ask="--from $FROM"
  [[ "$ALL" -eq 1 ]] && ask="$ask --all"
  [[ -n "$OF" ]] && ask="$ask --of $OF --tree $TREE"
  [[ -n "$HOME_ARG" ]] && ask="$ask --home $HOME_ARG"
  [[ -n "$INTO" ]] && ask="$ask --into $INTO"

  # the shape of the ask
  [[ -n "$FROM" ]] || constraint "--from <grove> is required" "see what each grove left: rhx grove.backup.get --list"
  [[ "$FROM" =~ $GROVE_BACKUP_SLUG_PATTERN ]] || constraint "'$FROM' is not a grove slug" "list the groves: rhx grove.backup.get --list"
  local forms=0
  [[ "$ALL" -eq 1 ]] && forms=$((forms + 1))
  [[ -n "$OF$TREE" ]] && forms=$((forms + 1))
  [[ -n "$HOME_ARG" ]] && forms=$((forms + 1))
  [[ "$forms" -eq 1 ]] || constraint "name exactly one of: --all · --of <org/repo> --tree <dir> · --home <dir>" "see: rhx grove.backup.restore --help"
  if [[ -n "$OF$TREE" ]]; then
    [[ "$OF" == */* && "$OF" != */*/* && -n "$TREE" ]] \
      || constraint "--of takes <org/repo>, and --tree is required beside it" "e.g.: --of ahbode/svc-quotes --tree svc-quotes"
  fi
  if [[ -n "$HOME_ARG" ]]; then
    local ok=0 d
    for d in "${GROVE_BACKUP_SCOPE_DIRS[@]}"; do [[ "${d#\~/}" == "$HOME_ARG" && "$HOME_ARG" != git ]] && ok=1; done
    [[ "$ok" -eq 1 ]] || constraint "--home takes one of the backed-up home dirs: .claude · .rhachet" "a clone or worktree takes --of and --tree"
  fi
  [[ "$ALL" -eq 1 && -n "$INTO" ]] && constraint "--into lays ONE unit aside; it does not combine with --all"
  if [[ -n "$INTO" ]]; then INTO="$(realpath -m "$INTO")"; fi

  ME="$(id -un)"

  # one restore per seat
  mkdir -p "$HOME/.cache/grove-backup"
  exec 8>"$HOME/.cache/grove-backup/restore.lock"
  flock -n 8 || constraint "a restore is active on this seat" "let it finish, then rerun this one"

  # the reach — a restore that cannot read lays naught
  grove_backup_reach_check no \
    || constraint "cannot reach the backup bucket · $GROVE_BACKUP_CAUSE" "$GROVE_BACKUP_FIX"

  WORK="$(mktemp -d "$HOME/.cache/grove-backup/restore.XXXXXX")"
  trap 'rm -rf "$WORK"' EXIT

  local rc
  grove_backup_s3_list "grove=$FROM/" "$WORK/keys"
  rc=$?
  if [[ "$rc" -eq 3 ]]; then grove_backup_cause_denied; constraint "cannot reach the backup bucket · $GROVE_BACKUP_CAUSE" "$GROVE_BACKUP_FIX"; fi
  [[ "$rc" -eq 0 ]] || constraint "cannot reach the backup bucket · the list failed" "$GROVE_BACKUP_AWS_ERR"
  [[ -s "$WORK/keys" ]] || constraint "no backups under grove=$FROM" "list the groves the bucket holds: rhx grove.backup.get --list"

  # each unit's latest object: "unit<TAB>key<TAB>class", date= sorts as text
  local key class
  while IFS=$'\t' read -r key _ class; do
    printf '%s\t%s\t%s\n' "$(grove_backup_key_unit "$key")" "$key" "${class:-STANDARD}"
  done <"$WORK/keys" | sort -t$'\t' -k1,1 -k2,2 \
    | awk -F'\t' '{ latest[$1] = $0 } END { for (u in latest) print latest[u] }' >"$WORK/latest"

  # the targets, in dependency order: clones, then worktrees, then home dirs
  local -a targets=()
  local unit
  if [[ "$ALL" -eq 1 ]]; then
    mapfile -t targets < <(awk -F'\t' -v me="user=$ME/" 'index($1, me) == 1 { print $1 }' "$WORK/latest" \
      | while read -r unit; do
          case "$(grove_backup_unit_kind "$unit")" in clone) echo "1 $unit" ;; worktree) echo "2 $unit" ;; home) echo "3 $unit" ;; esac
        done | sort | cut -d' ' -f2-)
    if [[ "${#targets[@]}" -eq 0 ]]; then
      constraint "grove=$FROM holds no unit of seat $ME" \
        "the seats it does hold: $(cut -f1 "$WORK/latest" | sed 's#/.*##' | sort -u | tr '\n' ' ')"
    fi
  else
    if [[ -n "$HOME_ARG" ]]; then unit="user=$ME/home=$HOME_ARG"
    else unit="user=$ME/org=${OF%%/*}/repo=${OF#*/}/tree=$TREE"; fi
    if ! awk -F'\t' -v u="$unit" '$1 == u { found = 1 } END { exit !found }' "$WORK/latest"; then
      local other
      other="$(awk -F'\t' -v rest="${unit#user=*/}" '{ r = $1; sub(/^user=[^\/]*\//, "", r) } r == rest { print $1 }' "$WORK/latest" | head -n 1)"
      [[ -n "$other" ]] && constraint "that unit belongs to seat $(grove_backup_unit_field "$other" user), not $ME" \
        "a restore writes only its own seat's home; run it as $(grove_backup_unit_field "$other" user)"
      echo "✋ ConstraintError: no backup of ${unit#user=*/} under grove=$FROM" >&2
      echo "   └─ the units this seat holds there:" >&2
      awk -F'\t' -v me="user=$ME/" 'index($1, me) == 1 { sub(/^user=[^\/]*\//, "", $1); print "      · " $1 }' "$WORK/latest" >&2
      exit 2
    fi
    targets=("$unit")
  fi

  # each unit; one that fails does not stop the rest
  echo "🐢 lets carry $FROM's work home..."
  echo ""
  echo "🗄️ grove.backup.restore $ask"
  local landed=0 waits=0 refused=0 failed=0 day
  for unit in "${targets[@]}"; do
    key="$(awk -F'\t' -v u="$unit" '$1 == u { print $2 }' "$WORK/latest")"
    class="$(awk -F'\t' -v u="$unit" '$1 == u { print $3 }' "$WORK/latest")"
    day="${key##*/date=}"; day="${day%.tar.gz}"
    echo "   ├─ ${unit#user=*/} · $day · $class"
    case "$(grove_backup_unit_kind "$unit")" in
      clone)    restore_clone "$unit" "$key" "$class" ;;
      worktree) restore_worktree "$unit" "$key" "$class" ;;
      home)     restore_home "$unit" "$key" "$class" ;;
    esac
    rc=$?
    rows_flush
    case "$rc" in 0) landed=$((landed + 1)) ;; 3) waits=$((waits + 1)) ;; 2) refused=$((refused + 1)) ;; *) failed=$((failed + 1)) ;; esac
  done

  echo "   └─ $(plural "${#targets[@]}" unit) · $landed restored · $waits await a thaw · $refused refused · $failed failed"
  [[ "$failed" -gt 0 ]] && return 1
  # a refusal under --all is a unit already here, which is the point of a rerun
  [[ "$refused" -gt 0 && "$ALL" -eq 0 ]] && return 2
  return 0
}

# run only when executed — a play sources this file and calls restore_main itself
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  restore_main "$@"
  exit $?
fi
