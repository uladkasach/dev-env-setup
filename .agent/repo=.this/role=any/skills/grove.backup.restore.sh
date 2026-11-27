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
#   - two streams, split by WHAT refused: a refusal of the CALL (its args, its
#     reach, its lock) goes to stderr and no unit runs; each UNIT's verdict, a
#     refusal included, is a row of the run's tree on stdout, beside its peers
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
  echo "on a grove, run it as the seat that owns the work, from this repo's checkout:"
  echo "  cd ~/git/more/dev-env-setup && rhx grove.backup.restore --from <grove> --all"
}

# the root is four dirs above this skill, never `git rev-parse`: a grove's checkout
#   is pushed with no .git, so git finds no repo there (see grove.backup.get)
REPO_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../../.." && pwd)"
# shellcheck source=../../../../src/grove.provision/5.devtools/5.27.backup/grove.backup.operations.sh
source "$REPO_ROOT/src/grove.provision/5.devtools/5.27.backup/grove.backup.operations.sh" || {
  echo "💥 MalfunctionError: could not load grove.backup.operations.sh under $REPO_ROOT" >&2; exit 1; }

######################################################################
# the tree this run prints — rows gather per unit, then print with glyphs
######################################################################
#   a row that opens with three spaces is a CHILD of the row above it: it takes no
#   glyph of its own, and sits under its parent's trunk. its own glyphs and any deeper
#   indent (a grandchild, `      └─`) ride through as written
ROWS=()
row() { ROWS+=("$1"); }
# 🛑 .why every row passes ONE sink that strips control bytes — C0, DEL, and the utf-8 C1 set
#   (`C2 80`–`C2 9F`, where CSI sits) — with tab, newline, and every utf-8 glyph kept: a row
#   may carry text a unit supplied (a path kept, an origin, a branch), and
#   an escape sequence there could forge a ✓ row, move the cursor over a 🌙, or write the
#   clipboard. one sink, so no lane is left raw
rows_flush() {
  local i j glyph trunk last
  for i in "${!ROWS[@]}"; do
    [[ "${ROWS[$i]}" == "   "* ]] && continue
    # the last PARENT closes the tree, whatever children follow it
    last=1
    for (( j = i + 1; j < ${#ROWS[@]}; j++ )); do
      [[ "${ROWS[$j]}" != "   "* ]] && { last=0; break; }
    done
    glyph="├─"; trunk="│  "
    [[ "$last" -eq 1 ]] && { glyph="└─"; trunk="   "; }
    echo "   │  $glyph ${ROWS[$i]}"
    for (( j = i + 1; j < ${#ROWS[@]}; j++ )); do
      [[ "${ROWS[$j]}" == "   "* ]] || break
      echo "   │  $trunk${ROWS[$j]#   }"
    done
  done | LC_ALL=C tr -d '\000-\010\013-\037\177' | LC_ALL=C sed 's/\xc2[\x80-\x9f]//g'
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
# .why no hook runs on the restore's own acts: a checkout fires post-checkout, a merge
#   post-merge, an update-ref reference-transaction, and a present clone's `core.hooksPath`
#   may name a dir the unit's own commit just laid. the defuse guards the NEXT git act; this
#   guards the acts of the restore itself
g() { local path="$1"; shift; git -c safe.directory='*' -c core.hooksPath=/dev/null -C "$path" "$@"; }

######################################################################
# a unit's outcome — the rc each unit step returns, named in one place
######################################################################
UNIT_LANDED=0 UNIT_REFUSED=2 UNIT_THAWS=3 UNIT_KEPT=4

# .what = the tally word for a unit's rc; any rc outside the vocabulary is a failure
restore_outcome_of_rc() {
  case "$1" in
    "$UNIT_LANDED") echo landed ;;
    "$UNIT_KEPT") echo kept ;;
    "$UNIT_THAWS") echo waits ;;
    "$UNIT_REFUSED") echo refused ;;
    *) echo failed ;;
  esac
}

######################################################################
# .what = fetch one object into a file, or ask s3 to thaw it
# rc: UNIT_LANDED the file is here · UNIT_THAWS a thaw is requested or awaited (named) · 1 failed
######################################################################
# .what = a grant the bucket refused for one unit: the caller's owner to fix, so a ✋ with that
#   owner named — the same cause and fix `grove.backup.get` prints, never a fixless 💥
restore_fetch_denied() {
  grove_backup_cause_denied
  row "✋ ConstraintError: $GROVE_BACKUP_CAUSE"
  row "   └─ fix: $GROVE_BACKUP_FIX"
  return "$UNIT_REFUSED"
}

# .what = an archived object whose thaw the grant refused: past the 90-day reach, the admin
#   tier alone thaws it (S8), so the ✋ names the admin's command, never a retry by this box
restore_fetch_locked() {
  local key="$1" class="$2"
  row "✋ ConstraintError: sits in $class, past this box's 90-day reach"
  row "   ├─ why: the grant locks a grove out of an archived object; the admin tier alone thaws it"
  row "   └─ fix: at the admin tier, thaw it; then this same command lays it, once it reads"
  row "      └─ aws s3api restore-object --bucket $GROVE_BACKUP_BUCKET --key '$key' --restore-request '{\"Days\":7,\"GlacierJobParameters\":{\"Tier\":\"Standard\"}}'"
  return "$UNIT_REFUSED"
}

restore_fetch() {
  local key="$1" class="$2" out="$3" facts restore rc stamp record since
  record="$HOME/.cache/grove-backup/thaw/$(printf '%s' "$key" | tr '/=' '__')"

  if [[ "$class" == DEEP_ARCHIVE || "$class" == GLACIER ]]; then
    facts="$WORK/head"
    grove_backup_s3_head "$key" "$facts"
    rc=$?
    [[ "$rc" -eq 3 ]] && { restore_fetch_denied; return; }
    [[ "$rc" -ne 0 ]] && { row "💥 MalfunctionError: its object could not be read: $GROVE_BACKUP_AWS_ERR"; return 1; }
    restore="$(grove_backup_s3_head_restore "$facts")"

    if [[ "$restore" == *'request="true"'* ]]; then
      since="$(cat "$record" 2>/dev/null)"
      row "🌙 sits in $class; its thaw is in progress"
      [[ -n "$since" ]] && row "   ├─ asked $(grove_backup_age $(( $(grove_backup_now) - since ))) ago; eta 12–48h from the ask"
      row "   └─ resume with the same command, once it reads"
      return "$UNIT_THAWS"
    fi

    if [[ "$restore" != *'request="false"'* ]]; then
      grove_backup_s3_thaw "$key"
      rc=$?
      [[ "$rc" -eq 3 ]] && { restore_fetch_locked "$key" "$class"; return; }
      [[ "$rc" -ne 0 ]] && { row "💥 MalfunctionError: the thaw could not be asked: $GROVE_BACKUP_AWS_ERR"; return 1; }
      stamp="$(grove_backup_now)"
      mkdir -p "$(dirname "$record")" && printf '%s\n' "$stamp" >"$record"
      row "🌙 sits in $class"
      row "   ├─ thaw requested"
      row "   ├─ eta: 12–48h"
      row "   └─ resume with the same command"
      return "$UNIT_THAWS"
    fi
  fi

  grove_backup_s3_get "$key" "$out"
  rc=$?
  if [[ "$rc" -eq 0 ]]; then
    rm -f "$record"
    restore_object_fits "$out" || return "$UNIT_REFUSED"
    return 0
  fi
  [[ "$rc" -eq 3 ]] && { restore_fetch_denied; return; }
  row "💥 MalfunctionError: its object could not be read: $GROVE_BACKUP_AWS_ERR"
  return 1
}

# .what = may this object be laid: its bytes twice (the unpack, then the lay) leave the floor free?
# .why asked per unit, of its own size: a small unit lays on a near-full disk, and a huge
#   one is refused before it fills the disk the live clones sit on
restore_object_fits() {
  local file="$1" bytes
  # a full read, never `gzip -l`: its size is the true size modulo 2^32, so a 5 GiB unit
  #   or a gzip bomb would read as near naught. the read costs cpu, and no disk
  bytes="$(gzip -dc "$file" 2>/dev/null | wc -c)"
  grove_backup_disk_fits "$HOME" $(( 2 * ${bytes:-0} / 1024 )) && return 0
  row "✋ ConstraintError: no room to lay this unit: $GROVE_BACKUP_DISK_WHY"
  row "   └─ free space on the disk that holds $HOME, then rerun the same command"
  return 1
}

# .what = this box's grove name, as a fix-text names it; `<this grove>` where none is declared
restore_this_grove() {
  local name
  name="$(head -n 1 "$(grove_backup_name_file)" 2>/dev/null)"
  [[ "$name" =~ $GROVE_BACKUP_SLUG_PATTERN ]] && { printf '%s' "$name"; return 0; }
  printf '<this grove>'
}

# .what = name each path the pack cut as a credential: by shape or by content, it never left the dead grove
restore_report_cuts() {
  local u="$1" i
  local -a cuts=()
  # a files unit an older agent wrote holds no manifest: no cut is known, and naught is named
  [[ -f "$u/.grove-backup/meta.json" ]] || return 0
  mapfile -t cuts < <(jq -r '(.cut // [])[] | strings' "$u/.grove-backup/meta.json" 2>/dev/null | tr -c '[:print:]\n' '?')
  [[ "${#cuts[@]}" -gt 0 ]] || return 0
  row "🌙 $(grove_backup_plural "${#cuts[@]}" file) cut as a credential never left $FROM; re-derive each here"
  for i in "${!cuts[@]}"; do
    [[ "$i" -ge 8 ]] && { row "   └─ … and $(( ${#cuts[@]} - 8 )) more"; return 0; }
    [[ "$i" -eq $(( ${#cuts[@]} - 1 )) ]] && { row "   └─ ${cuts[$i]}"; return 0; }
    row "   ├─ ${cuts[$i]}"
  done
}

# .what = unpack one object into a fresh dir under the work dir; prints the dir
restore_unpack() {
  local file="$1" dir
  dir="$(mktemp -d "$WORK/unit.XXXXXX")"
  tar -xzf "$file" -C "$dir" || { grove_backup_scratch_clear "$dir"; return 1; }
  printf '%s\n' "$dir"
}

######################################################################
# the defuse — git-run code a unit carries, laid inert
#
# 🛑 .why a unit is untrusted, and git runs code it finds on disk: a hook, a config key
#   (`core.fsmonitor`, `core.sshCommand`, `filter.*`, `alias.*`), and a rebase todo's
#   `exec` line. the top tree's own config and hooks are cut on their own lane; this lane
#   is every OTHER git dir a unit holds — a nested repo, a bare-shaped dir, a worktree's
#   admin dir — and the tree's mid-rebase state. none is refused: a cut repo is a broken
#   repo (F16). each is laid inert, and named, with the act that arms it
######################################################################

# .what = may a nested git dir's config keep <key> with <value>? rc 0 = yes
# .why the format keys a repo needs to open, as their one plain value; then the remote and
#   upstream facts the top tree's lane already allows, held to that repo's own origin
restore_gitdir_key_is_kept() {
  local key="${1,,}" value="$2" origin="$3"
  case "$key" in
    core.repositoryformatversion) [[ "$value" =~ ^[01]$ ]] ;;
    core.bare|core.filemode|core.logallrefupdates|core.ignorecase|core.precomposeunicode|core.symlinks)
      [[ "${value,,}" =~ ^(true|false)$ ]] ;;
    extensions.objectformat) [[ "${value,,}" =~ ^(sha1|sha256)$ ]] ;;
    extensions.refstorage) [[ "${value,,}" =~ ^(files|reftable)$ ]] ;;
    *) grove_backup_config_entry_is_carried "$key" "$value" "$origin" ;;
  esac
}

# .what = comment out each `exec` / `x` line of a rebase todo; prints how many
# .why `git rebase --continue` runs each such line as a shell command
restore_todo_defuse() {
  local todo="$1" n
  # a linked todo is read through its link, at a file this check never sees: dropped
  [[ -L "$todo" ]] && { rm -f "$todo"; printf '1'; return 0; }
  [[ -f "$todo" ]] || { printf '0'; return 0; }
  n="$(grep -cE '^[[:space:]]*(x|exec)([[:space:]]|$)' "$todo")"
  [[ "$n" -gt 0 ]] && sed -E -i 's/^([[:space:]]*(x|exec)([[:space:]]|$).*)$/# held by grove.backup.restore: \1/' "$todo"
  printf '%s' "${n:-0}"
}

# .what = one git dir, made inert: its config cut to the kept keys, its worktree config
#   gone, each hook laid NOT executable, each rebase `exec` held as a comment
# .why its counts land in DEFUSE_KEYS DEFUSE_HOOKS DEFUSE_EXECS, read by restore_unit_defuse
restore_gitdir_defuse() {
  local gd="$1" key value origin hook kept="$WORK/gitdir.config" todo
  if [[ -f "$gd/config" && ! -L "$gd/config" ]]; then
    origin="$(git config -f "$gd/config" --get remote.origin.url 2>/dev/null)"
    grove_backup_url_is_plain "$origin" || origin=""
    rm -f "$kept" && touch "$kept"
    # `-f` reads the file alone: no include is followed, and no key of it runs
    while IFS= read -r -d '' key && IFS= read -r -d '' value; do
      restore_gitdir_key_is_kept "$key" "$value" "$origin" || { DEFUSE_KEYS=$((DEFUSE_KEYS + 1)); continue; }
      git config -f "$kept" --add "$key" "$value" || return 1
    done < <(git config -f "$gd/config" --list -z 2>/dev/null | while IFS= read -r -d '' e; do printf '%s\0%s\0' "${e%%$'\n'*}" "${e#*$'\n'}"; done)
    mv "$kept" "$gd/config" || return 1
  fi
  # a linked config is read through its link: it may point at any file the unit holds
  [[ -L "$gd/config" ]] && { rm -f "$gd/config"; DEFUSE_KEYS=$((DEFUSE_KEYS + 1)); }
  [[ -e "$gd/config.worktree" || -L "$gd/config.worktree" ]] && { rm -f "$gd/config.worktree"; DEFUSE_KEYS=$((DEFUSE_KEYS + 1)); }
  if [[ -L "$gd/hooks" ]]; then rm -f "$gd/hooks"; DEFUSE_HOOKS=$((DEFUSE_HOOKS + 1)); fi
  for hook in "$gd/hooks"/*; do
    [[ -L "$hook" ]] && { rm -f "$hook"; DEFUSE_HOOKS=$((DEFUSE_HOOKS + 1)); continue; }
    [[ -f "$hook" && -x "$hook" ]] || continue
    chmod 0644 "$hook" || return 1
    DEFUSE_HOOKS=$((DEFUSE_HOOKS + 1))
  done
  for todo in "$gd"/rebase-merge/git-rebase-todo "$gd"/rebase-merge/git-rebase-todo.backup; do
    DEFUSE_EXECS=$((DEFUSE_EXECS + $(restore_todo_defuse "$todo")))
  done
  return 0
}

# .what = every git dir under <root>, at any depth, made inert, then named
# usage: restore_unit_defuse <root> [<path to pass over>, default <root>/.grove-backup]
# .why shape, never name: a dir git would open (a HEAD, as a file OR a link — git reads a
#   link that names `refs/…` — beside a refs dir or a commondir file) is a git dir whatever
#   it is called, and a `.git` file may point at one the unit put under another name.
#   `.grove-backup` is the unit's own manifest, which no lay step reads as a repo, so it is
#   passed — but for the tree's own rebase state
# 🛑 .why it runs twice for a tree: on the unpacked unit, and on the laid tree after its last
#   lay (restore_tree_checkout). git opens the FINAL tree, and HEAD's checkout lays files no
#   unpacked unit holds: a planted pack can commit a git dir under any name. the second pass
#   passes over the tree's own `.git`, whose config and hooks have their own lane
# 🛑 .why the set is closed over git's own pointer: a `commondir` file names the dir git reads
#   config and hooks from, and that dir needs no HEAD (objects and refs suffice), so no HEAD
#   search lists it. each pointer is followed as git follows it, against its own dir, through
#   any link; one that lands inside <root> is made inert with the rest, one that leaves <root>
#   is dropped and named (git writes it relative, `../..`). a pointer into <prune> is passed:
#   that dir has its own lane. shape alone (objects + refs) is never the test: a store of
#   another tool holds both, and its config is no git config
restore_unit_defuse() {
  local u="$1" prune="${2:-$1/.grove-backup}" gd cf text common root_real prune_real rebase="$1/.grove-backup/checkout/rebase-merge"
  local -A gitdirs=()
  DEFUSE_DIRS=0 DEFUSE_KEYS=0 DEFUSE_HOOKS=0 DEFUSE_EXECS=0 DEFUSE_POINTERS=0
  root_real="$(realpath -- "$u")" || { row "💥 MalfunctionError: could not read the real path of ${u}"; return 1; }
  prune_real="$(realpath -m -- "$prune")"
  while IFS= read -r -d '' gd; do
    [[ -d "$gd/refs" || -f "$gd/commondir" ]] || continue
    gitdirs["$(realpath -m -- "$gd")"]=1
  done < <(find "$u" -path "$prune" -prune -o -name HEAD \( -type f -o -type l \) -printf '%h\0' | sort -zu)
  while IFS= read -r -d '' cf; do
    gd="${cf%/commondir}"
    text=""
    [[ -f "$cf" && ! -L "$cf" ]] && IFS= read -r text <"$cf"
    common=""
    [[ -n "$text" && "$text" == /* ]] && common="$(realpath -m -- "$text")"
    [[ -n "$text" && "$text" != /* ]] && common="$(realpath -m -- "$gd/$text")"
    if [[ -z "$common" || "$common" != "$root_real"/* ]]; then
      rm -f "$cf" || return 1
      DEFUSE_POINTERS=$((DEFUSE_POINTERS + 1))
      continue
    fi
    [[ "$common" == "$prune_real" || "$common" == "$prune_real"/* ]] && continue
    gitdirs["$common"]=1
  done < <(find "$u" -path "$prune" -prune -o -name commondir -print0)
  while IFS= read -r -d '' gd; do
    restore_gitdir_defuse "$gd" || { row "💥 MalfunctionError: could not make the git dir ${gd#"$root_real"/} inert"; return 1; }
    DEFUSE_DIRS=$((DEFUSE_DIRS + 1))
  done < <(printf '%s\0' "${!gitdirs[@]}" | LC_ALL=C sort -zu | grep -zv '^$')
  [[ "$DEFUSE_POINTERS" -gt 0 ]] \
    && row "🌙 $(grove_backup_plural "$DEFUSE_POINTERS" "commondir pointer") dropped: each named a dir outside the tree, where git would read config and hooks"
  [[ -L "$rebase" ]] && { rm -f "$rebase"; DEFUSE_EXECS=$((DEFUSE_EXECS + 1)); }
  DEFUSE_EXECS=$((DEFUSE_EXECS + $(restore_todo_defuse "$rebase/git-rebase-todo") + $(restore_todo_defuse "$rebase/git-rebase-todo.backup")))
  [[ "$DEFUSE_KEYS" -gt 0 ]] \
    && row "🌙 $(grove_backup_plural "$DEFUSE_DIRS" "nested git dir") laid inert: $(grove_backup_plural "$DEFUSE_KEYS" "config key") cut, since a key can run a command on the next git act"
  [[ "$DEFUSE_HOOKS" -gt 0 ]] \
    && row "🌙 $(grove_backup_plural "$DEFUSE_HOOKS" "hook") of a nested git dir laid NOT executable: read each, then arm it: chmod +x <hook>"
  [[ "$DEFUSE_EXECS" -gt 0 ]] \
    && row "🌙 $(grove_backup_plural "$DEFUSE_EXECS" "exec line") of a rebase held as a comment, since --continue runs each: read the todo, then restore each you trust: git rebase --edit-todo"
  return 0
}

# .what = does this restore read the version <unit dir>'s manifest names? a refusal is named
restore_unit_version_is_read() {
  local version
  version="$(jq -r '.version' "$1/.grove-backup/meta.json" 2>/dev/null)"
  grove_backup_unit_version_is_read "$version" && return 0
  row "✋ ConstraintError: this unit's manifest is version '${version//[^0-9a-z]/?}'; this restore reads version ${GROVE_BACKUP_UNIT_VERSIONS_READ[*]}"
  row "   └─ a newer agent wrote it: pull this repo, then rerun"
  return 1
}

# 🛑 .what = the ONE door every unit opens through: fetch, unpack, and check it by its kind;
#   sets UNIT_DIR. <kind> is `tree` (a clone or a worktree) or `files` (home, orphan, set-aside)
# .why a unit is untrusted (see grove.backup.operations.sh), and a check on one door is no
#   check where a neighbour door opens the same bucket. a tree unit's manifest and every
#   path it lays are checked; a files unit's every path is checked. a top-level `.git` in a
#   files unit is refused: an orphan lands where the walk reads `.git` as a repo, so a
#   planted config would run on the next pass
# .why each member a lay step reads is admitted here, once: the manifest and refs.txt by
#   their grammar (a ref is an argument to git), and every git dir at any depth laid inert
#   (restore_unit_defuse). a member no step names is never read
# .why no `$(…)`: the rows it adds would die with the subshell
restore_unit_open() {
  local key="$1" class="$2" kind="$3" version rel
  UNIT_DIR=""
  restore_fetch "$key" "$class" "$WORK/obj.tar.gz" || return $?
  UNIT_DIR="$(restore_unpack "$WORK/obj.tar.gz")" || { row "💥 MalfunctionError: the object did not unpack"; return 1; }
  # a files unit's manifest is asked its version too, where it has one: a unit written before
  #   the files manifest existed holds none, and lays as it always did
  if [[ "$kind" == files && -f "$UNIT_DIR/.grove-backup/meta.json" ]]; then
    restore_unit_version_is_read "$UNIT_DIR" || return "$UNIT_REFUSED"
  fi
  # the one admit the writer also asked of this unit before its put (grove_backup_unit_admit)
  if [[ "$kind" == files ]]; then
    grove_backup_unit_admit "$UNIT_DIR" files || { restore_unit_refuse_foreign "$GROVE_BACKUP_UNIT_WHY"; return; }
    restore_unit_defuse "$UNIT_DIR"
    return
  fi
  if [[ ! -f "$UNIT_DIR/.grove-backup/meta.json" ]]; then
    row "✋ ConstraintError: this object holds no tree manifest (.grove-backup/meta.json); it is no tree unit"
    row "   └─ the grove's next pass writes one: rhx grove.backup.get --from $FROM --list"
    return "$UNIT_REFUSED"
  fi
  restore_unit_version_is_read "$UNIT_DIR" || return "$UNIT_REFUSED"
  grove_backup_unit_admit "$UNIT_DIR" tree || { restore_unit_refuse_foreign "$GROVE_BACKUP_UNIT_WHY"; return; }
  restore_unit_defuse "$UNIT_DIR"
}

# .what = refuse a unit that names what no backup writes: one wording, one pointer, for every such cause
# .why no pass of this repo writes such a unit, so the list of what the grove did write is the next read
restore_unit_refuse_foreign() {
  row "✋ ConstraintError: this unit names what no backup writes ($1); naught of it is laid"
  row "   └─ no pass writes such a unit; read who did: rhx grove.backup.get --from $FROM --list"
  return "$UNIT_REFUSED"
}

# .why `== null`, never `// empty`: jq's `//` reads `false` as absent, so `point_in_time: false`
#   would read back as no answer, and its warn would never print
meta() { jq -r --arg f "$2" 'if .[$f] == null then empty else .[$f] end' "$1/.grove-backup/meta.json"; }

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
# rc 0 landed or already there · 1 the name holds another sha · 2 the write failed (named)
land_aside() {
  local live="$1" name="$2" sha="$3" have
  have="$(g "$live" rev-parse -q --verify "refs/heads/$name")"
  if [[ -z "$have" ]]; then
    graft_ref_write "$live" "$name" "$sha" "" && return 0
    return 2
  fi
  [[ "$have" == "$sha" ]] && return 0
  return 1
}

# .what = set refs/heads/<name> to <sha>, only from <old> (empty: only if absent); a failure is named
graft_ref_write() {
  local live="$1" name="$2" sha="$3" old="$4"
  g "$live" update-ref "refs/heads/$name" "$sha" "$old" 2>"$WORK/ref.err" && return 0
  row "💥 MalfunctionError: could not set refs/heads/$name: $(head -n 1 "$WORK/ref.err")"
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
    graft_ref_write "$live" "$name" "$sha" "" || return 1
    [[ "$role" == aside ]] && { row "$pad + $label, kept aside"; return 0; }
    row "$pad + new branch · $(grove_backup_plural "${count:-0}" commit) this clone lacked"
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
    land_aside "$live" "$grove/$name" "$sha"
    case $? in
      0) row "$pad ≠ diverged (live ${have:0:8}, $grove ${sha:0:8}); landed as $grove/$name" ;;
      1) row "$pad ≠ diverged (live ${have:0:8}, $grove ${sha:0:8}); $grove/$name holds another sha, so neither moved"
         GRAFT_NAME="" ;;
      *) return 1 ;;
    esac
    return 0
  fi

  # ahead — fast-forward, unless it is checked out on a dirty tree
  count="$(g "$live" rev-list --count "$have..$sha")"
  wt="$(live_checkout_of "$live" "$name")"
  if [[ -z "$wt" ]]; then
    graft_ref_write "$live" "$name" "$sha" "$have" || return 1
    row "$pad + fast-forward · $(grove_backup_plural "$count" commit)"
    return 0
  fi
  # an untracked file never blocks it: `merge --ff-only` refuses on its own where it would overwrite one
  if [[ -z "$(g "$wt" status --porcelain --untracked-files=no)" ]]; then
    g "$wt" merge --ff-only --quiet "$sha" \
      && { row "$pad + fast-forward · $(grove_backup_plural "$count" commit) · checked out, its tree clean"; return 0; }
  fi
  GRAFT_NAME="$grove/$name"
  land_aside "$live" "$grove/$name" "$sha"
  [[ $? -ge 2 ]] && return 1
  row "$pad ≠ $(grove_backup_plural "$count" commit) ahead, and checked out on a dirty tree; landed as $grove/$name"
  row "   └─ once the tree is clean: git -C $wt merge --ff-only $grove/$name"
  return 0
}

######################################################################
# the tree steps — each a plain git act on a unit dir <u>
######################################################################

# .what = a repo at <dir> that holds what origin holds: a clone of origin, or an
#         empty repo where the unit names no origin (its pack then holds all)
# .why `--template`: the half-lay mark's twin lands inside the git dir at git's first act,
#   so a cut clone holds it, and a clone made by any other hand never does
# .why a failed clone clears its mark with its dir: a mark left beside naught would read, to
#   a later rerun, as license to wipe whatever a human put there next
restore_tree_base() {
  local u="$1" dir="$2" origin tpl
  origin="$(meta "$u" origin)"
  mkdir -p "$(dirname "$dir")" || return 1
  tpl="$(restore_unfinished_template "$dir")" || { row "💥 MalfunctionError: could not make a git template"; return 1; }
  if [[ -z "$origin" ]]; then
    git init -q --template="$tpl" "$dir" && return 0
    row "💥 MalfunctionError: could not make a repo at $dir"
    restore_unfinished_clear "$dir"
    return 1
  fi
  # bounded, with -k: a stalled origin must end in a verdict, never hold the lock
  if ! timeout -k 10 600 env GIT_TERMINAL_PROMPT=0 git -c core.hooksPath=/dev/null clone -q --no-checkout --template="$tpl" -- "$origin" "$dir" 2>"$WORK/clone.err" </dev/null; then
    row "💥 MalfunctionError: origin could not be cloned: $origin"
    # a fresh grove's likeliest cause is its git credential, which a rerun alone never fixes
    if grep -qiE 'authentication|could not read username|permission denied|terminal prompts disabled|403|401' "$WORK/clone.err"; then
      row "   └─ $(head -n 1 "$WORK/clone.err"); this grove's git credential did not answer: from the laptop, rhx git.grove.ready.verify $(restore_this_grove) --from 5, then rerun"
    else
      row "   └─ $(head -n 1 "$WORK/clone.err"); rerun once origin answers"
    fi
    rm -rf "$dir"
    restore_unfinished_clear "$dir"
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
  # the walk stops at each ref this repo already holds, so it reads only the unit's own commits.
  #   a unit leans on origin's default branch and tags; where that moved (a force-push), origin
  #   may still hold the sha under no ref this clone fetched, so it is asked once by name
  while read -r sha ref; do
    g "$dir" rev-list --objects --quiet "$sha" --not --all >/dev/null 2>&1 && continue
    if [[ -n "$(meta "$u" origin)" ]] \
       && timeout -k 10 300 env GIT_TERMINAL_PROMPT=0 git -c safe.directory='*' -c core.hooksPath=/dev/null -C "$dir" fetch -q --end-of-options origin "$sha" </dev/null >/dev/null 2>&1 \
       && g "$dir" rev-list --objects --quiet "$sha" >/dev/null 2>&1; then
      continue
    fi
    row "💥 MalfunctionError: $ref (${sha:0:8}) is not whole here: origin no longer holds what it leans on"
    return 1
  done <"$u/.grove-backup/refs.txt"
}

# .what = the unit's branch and remote config, exclude list, and hooks, into <common dir>
#
# 🛑 .why a unit is untrusted here (see grove.backup.operations.sh, `a unit is UNTRUSTED input`)
#   - only a key AND value grove_backup_config_entry_is_carried allows is set; each other
#     key is named and dropped, so no unit sets a git key that runs a command, nor points
#     origin, a remote, or an upstream anywhere the unit's own origin does not
#   - <mode> `fresh` (the default) is a clone this restore just made: the unit's set
#     replaces each carried key, and its exclude is laid whole. `present` is a clone the
#     human already holds: no key of theirs is cleared or changed, only a key absent here
#     is added, and only an exclude line absent here is appended
#   - a hook is code the next git act would run, so each lands NOT executable, named,
#     with the one command that arms it once a human has read it. a hook this clone
#     already holds is kept as it stands
restore_tree_repo_state() {
  local u="$1" dir="$2" cd="$3" mode="${4:-fresh}" key value hook name origin line
  local rs="$u/.grove-backup/repo" carried="$WORK/config.carried"
  local -a dropped=()
  origin="$(meta "$u" origin)"
  if [[ -s "$rs/config.list" ]]; then
    : >"$carried"
    while read -r key value; do
      grove_backup_config_entry_is_carried "$key" "$value" "$origin" && { printf '%s %s\n' "$key" "$value" >>"$carried"; continue; }
      # printed, so a byte outside a plain key's charset prints as `?`, never raw
      dropped+=("${key//[^A-Za-z0-9._-]/?}")
    done <"$rs/config.list"
    # a live clone: a key it already holds is the human's, kept as it stands
    if [[ "$mode" == present ]]; then
      while read -r key value; do
        [[ -n "$(g "$dir" config --get-all "$key" 2>/dev/null)" ]] && continue
        printf '%s %s\n' "$key" "$value"
      done <"$carried" >"$carried.absent"
      mv "$carried.absent" "$carried"
    fi
    # git exits 5 on an unset of a key that is absent: that is the one silence allowed
    [[ "$mode" == fresh ]] && while read -r key; do
      g "$dir" config --unset-all "$key" 2>"$WORK/unset.err"
      case $? in 0|5) ;; *) row "💥 MalfunctionError: could not clear $key: $(head -n 1 "$WORK/unset.err")"; return 1 ;; esac
    done < <(cut -d' ' -f1 "$carried" | sort -u)
    while read -r key value; do
      g "$dir" config --add "$key" "$value" 2>"$WORK/add.err" && continue
      row "💥 MalfunctionError: could not set $key: $(head -n 1 "$WORK/add.err")"
      return 1
    done <"$carried"
  fi
  [[ "${#dropped[@]}" -gt 0 ]] \
    && row "⚠️ $(grove_backup_plural "${#dropped[@]}" "config key") dropped, since no backup writes it so: ${dropped[*]}"
  if [[ -f "$rs/exclude" && "$mode" == fresh ]]; then
    restore_lay_git_state "$rs" exclude "$cd" info/exclude \
      || { row "💥 MalfunctionError: info/exclude could not be laid"; return 1; }
  elif [[ -f "$rs/exclude" ]]; then
    { mkdir -p "$cd/info" && touch "$cd/info/exclude"; } \
      || { row "💥 MalfunctionError: info/exclude could not be made"; return 1; }
    while IFS= read -r line || [[ -n "$line" ]]; do
      grep -qxF -- "$line" "$cd/info/exclude" && continue
      printf '%s\n' "$line" >>"$cd/info/exclude" \
        || { row "💥 MalfunctionError: info/exclude could not take a line"; return 1; }
    done <"$rs/exclude"
  fi
  for hook in "$rs/hooks"/*; do
    [[ -f "$hook" ]] || continue
    name="${hook##*/}"
    [[ -e "$cd/hooks/$name" ]] && continue
    mkdir -p "$cd/hooks" && install -m 0644 "$hook" "$cd/hooks/$name" \
      || { row "💥 MalfunctionError: could not lay hook $name"; return 1; }
    row "🌙 hook $name laid, NOT executable: read it, then arm it: chmod +x $cd/hooks/$name"
  done
  return 0
}

# .what = how many entries the stash of <dir> holds
restore_stash_entry_count() { g "$1" stash list 2>/dev/null | wc -l | tr -d ' '; }

# .what = the branch name a full ref names: refs/heads/feat-x → feat-x
restore_branch_of_ref() { printf '%s\n' "${1#refs/heads/}"; }

# .what = the stash, with every entry its reflog held
restore_tree_stash() {
  local u="$1" dir="$2" cd="$3" sha have
  sha="$(awk '$2 == "refs/stash" { print $1 }' "$u/.grove-backup/refs.txt")"
  [[ -n "$sha" ]] || return 0
  have="$(g "$dir" rev-parse -q --verify refs/stash)"
  if [[ -z "$have" ]]; then
    g "$dir" update-ref refs/stash "$sha" "" 2>"$WORK/ref.err" \
      || { row "💥 MalfunctionError: could not set refs/stash: $(head -n 1 "$WORK/ref.err")"; return 1; }
    if [[ -f "$u/.grove-backup/checkout/logs/refs/stash" ]]; then
      restore_lay_git_state "$u/.grove-backup/checkout" logs/refs/stash "$cd" logs/refs/stash \
        || { row "💥 MalfunctionError: the stash's reflog could not be laid; its entries past the first are not here"; return 1; }
    fi
    row "+ stash · $(grove_backup_plural "$(restore_stash_entry_count "$dir")" entry entries)"
    return 0
  fi
  [[ "$have" == "$sha" ]] && return 0
  graft_ref "$dir" "$FROM" "$FROM/stash" "$sha" "stash entry, from refs/stash" aside
}

# .what = unstage each index entry whose blob never came; the pack cuts a staged secret
#   (GROVE_BACKUP_SECRET_SHAPES), and an index that names an absent blob breaks every git read
restore_index_drop_uncarried() {
  local wt="$1" entry sha path n=0 absent
  # `--batch-check` answers `<sha> missing` for each blob the store lacks
  absent="$(g "$wt" ls-files -s | awk '{ print $2 }' | g "$wt" cat-file --batch-check | awk '$2 == "missing" { print $1 }')"
  [[ -n "$absent" ]] || return 0
  while IFS= read -r -d '' entry; do
    sha="$(cut -d' ' -f2 <<<"${entry%%$'\t'*}")"
    path="${entry#*$'\t'}"
    grep -qxF -- "$sha" <<<"$absent" || continue
    g "$wt" update-index --force-remove -- "$path" \
      || { row "💥 MalfunctionError: could not unstage $path, whose staged copy was not carried"; return 1; }
    n=$((n + 1))
  done < <(g "$wt" ls-files -s -z)
  row "🌙 $(grove_backup_plural "$n" "staged path") of a secret shape left unstaged; its copy never left the dead grove"
}

# .what = does <rel> under <root> pass through a symlink on its way? then a write or a
#   delete at it would land wherever that link points, outside the tree it names
restore_path_crosses_a_link() {
  local root="$1" dir
  restore_dir_of dir "$2"
  while [[ "$dir" != . && "$dir" != / ]]; do
    [[ -L "$root/$dir" ]] && return 0
    restore_dir_of dir "$dir"
  done
  return 1
}

# .what = set <var> to the dir part of <path>, as `dirname` gives it for a path that ends on
#   its leaf, with no fork
# usage: restore_dir_of <var> <path>
# .why each file a restore lays asks this at every depth of its path: as a `$(dirname …)`
#   subshell, a home unit of ~40k files paid ~15 forks a file, and an 8 GiB `.claude` outran
#   the live proof's 600s bound on the ec2 grove
restore_dir_of() {
  local _path="$2"
  [[ "$_path" == */* ]] || { printf -v "$1" '%s' .; return 0; }
  _path="${_path%/*}"
  printf -v "$1" '%s' "${_path:-/}"
}

# 🛑 .what = the ONE step that writes a unit's file into place: <src root>/<rel> at <dst root>/<rel>
# usage: restore_lay_path <src root> <dst root> <rel>
# rc: 0 laid · 3 refused, a dir on its way at <dst> is a link · 1 a fault
# .why a write through a link lands wherever it points: a link one unit laid (a planted commit,
#   a prior run) would carry the next unit's file out of the tree, into the seat's home. so
#   each lay asks, at the moment it writes, before `mkdir -p` (which follows a link) runs
# .why staged in the leaf's own dir, then renamed: a rename never follows a link at the leaf,
#   and a killed copy leaves a stage file, never a cut file under the final name a rerun keeps.
#   which leaf may be replaced is the caller's rule; this step writes, and guards
restore_lay_path() {
  local src="$1" dst="$2" rel="$3" stage parent
  restore_path_crosses_a_link "$dst" "$rel" && return 3
  restore_dir_of parent "$dst/$rel"
  [[ -d "$parent" ]] || mkdir -p -- "$parent" || return 1
  stage="$parent/.grove-restore.stage.$$.$RANDOM"
  cp -a -- "$src/$rel" "$stage" || { rm -f -- "$stage"; return 1; }
  mv -fT -- "$stage" "$dst/$rel" || { rm -f -- "$stage"; return 1; }
  return 0
}

# 🛑 .what = the ONE step that writes a unit's git state into a git dir: <src root>/<src rel>
#   at <dst root>/<dst rel> — a file or a dir (rebase-merge, logs/refs)
# usage: restore_lay_git_state <src root> <src rel> <dst root> <dst rel>
# rc: 0 laid · 1 a fault, with the prior entry still in place
# .why the copy is HELD before the prior entry goes: a copy that fails (an unreadable source,
#   a full disk) must leave the tree's own HEAD or index where it was, never a git dir with no
#   HEAD that git no longer reads while the row says it landed
restore_lay_git_state() {
  local src="$1" srel="$2" dst="$3" drel="$4" stage aside="" parent
  LAY_WHY=""
  restore_path_crosses_a_link "$dst" "$drel" && return 1
  restore_dir_of parent "$dst/$drel"
  mkdir -p -- "$parent" || return 1
  stage="$parent/.grove-restore.stage.$$.$RANDOM"
  # cp's why rides in LAY_WHY, for the caller's row: raw stderr would break the tree a human reads.
  #   a fork per git-state entry, never per path, so a lay of many files pays it a few times only
  LAY_WHY="$(cp -a -- "$src/$srel" "$stage" 2>&1)" \
    || { LAY_WHY="${LAY_WHY##*: }"; grove_backup_scratch_clear "$stage" >/dev/null; return 1; }
  if [[ -d "$dst/$drel" && ! -L "$dst/$drel" ]]; then
    aside="$parent/.grove-restore.aside.$$.$RANDOM"
    mv -T -- "$dst/$drel" "$aside" || { grove_backup_scratch_clear "$stage" >/dev/null; return 1; }
  fi
  if ! mv -fT -- "$stage" "$dst/$drel"; then
    [[ -z "$aside" ]] || mv -T -- "$aside" "$dst/$drel"
    grove_backup_scratch_clear "$stage" >/dev/null
    return 1
  fi
  [[ -z "$aside" ]] || grove_backup_scratch_clear "$aside" || return 1
  return 0
}

# .what = does <rel> sit beneath any of the dirs that follow it?
restore_path_is_under_any() {
  local rel="$1" d
  shift
  for d in "$@"; do [[ "$rel" == "$d/"* ]] && return 0; done
  return 1
}

# .what = remove each dir above <rel> that a delete left empty, up to <root>
restore_dirs_prune_empty() {
  local root="$1" dir
  restore_dir_of dir "$2"
  while [[ "$dir" != . && "$dir" != / ]]; do
    rmdir -- "$root/$dir" 2>/dev/null || return 0
    restore_dir_of dir "$dir"
  done
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
  for rel in "${GROVE_BACKUP_UNIT_GIT_STATE[@]}" logs/HEAD; do
    [[ -e "$co/$rel" ]] || continue
    restore_lay_git_state "$co" "$rel" "$gd" "$rel" \
      || { row "💥 MalfunctionError: the unit's $rel could not be laid into $gd${LAY_WHY:+ ($LAY_WHY)}; the tree stays marked laid in part"; return 1; }
  done
  restore_index_drop_uncarried "$wt" || return 1

  # the deletes FIRST, on HEAD's own checkout: a dead tree that swapped a tracked dir for a
  #   link holds a delete of each file under that dir, and its link lands only once the dir
  #   is gone. applied after the lay, a delete would reach through the new link
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    restore_path_crosses_a_link "$wt" "$rel" && continue
    rm -f -- "$wt/$rel" && n=$((n + 1))
    restore_dirs_prune_empty "$wt" "$rel"
  done < <(jq -r '.deletes[]' "$u/.grove-backup/meta.json")

  # no file lays through a link HEAD's checkout put down: tar would follow it out of the tree
  while IFS= read -r -d '' rel; do
    restore_path_crosses_a_link "$wt" "${rel#./}" \
      && { row "✋ ConstraintError: ${rel#./} would lay through a link in this checkout; naught more of the unit is laid"; return 1; }
  done < <(cd "$u" && find . -mindepth 1 -path ./.grove-backup -prune -o -print0)

  # the unit's own files — every one differs from HEAD, is untracked, or is ignored and kept
  tar -C "$u" --exclude=./.grove-backup -cf - . | tar -C "$wt" -xf - \
    || { row "💥 MalfunctionError: the unit's files could not be laid at $wt"; return 1; }

  # the laid tree, defused again: HEAD's checkout put down files no unpacked unit held
  restore_unit_defuse "$wt" "$wt/.git" || return 1

  RESTORED_FILES="$( (cd "$u" && find . -path ./.grove-backup -prune -o \( -type f -o -type l \) -print) | wc -l | tr -d ' ')"
  RESTORED_DELETES="$n"
  restore_report_cuts "$u"
  return 0
}

######################################################################
# .what = a unit's files into a PRESENT clone, where that lays over naught of its own
#
# .the rule, per path
#   - on another HEAD, a change has no base: only a path absent AND untracked here
#     lands (a transcript, a new file); each edit and delete is held, and counted
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

# .what = is <rel> tracked in the live clone and unchanged from its HEAD? only then may a unit's copy replace it
restore_path_is_clean_at_head() {
  local live="$1" rel="$2"
  g "$live" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1 && g "$live" diff --quiet HEAD -- "$rel"
}

# .what = is <rel> absent from the live clone and untracked at its HEAD? then a lay clobbers naught
restore_path_is_absent_and_untracked() {
  local live="$1" rel="$2"
  [[ ! -e "$live/$rel" && ! -L "$live/$rel" ]] && ! g "$live" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1
}

# usage: restore_tree_lay_over <unit dir> <live clone> <the command that lays this unit aside>
restore_tree_lay_over() {
  local u="$1" live="$2" aside="$3" rel laid=0 n i held=0 same_head rc
  local -a kept=() dirs_kept=()
  restore_unit_has_layable_content "$u" || return 0

  # on another HEAD, a change has no base here; a file absent and untracked here has none to need
  same_head=1
  [[ "$(g "$live" rev-parse -q --verify HEAD)" == "$(meta "$u" head_sha)" ]] || same_head=0

  # each path, as the rule above says
  while IFS= read -r -d '' rel; do
    rel="${rel#./}"
    # already the same bytes → naught to do, naught to name (a rerun lands here)
    [[ -f "$live/$rel" && ! -L "$live/$rel" ]] && cmp -s "$u/$rel" "$live/$rel" && continue
    # a path whose place here is a dir, or that passes through a link here, lays over
    #   naught: the clone's own dir is never removed, and no write lands through a link
    if [[ -d "$live/$rel" && ! -L "$live/$rel" ]]; then
      dirs_kept+=("$rel")
      if [[ -L "$u/$rel" ]]; then kept+=("$rel (kept: a dir here, the dead tree held a link)"); else kept+=("$rel (kept: a dir here, the dead tree held a file)"); fi
      continue
    fi
    restore_path_crosses_a_link "$live" "$rel" && { kept+=("$rel (kept: its dir here is a link)"); continue; }
    if [[ "$same_head" -eq 0 ]] && ! restore_path_is_absent_and_untracked "$live" "$rel"; then held=$((held + 1)); continue; fi
    if [[ ( -e "$live/$rel" || -L "$live/$rel" ) ]] && ! restore_path_is_clean_at_head "$live" "$rel"; then kept+=("$rel (kept: this clone changed it)"); continue; fi
    restore_lay_path "$u" "$live" "$rel"; rc=$?
    [[ "$rc" -eq 3 ]] && { kept+=("$rel (kept: its dir here is a link)"); continue; }
    [[ "$rc" -eq 0 ]] || { row "💥 MalfunctionError: could not lay $live/$rel"; return 1; }
    laid=$((laid + 1))
  done < <(cd "$u" && find . -path ./.grove-backup -prune -o \( -type f -o -type l \) -print0 | sort -z)
  n=0
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    [[ "$same_head" -eq 0 ]] && { held=$((held + 1)); continue; }
    restore_path_crosses_a_link "$live" "$rel" && continue
    # a delete under a dir kept above is the other half of that swap: the dir stays whole
    restore_path_is_under_any "$rel" "${dirs_kept[@]}" && continue
    if [[ -e "$live/$rel" ]] && restore_path_is_clean_at_head "$live" "$rel"; then rm -f -- "$live/$rel" && n=$((n + 1)); continue; fi
    [[ -e "$live/$rel" ]] && kept+=("$rel (a delete) (kept: this clone changed it)")
  done < <(jq -r '.deletes[]' "$u/.grove-backup/meta.json")

  # `+` says a file landed; with none laid and none deleted the clone stays as it was, so `=`
  local mark="+"; [[ $((laid + n)) -eq 0 ]] && mark="="
  row "$mark $(grove_backup_plural "$laid" file) of the dead checkout laid · $(grove_backup_plural "$n" delete) applied"
  [[ "$held" -gt 0 ]] \
    && row "   ├─ $held held: the dead checkout sat on another HEAD, so its edits and deletes have no base here"
  for i in "${!kept[@]}"; do
    [[ "$i" -ge 8 ]] && { row "   ├─ … and $(( ${#kept[@]} - 8 )) more, each kept as this clone has it"; break; }
    row "   ├─ = ${kept[$i]}"
  done
  [[ "$(jq '.staged | length' "$u/.grove-backup/meta.json")" -gt 0 ]] \
    && row "   ├─ its staged copies are not staged here; this clone's index is its own"
  row "   └─ to read the dead checkout whole, lay it aside: $aside"
  restore_report_cuts "$u"
}

# .what = one summary row for a tree that landed
restore_tree_report() {
  local u="$1" wt="$2" head ahead pit
  head="$(g "$wt" symbolic-ref -q --short HEAD 2>/dev/null)"
  [[ -n "$head" ]] || head="detached at $(g "$wt" rev-parse --short=8 HEAD 2>/dev/null)"
  ahead="$(g "$wt" rev-list --count '@{u}..HEAD' 2>/dev/null)"
  pit="$(meta "$u" point_in_time)"
  [[ -n "$ahead" ]] && row "   ├─ HEAD $head · $(grove_backup_plural "$ahead" commit) not on its upstream" \
                    || row "   ├─ HEAD $head"
  [[ "$pit" == false ]] && row "   ├─ ⚠️ it moved through each pack of its last pass; files may span a few seconds"
  row "   └─ $(grove_backup_plural "${RESTORED_FILES:-0}" file) laid · $(grove_backup_plural "${RESTORED_DELETES:-0}" delete) applied"
}

######################################################################
# the lay sentinel — a tree laid at an absent target is whole, or it is laid again
#
# .why a lay is many git acts (clone, index, refs, checkout). a cut between any two
#   — ENOSPC, ctrl-c, a stalled origin — leaves a target that LOOKS present: a rerun
#   would graft into a clone with no checkout, or keep a worktree with no files, and
#   call either landed. so `<target>.grove-restore.unfinished` is written before the
#   first act and removed after the last; a rerun that finds it wipes the target
#   and lays it again. only this skill writes the sentinel, so only its own half-lay
#   is ever wiped
######################################################################
restore_unfinished_path()  { printf '%s%s\n' "$1" "$GROVE_BACKUP_RESTORE_UNFINISHED_SUFFIX"; }
# the mark carries a nonce, so a twin inside a target matches this one restore and no other
restore_unfinished_set() {
  mkdir -p "$(dirname "$1")" \
    && printf '%s %s\n' "$2" "$(od -An -N8 -tx8 /dev/urandom | tr -d ' ')" >"$(restore_unfinished_path "$1")"
}
# .what = the twin, inside <target>'s git dir, once that dir exists (a worktree's link)
restore_unfinished_mark_inside() {
  local beside inner
  beside="$(restore_unfinished_path "$1")"
  [[ -f "$beside" ]] || return 0
  inner="$(grove_backup_restore_inner_mark_path "$1")" && cp -- "$beside" "$inner"
}
# .what = a git template that lays the twin at git's first act, for a clone or an init
#   at <target>; prints the template dir
restore_unfinished_template() {
  local tpl
  tpl="$(mktemp -d "$WORK/template.XXXXXX")" || return 1
  [[ -f "$(restore_unfinished_path "$1")" ]] && cp -- "$(restore_unfinished_path "$1")" "$tpl/$GROVE_BACKUP_RESTORE_UNFINISHED_MARK"
  printf '%s\n' "$tpl"
}
restore_unfinished_clear() {
  local inner
  inner="$(grove_backup_restore_inner_mark_path "$1" 2>/dev/null)" && rm -f -- "$inner"
  rm -f -- "$(restore_unfinished_path "$1")"
}

# .what = wipe a target a prior restore left half-laid; rc 0 = naught to wipe, or wiped
# 🛑 .why only a target that holds the twin of the mark beside it is wiped: a mark whose
#   target is gone, or replaced by a clone a human made, is cleared, and that tree is kept
# usage: restore_unfinished_wipe <target> [<live clone it links into>]
restore_unfinished_wipe() {
  local target="$1" live="${2:-}"
  if grove_backup_restore_mark_is_stale "$target"; then
    rm -f -- "$(restore_unfinished_path "$target")"
    row "⚠️ a cut restore's mark sat beside $target, which that restore did not lay; the mark is cleared, and $target is kept as it stands"
    return 0
  fi
  grove_backup_restore_is_unfinished "$target" || return 0
  [[ -n "$live" && -d "$live/.git" ]] && g "$live" worktree remove --force "$target" >/dev/null 2>&1
  rm -rf -- "$target" || { row "💥 MalfunctionError: could not wipe the half-laid $target"; return 1; }
  [[ -n "$live" && -d "$live/.git" ]] && g "$live" worktree prune
  restore_unfinished_clear "$target"
  row "↻ a prior restore was cut as it laid $target; laid again from the start"
}

######################################################################
# one unit, by kind
######################################################################

# .what = a clone — whole at an absent target; grafted into a present one
restore_clone() {
  local unit="$1" key="$2" class="$3" target u sha ref rc org repo
  org="$(grove_backup_unit_field "$unit" org)"
  repo="$(grove_backup_unit_field "$unit" repo)"
  target="${INTO:-$HOME/git/$org/$repo}"
  restore_unfinished_wipe "$target" || return 1

  if [[ -n "$INTO" && -e "$target" ]]; then
    row "✋ ConstraintError: $target is present; --into lays a unit only where naught is"
    return "$UNIT_REFUSED"
  fi
  if [[ -e "$target" && ! -d "$target/.git" ]]; then
    row "✋ ConstraintError: $target is present and is no clone; it is left as it stands"
    row "   └─ lay the unit aside instead: --into <dir>"
    return "$UNIT_REFUSED"
  fi

  restore_unit_open "$key" "$class" tree; rc=$?
  [[ "$rc" -eq 0 ]] || return "$rc"
  u="$UNIT_DIR"

  # present — a graft of refs, never a file touched
  if [[ -e "$target" ]]; then
    row "⇄ graft into $target (each file it changed is kept)"
    restore_tree_objects "$u" "$target" || return 1
    while read -r sha ref; do
      [[ "$ref" == refs/heads/* ]] || continue
      graft_ref "$target" "$FROM" "$(restore_branch_of_ref "$ref")" "$sha" "" branch || return 1
    done <"$u/.grove-backup/refs.txt"
    restore_tree_stash "$u" "$target" "$target/.git" || return 1
    restore_tree_lay_over "$u" "$target" "rhx grove.backup.restore --from $FROM --of $org/$repo --tree $repo --into <dir>" || return 1
    return "$UNIT_LANDED"
  fi

  # absent — origin, plus the unit; unfinished until its last act lands
  restore_unfinished_set "$target" "$key" || { row "💥 MalfunctionError: could not mark $target as laid in part"; return 1; }
  restore_tree_base "$u" "$target" || return 1
  restore_tree_objects "$u" "$target" || return 1
  while read -r sha ref; do
    [[ "$ref" == refs/heads/* || "$ref" == refs/tags/* ]] || continue
    g "$target" update-ref "$ref" "$sha" || { row "💥 MalfunctionError: could not set $ref here"; return 1; }
  done <"$u/.grove-backup/refs.txt"
  if [[ -d "$u/.grove-backup/checkout/logs/refs" ]]; then
    restore_lay_git_state "$u/.grove-backup/checkout" logs/refs "$target/.git" logs/refs \
      || { row "💥 MalfunctionError: the reflogs could not be laid into $target/.git"; return 1; }
  fi
  restore_tree_repo_state "$u" "$target" "$target/.git" || return 1
  restore_tree_stash "$u" "$target" "$target/.git" || return 1
  restore_tree_checkout "$u" "$target" "$target/.git" || return 1
  restore_unfinished_clear "$target"
  [[ -n "$(meta "$u" origin)" ]] && row "+ laid at $target, from origin and its own unit" \
                                 || row "+ laid at $target, whole from its own unit (it has no origin)"
  restore_tree_report "$u" "$target"
  return 0
}

# .what = link the worktree dir into its live clone, on its branch — grafted, so a
#   diverged live branch is never moved — or detached at its HEAD when it had no branch
restore_worktree_link() {
  local u="$1" live="$2" cd="$3" target="$4" head_branch="$5" head_sha="$6" branch

  # detached — no branch to graft; the tree sits at its own HEAD
  if [[ -z "$head_branch" ]]; then
    g "$live" worktree add -q --no-checkout --detach -- "$target" "$head_sha" 2>"$WORK/wt.err" \
      || { row "💥 MalfunctionError: git worktree add refused $target: $(head -n 1 "$WORK/wt.err")"; return 1; }
    restore_unfinished_mark_inside "$target" || { row "💥 MalfunctionError: could not mark $target as laid in part"; return 1; }
    return 0
  fi

  graft_ref "$live" "$FROM" "$head_branch" "$head_sha" "" branch || return 1
  branch="$GRAFT_NAME"
  # the worktree takes a branch that sits at its own HEAD and is checked out nowhere else
  if ! restore_branch_is_free_at "$live" "$branch" "$head_sha"; then
    # name the one cause that holds: a branch already equal is busy, never different
    local busy_why="differs from this tree's HEAD"
    [[ "$(g "$live" rev-parse -q --verify "refs/heads/$branch")" == "$head_sha" ]] \
      && busy_why="is checked out in another worktree"
    branch="$FROM/$head_branch"
    land_aside "$live" "$branch" "$head_sha" \
      || { row "💥 MalfunctionError: neither $head_branch nor $branch is free to check out here"; return 1; }
    row "⇄ the live $head_branch $busy_why; this worktree takes $branch"
  fi
  g "$live" worktree add -q --no-checkout -- "$target" "$branch" 2>"$WORK/wt.err" \
    || { row "💥 MalfunctionError: git worktree add refused $target: $(head -n 1 "$WORK/wt.err")"; return 1; }
  restore_unfinished_mark_inside "$target" || { row "💥 MalfunctionError: could not mark $target as laid in part"; return 1; }
  if [[ -f "$u/.grove-backup/checkout/HEAD" ]]; then
    printf 'ref: refs/heads/%s\n' "$branch" >"$u/.grove-backup/checkout/HEAD" \
      || { row "💥 MalfunctionError: the unit's HEAD could not be pointed at $branch"; return 1; }
  fi
  if [[ -f "$u/.grove-backup/checkout/logs/refs/heads/$head_branch" && ! -e "$cd/logs/refs/heads/$branch" ]]; then
    restore_lay_git_state "$u/.grove-backup/checkout" "logs/refs/heads/$head_branch" "$cd" "logs/refs/heads/$branch" \
      || { row "💥 MalfunctionError: the reflog of $branch could not be laid"; return 1; }
  fi
  return 0
}

# .what = a worktree — linked into its clone, which comes from origin if absent
restore_worktree() {
  local unit="$1" key="$2" class="$3" org repo tree target live u rc head_ref head_sha head_branch branch gd cd live_mode
  org="$(grove_backup_unit_field "$unit" org)"
  repo="$(grove_backup_unit_field "$unit" repo)"
  tree="$(grove_backup_unit_field "$unit" tree)"
  live="$HOME/git/$org/$repo"
  target="${INTO:-$HOME/git/$org/_worktrees/$tree}"
  restore_unfinished_wipe "$target" "$live" || return 1
  restore_unfinished_wipe "$live" || return 1

  if [[ -e "$target" ]]; then
    [[ "$ALL" -eq 1 ]] && { row "= already here; kept as it stands"; return "$UNIT_KEPT"; }
    row "✋ ConstraintError: $target is present; a restore never lays over it"
    row "   └─ lay it aside instead: rhx grove.backup.restore --from $FROM --of $org/$repo --tree $tree --into <dir>"
    return "$UNIT_REFUSED"
  fi

  restore_unit_open "$key" "$class" tree; rc=$?
  [[ "$rc" -eq 0 ]] || return "$rc"
  u="$UNIT_DIR"
  head_ref="$(meta "$u" head_ref)"
  head_sha="$(meta "$u" head_sha)"
  head_branch="$(restore_branch_of_ref "$head_ref")"

  # --into: the worktree lands as a clone of its own, whole
  if [[ -n "$INTO" ]]; then
    restore_unfinished_set "$target" "$key" || { row "💥 MalfunctionError: could not mark $target as laid in part"; return 1; }
    restore_tree_base "$u" "$target" || return 1
    restore_tree_objects "$u" "$target" || return 1
    if [[ -n "$head_ref" && -n "$head_sha" ]]; then
      g "$target" update-ref "$head_ref" "$head_sha" || { row "💥 MalfunctionError: could not set $head_ref here"; return 1; }
    fi
    restore_tree_repo_state "$u" "$target" "$target/.git" || return 1
    restore_tree_stash "$u" "$target" "$target/.git" || return 1
    restore_tree_checkout "$u" "$target" "$target/.git" || return 1
    restore_unfinished_clear "$target"
    row "+ laid aside at $target, a clone of its own"
    restore_tree_report "$u" "$target"
    return 0
  fi

  # the clone it links into — from origin, when this box has none. a clone already here is
  #   the human's own: its config and exclude are kept, and only an absent key is added
  live_mode=present
  if [[ ! -d "$live/.git" ]]; then
    live_mode=fresh
    if [[ -e "$live" ]]; then
      row "✋ ConstraintError: $live is present and is no clone; its worktree cannot link into it"
      return "$UNIT_REFUSED"
    fi
    restore_unfinished_set "$live" "$key" || { row "💥 MalfunctionError: could not mark $live as laid in part"; return 1; }
    restore_tree_base "$u" "$live" || return 1
    if [[ -n "$(meta "$u" origin)" ]]; then
      g "$live" checkout -q 2>"$WORK/live.err" \
        || { row "💥 MalfunctionError: its clone $live could not check out origin's HEAD: $(head -n 1 "$WORK/live.err")"; return 1; }
    fi
    restore_unfinished_clear "$live"
    row "+ its clone $live, from origin"
  fi
  cd="$live/.git"
  restore_tree_objects "$u" "$live" || return 1
  restore_tree_repo_state "$u" "$live" "$cd" "$live_mode" || return 1
  restore_tree_stash "$u" "$live" "$cd" || return 1

  restore_unfinished_set "$target" "$key" || { row "💥 MalfunctionError: could not mark $target as laid in part"; return 1; }
  restore_worktree_link "$u" "$live" "$cd" "$target" "$head_branch" "$head_sha" || return 1
  gd="$(g "$target" rev-parse --absolute-git-dir)"
  restore_tree_checkout "$u" "$target" "$gd" || return 1
  restore_unfinished_clear "$target"
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
# usage: restore_top_group <var> <rel> — set into <var>, so a lay of ~40k files forks none
restore_top_group() {
  local _rel="$2" _top="${2%%/*}"
  [[ "$_top" == "$_rel" ]] && { printf -v "$1" '%s' "$_rel"; return 0; }
  printf -v "$1" '%s/…' "$_top"
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
    "a restore writes only its own seat's home; become that seat and rerun (from ground: sudo -iu $(grove_backup_unit_field "$other" user))"
  echo "✋ ConstraintError: no backup of ${unit#user=*/} under grove=$FROM" >&2
  echo "   └─ the units this seat holds there" >&2
  # each unit a child branch under its label, the last one closed; none held reads as such
  awk -F'\t' -v me="user=$ME/" '
    index($1, me) == 1 { sub(/^user=[^\/]*\//, "", $1); u[n++] = $1 }
    END {
      if (n == 0) { print "      └─ (none)"; exit }
      for (i = 0; i < n; i++) print "      " (i == n - 1 ? "└─ " : "├─ ") u[i]
    }' "$WORK/latest" >&2
  exit 2
}

######################################################################
# .what = lay a unit of plain files (a home dir, an orphan, a set-aside): each absent file
#   lands, each present one is kept, and none lays through a link (restore_lay_path)
# .why the scope excludes are skipped and named on the way in, by the ONE list the pack cuts
#   by: a planted unit's `.credentials.json` would land where none sits before a login, and
#   the first brain to start would send its prompts to that account
######################################################################
restore_files() {
  local unit="$1" key="$2" class="$3" hd target src rel top laid=0 keyrack=0 i rc ex
  local -a kept=() scoped=() scoped_hit=()
  local -A groups=()
  hd="$(grove_backup_unit_field "$unit" home)"
  target="${INTO:-$(restore_files_target "$unit")}"
  mapfile -t scoped < <(grove_backup_scope_excludes_in "$HOME" "$(restore_files_target "$unit")")

  restore_unit_open "$key" "$class" files; rc=$?
  [[ "$rc" -eq 0 ]] || return "$rc"
  src="$UNIT_DIR"

  while IFS= read -r -d '' rel; do
    rel="${rel#./}"
    # the unit's own manifest, never a file of the home
    [[ "$rel" == .grove-backup/* ]] && continue
    if [[ "$hd" == .rhachet && "$rel" == keyrack/* ]]; then keyrack=1; continue; fi
    for ex in "${scoped[@]}"; do [[ "$rel" == "$ex" || "$rel" == "$ex"/* ]] && { scoped_hit+=("$rel"); continue 2; }; done
    if [[ -e "$target/$rel" || -L "$target/$rel" ]]; then kept+=("$rel (kept: this box's copy)"); continue; fi
    restore_lay_path "$src" "$target" "$rel"; rc=$?
    [[ "$rc" -eq 3 ]] && { kept+=("$rel (kept: its dir here is a link)"); continue; }
    [[ "$rc" -eq 0 ]] || { row "💥 MalfunctionError: could not lay $target/$rel"; return 1; }
    laid=$((laid + 1))
    restore_top_group top "$rel"
    groups[$top]=$(( ${groups[$top]:-0} + 1 ))
  done < <(cd "$src" && find . -mindepth 1 \( -type f -o -type l \) -print0 | sort -z)

  [[ "$laid" -gt 0 ]] && row "into $target"
  for top in $(printf '%s\n' "${!groups[@]}" | sort); do
    # a lone file names itself; a dir group always carries its count, one file or many
    [[ "$top" != */… ]] && { row "+ $top"; continue; }
    row "+ $top ($(grove_backup_plural "${groups[$top]}" file))"
  done
  for i in "${!kept[@]}"; do
    [[ "$i" -ge 8 ]] && { row "= … and $(( ${#kept[@]} - 8 )) more, each kept as this box has it"; break; }
    row "= ${kept[$i]}"
  done
  for rel in "${scoped_hit[@]}"; do
    row "🌙 $rel not laid: a backup never carries it, so this unit's copy is no backup's; place this box's own"
  done
  [[ "$laid" -eq 0 && "${#kept[@]}" -eq 0 ]] && row "= the backup held no file to lay"
  restore_report_cuts "$src"

  [[ "$hd" == .claude ]] \
    && row "🌙 the brain login never left $FROM; log in here: rhx brains.auth.set"
  # the row names no death: a rebuild may keep the dead grove's name, and a walk may restore
  #   a live grove's own backup aside, so only "the box that wrote it" holds in every case
  [[ "$keyrack" -eq 1 ]] \
    && row "🌙 keyrack/ not laid: it is sealed to the host key of the box that wrote it; to place this grove's own, from the laptop: rhx git.grove.auth.keys.set $(restore_this_grove) --mode apply"
  # a resume that finds each file already here lays naught, and says so in the tally
  [[ "$laid" -eq 0 ]] && return "$UNIT_KEPT"
  return "$UNIT_LANDED"
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
  # in main, never at source time: a play that sources this file calls main with its own args
  if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then help; return 0; fi
  # a run prints only the rows it gathered: a caller that sourced this file and drove one step
  #   by hand may have left rows behind, and the first unit would print them as its own
  ROWS=()
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
  [[ -z "$HOME_ARG" ]] || grove_backup_home_is_in_scope "$HOME_ARG" \
    || constraint "--home takes one of the backed-up home dirs: .claude · .rhachet" "a clone or worktree takes --of and --tree"
  [[ "$ALL" -eq 1 && -n "$INTO" ]] && constraint "--into lays ONE unit aside; it does not combine with --all" "drop --into, or name one unit in place of --all"
  if [[ -n "$INTO" ]]; then INTO="$(realpath -m "$INTO")"; fi
  ask="$(restore_ask_render)"

  ME="$(id -un)"

  # one restore per seat
  mkdir -p "$HOME/.cache/grove-backup"
  exec 8>"$HOME/.cache/grove-backup/restore.lock"
  flock -n 8 || constraint "a restore is active on this seat" "let it finish, then rerun this one"

  # the disk — a restore never fills the disk it lays onto; each unit asks again, of its own size
  grove_backup_disk_fits "$HOME" 0 \
    || constraint "no room to lay a restore: $GROVE_BACKUP_DISK_WHY" "free space on the disk that holds $HOME, then rerun"

  # the reach — a restore that cannot read lays naught
  grove_backup_reach_check no || restore_reach_refuse

  # an unmade scratch dir would root every path below at /, so it halts here
  WORK="$(mktemp -d "$HOME/.cache/grove-backup/restore.XXXXXX")" && [[ -d "$WORK" ]] || {
    echo "💥 MalfunctionError: could not make a scratch dir under $HOME/.cache/grove-backup" >&2
    echo "   └─ check its disk and permissions: df -h \"$HOME\"" >&2
    exit 1; }
  # a unit may hold a dir that denies its owner write: the clear lifts that first, and names a survivor
  trap 'grove_backup_scratch_clear "$WORK"' EXIT

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
    mapfile -t targets < <(grove_backup_units_in_lay_order "$WORK/latest" "$ME")
    if [[ "${#targets[@]}" -eq 0 ]]; then
      constraint "grove=$FROM holds no unit of seat $ME" \
        "a restore writes only its own seat's home; it holds $(cut -f1 "$WORK/latest" | sed 's#/.*##; s#^user=##' | sort -u | paste -sd, | sed 's#,#, #g'), so become that seat and rerun (from ground: sudo -iu <seat>)"
    fi
  fi

  # one named unit: its id from the flags, then held under --from or refused
  if [[ "$ALL" -ne 1 ]]; then
    unit="$(restore_unit_of_args)"
    grove_backup_unit_is_valid "$unit" \
      || constraint "that names no unit a backup writes: each name is plain, never . or .., never _worktrees or _setaside" \
           "see what $FROM holds: rhx grove.backup.get --from $FROM --list"
    restore_unit_assert_held "$unit"
    targets=("$unit")
  fi

  # each unit; one that fails does not stop the rest
  echo "🐢 lets carry $FROM's work home..."
  echo ""
  echo "🗄️ grove.backup.restore $ask"
  local day outcome
  local -A tally=([landed]=0 [kept]=0 [waits]=0 [refused]=0 [failed]=0)
  for unit in "${targets[@]}"; do
    key="$(grove_backup_units_latest_field "$WORK/latest" "$unit" key)"
    class="$(grove_backup_units_latest_field "$WORK/latest" "$unit" class)"
    day="$(grove_backup_key_day "$key")"
    # printed from a key any box may have written, so a byte outside a key's charset prints as `?`
    echo "   ├─ $(grove_backup_unit_without_seat "$unit" | tr -c '[:alnum:]._@+=/-' '?') · ${day//[^0-9-]/?} · ${class//[^A-Z_]/?}"
    if ! grove_backup_unit_is_valid "$unit"; then
      # a pass never writes such a key, so naught of it is laid: a box other than $FROM put it
      restore_unit_refuse_foreign "its id is outside every shape a backup writes"; rc=$?
    else
      case "$(grove_backup_unit_kind "$unit")" in
        clone)    restore_clone "$unit" "$key" "$class" ;;
        worktree) restore_worktree "$unit" "$key" "$class" ;;
        home|orphan|setaside) restore_files "$unit" "$key" "$class" ;;
      esac
      rc=$?
    fi
    rows_flush
    grove_backup_scratch_clear "$WORK"/unit.* "$WORK/obj.tar.gz"
    outcome="$(restore_outcome_of_rc "$rc")"
    tally[$outcome]=$(( tally[$outcome] + 1 ))
  done

  echo "   └─ $(grove_backup_plural "${#targets[@]}" unit) · ${tally[landed]} restored · ${tally[kept]} already here · ${tally[waits]} await a thaw · ${tally[refused]} refused · ${tally[failed]} failed"
  [[ "${tally[failed]}" -gt 0 ]] && return 1
  [[ "${tally[refused]}" -gt 0 ]] && return 2
  return 0
}

# run only when executed — a play sources this file and calls restore_main itself
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  restore_main "$@"
  exit $?
fi
