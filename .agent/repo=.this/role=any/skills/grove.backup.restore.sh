#!/usr/bin/env bash
######################################################################
# .what = restore a dead grove's work onto this box, from its backup
#
# usage:
#   rhx grove.backup.restore --from grove-1 --of ahbode/svc-quotes --tree svc-quotes         # a clone
#   rhx grove.backup.restore --from grove-1 --of ahbode/svc-quotes --tree svc-quotes.feat-x  # a worktree
#   rhx grove.backup.restore --from grove-1 --home .claude                                   # a home dir
#   rhx grove.backup.restore --from grove-1 --orphan ahbode/svc-quotes.feat-y               # a dropped worktree's files
#   rhx grove.backup.restore --from grove-1 --of ahbode/svc-quotes --setaside <name>         # a set-aside tree
#   rhx grove.backup.restore --from grove-1 --all                    # every unit of this seat
#   rhx grove.backup.restore --from grove-1 --of … --tree … --into ~/aside/x   # lay it aside, whole
#
# 🛑 .why `--of` and never `--repo`
#   rhachet injects `--repo <registry>` into every skill it runs, so a skill
#   flag named `--repo` reads the registry slug as a repo name
#   (`git.grove.provision.test` measured it 2026-08-31, and took `--of`)
#
# .each tree restores from its OWN unit, alone
#   a tree's unit carries the commits origin lacks, its checkout, its changed and
#   untracked files, and its transcripts. the rest is origin's: the restore clones
#   origin, adds the unit's commits, checks out its HEAD with its index, and lays
#   its files. a worktree with no clone on this box gets the clone first, from origin
#
# 🛑 .it never overwrites
#   - a present clone GRAFTS: the unit's branches and stash are added, fast-forward
#     only; a diverged one lands beside the live one as `<grove>/<branch>`, named,
#     and never forced. the live checkout is left as it stands
#   - a present worktree is kept as it stands: `--all` reruns pass over it
#   - a home dir, an orphan, and a set-aside lay each absent file and keep each
#     present one, named
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
#   - `--all` is a resume: a tree already here is kept, and the rest land
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
  echo "  rhx grove.backup.restore --from <grove> --orphan <org>/<dir>        [--into <dir>]"
  echo "  rhx grove.backup.restore --from <grove> --of <org/repo> --setaside <name> [--into <dir>]"
  echo "  rhx grove.backup.restore --from <grove> --all"
  echo ""
  echo "options:"
  echo "  --from <grove>     the grove whose backup to read (required)"
  echo "  --of <org/repo>    with --tree: one clone (--tree <repo>) or one worktree (--tree <dir>)"
  echo "                     with --setaside: one tree a clone set aside, laid at ~/git/<org>/_setaside/<repo>/"
  echo "  --orphan <o>/<d>   one worktree dir git had dropped, laid back at ~/git/<org>/_worktrees/<dir>"
  echo "  --home <dir>       one home dir"
  echo "  --all              every unit of this seat; a tree already here is kept"
  echo "  --into <dir>       lay the unit at <dir> as a clone of its own, rather than in ~/git"
  echo ""
  echo "it never overwrites: a present clone grafts, a home dir keeps each present file."
  echo "see what a grove left first:  rhx grove.backup.get --from <grove> --list"
}

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then help; exit 0; fi

# the root is four dirs above this skill, never `git rev-parse`: a grove's checkout
#   is pushed with no .git, so git finds no repo there (see grove.backup.get)
REPO_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../../.." && pwd)"
# shellcheck source=../../../../src/grove.provision/5.devtools/5.26.backup/grove.backup.operations.sh
source "$REPO_ROOT/src/grove.provision/5.devtools/5.26.backup/grove.backup.operations.sh" || {
  echo "💥 MalfunctionError: could not load grove.backup.operations.sh under $REPO_ROOT" >&2; exit 1; }

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


constraint() {
  echo "✋ ConstraintError: $1" >&2
  shift
  local line
  for line in "$@"; do echo "   └─ $line" >&2; done
  exit 2
}

# git, as the restore runs it: a unit from another box or seat may carry another owner
g() { local path="$1"; shift; git -c safe.directory='*' -C "$path" "$@"; }

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
    [[ "$rc" -eq 3 ]] && { grove_backup_cause_denied; row "💥 MalfunctionError: $GROVE_BACKUP_CAUSE"; return 1; }
    [[ "$rc" -ne 0 ]] && { row "💥 MalfunctionError: its object could not be read: $GROVE_BACKUP_AWS_ERR"; return 1; }
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
      [[ "$rc" -eq 3 ]] && { grove_backup_cause_denied; row "💥 MalfunctionError: $GROVE_BACKUP_CAUSE"; return 1; }
      [[ "$rc" -ne 0 ]] && { row "💥 MalfunctionError: the thaw could not be asked: $GROVE_BACKUP_AWS_ERR"; return 1; }
      stamp="$(grove_backup_now)"
      mkdir -p "$(dirname "$record")" && printf '%s\n' "$stamp" >"$record"
      row "🌙 sits in $class"
      row "   ├─ thaw requested"
      row "   ├─ eta: 12–48h"
      row "   └─ resume with the same command"
      return 3
    fi
  fi

  grove_backup_s3_get "$key" "$out"
  rc=$?
  [[ "$rc" -eq 0 ]] && { rm -f "$record"; return 0; }
  [[ "$rc" -eq 3 ]] && { grove_backup_cause_denied; row "💥 MalfunctionError: $GROVE_BACKUP_CAUSE"; return 1; }
  row "💥 MalfunctionError: its object could not be read: $GROVE_BACKUP_AWS_ERR"
  return 1
}

# .what = unpack one object into a fresh dir under the work dir; prints the dir
restore_unpack() {
  local file="$1" dir
  dir="$(mktemp -d "$WORK/unit.XXXXXX")"
  tar -xzf "$file" -C "$dir" || { rm -rf "$dir"; return 1; }
  printf '%s\n' "$dir"
}

# .what = fetch + unpack a tree unit, and refuse one with no manifest; sets UNIT_DIR
# .why no `$(…)`: the rows it adds would die with the subshell
restore_tree_unit() {
  local key="$1" class="$2" version
  UNIT_DIR=""
  restore_fetch "$key" "$class" "$WORK/obj.tar.gz" || return $?
  UNIT_DIR="$(restore_unpack "$WORK/obj.tar.gz")" || { row "💥 MalfunctionError: the object did not unpack"; return 1; }
  if [[ ! -f "$UNIT_DIR/.grove-backup/meta.json" ]]; then
    row "✋ ConstraintError: this object holds no tree manifest (.grove-backup/meta.json); it is no tree unit"
    row "   └─ the grove's next pass writes one: rhx grove.backup.get --from $FROM --list"
    return 2
  fi
  version="$(jq -r '.version' "$UNIT_DIR/.grove-backup/meta.json" 2>/dev/null)"
  [[ "$version" == 2 ]] || { row "✋ ConstraintError: this unit's manifest is version '$version'; this restore reads version 2"; return 2; }
}

meta() { jq -r --arg f "$2" '.[$f] // empty' "$1/.grove-backup/meta.json"; }

######################################################################
# the graft — a unit's refs into a live clone, fast-forward only
######################################################################

# .what = the worktree that has <branch> checked out in the live clone, if any
live_checkout_of() {
  local live="$1" branch="$2"
  g "$live" worktree list --porcelain \
    | awk -v want="branch refs/heads/$branch" '/^worktree / { wt = substr($0, 10) } $0 == want { print wt }'
}

# .what = land a sha as a new ref beside the live one; never move a present one
land_aside() {
  local live="$1" name="$2" sha="$3" have
  have="$(g "$live" rev-parse -q --verify "refs/heads/$name")"
  [[ -z "$have" ]] && { g "$live" update-ref "refs/heads/$name" "$sha" ""; return 0; }
  [[ "$have" == "$sha" ]] && return 0
  return 1
}

# .what = graft one ref into the live clone, fast-forward only, and say what moved
# usage: graft_ref <live> <grove> <name> <sha> <label> branch|aside
# sets GRAFT_NAME to the branch name the sha now lives at, if any
graft_ref() {
  local live="$1" grove="$2" name="$3" sha="$4" label="$5" role="$6"
  local have count wt pad
  pad="$(printf '%-28s' "$name")"
  have="$(g "$live" rev-parse -q --verify "refs/heads/$name")"
  GRAFT_NAME="$name"

  if [[ -z "$have" ]]; then
    count="$(g "$live" rev-list --count "$sha" --not --exclude="refs/heads/$name" --all 2>/dev/null)"
    g "$live" update-ref "refs/heads/$name" "$sha" ""
    [[ "$role" == aside ]] && { row "$pad + $label, kept aside"; return 0; }
    row "$pad + new branch · $(plural "${count:-0}" commit) this clone lacked"
    return 0
  fi
  [[ "$have" == "$sha" ]] && { row "$pad = (already equal)"; return 0; }

  if g "$live" merge-base --is-ancestor "$sha" "$have"; then
    row "$pad = (live is ahead; kept)"
    return 0
  fi

  if [[ "$role" == aside ]]; then
    row "$pad ≠ differs from the live ref; left as it stands"
    GRAFT_NAME=""
    return 0
  fi

  # diverged — never forced, never skipped silently
  if ! g "$live" merge-base --is-ancestor "$have" "$sha"; then
    GRAFT_NAME="$grove/$name"
    if land_aside "$live" "$grove/$name" "$sha"; then
      row "$pad ≠ diverged (live ${have:0:8}, $grove ${sha:0:8}); landed as $grove/$name"
    else
      row "$pad ≠ diverged (live ${have:0:8}, $grove ${sha:0:8}); $grove/$name holds another sha, so neither moved"
      GRAFT_NAME=""
    fi
    return 0
  fi

  # ahead — fast-forward, unless it is checked out on a dirty tree
  count="$(g "$live" rev-list --count "$have..$sha")"
  wt="$(live_checkout_of "$live" "$name")"
  if [[ -z "$wt" ]]; then
    g "$live" update-ref "refs/heads/$name" "$sha" "$have"
    row "$pad + fast-forward · $(plural "$count" commit)"
    return 0
  fi
  # an untracked file never blocks it: `merge --ff-only` refuses on its own where it would overwrite one
  if [[ -z "$(g "$wt" status --porcelain --untracked-files=no)" ]]; then
    g "$wt" merge --ff-only --quiet "$sha" \
      && { row "$pad + fast-forward · $(plural "$count" commit) · checked out, its tree clean"; return 0; }
  fi
  GRAFT_NAME="$grove/$name"
  land_aside "$live" "$grove/$name" "$sha"
  row "$pad ≠ $(plural "$count" commit) ahead, and checked out on a dirty tree; landed as $grove/$name"
  row "   └─ once the tree is clean: git -C $wt merge --ff-only $grove/$name"
  return 0
}

######################################################################
# the tree steps — each a plain git act on a unit dir <u>
######################################################################

# .what = a repo at <dir> that holds what origin holds: a clone of origin, or an
#         empty repo where the unit names no origin (its pack then holds all)
restore_tree_base() {
  local u="$1" dir="$2" origin
  origin="$(meta "$u" origin)"
  mkdir -p "$(dirname "$dir")" || return 1
  if [[ -z "$origin" ]]; then
    git init -q "$dir" && return 0
    row "💥 MalfunctionError: could not make a repo at $dir"
    return 1
  fi
  if ! GIT_TERMINAL_PROMPT=0 git clone -q --no-checkout "$origin" "$dir" 2>"$WORK/clone.err"; then
    row "💥 MalfunctionError: origin could not be cloned: $origin"
    row "   └─ $(head -n 1 "$WORK/clone.err"); rerun once origin answers"
    rm -rf "$dir"
    return 1
  fi
}

# .what = the unit's commits into the repo at <dir>, then a check that each kept ref is whole
restore_tree_objects() {
  local u="$1" dir="$2" sha ref
  if ! g "$dir" index-pack --stdin <"$u/.grove-backup/objects.pack" >/dev/null 2>"$WORK/pack.err"; then
    row "💥 MalfunctionError: the unit's commits did not index: $(head -n 1 "$WORK/pack.err")"
    return 1
  fi
  # the walk stops at each ref this repo already holds, so it reads only the unit's own commits
  while read -r sha ref; do
    g "$dir" rev-list --objects --quiet "$sha" --not --all >/dev/null 2>&1 && continue
    row "💥 MalfunctionError: $ref (${sha:0:8}) is not whole here: origin no longer holds what it leans on"
    return 1
  done <"$u/.grove-backup/refs.txt"
}

# .what = the unit's branch and remote config, exclude list, and hooks, into <common dir>
restore_tree_repo_state() {
  local u="$1" dir="$2" cd="$3" key value
  local rs="$u/.grove-backup/repo"
  if [[ -s "$rs/config.list" ]]; then
    # git exits 5 on an unset of a key that is absent: that is the one silence allowed
    while read -r key; do
      g "$dir" config --unset-all "$key" 2>"$WORK/unset.err"
      case $? in 0|5) ;; *) row "💥 MalfunctionError: could not clear $key: $(head -n 1 "$WORK/unset.err")"; return 1 ;; esac
    done < <(cut -d' ' -f1 "$rs/config.list" | sort -u)
    while read -r key value; do g "$dir" config --add "$key" "$value"; done <"$rs/config.list"
  fi
  [[ -f "$rs/exclude" ]] && mkdir -p "$cd/info" && cp -a "$rs/exclude" "$cd/info/exclude"
  [[ -d "$rs/hooks" ]] && mkdir -p "$cd/hooks" && cp -a "$rs/hooks/." "$cd/hooks/"
  return 0
}

# .what = the stash, with every entry its reflog held
restore_tree_stash() {
  local u="$1" dir="$2" cd="$3" sha have
  sha="$(awk '$2 == "refs/stash" { print $1 }' "$u/.grove-backup/refs.txt")"
  [[ -n "$sha" ]] || return 0
  have="$(g "$dir" rev-parse -q --verify refs/stash)"
  if [[ -z "$have" ]]; then
    g "$dir" update-ref refs/stash "$sha" ""
    [[ -f "$u/.grove-backup/checkout/logs/refs/stash" ]] \
      && mkdir -p "$cd/logs/refs" && cp -a "$u/.grove-backup/checkout/logs/refs/stash" "$cd/logs/refs/stash"
    row "+ stash · $(plural "$(g "$dir" stash list 2>/dev/null | wc -l | tr -d ' ')" entry | sed 's/entrys$/entries/')"
    return 0
  fi
  [[ "$have" == "$sha" ]] && return 0
  graft_ref "$dir" "$FROM" "$FROM/stash" "$sha" "stash entry, from refs/stash" aside
}

# .what = the checkout: HEAD's files from git, then the unit's index, its own state,
#         its changed and untracked files, and its deletes
# usage: restore_tree_checkout <u> <worktree> <its git dir>
restore_tree_checkout() {
  local u="$1" wt="$2" gd="$3" co rel n=0
  co="$u/.grove-backup/checkout"

  # the staged copies, which no ref reaches — into the object store, before the index
  if [[ -d "$u/.grove-backup/staged" ]]; then
    ( cd "$u/.grove-backup/staged" && find . -type f -print0 ) \
      | while IFS= read -r -d '' rel; do
          g "$wt" hash-object -w --no-filters "$u/.grove-backup/staged/${rel#./}" >/dev/null || exit 1
        done || { row "💥 MalfunctionError: a staged copy could not be written to the object store"; return 1; }
  fi

  # HEAD's files, then the checkout state as the dead tree held it
  if [[ -n "$(meta "$u" head_sha)" ]]; then
    g "$wt" checkout -q -f "$(meta "$u" head_sha)" 2>"$WORK/co.err" \
      || { row "💥 MalfunctionError: HEAD could not be checked out: $(head -n 1 "$WORK/co.err")"; return 1; }
  fi
  for rel in HEAD index ORIG_HEAD MERGE_HEAD MERGE_MSG CHERRY_PICK_HEAD rebase-merge rebase-apply; do
    [[ -e "$co/$rel" ]] || continue
    rm -rf "${gd:?}/$rel" && cp -a "$co/$rel" "$gd/$rel"
  done
  [[ -f "$co/logs/HEAD" ]] && mkdir -p "$gd/logs" && cp -a "$co/logs/HEAD" "$gd/logs/HEAD"

  # the unit's own files — every one differs from HEAD, is untracked, or is ignored and kept
  tar -C "$u" --exclude=./.grove-backup -cf - . | tar -C "$wt" -xf - \
    || { row "💥 MalfunctionError: the unit's files could not be laid at $wt"; return 1; }
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    rm -f -- "$wt/$rel" && n=$((n + 1))
  done < <(jq -r '.deletes[]' "$u/.grove-backup/meta.json")

  RESTORED_FILES="$( (cd "$u" && find . -path ./.grove-backup -prune -o \( -type f -o -type l \) -print) | wc -l | tr -d ' ')"
  RESTORED_DELETES="$n"
  return 0
}

######################################################################
# .what = a unit's files into a PRESENT clone, where that lays over naught of its own
#
# .the rule, per path
#   - the live HEAD must be the unit's HEAD: a change is relative to its base, and
#     on another base it would read as a revert
#   - a path absent here, or tracked and equal to this HEAD → the unit's copy lands
#   - a path this clone changed, or holds untracked → kept as it stands, and named
#   - a delete lands only where this clone's copy still equals HEAD
#   - the index is this clone's own; a staged copy is named, never staged here
######################################################################
# .what = does an unpacked tree unit hold aught to lay: a file of its own, a delete, or a staged copy?
restore_unit_has_layable_content() {
  local u="$1"
  [[ -n "$( (cd "$u" && find . -path ./.grove-backup -prune -o \( -type f -o -type l \) -print -quit) )" ]] && return 0
  [[ "$(jq '(.deletes | length) + (.staged | length)' "$u/.grove-backup/meta.json")" -gt 0 ]]
}

restore_tree_lay_over() {
  local u="$1" live="$2" rel laid=0 n i
  local -a kept=()
  restore_unit_has_layable_content "$u" || return 0

  if [[ "$(g "$live" rev-parse -q --verify HEAD)" != "$(meta "$u" head_sha)" ]]; then
    row "🌙 the dead clone's checkout held edits on another HEAD; none laid here"
    row "   └─ to read them, lay it aside: rhx grove.backup.restore --from $FROM --of $ORG/$REPO --tree $REPO --into <dir>"
    return 0
  fi

  # each path, as the rule above says
  is_clean_here() { g "$live" ls-files --error-unmatch -- "$1" >/dev/null 2>&1 && g "$live" diff --quiet HEAD -- "$1"; }
  while IFS= read -r -d '' rel; do
    rel="${rel#./}"
    # already the same bytes → naught to do, naught to name (a rerun lands here)
    [[ -f "$live/$rel" && ! -L "$live/$rel" ]] && cmp -s "$u/$rel" "$live/$rel" && continue
    if [[ ( -e "$live/$rel" || -L "$live/$rel" ) ]] && ! is_clean_here "$rel"; then kept+=("$rel"); continue; fi
    mkdir -p "$(dirname "$live/$rel")" && rm -f -- "$live/$rel" && cp -a "$u/$rel" "$live/$rel" \
      || { row "💥 MalfunctionError: could not lay $live/$rel"; return 1; }
    laid=$((laid + 1))
  done < <(cd "$u" && find . -path ./.grove-backup -prune -o \( -type f -o -type l \) -print0 | sort -z)
  n=0
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    if [[ -e "$live/$rel" ]] && is_clean_here "$rel"; then rm -f -- "$live/$rel" && n=$((n + 1)); continue; fi
    [[ -e "$live/$rel" ]] && kept+=("$rel (a delete)")
  done < <(jq -r '.deletes[]' "$u/.grove-backup/meta.json")

  row "+ $(plural "$laid" file) of the dead checkout laid · $(plural "$n" delete) applied"
  for i in "${!kept[@]}"; do
    [[ "$i" -ge 8 ]] && { row "   ├─ … and $(( ${#kept[@]} - 8 )) more, each kept as this clone has it"; break; }
    row "   ├─ = ${kept[$i]} (kept: this clone changed it)"
  done
  [[ "$(jq '.staged | length' "$u/.grove-backup/meta.json")" -gt 0 ]] \
    && row "   ├─ its staged copies are not staged here; this clone's index is its own"
  row "   └─ to read the dead checkout whole: --into <dir>"
}

# .what = one summary row for a tree that landed
restore_tree_report() {
  local u="$1" wt="$2" head ahead pit
  head="$(g "$wt" symbolic-ref -q --short HEAD 2>/dev/null)"
  [[ -n "$head" ]] || head="detached at $(g "$wt" rev-parse --short=8 HEAD 2>/dev/null)"
  ahead="$(g "$wt" rev-list --count '@{u}..HEAD' 2>/dev/null)"
  pit="$(meta "$u" point_in_time)"
  [[ -n "$ahead" ]] && row "   ├─ HEAD $head · $(plural "$ahead" commit) not on its upstream" \
                    || row "   ├─ HEAD $head"
  [[ "$pit" == false ]] && row "   ├─ ⚠ it moved through each pack of its last pass; files may span a few seconds"
  row "   └─ $(plural "${RESTORED_FILES:-0}" file) laid · $(plural "${RESTORED_DELETES:-0}" delete) applied"
}

######################################################################
# one unit, by kind
######################################################################

# .what = a clone — whole at an absent target; grafted into a present one
restore_clone() {
  local unit="$1" key="$2" class="$3" target u sha ref rc
  ORG="$(grove_backup_unit_field "$unit" org)"
  REPO="$(grove_backup_unit_field "$unit" repo)"
  target="${INTO:-$HOME/git/$ORG/$REPO}"

  if [[ -n "$INTO" && -e "$target" ]]; then
    row "✋ ConstraintError: $target is present; --into lays a unit only where naught is"
    return 2
  fi
  if [[ -e "$target" && ! -d "$target/.git" ]]; then
    row "✋ ConstraintError: $target is present and is no clone; it is left as it stands"
    row "   └─ lay the unit aside instead: --into <dir>"
    return 2
  fi

  restore_tree_unit "$key" "$class"; rc=$?
  [[ "$rc" -eq 0 ]] || return "$rc"
  u="$UNIT_DIR"

  # present — a graft of refs, never a file touched
  if [[ -e "$target" ]]; then
    row "⇄ graft into $target (its files untouched)"
    restore_tree_objects "$u" "$target" || return 1
    while read -r sha ref; do
      [[ "$ref" == refs/heads/* ]] || continue
      graft_ref "$target" "$FROM" "${ref#refs/heads/}" "$sha" "" branch
    done <"$u/.grove-backup/refs.txt"
    restore_tree_stash "$u" "$target" "$target/.git"
    restore_tree_lay_over "$u" "$target"
    return 0
  fi

  # absent — origin, plus the unit
  restore_tree_base "$u" "$target" || return 1
  restore_tree_objects "$u" "$target" || return 1
  while read -r sha ref; do
    [[ "$ref" == refs/heads/* || "$ref" == refs/tags/* ]] || continue
    g "$target" update-ref "$ref" "$sha"
  done <"$u/.grove-backup/refs.txt"
  [[ -d "$u/.grove-backup/checkout/logs/refs" ]] \
    && mkdir -p "$target/.git/logs" && cp -a "$u/.grove-backup/checkout/logs/refs" "$target/.git/logs/"
  restore_tree_repo_state "$u" "$target" "$target/.git" || return 1
  restore_tree_stash "$u" "$target" "$target/.git"
  restore_tree_checkout "$u" "$target" "$target/.git" || return 1
  [[ -n "$(meta "$u" origin)" ]] && row "+ laid at $target, from origin and its own unit" \
                                 || row "+ laid at $target, whole from its own unit (it has no origin)"
  restore_tree_report "$u" "$target"
  return 0
}

# .what = a worktree — linked into its clone, which comes from origin if absent
restore_worktree() {
  local unit="$1" key="$2" class="$3" org repo tree target live u rc head_ref head_sha branch gd cd
  org="$(grove_backup_unit_field "$unit" org)"
  repo="$(grove_backup_unit_field "$unit" repo)"
  tree="$(grove_backup_unit_field "$unit" tree)"
  live="$HOME/git/$org/$repo"
  target="${INTO:-$HOME/git/$org/_worktrees/$tree}"

  if [[ -e "$target" ]]; then
    [[ "$ALL" -eq 1 ]] && { row "= already here; kept as it stands"; return 4; }
    row "✋ ConstraintError: $target is present; a restore never lays over it"
    row "   └─ lay it aside instead: rhx grove.backup.restore --from $FROM --of $org/$repo --tree $tree --into <dir>"
    return 2
  fi

  restore_tree_unit "$key" "$class"; rc=$?
  [[ "$rc" -eq 0 ]] || return "$rc"
  u="$UNIT_DIR"
  head_ref="$(meta "$u" head_ref)"
  head_sha="$(meta "$u" head_sha)"

  # --into: the worktree lands as a clone of its own, whole
  if [[ -n "$INTO" ]]; then
    restore_tree_base "$u" "$target" || return 1
    restore_tree_objects "$u" "$target" || return 1
    [[ -n "$head_ref" && -n "$head_sha" ]] && g "$target" update-ref "$head_ref" "$head_sha"
    restore_tree_repo_state "$u" "$target" "$target/.git" || return 1
    restore_tree_stash "$u" "$target" "$target/.git"
    restore_tree_checkout "$u" "$target" "$target/.git" || return 1
    row "+ laid aside at $target, a clone of its own"
    restore_tree_report "$u" "$target"
    return 0
  fi

  # the clone it links into — from origin, when this box has none
  if [[ ! -d "$live/.git" ]]; then
    if [[ -e "$live" ]]; then
      row "✋ ConstraintError: $live is present and is no clone; its worktree cannot link into it"
      return 2
    fi
    restore_tree_base "$u" "$live" || return 1
    [[ -n "$(meta "$u" origin)" ]] && g "$live" checkout -q 2>/dev/null
    row "+ its clone $live, from origin"
  fi
  cd="$live/.git"
  restore_tree_objects "$u" "$live" || return 1
  restore_tree_repo_state "$u" "$live" "$cd" || return 1
  restore_tree_stash "$u" "$live" "$cd"

  # its branch — grafted, so a diverged live branch is never moved
  if [[ -n "$head_ref" ]]; then
    graft_ref "$live" "$FROM" "${head_ref#refs/heads/}" "$head_sha" "" branch
    branch="$GRAFT_NAME"
    # the worktree takes a branch that sits at its own HEAD and is checked out nowhere else
    if ! restore_branch_is_free_at "$live" "$branch" "$head_sha"; then
      branch="$FROM/${head_ref#refs/heads/}"
      land_aside "$live" "$branch" "$head_sha" \
        || { row "💥 MalfunctionError: neither ${head_ref#refs/heads/} nor $branch is free to check out here"; return 1; }
      row "⇄ the live ${head_ref#refs/heads/} differs or is checked out; this worktree takes $branch"
    fi
    g "$live" worktree add -q --no-checkout "$target" "$branch" 2>"$WORK/wt.err" \
      || { row "💥 MalfunctionError: git worktree add refused $target: $(head -n 1 "$WORK/wt.err")"; return 1; }
    [[ -f "$u/.grove-backup/checkout/HEAD" ]] && printf 'ref: refs/heads/%s\n' "$branch" >"$u/.grove-backup/checkout/HEAD"
    [[ -f "$u/.grove-backup/checkout/logs/refs/heads/${head_ref#refs/heads/}" && ! -e "$cd/logs/refs/heads/$branch" ]] \
      && mkdir -p "$(dirname "$cd/logs/refs/heads/$branch")" \
      && cp -a "$u/.grove-backup/checkout/logs/refs/heads/${head_ref#refs/heads/}" "$cd/logs/refs/heads/$branch"
  else
    g "$live" worktree add -q --no-checkout --detach "$target" "$head_sha" 2>"$WORK/wt.err" \
      || { row "💥 MalfunctionError: git worktree add refused $target: $(head -n 1 "$WORK/wt.err")"; return 1; }
  fi
  gd="$(g "$target" rev-parse --absolute-git-dir)"
  restore_tree_checkout "$u" "$target" "$gd" || return 1
  row "+ laid at $target, linked into $live"
  restore_tree_report "$u" "$target"
  return 0
}

######################################################################
# .what = can a new worktree in <clone> check out <branch> at <sha>?
#   it must be named, sit at that sha, and be checked out in no other worktree
######################################################################
restore_branch_is_free_at() {
  local live="$1" branch="$2" sha="$3"
  [[ -n "$branch" ]] || return 1
  [[ "$(g "$live" rev-parse -q --verify "refs/heads/$branch")" == "$sha" ]] || return 1
  [[ -z "$(live_checkout_of "$live" "$branch")" ]]
}

# .what = the group a laid path is counted under: its first dir as `<dir>/…`, or itself
restore_top_group() {
  local rel="$1" top="${1%%/*}"
  [[ "$top" == "$rel" ]] && { printf '%s' "$rel"; return 0; }
  printf '%s/…' "$top"
}

######################################################################
# .what = where a unit of plain files lands on this box
#   home      ~/<dir>
#   orphan    ~/git/<org>/_worktrees/<dir>   (where it sat)
#   setaside  ~/git/<org>/_setaside/<repo>/<name>
#
# .why a set-aside lands OUTSIDE its clone's `.git`: on a fresh box the clone may
#   be absent, and a `<repo>/.git/` made just to hold it would read as a clone
######################################################################
restore_files_target() {
  local unit="$1" org
  org="$(grove_backup_unit_field "$unit" org)"
  case "$(grove_backup_unit_kind "$unit")" in
    home)     printf '%s/%s' "$HOME" "$(grove_backup_unit_field "$unit" home)" ;;
    orphan)   printf '%s/git/%s/_worktrees/%s' "$HOME" "$org" "$(grove_backup_unit_field "$unit" orphan)" ;;
    setaside) printf '%s/git/%s/_setaside/%s/%s' "$HOME" "$org" "$(grove_backup_unit_field "$unit" repo)" \
                "$(grove_backup_unit_field "$unit" setaside)" ;;
  esac
}

######################################################################
# .what = the unit id one named restore asks for, from its flags
# .why  a transformer, so the flag-to-id map reads in one place, each form an early return
######################################################################
restore_unit_of_args() {
  [[ -n "$HOME_ARG" ]] && { printf 'user=%s/home=%s' "$ME" "$HOME_ARG"; return 0; }
  [[ -n "$ORPHAN" ]] && { printf 'user=%s/org=%s/orphan=%s' "$ME" "${ORPHAN%%/*}" "${ORPHAN#*/}"; return 0; }
  [[ -n "$SETASIDE" ]] && { printf 'user=%s/org=%s/repo=%s/setaside=%s' "$ME" "${OF%%/*}" "${OF#*/}" "$SETASIDE"; return 0; }
  printf 'user=%s/org=%s/repo=%s/tree=%s' "$ME" "${OF%%/*}" "${OF#*/}" "$TREE"
}

######################################################################
# .what = refuse a named unit that --from does not hold for this seat
# .why  run in the caller's shell, so its exit 2 ends the restore. a unit another
#   seat holds is named with that seat; else the units this seat does hold are listed
######################################################################
restore_unit_assert_held() {
  local unit="$1" other
  awk -F'\t' -v u="$unit" '$1 == u { found = 1 } END { exit !found }' "$WORK/latest" && return 0
  other="$(awk -F'\t' -v rest="${unit#user=*/}" '{ r = $1; sub(/^user=[^\/]*\//, "", r) } r == rest { print $1 }' "$WORK/latest" | head -n 1)"
  [[ -n "$other" ]] && constraint "that unit belongs to seat $(grove_backup_unit_field "$other" user), not $ME" \
    "a restore writes only its own seat's home; run it as $(grove_backup_unit_field "$other" user)"
  echo "✋ ConstraintError: no backup of ${unit#user=*/} under grove=$FROM" >&2
  echo "   └─ the units this seat holds there:" >&2
  awk -F'\t' -v me="user=$ME/" 'index($1, me) == 1 { sub(/^user=[^\/]*\//, "", $1); print "      · " $1 }' "$WORK/latest" >&2
  exit 2
}

######################################################################
# .what = lay a unit of plain files: each absent file lands, each present one is kept
######################################################################
restore_home() {
  local unit="$1" key="$2" class="$3" hd target obj src rel top laid=0 keyrack=0 i
  local -a kept=()
  local -A groups=()
  hd="$(grove_backup_unit_field "$unit" home)"
  target="${INTO:-$(restore_files_target "$unit")}"

  obj="$WORK/obj.tar.gz"
  restore_fetch "$key" "$class" "$obj" || return $?
  src="$(restore_unpack "$obj")" || { row "💥 MalfunctionError: the object did not unpack"; return 1; }

  while IFS= read -r -d '' rel; do
    rel="${rel#./}"
    if [[ "$hd" == .rhachet && "$rel" == keyrack/* ]]; then keyrack=1; continue; fi
    if [[ -e "$target/$rel" || -L "$target/$rel" ]]; then kept+=("$rel"); continue; fi
    mkdir -p "$(dirname "$target/$rel")" && mv "$src/$rel" "$target/$rel" || { row "💥 MalfunctionError: could not lay $target/$rel"; return 1; }
    laid=$((laid + 1))
    top="$(restore_top_group "$rel")"
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
# the ask — its shape, read from the parsed flags (FROM ALL OF TREE SETASIDE ORPHAN HOME_ARG INTO)
######################################################################

# .what = the command this run answers, as the tree header prints it
restore_ask_render() {
  local ask="--from $FROM"
  [[ "$ALL" -eq 1 ]] && ask="$ask --all"
  [[ -n "$SETASIDE" ]] && ask="$ask --of $OF --setaside $SETASIDE"
  [[ -n "$TREE" ]] && ask="$ask --of $OF --tree $TREE"
  [[ -n "$ORPHAN" ]] && ask="$ask --orphan $ORPHAN"
  [[ -n "$HOME_ARG" ]] && ask="$ask --home $HOME_ARG"
  [[ -n "$INTO" ]] && ask="$ask --into $INTO"
  printf '%s' "$ask"
}

# .what = how many restore forms the flags name; exactly one is a valid ask
restore_ask_forms() {
  local forms=0
  [[ "$ALL" -eq 1 ]] && forms=$((forms + 1))
  [[ -n "$OF$TREE$SETASIDE" ]] && forms=$((forms + 1))
  [[ -n "$HOME_ARG" ]] && forms=$((forms + 1))
  [[ -n "$ORPHAN" ]] && forms=$((forms + 1))
  printf '%s' "$forms"
}

# .what = is <value> one `<org>/<name>` pair, no more and no less?
restore_is_org_pair() { [[ "$1" == */* && "$1" != */*/* ]]; }

# .what = does --of name one repo, with exactly one of --tree or --setaside beside it?
restore_of_is_valid() {
  restore_is_org_pair "$OF" || return 1
  [[ -n "$TREE" && -z "$SETASIDE" ]] && return 0
  [[ -z "$TREE" && -n "$SETASIDE" ]]
}

# .what = is <name> one of the home dirs the backup holds (`~/git` rides as trees, never as home)?
restore_home_is_backed_up() {
  local name="$1" d
  [[ "$name" != git ]] || return 1
  for d in "${GROVE_BACKUP_SCOPE_DIRS[@]}"; do [[ "${d#\~/}" == "$name" ]] && return 0; done
  return 1
}

# .what = refuse a run whose bucket cannot be read, with the exit its cause earns
restore_reach_refuse() {
  if grove_backup_cause_is_transient; then
    echo "💥 MalfunctionError: cannot reach the backup bucket · $GROVE_BACKUP_CAUSE" >&2
    echo "   └─ $GROVE_BACKUP_FIX" >&2
    exit 1
  fi
  constraint "cannot reach the backup bucket · $GROVE_BACKUP_CAUSE" "$GROVE_BACKUP_FIX"
}

######################################################################
# main
######################################################################
restore_main() {
  local ask="$*"
  FROM="" ALL=0 OF="" TREE="" HOME_ARG="" INTO="" ORPHAN="" SETASIDE=""
  while [[ $# -gt 0 ]]; do
    # a value flag with no value refuses: `shift 2` past the last arg shifts naught,
    # so the loop would read the same flag forever
    [[ "$1" =~ ^--(from|of|tree|home|orphan|setaside|into|skill|repo|role)$ && $# -lt 2 ]] \
      && constraint "$1 needs a value" "see: rhx grove.backup.restore --help"
    case "$1" in
      --from) FROM="${2:-}"; shift 2 ;;
      --all)  ALL=1; shift ;;
      --of)   OF="${2:-}"; shift 2 ;;
      --tree) TREE="${2:-}"; shift 2 ;;
      --home) HOME_ARG="${2:-}"; shift 2 ;;
      --orphan)   ORPHAN="${2:-}"; shift 2 ;;
      --setaside) SETASIDE="${2:-}"; shift 2 ;;
      --into) INTO="${2:-}"; shift 2 ;;
      # rhachet injects these three into every skill it runs
      --skill|--repo|--role) shift 2 ;;
      --) shift ;;
      *) constraint "unknown argument '$1'" "see: rhx grove.backup.restore --help" ;;
    esac
  done
  # the shape of the ask
  [[ -n "$FROM" ]] || constraint "--from <grove> is required" "see what each grove left: rhx grove.backup.get --list"
  [[ "$FROM" =~ $GROVE_BACKUP_SLUG_PATTERN ]] || constraint "'$FROM' is not a grove slug" "list the groves: rhx grove.backup.get --list"
  [[ "$(restore_ask_forms)" -eq 1 ]] || constraint "name exactly one of: --all · --of <org/repo> --tree <dir> · --of <org/repo> --setaside <name> · --orphan <org>/<dir> · --home <dir>" "see: rhx grove.backup.restore --help"
  [[ -z "$OF$TREE$SETASIDE" ]] || restore_of_is_valid \
    || constraint "--of takes <org/repo>, with one of --tree or --setaside beside it" "e.g.: --of ahbode/svc-quotes --tree svc-quotes"
  [[ -z "$ORPHAN" ]] || restore_is_org_pair "$ORPHAN" \
    || constraint "--orphan takes <org>/<dir>" "e.g.: --orphan ahbode/svc-quotes.feat-x"
  [[ -z "$HOME_ARG" ]] || restore_home_is_backed_up "$HOME_ARG" \
    || constraint "--home takes one of the backed-up home dirs: .claude · .rhachet" "a clone or worktree takes --of and --tree"
  [[ "$ALL" -eq 1 && -n "$INTO" ]] && constraint "--into lays ONE unit aside; it does not combine with --all"
  if [[ -n "$INTO" ]]; then INTO="$(realpath -m "$INTO")"; fi
  ask="$(restore_ask_render)"

  ME="$(id -un)"

  # one restore per seat
  mkdir -p "$HOME/.cache/grove-backup"
  exec 8>"$HOME/.cache/grove-backup/restore.lock"
  flock -n 8 || constraint "a restore is active on this seat" "let it finish, then rerun this one"

  # the reach — a restore that cannot read lays naught
  grove_backup_reach_check no || restore_reach_refuse

  WORK="$(mktemp -d "$HOME/.cache/grove-backup/restore.XXXXXX")"
  trap 'rm -rf "$WORK"' EXIT

  local rc
  grove_backup_s3_list "grove=$FROM/" "$WORK/keys"
  rc=$?
  [[ "$rc" -eq 3 ]] && { grove_backup_cause_denied; restore_reach_refuse; }
  [[ "$rc" -eq 0 ]] || { GROVE_BACKUP_CAUSE="the list failed"; GROVE_BACKUP_FIX="$GROVE_BACKUP_AWS_ERR"; restore_reach_refuse; }
  [[ -s "$WORK/keys" ]] || constraint "no backups under grove=$FROM" "list the groves the bucket holds: rhx grove.backup.get --list"

  # each unit's latest object: "unit<TAB>key<TAB>class"
  local key class
  grove_backup_units_latest <"$WORK/keys" >"$WORK/latest"

  # the targets, in lay order (grove_backup_unit_rank): a worktree finds its clone laid
  local -a targets=()
  local unit
  if [[ "$ALL" -eq 1 ]]; then
    mapfile -t targets < <(awk -F'\t' -v me="user=$ME/" 'index($1, me) == 1 { print $1 }' "$WORK/latest" \
      | while read -r unit; do echo "$(grove_backup_unit_rank "$unit") $unit"; done \
      | sort | cut -d' ' -f2-)
    if [[ "${#targets[@]}" -eq 0 ]]; then
      constraint "grove=$FROM holds no unit of seat $ME" \
        "the seats it does hold: $(cut -f1 "$WORK/latest" | sed 's#/.*##' | sort -u | tr '\n' ' ')"
    fi
  fi

  # one named unit: its id from the flags, then held under --from or refused
  if [[ "$ALL" -ne 1 ]]; then
    unit="$(restore_unit_of_args)"
    restore_unit_assert_held "$unit"
    targets=("$unit")
  fi

  # each unit; one that fails does not stop the rest
  echo "🐢 lets carry $FROM's work home..."
  echo ""
  echo "🗄️ grove.backup.restore $ask"
  local landed=0 kept=0 waits=0 refused=0 failed=0 day
  for unit in "${targets[@]}"; do
    key="$(awk -F'\t' -v u="$unit" '$1 == u { print $2 }' "$WORK/latest")"
    class="$(awk -F'\t' -v u="$unit" '$1 == u { print $3 }' "$WORK/latest")"
    day="$(grove_backup_key_day "$key")"
    echo "   ├─ $(grove_backup_unit_without_seat "$unit") · $day · $class"
    case "$(grove_backup_unit_kind "$unit")" in
      clone)    restore_clone "$unit" "$key" "$class" ;;
      worktree) restore_worktree "$unit" "$key" "$class" ;;
      home|orphan|setaside) restore_home "$unit" "$key" "$class" ;;
    esac
    rc=$?
    rows_flush
    rm -rf "$WORK"/unit.* "$WORK/obj.tar.gz"
    case "$rc" in 0) landed=$((landed + 1)) ;; 4) kept=$((kept + 1)) ;; 3) waits=$((waits + 1)) ;; 2) refused=$((refused + 1)) ;; *) failed=$((failed + 1)) ;; esac
  done

  echo "   └─ $(plural "${#targets[@]}" unit) · $landed restored · $kept already here · $waits await a thaw · $refused refused · $failed failed"
  [[ "$failed" -gt 0 ]] && return 1
  [[ "$refused" -gt 0 ]] && return 2
  return 0
}

# run only when executed — a play sources this file and calls restore_main itself
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  restore_main "$@"
  exit $?
fi
