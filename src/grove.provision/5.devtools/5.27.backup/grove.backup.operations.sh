#!/usr/bin/env bash
######################################################################
# .what = the grove backup's shared operations — one library, four callers
#
# .who reads it
#   - the agent, `grove-backup`, run as camper by `grove-backup.service`
#   - `rhx grove.backup.get` and `rhx grove.backup.restore`, run by a seat
#   - the plays that prove the reach order and the round trip
#
# .why every box fact is a FUNCTION
#   - a play redefines it to point at a fixture, so the logic is driven with
#     no root, no /etc write, and no runtime override a human could set by
#     accident (the shape `grove_env_platform_file` set)
#   - the s3 calls are the same kind of seam: a play swaps them for a local
#     dir, and every tar, hash, and git step above them runs for real
#
# .why it is SOURCED, never run
#   - it declares; it acts on naught until a caller asks
#   - it sets no shell option, so a caller's `set -e` or `nullglob` holds
#
# 🛑 .what it never holds
#   - the bucket name. this repo is public; the name is read from the box,
#     where infra declares it from its one source (`CAMP_GROVE_BUCKET_NAME`)
#   - the grove name. same channel, same reason: a guessed name would let
#     two groves overwrite each other's prefix
######################################################################

######################################################################
# the scope — what a backup carries, and what it must never carry
#
# 🛑 these two lists are CLAMPED to their one source, infra's
#   `GROVE_BACKUP_SCOPE` (`provision/aws.infra/account=camp/grove/groveBackupScope.ts`),
#   by `prove.grove-backup-scope-matches-infra`. an edit here that infra did not
#   make first turns that play red
#
# .why the excludes are PLAINTEXT credentials only
#   - every grove's role reads the bucket, so a plaintext key put there is a key
#     every grove holds. the owner re-fills them after a restore
#   - the keyrack's age-sealed vaults ride along: no private key sits under them
######################################################################
GROVE_BACKUP_SCOPE_DIRS=('~/git' '~/.claude' '~/.rhachet')
GROVE_BACKUP_SCOPE_EXCLUDE=('~/.claude/.credentials.json' '~/.rhachet/keyrack/vault/os.direct/')

# .what = names git ignores, never source, that a clone rebuilds on demand
# .why only where git IGNORES them: a tracked dir named `build` is source, and its
#   uncommitted edits must ride along (inventory b17)
# .why one list, read by ONE function (grove_backup_tree_rebuilt_dirs): the pack cuts
#   these dirs and the change checks prune them, so a rebuild never repacks a tree
GROVE_BACKUP_REBUILT_DIRS=(node_modules dist build out coverage .next .nuxt .turbo .parcel-cache .cache
                           .venv venv __pycache__ .pytest_cache .mypy_cache .tox target .gradle .terraform)

# .what = the basename shapes of a plaintext credential, cut from EVERY unit at any depth
# .why a tree unit carries its ignored and untracked files whole, and every grove's role
#   reads the bucket. a grove's trees hold `.env`, `.env.*`, `*.pem`, `*.key`, and `.npmrc`
#   files (measured 2026-11-20). the owner re-derives each through keyrack after a restore
# .note a template edit (`.env.example`) is cut too: the shape cannot tell it from a secret.
#   each cut path is recorded in the unit's manifest, and the restore names it
GROVE_BACKUP_SECRET_SHAPES=(.env '.env.*' .envrc '*.pem' '*.key' '*.p12' '*.pfx' .npmrc .pypirc .netrc .pgpass
                            .git-credentials .dockercfg .credentials.json credentials '*.tfvars' '*.tfstate'
                            '*.tfstate.backup' 'id_rsa*' 'id_ed25519*' 'id_ecdsa*')

# .what = the content of a plaintext credential, whatever its name: a private key, or a
#   token whose prefix its issuer fixed. a file that holds one is cut as a shape is
# .why a name is a guess at content; a key pasted into `notes.txt` rides by name alone
# .note a `.jsonl` transcript is never scanned: a cut would drop a whole conversation,
#   the very work the wish keeps. that residual is named in the vision's b18
GROVE_BACKUP_SECRET_CONTENT='-----BEGIN ([A-Z]+ )?PRIVATE KEY-----|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{60,}|gh[osu]_[A-Za-z0-9]{36}|AKIA[0-9A-Z]{16}|sk-ant-[A-Za-z0-9_-]{20,}|xox[abpr]-[A-Za-z0-9-]{10,}'

# .what = the free space a stage or a lay must leave on its disk, after its own bytes
# .why the stage sits on the disk the clones live on; a full disk breaks every clone,
#   which costs far more than one unit that waits a pass
# .why a SIZE and never a percent: the guard asks whether THIS unit's bytes fit, so a
#   quiet unit, which stages naught, is never refused — and a 90%-used disk with 200 GiB
#   free stages as it should. the near-full disk is exactly where a pass must go on
GROVE_BACKUP_DISK_FLOOR_KB=$((2 * 1024 * 1024))

# .what = may <need kb> more land on the disk that holds <dir>, and still leave the floor?
# rc 0 = yes · 1 = no (GROVE_BACKUP_DISK_WHY)
grove_backup_disk_fits() {
  local dir="$1" need="${2:-0}" avail
  avail="$(df -Pk "$dir" 2>/dev/null | awk 'NR == 2 { print $4 }')"
  if [[ -z "$avail" ]]; then GROVE_BACKUP_DISK_WHY="df could not read the disk of $dir"; return 1; fi
  (( avail - need >= GROVE_BACKUP_DISK_FLOOR_KB )) && return 0
  GROVE_BACKUP_DISK_WHY="$((avail / 1024)) MiB free; this needs $((need / 1024)) MiB and keeps $((GROVE_BACKUP_DISK_FLOOR_KB / 1024)) MiB free"
  return 1
}

# .what = the kb a unit's files hold: <path>, and the NUL-separated list of paths under it in <list>
grove_backup_files_kb() {
  local path="$1" list="$2"
  [[ -s "$list" ]] || { printf '0'; return 0; }
  (cd "$path" && du -ck --files0-from="$list" 2>/dev/null) | tail -n 1 | cut -f1
}

# .what = the tree unit format: its version, and the git dir entries its checkout carries
# .why declared ONCE, here: the pack writes them and grove.backup.restore reads them,
#   and both source this file — so the writer and the reader can never drift apart
GROVE_BACKUP_UNIT_VERSION=2
GROVE_BACKUP_UNIT_GIT_STATE=(HEAD index ORIG_HEAD MERGE_HEAD MERGE_MSG CHERRY_PICK_HEAD rebase-merge rebase-apply)

# 🛑 .what = every unit version this restore reads — the version a pass writes, and each before it
# .why an object never expires, and a dead grove's agent can never be upgraded: the objects
#   it wrote are all a restore will ever get. so a version bump ADDS a version here and keeps
#   every prior reader, and each version holds a golden object the round trip restores
#   (`prove.grove-backup-round-trip.golden/`) — a reader that drops one turns that play red
GROVE_BACKUP_UNIT_VERSIONS_READ=(2)

# .what = one hash of every rule that decides what a pack carries: the unit version, the
#   scope excludes, the rebuilt dirs, and both credential cuts
# 🛑 .why the mark holds it: a quiet unit is never packed again, so a widened cut list would
#   reach only the units that change, and every quiet tree would keep, as its latest object,
#   the file the new rule cuts. a mark made under other rules is no quiet mark, so each unit
#   packs once under the new rules; one whose bytes did not change is put no more
# 🛑 .why the code is hashed as this FILE's text: every rule a pack or its admit leans on lives
#   here, and a member chosen by name or prefix is a proxy that is too wide on one side (a
#   glyph edit) and too narrow on the other (an admit edit leaves each quiet unit ✓ on an
#   object the restore now refuses). an edit here repacks each unit once: idle cpu, where a
#   missed repack keeps a cut file on every quiet unit. it fails toward the repack
# .why the lists' live values ride beside the text: a caller that widens one at run time (a
#   play, or the agent) is a new rule too
GROVE_BACKUP_LIB_FILE="$(realpath -- "${BASH_SOURCE[0]}")"
grove_backup_pack_rules_digest() {
  {
    cat -- "$GROVE_BACKUP_LIB_FILE" || return 1
    printf '%s\0' -- "$GROVE_BACKUP_UNIT_VERSION" "${GROVE_BACKUP_SCOPE_EXCLUDE[@]}" -- "${GROVE_BACKUP_REBUILT_DIRS[@]}" \
      -- "${GROVE_BACKUP_SECRET_SHAPES[@]}" -- "$GROVE_BACKUP_SECRET_CONTENT" -- "${GROVE_BACKUP_UNIT_GIT_STATE[@]}" --
  } | sha256sum | cut -c1-16
}

# .what = does this restore read unit version <v>? rc 0 = yes
grove_backup_unit_version_is_read() {
  local v
  for v in "${GROVE_BACKUP_UNIT_VERSIONS_READ[@]}"; do [[ "$1" == "$v" ]] && return 0; done
  return 1
}

# .what = the suffix a restore writes beside a target it lays, until its last act lands
# .why declared here: the restore writes it, and the walk skips a target that bears it,
#   so a pass never backs up a half-laid tree as if it were whole
GROVE_BACKUP_RESTORE_UNFINISHED_SUFFIX=.grove-restore.unfinished
GROVE_BACKUP_RESTORE_UNFINISHED_MARK=grove-restore.unfinished

######################################################################
# 🛑 a unit is UNTRUSTED input
#
# .why every grove's role may write every grove's prefix (infra's grant, F8), so a key
#   or a manifest in the bucket may come from any box, a hostile one included. a restore
#   validates what a unit names before it lays one byte: its id, every field of it, and
#   each repo config key, so no unit can lay outside `~/git` or `~/<scope dir>`, or set a
#   git key that runs a command
######################################################################

# a unit id field: a plain name, never `.` or `..`, never one of the walk's own dirs
GROVE_BACKUP_UNIT_FIELD_PATTERN='^[A-Za-z0-9._@+-]+$'

# .what = is <value> safe as one path segment of a unit's target? rc 0 = yes
grove_backup_unit_field_is_valid() {
  [[ "$1" =~ $GROVE_BACKUP_UNIT_FIELD_PATTERN ]] || return 1
  [[ "$1" != . && "$1" != .. && "$1" != _worktrees && "$1" != _setaside ]]
}

# .what = is <name> a home dir the backup holds (`~/git` rides as trees, never as home)?
grove_backup_home_is_in_scope() {
  local name="$1" d
  [[ "$name" != git ]] || return 1
  for d in "${GROVE_BACKUP_SCOPE_DIRS[@]}"; do [[ "${d#\~/}" == "$name" ]] && return 0; done
  return 1
}

# .what = is <unit> one of the four shapes a pass writes, each field plain? rc 0 = yes
grove_backup_unit_is_valid() {
  local unit="$1" seg
  local -a segs
  [[ "$unit" =~ ^user=[^/]+/home=[^/]+$ \
     || "$unit" =~ ^user=[^/]+/org=[^/]+/orphan=[^/]+$ \
     || "$unit" =~ ^user=[^/]+/org=[^/]+/repo=[^/]+/setaside=[^/]+$ \
     || "$unit" =~ ^user=[^/]+/org=[^/]+/repo=[^/]+/tree=[^/]+$ ]] || return 1
  IFS=/ read -r -a segs <<<"$unit"
  for seg in "${segs[@]}"; do grove_backup_unit_field_is_valid "${seg#*=}" || return 1; done
  [[ "$unit" == */home=* ]] && { grove_backup_home_is_in_scope "${unit##*/home=}" || return 1; }
  return 0
}

# .what = may a repo config key ride in a unit, and be set by a restore? rc 0 = yes
# .why only the upstream and remote facts a clone needs. a key such as `core.sshCommand`,
#   `core.fsmonitor`, `alias.*`, or `remote.*.uploadpack` runs a command on the next git
#   act, so the pack never writes one and the restore never sets one. `remote.*.push` is
#   not carried: a `+` refspec there turns the human's next push into a force-push
grove_backup_config_key_is_carried() {
  local key="${1,,}"
  [[ "$key" =~ ^branch\..+\.(remote|merge|pushremote|rebase|description)$ ]] && return 0
  [[ "$key" =~ ^remote\..+\.(url|pushurl|fetch|tagopt|prune)$ ]]
}

# .what = is <url> a plain git url — a scheme a clone reads as data, no whitespace? rc 0 = yes
# .why `ext::` runs a command, and a url with a space or newline is no url a pass wrote
# .why the scp form must open with a plain user, so no url reads as a flag (`-u…`)
grove_backup_url_is_plain() {
  [[ -n "$1" && "$1" =~ ^(https?://|ssh://|git://|file://|/|[A-Za-z0-9._][A-Za-z0-9._-]*@[A-Za-z0-9.-]+:) && "$1" != *[[:space:]]* ]]
}

# .what = may this key, with this VALUE, be set by a restore? rc 0 = yes
#   usage: grove_backup_config_entry_is_carried <key> <value> <the unit's origin, or empty>
# 🛑 .why an allowed key with a forged value still redirects the human: `remote.origin.url`
#   pointed elsewhere sends the next push there, and a `branch.*.remote` that is a url does
#   the same. so the origin's url must equal the unit's own origin, and each other value
#   must have the one shape a pass writes
grove_backup_config_entry_is_carried() {
  local key="${1,,}" value="$2" origin="$3"
  grove_backup_config_key_is_carried "$key" || return 1
  [[ "$value" != *$'\n'* ]] || return 1
  case "$key" in
    remote.origin.url|remote.origin.pushurl) [[ -n "$origin" && "$value" == "$origin" ]] ;;
    remote.*.url|remote.*.pushurl) grove_backup_url_is_plain "$value" ;;
    remote.*.fetch) [[ "$value" =~ ^\+?refs/[^:[:space:]]+:refs/remotes/[^[:space:]]+$ && "$value" != *..* ]] ;;
    remote.*.tagopt) [[ "$value" =~ ^--(no-)?tags$ ]] ;;
    remote.*.prune) [[ "$value" =~ ^(true|false)$ ]] ;;
    branch.*.remote|branch.*.pushremote) [[ "$value" == . ]] || grove_backup_unit_field_is_valid "$value" ;;
    branch.*.merge) [[ "$value" =~ ^refs/heads/[^[:space:]]+$ && "$value" != *..* ]] ;;
    branch.*.rebase) [[ "$value" =~ ^(true|false|merges|interactive)$ ]] ;;
    branch.*.description) return 0 ;;
    *) return 1 ;;
  esac
}

# .what = may a unit lay or delete <rel> inside its tree? rc 0 = yes
# .why a path is untrusted as an id is: `../` would leave the tree, and a top `.git/`
#   would set config or arm a hook past the allowlist above
grove_backup_unit_rel_is_valid() {
  local rel="$1" seg
  local -a segs
  [[ -n "$rel" && "$rel" != /* && "$rel" != *$'\n'* ]] || return 1
  IFS=/ read -r -a segs <<<"$rel"
  [[ "${segs[0]}" != .git ]] || return 1
  for seg in "${segs[@]}"; do [[ "$seg" != .. ]] || return 1; done
  return 0
}

# .what = is <ref> one a unit keeps — HEAD, the stash, or a plain branch or tag? rc 0 = yes
# 🛑 .why a ref reaches git as an argument (`fetch origin <sha>`, `update-ref <ref>`), and a
#   field shaped `--upload-pack=…` would read as an option that runs a command. so each
#   component is plain: no `-` or `.` at its head, no `..`, no byte git's ref grammar
#   forbids, and no control byte, which would also print raw to the human's terminal
grove_backup_unit_ref_is_valid() {
  local ref="$1" name seg
  local -a segs
  [[ "$ref" == HEAD || "$ref" == refs/stash ]] && return 0
  [[ "$ref" =~ ^refs/(heads|tags)/(.+)$ ]] || return 1
  name="${BASH_REMATCH[2]}"
  [[ "$name" != *[[:cntrl:][:space:]~^:?*\[\\]* && "$name" != *..* && "$name" != *@\{* ]] || return 1
  [[ "$name" != */ && "$name" != *. && "$name" != *.lock ]] || return 1
  IFS=/ read -r -a segs <<<"$name"
  for seg in "${segs[@]}"; do [[ -n "$seg" && "$seg" != -* && "$seg" != .* ]] || return 1; done
  return 0
}

# .what = does a unit's refs.txt hold only "<sha> <ref>" lines a pass writes? rc 0 = yes;
#   else rc 1 and GROVE_BACKUP_UNIT_WHY names the fault
# .why every lay step reads this file, so it is admitted whole, once, before any of them
grove_backup_unit_refs_are_valid() {
  local refs="$1" line
  [[ -f "$refs" ]] || { GROVE_BACKUP_UNIT_WHY="it holds no refs.txt"; return 1; }
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[0-9a-f]{40}([0-9a-f]{24})?\ ([^ ]+)$ ]] \
      || { GROVE_BACKUP_UNIT_WHY="a line of refs.txt is no '<sha> <ref>' pair"; return 1; }
    grove_backup_unit_ref_is_valid "${BASH_REMATCH[2]}" \
      || { GROVE_BACKUP_UNIT_WHY="refs.txt names a ref no pass writes (a '-' or '.' at a part's head, '..', or a control byte)"; return 1; }
  done <"$refs"
  return 0
}

# .what = is the checkout's HEAD file absent, a commit id, or `ref: ` a valid branch? rc 0 = yes
grove_backup_unit_head_is_valid() {
  local file="$1" line
  [[ -f "$file" ]] || return 0
  # a HEAD no read can open is its own why: head's raw stderr would break the tree a human reads
  line="$(head -c 4096 "$file" 2>/dev/null)" \
    || { GROVE_BACKUP_UNIT_WHY="its checkout HEAD cannot be read"; return 1; }
  [[ "$line" =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] && return 0
  [[ "$line" =~ ^ref:\ (refs/heads/.+)$ ]] && grove_backup_unit_ref_is_valid "${BASH_REMATCH[1]}" && return 0
  GROVE_BACKUP_UNIT_WHY="its checkout HEAD is neither a commit id nor a branch"
  return 1
}

# .what = does a unit's .grove-backup hold only plain files and dirs? rc 0 = yes;
#   else rc 1 and GROVE_BACKUP_UNIT_WHY names the first member at fault
# 🛑 .why every step that reads a member there (`[[ -f ]]`, `cp`, `install`, a `while read`)
#   follows a link, so a member planted as a link to ~/.ssh would copy camper's keys into the
#   clone, and the next pass would carry them to the bucket. a pass writes no link there:
#   the writer copies each hook's and exclude's CONTENT. so the type is asked once, here
grove_backup_unit_members_are_plain() {
  local gb="$1" bad
  # absent: naught to follow (a tree unit's manifest is asked for before this)
  [[ -e "$gb" || -L "$gb" ]] || return 0
  [[ -d "$gb" && ! -L "$gb" ]] || { GROVE_BACKUP_UNIT_WHY="its .grove-backup is no plain dir"; return 1; }
  bad="$(cd "$gb" && find . -mindepth 1 ! -type f ! -type d -print -quit)"
  [[ -z "$bad" ]] && return 0
  # printed, so a byte outside a plain path's charset prints as `?`, never raw
  bad="${bad#./}"
  GROVE_BACKUP_UNIT_WHY="its .grove-backup/${bad//[^A-Za-z0-9._\/-]/?} is a link or a special file, and a restore would follow it"
  return 1
}

# .what = does an unpacked tree unit name only what a pass writes? rc 0 = yes;
#   else rc 1 and GROVE_BACKUP_UNIT_WHY names the first field at fault
# .why the manifest drives a clone, a checkout, and each delete; every field is checked
#   before a byte lays, as the unit id is
grove_backup_unit_manifest_is_valid() {
  local u="$1" rel
  [[ -d "$u" ]] || { GROVE_BACKUP_UNIT_WHY="it did not unpack"; return 1; }
  grove_backup_unit_members_are_plain "$u/.grove-backup" || return 1
  grove_backup_unit_meta_is_valid "$u/.grove-backup/meta.json" || return 1
  grove_backup_unit_refs_are_valid "$u/.grove-backup/refs.txt" || return 1
  grove_backup_unit_head_is_valid "$u/.grove-backup/checkout/HEAD" || return 1
  while IFS= read -r -d '' rel; do
    grove_backup_unit_rel_is_valid "${rel#./}" || { GROVE_BACKUP_UNIT_WHY="a file it lays reaches .git, or its name holds a newline"; return 1; }
  done < <(cd "$u" && find . -mindepth 1 -path ./.grove-backup -prune -o -print0)
  return 0
}

# 🛑 .what = the ONE admit: does an unpacked unit of <class> (tree | files) hold only what a
#   pass writes? rc 0 = yes; else rc 1 and GROVE_BACKUP_UNIT_WHY names the first fault
# .why the reader calls it on what it fetched, and the writer calls it on what it is about
#   to put — its own tar, unpacked — so both ask one question of one set. a writer check of
#   any other set (a file list whose dirs stand for their members, a path joined by hand)
#   can pass where the reader refuses, and a ✓ would stand on a unit that cannot come back
grove_backup_unit_admit() {
  local u="$1" class="$2" rel
  [[ "$class" == tree ]] && { grove_backup_unit_manifest_is_valid "$u"; return; }
  [[ -d "$u" ]] || { GROVE_BACKUP_UNIT_WHY="it did not unpack"; return 1; }
  grove_backup_unit_members_are_plain "$u/.grove-backup" || return 1
  while IFS= read -r -d '' rel; do
    grove_backup_unit_rel_is_valid "${rel#./}" && continue
    GROVE_BACKUP_UNIT_WHY="a file it lays reaches .git, or its name holds a newline"
    return 1
  done < <(cd "$u" && find . -mindepth 1 -print0)
  return 0
}

# .what = remove each <path> whole, even where a member dir denies its owner write
# rc 0 = each is gone · 1 = one survived, named on stderr
# .why a unit may hold a 0555 or 0000 dir, which `rm -rf` alone cannot empty: its scratch would
#   survive, and the next unit's scratch at that path would fail on every pack, run after run.
#   `chmod -R` follows no link it meets, so it changes naught outside <path>
grove_backup_scratch_clear() {
  local p
  for p in "$@"; do
    [[ -e "$p" || -L "$p" ]] || continue
    [[ -d "$p" && ! -L "$p" ]] && chmod -R u+rwX -- "$p" 2>/dev/null
    rm -rf -- "$p"
    [[ -e "$p" || -L "$p" ]] && { echo "💥 MalfunctionError: the scratch $p could not be removed" >&2; return 1; }
  done
  return 0
}

# .what = the writer's half of the admit: unpack the tar it is about to put, into a scratch
#   dir, and ask grove_backup_unit_admit of exactly what the restore would read
# usage: grove_backup_pack_admit <tar, or tar.gz> <scratch dir> <class>
# rc 0 = admitted · 2 = refused or unread, GROVE_BACKUP_PACK_WHY names it
grove_backup_pack_admit() {
  local tarball="$1" scratch="$2" class="$3" rc
  grove_backup_scratch_clear "$scratch" && mkdir -p "$scratch" \
    || { GROVE_BACKUP_PACK_WHY="the admit dir could not be made"; return 2; }
  tar -xf "$tarball" -C "$scratch" 2>"$scratch.err" \
    || { GROVE_BACKUP_PACK_WHY="its own tar did not unpack: $(head -n 1 "$scratch.err")"; grove_backup_scratch_clear "$scratch" "$scratch.err"; return 2; }
  grove_backup_unit_admit "$scratch" "$class"
  rc=$?
  grove_backup_scratch_clear "$scratch" "$scratch.err" \
    || { GROVE_BACKUP_PACK_WHY="its admit scratch could not be removed: $scratch"; return 2; }
  [[ "$rc" -eq 0 ]] && return 0
  GROVE_BACKUP_PACK_WHY="a restore would refuse this unit: $GROVE_BACKUP_UNIT_WHY"
  return 2
}

# .what = the manifest's own fields, alone (part of grove_backup_unit_admit)
grove_backup_unit_meta_is_valid() {
  local meta="$1" v rel
  v="$(jq -r '.head_sha // ""' "$meta")"
  [[ -z "$v" || "$v" =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] || { GROVE_BACKUP_UNIT_WHY="head_sha is no commit id"; return 1; }
  v="$(jq -r '.head_ref // ""' "$meta")"
  # one ref grammar for every field that reaches git: refs.txt's, held to a branch
  [[ -z "$v" ]] || { [[ "$v" == refs/heads/* ]] && grove_backup_unit_ref_is_valid "$v"; } \
    || { GROVE_BACKUP_UNIT_WHY="head_ref is no branch ref"; return 1; }
  v="$(jq -r '.origin // ""' "$meta")"
  [[ -z "$v" ]] || grove_backup_url_is_plain "$v" || { GROVE_BACKUP_UNIT_WHY="origin is no plain git url"; return 1; }
  while IFS= read -r -d '' rel; do
    grove_backup_unit_rel_is_valid "$rel" || { GROVE_BACKUP_UNIT_WHY="a delete leaves the tree or reaches .git"; return 1; }
  done < <(jq -j '.deletes[]? | (., "\u0000")' "$meta")
  return 0
}

# .what = does <path>'s basename match a secret shape? (for a copy made outside tar)
grove_backup_name_is_secret_shaped() {
  local base="${1##*/}" shape
  for shape in "${GROVE_BACKUP_SECRET_SHAPES[@]}"; do
    # shellcheck disable=SC2053 # the shape is a glob, matched on purpose
    [[ "$base" == $shape ]] && return 0
  done
  return 1
}

# .what = the paths of a tree unit that hold a plaintext credential, by shape or by content
#   in:  <path>, and the NUL-separated list of what the unit carries (a dir stands for all under it)
#   out: tree-relative paths, NUL-separated, into <out> — the pack cuts each, the manifest names each
# .why the list is computed, never left to tar's own excludes: a cut tar makes silently is a
#   cut no restore can name, and an edit to a tracked `.npmrc` would vanish with no word
grove_backup_tree_secret_cuts() {
  local path="$1" files="$2" out="$3" rel
  : >"$out"
  [[ -s "$files" ]] || return 0
  (cd "$path" && while IFS= read -r -d '' rel; do
      find "./$rel" \( -name .git -o -name node_modules \) -prune -o \( -type f -o -type l \) -print0 2>/dev/null
    done <"$files") >"$out.all"

  # by shape
  while IFS= read -r -d '' rel; do
    rel="${rel#./}"
    grove_backup_name_is_secret_shaped "$rel" && printf '%s\0' "$rel"
  done <"$out.all" >"$out"

  # by content: each plain file the shapes left, never a transcript (see GROVE_BACKUP_SECRET_CONTENT)
  (cd "$path" && while IFS= read -r -d '' rel; do
      rel="${rel#./}"
      [[ -f "$rel" && ! -L "$rel" && "$rel" != *.jsonl ]] || continue
      grove_backup_name_is_secret_shaped "$rel" && continue
      printf '%s\0' "$rel"
    done <"$out.all" | xargs -0 -r grep -lIZE -m 1 --no-messages -e "$GROVE_BACKUP_SECRET_CONTENT" --) >>"$out"
  rm -f "$out.all"
  return 0
}

# .what = cut each file of a stage dir whose content holds a credential; prints each cut,
#   NUL-separated, behind <prefix>
# usage: grove_backup_staged_secret_cuts <stage dir> [<prefix the manifest names it by>]
# .why every lane a pass copies outside tar is cut alike: the staged copies, and the repo
#   lane (its hooks, its exclude, its config), so a token in a hook never rides
grove_backup_staged_secret_cuts() {
  local staged="$1" prefix="${2:-}" rel
  [[ -d "$staged" ]] || return 0
  (cd "$staged" && grep -rlIZE -m 1 --no-messages -e "$GROVE_BACKUP_SECRET_CONTENT" -- .) \
    | while IFS= read -r -d '' rel; do
        rm -f -- "$staged/${rel#./}" && printf '%s%s\0' "$prefix" "${rel#./}"
      done
  return 0
}

# a grove slug, and an s3 bucket name — a declaration that fails its shape is a fault
GROVE_BACKUP_SLUG_PATTERN='^[a-z0-9][a-z0-9-]{0,62}$'
GROVE_BACKUP_BUCKET_PATTERN='^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$'

# a status older than this reads ✗ STALE: two missed passes of the 3-hour timer, plus an
#   hour for a long pass. it moves with the timer: a bound under one interval reads a
#   healthy box as ✗ between passes
GROVE_BACKUP_STALE_SECS=25200

# a pass at work past this reads ✗, however long it runs: it has run too long to vouch for
GROVE_BACKUP_PASS_BOUND_SECS=43200

# every aws call is bounded, so a hung endpoint fails one run and never holds the timer
GROVE_BACKUP_AWS_TIMEOUT_SECS=900

######################################################################
# the box facts — each a function, so a play can point it at a fixture
######################################################################
grove_backup_name_file()   { printf '/etc/grove/name'; }
grove_backup_bucket_file() { printf '/etc/grove/backup.bucket'; }
# the grove this one replaced, declared by infra beside the bucket name (S8); absent on a box
#   that replaced none
grove_backup_predecessor_file() { printf '/etc/grove/backup.predecessor'; }
grove_backup_seat_home()   { printf '%s' "$HOME"; }
grove_backup_state_dir()   { printf '/var/lib/grove-backup'; }
grove_backup_status_file() { printf '%s/status.json' "$(grove_backup_state_dir)"; }
grove_backup_now()         { date -u +%s; }
# .why a stamp to the nanosecond: an edit in the same second as a pack start, but
#   before it, must never read as newer than the pack
grove_backup_now_precise() { date -u +%s.%N; }
grove_backup_today()       { date -u -d "@$(grove_backup_now)" +%F; }

######################################################################
# .what = may this box write its name's prefix? yes once it claimed it, once it ever
#   ran a GOOD pass (a status whose `last_ok` is set: a box enrolled before the claim),
#   or while the prefix is empty
#
# 🛑 .why never the bare status file: every early exit writes a FAILED status, the
#   guard's own refusal and a reach that fails before the guard included. so a status
#   file proves only that the agent ran, never that this box wrote the prefix
#
# .why a rebuild may keep its name (`howto.adopt-a-replacement-grove`, the mirror case).
#   its first pass would put fresh, near-empty units over the dead grove's latest, and a
#   restore would lay those. so a box writes a prefix that holds objects only once a human
#   adopts it (`grove-backup --adopt`). the claim lands before the first put, so a first
#   pass cut short never reads its own objects as a stranger's
######################################################################
grove_backup_prefix_is_ours() {
  local state="$1" index="$2"
  [[ -e "$state/prefix.claimed" ]] && return 0
  [[ -n "$(jq -r '.last_ok // empty' "$state/status.json" 2>/dev/null)" ]] && return 0
  [[ ! -s "$index" ]]
}
grove_backup_prefix_claim() {
  [[ -e "$1/prefix.claimed" ]] || grove_backup_now >"$1/prefix.claimed"
}
grove_backup_iso()         { date -u -d "@$1" +%Y-%m-%dT%H:%MZ; }

######################################################################
# .what = read a one-line declaration from the box, three-valued
#
# 🛑 .three answers, never two
#   rc 0 = declared (the value on stdout) · rc 1 = absent or empty ·
#   rc 2 = present and unreadable, a dir, or a value outside its shape.
#   rc 2 is a FAULT and never a decline: read as "absent", it would send the
#   human to infra for a file that is there and broken
#
# usage: value="$(grove_backup_decl_read "$file" "$pattern")"; rc=$?
######################################################################
grove_backup_decl_read() {
  local file="$1" pattern="$2" value
  [[ -e "$file" ]] || return 1
  [[ -f "$file" && -r "$file" ]] || return 2
  value="$(head -n 1 "$file")"
  value="${value//[[:space:]]/}"
  [[ -n "$value" ]] || return 1
  [[ "$value" =~ $pattern ]] || return 2
  printf '%s\n' "$value"
}

######################################################################
# .what = run one aws call, bounded, and sort its failure into a CAUSE
#
# .why a wrapper
#   - the reach order needs to tell "no credential" from "denied" from a blip,
#     and only the cli's own stderr knows which. one sort, declared once
#   - the stdout goes to a FILE, never through `$(…)`: a subshell would drop the
#     fault vars this sets, and the caller would read a blank cause
#
# rc: 0 ok · 3 denied (GROVE_BACKUP_AWS_VERB names the verb) · 4 no credential ·
#     5 a run-time fault (GROVE_BACKUP_AWS_ERR) · 6 the key is absent
#
# usage: grove_backup_aws s3:PutObject /dev/null s3 cp …
######################################################################
grove_backup_aws() {
  local verb="$1" out="$2" errf rc
  shift 2
  errf="$(mktemp)"
  # -k: a bare timeout only asks; a TERM-deaf aws would hold the call past its bound
  timeout -k 30 "$GROVE_BACKUP_AWS_TIMEOUT_SECS" aws "$@" >"$out" 2>"$errf" </dev/null
  rc=$?
  GROVE_BACKUP_AWS_ERR="$(head -c 400 "$errf" | tr '\n' ' ')"
  rm -f "$errf"
  [[ "$rc" -eq 0 ]] && return 0

  GROVE_BACKUP_AWS_VERB="$verb"
  case "$GROVE_BACKUP_AWS_ERR" in
    *AccessDenied*|*"(403)"*|*Forbidden*) return 3 ;;
    *"Unable to locate credentials"*|*NoCredentialProviders*|*ExpiredToken*|*InvalidClientTokenId*|*"Error when retriev"*|*"credential provider"*) return 4 ;;
    *NoSuchKey*|*"(404)"*|*"Not Found"*) return 6 ;;
  esac
  [[ "$rc" -eq 124 || "$rc" -eq 137 ]] && GROVE_BACKUP_AWS_ERR="no answer from aws in ${GROVE_BACKUP_AWS_TIMEOUT_SECS}s"
  [[ "$rc" -eq 127 ]] && GROVE_BACKUP_AWS_ERR="the aws cli is absent from PATH"
  return 5
}

######################################################################
# the s3 seam — every call the backup and the restore make, one function each
#
# .why each is its own function: a play swaps them for a local dir, so the
#   tar, hash, git, and lay steps above them all run for real
######################################################################

# the credential, asked on its own: GetCallerIdentity needs no grant, so a
# failure here is the credential and never the policy
grove_backup_s3_whoami() {
  grove_backup_aws sts:GetCallerIdentity /dev/null sts get-caller-identity
}

# every key under a prefix → "key<TAB>last-modified<TAB>class" lines in $2
# .why read as json, never text: s3 allows a tab or a newline inside a key, and a text read
#   splits on both, so a key could forge the last-modified column latest is chosen by
grove_backup_s3_list() {
  local prefix="$1" out="$2" raw rc
  raw="$(mktemp)"
  grove_backup_aws s3:ListBucket "$raw" s3api list-objects-v2 \
    --bucket "$GROVE_BACKUP_BUCKET" --prefix "$prefix" \
    --query 'Contents[].[Key,LastModified,StorageClass]' --output json
  rc=$?
  [[ "$rc" -eq 0 ]] && { grove_backup_s3_list_rows "$raw" "$out" || rc=1; }
  rm -f "$raw"
  return "$rc"
}

# .what = a list call's json → its rows, each admitted by its grammar, in <out>; each row
#   dropped is counted and named on stderr, as json, any byte outside print shown as `?`
# .why the ONE seam every lister reads through (the agent's latest, `get`, the restore): a key
#   with a control byte, a last-modified or a class outside its shape, is no row a put wrote
# usage: grove_backup_s3_list_rows <json file> <out>
GROVE_BACKUP_S3_ROW_ADMIT='type == "array" and length == 3
  and (.[0] | type == "string" and (test("[\u0001-\u001f\u007f-\u009f]") | not))
  and (.[1] | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$"))
  and (.[2] | type == "string" and test("^[A-Z_]{1,32}$"))'
grove_backup_s3_list_rows() {
  local json="$1" out="$2" n
  jq -r "(. // [])[] | select($GROVE_BACKUP_S3_ROW_ADMIT) | @tsv" "$json" >"$out" || return 1
  n="$(jq "[(. // [])[] | select(($GROVE_BACKUP_S3_ROW_ADMIT) | not)] | length" "$json")" || return 1
  [[ "$n" -eq 0 ]] && return 0
  echo "⚠️ $(grove_backup_plural "$n" "listed row") dropped: no put writes a row of that shape" >&2
  jq -r "(. // [])[] | select(($GROVE_BACKUP_S3_ROW_ADMIT) | not) | @json" "$json" \
    | LC_ALL=C tr -c '\040-\176\n' '?' | head -n 8 | sed 's/^/   · /' >&2
  return 0
}

# the grove prefixes at the bucket root → one `grove=<slug>/` per line in $1
grove_backup_s3_prefixes() {
  local out="$1" raw rc
  raw="$(mktemp)"
  grove_backup_aws s3:ListBucket "$raw" s3api list-objects-v2 \
    --bucket "$GROVE_BACKUP_BUCKET" --delimiter / \
    --query 'CommonPrefixes[].Prefix' --output json
  rc=$?
  [[ "$rc" -eq 0 ]] && { jq -r '(. // [])[] | strings | select(test("[\u0001-\u001f\u007f-\u009f]") | not)' "$raw" >"$out" || rc=1; }
  rm -f "$raw"
  return "$rc"
}

# one object's facts → "sha256<TAB>class<TAB>restore" in $2 (`None` where unset)
grove_backup_s3_head() {
  local key="$1" out="$2"
  grove_backup_aws s3:GetObject "$out" s3api head-object \
    --bucket "$GROVE_BACKUP_BUCKET" --key "$key" \
    --query '[Metadata.sha256,StorageClass,Restore]' --output text
}

grove_backup_s3_put() {
  local file="$1" key="$2" sha="$3"
  grove_backup_aws s3:PutObject /dev/null s3 cp "$file" "s3://$GROVE_BACKUP_BUCKET/$key" \
    --metadata "sha256=$sha" --only-show-errors --no-progress
}

grove_backup_s3_get() {
  local key="$1" file="$2"
  grove_backup_aws s3:GetObject /dev/null s3 cp "s3://$GROVE_BACKUP_BUCKET/$key" "$file" \
    --only-show-errors --no-progress
}

grove_backup_s3_thaw() {
  local key="$1"
  grove_backup_aws s3:RestoreObject /dev/null s3api restore-object \
    --bucket "$GROVE_BACKUP_BUCKET" --key "$key" \
    --restore-request '{"Days":7,"GlacierJobParameters":{"Tier":"Standard"}}'
}

######################################################################
# .what = walk the reach in its WRITTEN order; the first that fails is the cause
#
# 🛑 .the order is the contract (vision `.reach order`)
#   grove name → bucket name → credential. the verb's grant is the fourth, and
#   only a real call can ask it, so each caller reports `access denied` itself
#   - a fresh hetzner box that lacks the bucket AND its identity reports the
#     bucket. it never probes a credential with no bucket to aim it at
#   - a retry cures none of these, so each fails the whole run
#
# usage: grove_backup_reach_check yes|no    # yes = this caller needs the grove name
#   sets GROVE_BACKUP_GROVE, GROVE_BACKUP_BUCKET
#   on a failure: GROVE_BACKUP_CAUSE + GROVE_BACKUP_FIX, and rc 2
######################################################################
grove_backup_reach_check() {
  local need_name="$1" file rc
  GROVE_BACKUP_CAUSE="" GROVE_BACKUP_FIX=""

  # 1. the grove name — a backup's own prefix. a restore names its source instead
  if [[ "$need_name" == yes ]]; then
    file="$(grove_backup_name_file)"
    GROVE_BACKUP_GROVE="$(grove_backup_decl_read "$file" "$GROVE_BACKUP_SLUG_PATTERN")"
    rc=$?
    if [[ "$rc" -eq 1 ]]; then
      GROVE_BACKUP_CAUSE="grove name undeclared"
      GROVE_BACKUP_FIX="owed by ahbode/infrastructure: the grove name, declared at $file (owed item 2)"
      return 2
    fi
    if [[ "$rc" -ne 0 ]]; then
      GROVE_BACKUP_CAUSE="grove name unreadable"
      GROVE_BACKUP_FIX="$file is present and holds no readable slug; owed by ahbode/infrastructure, which writes it"
      return 2
    fi
  fi

  # 2. the bucket name
  file="$(grove_backup_bucket_file)"
  GROVE_BACKUP_BUCKET="$(grove_backup_decl_read "$file" "$GROVE_BACKUP_BUCKET_PATTERN")"
  rc=$?
  if [[ "$rc" -eq 1 ]]; then
    GROVE_BACKUP_CAUSE="bucket name undeclared"
    GROVE_BACKUP_FIX="owed by ahbode/infrastructure: the bucket name, declared on the box at $file (owed item 1)"
    return 2
  fi
  if [[ "$rc" -ne 0 ]]; then
    GROVE_BACKUP_CAUSE="bucket name unreadable"
    GROVE_BACKUP_FIX="$file is present and holds no readable bucket name; owed by ahbode/infrastructure, which writes it"
    return 2
  fi

  # 3. the credential — the default chain, so ec2 and hetzner take one path
  grove_backup_s3_whoami
  rc=$?
  if [[ "$rc" -eq 4 ]]; then
    GROVE_BACKUP_CAUSE="no aws credential"
    GROVE_BACKUP_FIX="owed by ahbode/infrastructure: this grove's aws identity — the instance profile on ec2, roles anywhere on hetzner (infra#64, part 3)"
    return 2
  fi
  if [[ "$rc" -ne 0 ]]; then
    GROVE_BACKUP_CAUSE="aws unreachable"
    GROVE_BACKUP_FIX="the credential probe failed (${GROVE_BACKUP_AWS_ERR:-no stderr}); a transient reach heals on the next timed pass, or retry now: sudo systemctl start grove-backup.service"
    return 2
  fi
  return 0
}

# .what = the cause and fix for a grant the bucket refused (the fourth reach)
# .why the grant reaches this grove and its declared predecessor alone (S8): a refusal there
#   is infra's to fix; a refusal anywhere else is the isolation line at work
grove_backup_cause_denied() {
  GROVE_BACKUP_CAUSE="access denied: ${GROVE_BACKUP_AWS_VERB:-s3}"
  GROVE_BACKUP_FIX="the grant refused it. a box reaches its own grove and its declared predecessor alone: on those, owed by ahbode/infrastructure (the per-grove grant); on any other grove, the admin tier holds it"
}

######################################################################
# .what = the groves this box may read: its own, then its declared predecessor
# .why a grant scoped per grove refuses the fleet-wide list (S8), so a box names the groves it
#   reaches from its own declarations, never from the bucket
######################################################################
# .note = rc 2 when a declaration is present and broken: a fault, never read as absent
grove_backup_groves_in_reach() {
  local file g rc
  for file in "$(grove_backup_name_file)" "$(grove_backup_predecessor_file)"; do
    g="$(grove_backup_decl_read "$file" "$GROVE_BACKUP_SLUG_PATTERN")"; rc=$?
    [[ "$rc" -eq 2 ]] && { GROVE_BACKUP_DECL_BROKEN="$file"; return 2; }
    [[ "$rc" -eq 0 ]] && printf '%s\n' "$g"
  done
  return 0
}

######################################################################
# keys — the one shape every object takes
#
#   grove=<slug>/user=<seat>/org=<org>/repo=<repo>/tree=<dir>/date=<YYYY-MM-DD>.tar.gz
#   grove=<slug>/user=<seat>/home=<.claude|.rhachet>/date=<YYYY-MM-DD>.tar.gz
#
# .why `date=` marks the day a unit last CHANGED, never the day of the run: an
#   untouched clone is put once per refresh age (F8, S8)
# .why a clone's `tree=` is its repo name: the clone is the tree its repo holds
######################################################################
grove_backup_key() { printf 'grove=%s/%s/date=%s.tar.gz' "$1" "$2" "$3"; }

######################################################################
# .what = is a key's date at or past the refresh age?
# .why past 90 days the grant archives an object and locks camper out of it (S8; the
#   archive is ahbode/infrastructure's). a live unit put again at 80 days keeps
#   its latest object in reach, so the box restores it with no admin thaw
######################################################################
GROVE_BACKUP_REFRESH_DAYS=80
grove_backup_key_is_stale() {
  local day="${1##*date=}" epoch
  day="${day%.tar.gz}"
  [[ "$day" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
  epoch="$(date -u -d "$day" +%s 2>/dev/null)" || return 1
  (( $(grove_backup_now) - epoch >= GROVE_BACKUP_REFRESH_DAYS * 86400 ))
}

# .what = "1 commit", "3 commits" — a count with its noun, singular at one
# usage: grove_backup_plural <n> <noun> [<plural noun>]   (the third for a noun that takes no bare -s: entry → entries)
# .why prefixed: the provision verify sources this library into the runner's own shell
grove_backup_plural() { [[ "$1" -eq 1 ]] && printf '1 %s' "$2" || printf '%s %s' "$1" "${3:-${2}s}"; }

# .what = top-level bucket prefixes on stdin → one grove slug per line
# .why the bucket holds prefixes that are no grove's (infra keeps a `probe/` one);
#   read as a grove, each would render a row with no backup and a made-up date
# .why the slug meets the grammar a `--from` meets: a prefix no `--from` accepts names no
#   grove to read, and its raw text would reach the terminal as typed
grove_backup_groves_of_prefixes() {
  local p
  while IFS= read -r p; do
    [[ "$p" == grove=?*/ ]] || continue
    p="${p#grove=}"
    p="${p%/}"
    [[ "$p" =~ $GROVE_BACKUP_SLUG_PATTERN ]] || continue
    printf '%s\n' "$p"
  done
}

# the unit id of a key: drop `grove=<slug>/` and `/date=….tar.gz`
grove_backup_key_unit() {
  local key="${1#grove=*/}"
  printf '%s' "${key%/date=*}"
}

# clone | worktree | orphan | setaside | home, from a unit id
grove_backup_unit_kind() {
  local unit="$1" repo tree
  [[ "$unit" == */home=* ]] && { printf 'home'; return; }
  [[ "$unit" == */orphan=* ]] && { printf 'orphan'; return; }
  [[ "$unit" == */setaside=* ]] && { printf 'setaside'; return; }
  repo="${unit#*/repo=}"; repo="${repo%%/*}"
  tree="${unit##*/tree=}"
  [[ "$repo" == "$tree" ]] && { printf 'clone'; return; }
  printf 'worktree'
}

# .what = how a kind rides: `tree` (a clone or a worktree, with its git state) or `files`
#   (a home dir, an orphan, a set-aside: plain files alone)
# .why ONE map, read by the agent's pack and the restore's lay, so a new kind is named once
grove_backup_unit_class() {
  case "$1" in
    clone|worktree) printf tree ;;
    *) printf files ;;
  esac
}

# the field <name>= of a unit id
grove_backup_unit_field() {
  local unit="$1" name="$2" value
  [[ "/$unit/" == */"$name"=* ]] || return 1
  value="${unit#*"$name"=}"
  printf '%s' "${value%%/*}"
}

# .what = is the reach fault one a retry may cure (no answer), rather than one a human fixes?
# .why the exit follows the cause: a transient fault is a malfunction (1), a credential,
#   a bucket name, or a grant is a constraint (2)
grove_backup_cause_is_transient() {
  [[ "${GROVE_BACKUP_CAUSE:-}" == "aws unreachable" || "${GROVE_BACKUP_CAUSE:-}" == "the list failed" ]]
}

# the day a key's unit last changed: its `date=` value
grove_backup_key_day() {
  local day="${1##*/date=}"
  printf '%s' "${day%.tar.gz}"
}

# a unit id with its seat (`user=<seat>/`) dropped, for display under that seat
grove_backup_unit_without_seat() { printf '%s' "${1#user=*/}"; }

# .what = the order a unit lays in: 1 clone · 2 worktree · 3 orphan or set-aside · 4 home
# .why a worktree needs its clone laid first; plain files come last. the list reads the
#   same order, so what a human sees is what `--all` will do
grove_backup_unit_rank() {
  case "$(grove_backup_unit_kind "$1")" in
    clone) printf 1 ;; worktree) printf 2 ;; orphan|setaside) printf 3 ;; *) printf 4 ;;
  esac
}

# .what = each unit's LATEST object, from list lines on stdin
#   in:  "key<TAB>lastmod<TAB>class" (as grove_backup_s3_list writes)
#   out: "unit<TAB>key<TAB>class", one per unit; an absent class reads STANDARD
# 🛑 .why latest is the object the bucket RECEIVED last (its lastmod, which s3 stamps), never
#   the key text a writer chose: a key dated ahead (a wrong clock, another writer) would
#   win forever by text, and a restore would read it over every newer put. the key breaks a tie
grove_backup_units_latest() {
  local key lastmod class
  while IFS=$'\t' read -r key lastmod class; do
    printf '%s\t%s\t%s\t%s\n' "$(grove_backup_key_unit "$key")" "$lastmod" "$key" "${class:-STANDARD}"
  done | LC_ALL=C sort -t$'\t' -k1,1 -k2,2 -k3,3 \
    | awk -F'\t' '{ latest[$1] = $1 "\t" $3 "\t" $4 } END { for (u in latest) print latest[u] }' \
    | sort -t$'\t' -k1,1
}

# .what = one field of one unit's row in a units_latest file: key or class
# .why the column order lives here, beside grove_backup_units_latest, which writes it
grove_backup_units_latest_field() {
  local file="$1" unit="$2" col
  case "$3" in key) col=2 ;; class) col=3 ;; *) return 2 ;; esac
  awk -F'\t' -v u="$unit" -v c="$col" '$1 == u { print $c }' "$file"
}

# .what = one seat's units from a units_latest file, in the order `--all` lays them
#   (grove_backup_unit_rank): a worktree finds its clone laid first
grove_backup_units_in_lay_order() {
  local file="$1" seat="$2" unit
  awk -F'\t' -v me="user=$seat/" 'index($1, me) == 1 { print $1 }' "$file" \
    | while read -r unit; do printf '%s %s\n' "$(grove_backup_unit_rank "$unit")" "$unit"; done \
    | sort | cut -d' ' -f2-
}

# .what = the newest last-modified in a list file ("key<TAB>lastmod<TAB>class"), as
#   `YYYY-MM-DDTHH:MMZ`; the raw stamp when it does not parse; empty for an empty list
# .why `date -d ""` answers today's midnight, so an empty list would read as a backup today
grove_backup_latest_object_time() {
  local lm
  lm="$(cut -f2 "$1" | sort | tail -n 1)"
  [[ -n "$lm" ]] || return 0
  date -u -d "$lm" +%Y-%m-%dT%H:%MZ 2>/dev/null || printf '%s\n' "$lm"
}

# .what = the restore state from a head-object facts file ("sha256<TAB>class<TAB>restore")
grove_backup_s3_head_restore() { cut -f3 "$1"; }

# .what = the glyph a tree row takes: └─ for the last of $2 rows, ├─ for the rest
grove_backup_tree_glyph() { [[ "$1" -eq $(( $2 - 1 )) ]] && printf '└─' || printf '├─'; }

######################################################################
# .what = the repo a worktree belongs to, read from its `.git` link
#
# .why the worktree dir's own name says naught of its repo — `svc-quotes.feat-x`
#   could be any repo's. the link file is the box's own answer
# .why `_unlinked` and never a skip: a worktree whose link is broken still holds
#   files nobody pushed. the walk reads `_unlinked` as "ride as an orphan", since git
#   cannot read that tree. so no unit ever bears `repo=_unlinked`: a `.git` DIR is read
#   by the walk before this is asked, as a clone of its own
######################################################################
grove_backup_worktree_repo() {
  local line gitdir
  [[ -f "$1/.git" ]] || { printf '_unlinked'; return; }
  line="$(head -n 1 "$1/.git")"
  gitdir="${line#gitdir: }"
  [[ "$gitdir" == */.git/worktrees/* ]] || { printf '_unlinked'; return; }
  # a link of the right shape whose clone is gone: git cannot read it either
  [[ -d "$gitdir" ]] || { printf '_unlinked'; return; }
  gitdir="${gitdir%%/.git/worktrees/*}"
  printf '%s' "${gitdir##*/}"
}

######################################################################
# .what = a set-aside tree's unit name: its dir name, with no time in it
#
# .why a set-aside dir is named `<tree>.<YYYYMMDDTHHMMSSZ>`, the hour a clone set
#   it aside. a unit name is a bucket key, and a key carries no time of work. so
#   the stamp is cut, and in its place goes 8 hex of a hash keyed by this box's
#   machine-id: two set-asides of one tree stay apart, and the stamp cannot be
#   read back from the hash without the key, which never leaves the box
# .why a name with no stamp passes as is: a set-aside a restore laid back already
#   bears its hash, so the next box backs it up under the same unit
# 🛑 .why no machine-id means NO hash, never an unsalted one
#   a year holds ~31M seconds, so an unsalted hash of `<tree>.<stamp>` is read back
#   to its stamp by brute force in seconds. with no key, the stamp is cut and naught
#   stands in: the key leaks no time, and two set-asides of one tree share a unit,
#   whose bucket versions keep both. the fault is named on stderr, so it is no silent
#   degrade (a systemd box always holds a machine-id; its absence is a broken box)
######################################################################
grove_backup_machine_id_file() { printf '/etc/machine-id'; }
grove_backup_setaside_name() {
  local name="$1" base salt
  [[ "$name" =~ ^(.+)\.[0-9]{8}T[0-9]{6}Z$ ]] || { printf '%s' "$name"; return 0; }
  base="${BASH_REMATCH[1]}"
  salt="$(head -n 1 "$(grove_backup_machine_id_file)" 2>/dev/null)"
  if [[ -z "$salt" ]]; then
    echo "💥 MalfunctionError: $(grove_backup_machine_id_file) is absent or empty, so set-aside '$base' rides with no hash" >&2
    printf '%s' "$base"
    return 0
  fi
  printf '%s.%s' "$base" "$(printf '%s\n%s' "$salt" "$name" | sha256sum | cut -c1-8)"
}

######################################################################
# .what = every unit on this box → "kind<TAB>user<TAB>path<TAB>unit" lines, plus one
#   "gap<TAB>user<TAB>path<TAB>unit<TAB>why" line per tree whose work rides in no unit
#   (a reader of units skips a gap; the agent fails its pass on one, by name)
#
# .the walk
#   ~/git/<org>/<repo>             a clone      (its `.git` is a dir)
#   ~/git/<org>/_worktrees/<dir>   a worktree   (its `.git` is a link)
#   ~/git/<org>/_worktrees/<dir>   an orphan    (no `.git` at all: git dropped the
#                                  worktree, and its ignored files stayed — its
#                                  transcripts among them)
#   ~/git/<org>/<repo>/.git/tree-del-setaside/<dir>   a set-aside tree
#   ~/git/<org>/_setaside/<repo>/<dir>                a set-aside a restore laid
#   ~/<dir>                        a home unit, one per scope dir beside `~/git`
#
# .why orphans and set-asides ride as plain files: neither holds git state, and
#   each may hold the only copy of a conversation (📜 2026-11-20, 0901: 66 trees
#   that held transcripts sat inside no unit)
#
# .why ONE home, the agent's own: only the camper seat holds work, the scope
#   `git backup` carries. the key keeps `user=<seat>`, so a restore names it
######################################################################
# .what = the half-lay mark INSIDE <target>'s own git dir, the twin of the one beside it
# .why the mark beside a target outlives the target: a clone that failed, or a dir a human
#   removed and cloned again by hand, leaves it there. only a mark inside the target's git
#   dir proves the target in place is the one the cut restore laid — git puts it there at
#   its first act (`--template`), so it dies with that target, and no clone a human makes
#   holds one
grove_backup_restore_inner_mark_path() {
  local gd
  [[ -e "$1/.git" ]] || return 1
  gd="$(grove_backup_git "$1" rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  printf '%s/%s' "$gd" "$GROVE_BACKUP_RESTORE_UNFINISHED_MARK"
}

# .what = did a restore leave <target> half-laid? the ONE predicate the walk and the restore
#   both ask. rc 0 = yes: the mark beside it is set, and either naught is there, or the
#   target holds the twin of that mark inside its own git dir
# 🛑 .why the twin, and never the mark beside alone: a wipe on the mark beside alone deletes
#   a clone a human made after the cut restore's target was gone, with its unpushed work
# .why a regular file only: a unit may lay a DIR of the sentinel's name (`.` is in the id
#   pattern), and a dir must never read as a half-lay
grove_backup_restore_is_unfinished() {
  local beside="$1$GROVE_BACKUP_RESTORE_UNFINISHED_SUFFIX" inner
  [[ -f "$beside" && ! -L "$beside" ]] || return 1
  [[ -e "$1" || -L "$1" ]] || return 0
  inner="$(grove_backup_restore_inner_mark_path "$1")" || return 1
  [[ -f "$inner" ]] && cmp -s -- "$beside" "$inner"
}

# .what = a mark beside <target> that the target in place never matched: a cut restore's
#   leftover, beside a tree that restore did not lay. rc 0 = yes
grove_backup_restore_mark_is_stale() {
  [[ -f "$1$GROVE_BACKUP_RESTORE_UNFINISHED_SUFFIX" ]] && ! grove_backup_restore_is_unfinished "$1"
}

# .what = did a restore leave <dir> half-laid? then the walk passes over it, and names it
# .why a half-laid clone holds no checkout: packed, its unit would vouch for a tree that is
#   not there, and on the next restore lay that hollow tree in place of the whole one
grove_backup_walk_is_half_laid() {
  if grove_backup_restore_mark_is_stale "$1"; then
    echo "   ⚠️ ${1#"$(grove_backup_seat_home)"/} · a cut restore's mark sits beside it, yet this tree is not what that restore laid; it rides" >&2
    return 1
  fi
  grove_backup_restore_is_unfinished "$1" || return 1
  echo "   ⏸ ${1#"$(grove_backup_seat_home)"/} · a restore is laid in part here; it rides once that restore lands" >&2
  return 0
}

# .what = a GAP row for a clone whose submodules are initialized, else naught
# usage: grove_backup_walk_submodules_gap <user> <clone path> <its unit id>
# .why a submodule's git dir sits at `.git/modules/<x>`, which no unit carries: its unpushed
#   commits ride nowhere, and its gitfile points at a dir a new box lacks. the clone itself
#   rides; the gap row names what does not, and fails the pass while it stands
grove_backup_walk_submodules_gap() {
  local m
  for m in "$2/.git/modules"/*; do
    [[ -e "$m" ]] || continue
    printf 'gap\t%s\t%s\t%s\tits submodules'"'"' commits ride in no unit (.git/modules)\n' "$1" "$2" "$3"
    return 0
  done
  return 0
}

grove_backup_units_walk() {
  local home user org org_name entry name wt wt_repo sa dir hd
  home="$(grove_backup_seat_home)"
  [[ -d "$home" ]] || return 0
  user="${home##*/}"

  for dir in "${GROVE_BACKUP_SCOPE_DIRS[@]}"; do
    hd="${dir#\~/}"

    # the home dirs beside ~/git: one unit each
    if [[ "$hd" != git ]]; then
      [[ -d "$home/$hd" ]] && printf 'home\t%s\t%s\tuser=%s/home=%s\n' "$user" "$home/$hd" "$user" "$hd"
      continue
    fi

    # ~/git: one unit per clone, one per worktree
    [[ -d "$home/git" ]] || continue
    for org in "$home/git"/*/; do
      [[ -d "$org" ]] || continue
      org="${org%/}"
      org_name="${org##*/}"
      for entry in "$org"/*/; do
        [[ -d "$entry" ]] || continue
        entry="${entry%/}"
        name="${entry##*/}"
        if [[ "$name" == _worktrees ]]; then
          for wt in "$entry"/*/; do
            [[ -d "$wt" ]] || continue
            wt="${wt%/}"
            grove_backup_walk_is_half_laid "$wt" && continue
            # a `.git` DIR here is a clone of its own (a `git clone` or a `restore --into`
            #   pointed here): it rides as a clone, every branch with it, and a restore lays
            #   it at ~/git/<org>/<dir>. where a clone of that name already sits there, the
            #   two would share one unit id: its files ride as an orphan, `.git` cut, and its
            #   commits ride in no unit — a GAP row, which fails the pass until it is renamed
            if [[ -d "$wt/.git" && ! -L "$wt/.git" ]]; then
              if [[ ! -e "$org/${wt##*/}" ]]; then
                printf 'clone\t%s\t%s\tuser=%s/org=%s/repo=%s/tree=%s\n' \
                  "$user" "$wt" "$user" "$org_name" "${wt##*/}" "${wt##*/}"
                grove_backup_walk_submodules_gap "$user" "$wt" "user=$user/org=$org_name/repo=${wt##*/}/tree=${wt##*/}"
                continue
              fi
              printf 'gap\t%s\t%s\tuser=%s/org=%s/orphan=%s\tits files ride; its commits do not, since the clone %s/%s holds that name; rename the dir\n' \
                "$user" "$wt" "$user" "$org_name" "${wt##*/}" "$org_name" "${wt##*/}"
            fi
            wt_repo="$(grove_backup_worktree_repo "$wt")"
            # rides as plain files when git cannot name it as a worktree apart from its clone:
            #   no link, a broken link, or a dir named as its repo (its id would BE the clone's,
            #   and one unit would overwrite the other). its commits ride in its clone's unit,
            #   since a worktree shares its clone's object store
            if [[ ! -f "$wt/.git" || "$wt_repo" == _unlinked || "$wt_repo" == "${wt##*/}" ]]; then
              printf 'orphan\t%s\t%s\tuser=%s/org=%s/orphan=%s\n' "$user" "$wt" "$user" "$org_name" "${wt##*/}"
              continue
            fi
            printf 'worktree\t%s\t%s\tuser=%s/org=%s/repo=%s/tree=%s\n' \
              "$user" "$wt" "$user" "$org_name" "$wt_repo" "${wt##*/}"
          done
          continue
        fi
        if [[ "$name" == _setaside ]]; then
          for sa in "$entry"/*/*/; do
            [[ -d "$sa" ]] || continue
            sa="${sa%/}"
            printf 'setaside\t%s\t%s\tuser=%s/org=%s/repo=%s/setaside=%s\n' "$user" "$sa" "$user" "$org_name" \
              "$(basename "$(dirname "$sa")")" "$(grove_backup_setaside_name "${sa##*/}")"
          done
          continue
        fi
        [[ -d "$entry/.git" ]] || continue
        grove_backup_walk_is_half_laid "$entry" && continue
        printf 'clone\t%s\t%s\tuser=%s/org=%s/repo=%s/tree=%s\n' \
          "$user" "$entry" "$user" "$org_name" "$name" "$name"
        grove_backup_walk_submodules_gap "$user" "$entry" "user=$user/org=$org_name/repo=$name/tree=$name"
        for sa in "$entry"/.git/tree-del-setaside/*/; do
          [[ -d "$sa" ]] || continue
          sa="${sa%/}"
          printf 'setaside\t%s\t%s\tuser=%s/org=%s/repo=%s/setaside=%s\n' "$user" "$sa" "$user" "$org_name" \
            "$name" "$(grove_backup_setaside_name "${sa##*/}")"
        done
      done
    done
  done
}

######################################################################
# .what = git, as the agent runs it on a tree
#
# .why `safe.directory=*`: a clone restored from another box or seat may carry
#   another owner, and git refuses it as "dubious ownership" without it
# .why `core.quotepath=off`: a path with a byte above 0x7f prints raw, so a list
#   read back with `-z` names the file that is there
# .why `GIT_OPTIONAL_LOCKS=0`: a read such as `diff` or `status` may refresh the index
#   and so take `index.lock`; on a live clone that lock would fail a clone's own git
#   act mid-pass. the backup only reads, so it never takes a lock it can skip
######################################################################
grove_backup_git() {
  local path="$1"
  shift
  GIT_OPTIONAL_LOCKS=0 git -c safe.directory='*' -c core.quotepath=off -C "$path" "$@"
}

# .what = a url with its credential stripped, so none lands in a unit
# .why by scheme: an http or git url's user is a token in disguise, so all of `user:secret@`
#   goes; an ssh url's user is the login a clone needs (`ssh://git@host/…`), so only the
#   `:secret` beside it goes
grove_backup_url_clean() {
  case "$1" in
    ssh://*|git+ssh://*|ssh+git://*) printf '%s' "$1" | sed -E 's#^([a-z+]+://[^/@:]*):[^/@]*@#\1@#' ;;
    *) printf '%s' "$1" | sed -E 's#^([a-z+]+://)[^/@]*@#\1#' ;;
  esac
}

######################################################################
# .what = the unit-relative paths of each scope exclude that falls inside <path>, one per line
######################################################################
grove_backup_scope_excludes_in() {
  local home="$1" path="$2" ex abs
  for ex in "${GROVE_BACKUP_SCOPE_EXCLUDE[@]}"; do
    abs="$home/${ex#\~/}"
    abs="${abs%/}"
    [[ "$abs" == "$path"/* ]] && printf '%s\n' "${abs#"$path"/}"
  done
  return 0
}

######################################################################
# .what = the paths of a FILES unit (a home dir, an orphan, a set-aside) that hold a
#   plaintext credential, by shape or by content → unit-relative, NUL-separated, into <out>
#
# 🛑 .why the SAME cut a tree unit makes: an orphan carries every file it holds, tracked
#   ones too, and every grove's role reads the bucket. a token pasted into `notes.txt` in a
#   dropped worktree is the case a shape alone misses (inventory b18: U=any)
# .why a scope exclude is left out of the list: it never rides, so the manifest need not
#   name the files inside it (the plaintext vault among them)
######################################################################
grove_backup_files_secret_cuts() {
  local home="$1" path="$2" out="$3" rel ex
  local -a scoped
  mapfile -t scoped < <(grove_backup_scope_excludes_in "$home" "$path")
  (cd "$path" && find . -mindepth 1 -maxdepth 1 ! -name .git ! -name node_modules -printf '%P\0') >"$out.top"
  grove_backup_tree_secret_cuts "$path" "$out.top" "$out.raw"
  while IFS= read -r -d '' rel; do
    for ex in "${scoped[@]}"; do [[ "$rel" == "$ex" || "$rel" == "$ex"/* ]] && continue 2; done
    printf '%s\0' "$rel"
  done <"$out.raw" | LC_ALL=C sort -zu >"$out"
  rm -f "$out.top" "$out.raw"
}

######################################################################
# .what = the tar flags that cut what a FILES unit must not carry, one per line
#
#   - `node_modules` at any depth: rebuilt by an install, never work
#   - each scope exclude that falls inside this unit, ANCHORED at its root, so
#     `~/.claude/.credentials.json` cuts that one file and no file of that name
#     deeper down
#   - a top-level `.git`: a files unit holds no git state, and the restore refuses one,
#     since an orphan lands where the walk reads `.git` as a repo (see restore_unit_open)
#   - each credential cut in <cuts>, by its exact path: a shape glob would also cut a dir
#     by its name
######################################################################
grove_backup_pack_excludes() {
  local home="$1" path="$2" cuts="$3" rel
  printf '%s\n' --no-anchored --exclude=node_modules --anchored --exclude=./.git
  while IFS= read -r -d '' rel; do printf -- '--exclude=./%s\n' "$rel"; done <"$cuts"
  while IFS= read -r rel; do printf -- '--exclude=./%s\n' "$rel"; done < <(grove_backup_scope_excludes_in "$home" "$path")
}

######################################################################
# the change check — a quiet unit costs a metadata read, never a pack
######################################################################

# .what = one line that moves whenever a tree's git state moves: its local refs,
#         its HEAD, its index, its reflog, a rebase or merge mid-flight, and the repo
#         state the unit carries (config, info/exclude, hooks)
# .why remote refs are left out: a fetch moves them and changes no work here
grove_backup_tree_fingerprint() {
  local path="$1" gd cd
  gd="$(grove_backup_git "$path" rev-parse --absolute-git-dir 2>/dev/null)" || { printf 'no-git'; return 0; }
  cd="$(grove_backup_git "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  {
    grove_backup_git "$path" for-each-ref --format='%(objectname) %(refname)' refs/heads refs/stash refs/tags
    cat "$gd/HEAD" 2>/dev/null
    stat -c '%n %s %.9Y' "$gd/index" "$gd/logs/HEAD" "$gd/ORIG_HEAD" "$gd/MERGE_HEAD" "$gd/CHERRY_PICK_HEAD" 2>/dev/null
    ls -d "$gd/rebase-merge" "$gd/rebase-apply" 2>/dev/null
    [[ -n "$cd" ]] && stat -c '%n %s %.9Y' "$cd/config" "$cd/info/exclude" "$cd/hooks" "$cd/hooks"/* 2>/dev/null
  } | sha256sum | cut -d' ' -f1
}

# .what = did any file or dir under <path> change since <stamp> was written?
# rc 0 = it moved · 1 = it is quiet
# .why ctime, never mtime: ctime moves on every content change, rename, and
#   delete (a delete moves its dir), and no tool can set it back
# .why the top `.git` is pruned: the fingerprint above reads its git state; each dir the pack
#   never carries is pruned too, so a rebuild never repacks (grove_backup_prune_args)
grove_backup_unit_moved_since() {
  local path="$1" stamp="$2"
  local -a prune
  [[ -f "$stamp" ]] || return 0
  mapfile -d '' -t prune < <(grove_backup_prune_args "$path")
  [[ -n "$(find "$path" "${prune[@]}" -cnewer "$stamp" -print -quit 2>/dev/null)" ]]
}

# .what = did a pack read a still unit? rc 0 = settled · 1 = a file moved under it
# .why a `.jsonl` is skipped: a live conversation appends as a matter of course,
#   and it lands as a whole prefix of itself
grove_backup_pack_settled() {
  local path="$1" stamp="$2"
  local -a prune
  mapfile -d '' -t prune < <(grove_backup_prune_args "$path")
  [[ -z "$(find "$path" "${prune[@]}" \( -type f -o -type l \) ! -name '*.jsonl' -cnewer "$stamp" -print -quit 2>/dev/null)" ]]
}

######################################################################
# the marks — each unit records its own last pass, the moment it lands
#
#   <state>/marks/<id>.json   { unit, at, sha, key, fingerprint, origin_checked }
#   <state>/marks/<id>.stamp  mtime = the pack start, to the nanosecond, for the ctime check
#
# .why `at` is the pack START: a file that changes while the unit packs is newer
#   than the stamp, so the next pass sees it
# .why `key` is the object the mark vouches for: a mark is a claim about the
#   BUCKET, so it counts only while the bucket's index still holds that key. a
#   mark whose object was deleted, or a mark from before keys were kept, counts
#   for naught
######################################################################
grove_backup_mark_id()   { printf '%s' "$1" | sha256sum | cut -c1-32; }
grove_backup_mark_file() { printf '%s/marks/%s.json' "$(grove_backup_state_dir)" "$(grove_backup_mark_id "$1")"; }
# .why `== null`, never `// empty`: jq's `//` reads `false` as absent, so a mark's
#   `origin_checked: false` would read back as no answer at all
grove_backup_mark_get()  { jq -r --arg f "$2" 'if .[$f] == null then empty else .[$f] end' "$(grove_backup_mark_file "$1")" 2>/dev/null; }

# .what = does the bucket's index still hold the object this unit's mark vouches for?
grove_backup_mark_is_in_bucket() {
  local unit="$1" index="$2" key
  key="$(grove_backup_mark_get "$unit" key)"
  [[ -n "$key" ]] || return 1
  awk -F'\t' -v k="$key" '$1 == k { found = 1 } END { exit !found }' "$index"
}

grove_backup_mark_set() {
  local unit="$1" at="$2" sha="$3" fp="$4" checked="$5" key="$6" file tmp
  file="$(grove_backup_mark_file "$unit")"
  mkdir -p "$(dirname "$file")" || return 1
  tmp="$file.tmp.$$"
  jq -n --arg unit "$unit" --argjson at "$at" --arg sha "$sha" --arg key "$key" --arg fp "$fp" --argjson checked "$checked" \
    '{ unit: $unit, at: ($at | floor), sha: $sha, key: $key, fingerprint: $fp, origin_checked: $checked }' >"$tmp" \
    && mv -f "$tmp" "$file" \
    && touch -d "@$at" "${file%.json}.stamp"
}

######################################################################
# the tree pack — a tree carries exactly what origin and its own HEAD cannot
#   rebuild, and needs no other unit to restore
#
#   .grove-backup/objects.pack      every commit, tree, and blob the kept refs
#                                   reach that origin lacks — a plain git pack
#   .grove-backup/refs.txt          "<sha> <ref>" for HEAD, its branches, the stash, tags
#   .grove-backup/checkout/         HEAD, the index, HEAD's reflog, a rebase or merge mid-flight
#   .grove-backup/repo/             branch + remote config (urls cleaned), info/exclude, edited hooks
#   .grove-backup/staged/<path>     the index's copy of each staged file
#   .grove-backup/meta.json         { version, kind, head_sha, head_ref, origin, origin_checked,
#                                     deletes, staged, point_in_time }
#   <path>                          each file that differs from HEAD, untracked, or ignored and kept
#
# .why a plain pack and never a `git bundle`: a bundle refuses to exist when
#   every ref tip is already on origin, yet a reflog-only commit still owes a ride
# .why "on origin" is asked of origin NOW (`ls-remote`), never of this box's
#   remote refs: a branch deleted or force-pushed since the last fetch would
#   leave commits that origin no longer holds out of the pack
# 🛑 .why a unit leans ONLY on origin's default branch and its tags, never on a branch
#   a quiet unit never asks origin again, so whatever it leans on must outlive the pass.
#   a pr branch is deleted at merge, and a squash merge leaves its commits on no branch:
#   a unit that leaned on one would lose every commit above it, with its status ✓. the
#   default branch and tags move forward only; a commit only a pr branch holds rides in
#   the unit, at the cost of a few commits. a force-push to the default branch is the
#   one residual, and the restore asks origin for each absent sha before it gives up
######################################################################

# .what = the shas origin's default branch and tags hold now, that this repo also holds →
#   one per line in $2
# rc 0 = origin answered · 1 = no origin · 2 = origin did not answer (this box's own
#   view of origin is written instead, so the pack stays small, and the unit packs again)
grove_backup_origin_shas() {
  local path="$1" out="$2" raw
  raw="$out.raw"
  grove_backup_git "$path" remote get-url origin >/dev/null 2>&1 || { : >"$out"; return 1; }
  if timeout -k 5 60 env GIT_TERMINAL_PROMPT=0 git -c safe.directory='*' -C "$path" ls-remote origin HEAD 'refs/tags/*' >"$raw" 2>/dev/null </dev/null; then
    cut -f1 "$raw" | sort -u \
      | grove_backup_git "$path" cat-file --batch-check='%(objectname) %(objecttype)' 2>/dev/null \
      | awk '$2 == "commit" || $2 == "tag" { print $1 }' >"$out"
    rm -f "$raw"
    return 0
  fi
  rm -f "$raw"
  # the same lean, as this box last saw it: origin's default branch and the tags
  if grove_backup_git "$path" rev-parse -q --verify refs/remotes/origin/HEAD >/dev/null; then
    grove_backup_git "$path" for-each-ref --format='%(objectname)' refs/remotes/origin/HEAD refs/tags | sort -u >"$out"
    return 2
  fi
  grove_backup_git "$path" for-each-ref --format='%(objectname)' refs/remotes/origin | sort -u >"$out"
  return 2
}

# .what = the refs a unit keeps → "<sha> <ref>" lines
# .why a clone keeps every branch; a worktree keeps its own HEAD and branch —
#   and each keeps the stash, shared by every tree of the clone
grove_backup_tree_refs() {
  local path="$1" kind="$2" head branch
  head="$(grove_backup_git "$path" rev-parse -q --verify HEAD 2>/dev/null)"
  branch="$(grove_backup_git "$path" symbolic-ref -q HEAD 2>/dev/null)"
  [[ -n "$head" ]] && printf '%s HEAD\n' "$head"
  if [[ "$kind" == clone ]]; then
    grove_backup_git "$path" for-each-ref --format='%(objectname) %(refname)' refs/heads refs/tags refs/stash
    return 0
  fi
  [[ -n "$branch" && -n "$head" ]] && printf '%s %s\n' "$head" "$branch"
  grove_backup_git "$path" for-each-ref --format='%(objectname) %(refname)' refs/stash
}

# .what = every sha a reflog of this tree holds — an undo the restore keeps
grove_backup_tree_reflog_shas() {
  local path="$1" kind="$2" branch
  grove_backup_git "$path" reflog show --format=%H HEAD 2>/dev/null
  grove_backup_git "$path" reflog show --format=%H refs/stash 2>/dev/null
  if [[ "$kind" == clone ]]; then
    grove_backup_git "$path" for-each-ref --format='%(refname)' refs/heads \
      | while read -r branch; do grove_backup_git "$path" reflog show --format=%H "$branch" 2>/dev/null; done
    return 0
  fi
  branch="$(grove_backup_git "$path" symbolic-ref -q HEAD 2>/dev/null)"
  [[ -n "$branch" ]] && grove_backup_git "$path" reflog show --format=%H "$branch" 2>/dev/null
  return 0
}

# .what = is an ignored path one of the dirs a build or an install rebuilds? (by its basename)
grove_backup_dir_is_rebuilt() {
  local base="${1%/}" want
  base="${base##*/}"
  for want in "${GROVE_BACKUP_REBUILT_DIRS[@]}"; do [[ "$base" == "$want" ]] && return 0; done
  return 1
}

# .what = the dirs of a tree that git ignores AND a build rebuilds, tree-relative, NUL-separated
# .why the ONE answer to "what does this tree's unit never carry, by dir": the pack cuts
#   these, and the change checks prune them, so the two can never disagree. a dir not
#   under git (a home unit) has none
grove_backup_tree_rebuilt_dirs() {
  local path="$1" rel
  grove_backup_git "$path" ls-files -z --others --ignored --exclude-standard --directory 2>/dev/null \
    | while IFS= read -r -d '' rel; do
        grove_backup_dir_is_rebuilt "$rel" && printf '%s\0' "${rel%/}"
      done
}

# .what = the find(1) args that prune what the change checks must not watch: the unit's own
#   top `.git` (the fingerprint reads it), node_modules, and each rebuilt dir this tree ignores
# .why only the TOP `.git`: a nested repo rides in the tar whole, and the fingerprint never
#   reads it, so a commit there moves only `sub/.git/**`. pruned too, that commit would ride
#   in no object. a nested `.git` that churns costs a repack, never a lost commit
grove_backup_prune_args() {
  local path="$1" rel
  printf '%s\0' '(' -path "$path/.git" -o -name node_modules
  while IFS= read -r -d '' rel; do printf '%s\0' -o -path "$path/$rel"; done < <(grove_backup_tree_rebuilt_dirs "$path")
  printf '%s\0' ')' -prune -o
}

# .what = the tree-relative paths a unit carries, NUL-separated, into $2
grove_backup_tree_files() {
  local path="$1" out="$2" has_head="$3" rel flag
  {
    # what differs from HEAD, staged or not (a delete is listed, then dropped below)
    if [[ "$has_head" == yes ]]; then
      grove_backup_git "$path" diff -z --name-only --no-renames HEAD
    else
      grove_backup_git "$path" ls-files -z --cached
    fi
    # what git does not track, and does not ignore
    grove_backup_git "$path" ls-files -z --others --exclude-standard --directory --no-empty-directory
    # what git ignores — kept, but for the dirs a build or an install rebuilds
    grove_backup_git "$path" ls-files -z --others --ignored --exclude-standard --directory \
      | while IFS= read -r -d '' rel; do
          grove_backup_dir_is_rebuilt "$rel" && continue
          printf '%s\0' "$rel"
        done
    # a file git is told to trust blind: packed whole, since git would vouch for it falsely
    grove_backup_git "$path" ls-files -z -v \
      | while IFS= read -r -d '' rel; do
          flag="${rel:0:1}"
          [[ "$flag" == S || "$flag" =~ [a-z] ]] && printf '%s\0' "${rel:2}"
        done
  } | sort -zu | while IFS= read -r -d '' rel; do
        rel="${rel%/}"
        [[ -e "$path/$rel" || -L "$path/$rel" ]] && printf '%s\0' "$rel"
      done >"$out"
}

# .what = stage 1 of a tree unit: its refs, and one verified pack of the objects origin lacks
# usage: grove_backup_stage_objects <path> <kind> <stage .grove-backup dir> <work dir>
# rc 0 ok · 2 fault (GROVE_BACKUP_PACK_WHY)
grove_backup_stage_objects() {
  local path="$1" kind="$2" gb="$3" work="$4" rc
  grove_backup_tree_refs "$path" "$kind" | sort -u -k2 >"$gb/refs.txt"
  # ⚠️ an `if`, never `[[ … ]] && …`: the group's status is its last command's, and
  #   under pipefail a false test with no origin fails the whole pack
  {
    cut -d' ' -f1 "$gb/refs.txt"
    grove_backup_tree_reflog_shas "$path" "$kind"
    if [[ -s "$work/origin.shas" ]]; then echo --not; cat "$work/origin.shas"; fi
  } | grove_backup_git "$path" pack-objects --revs --stdout -q >"$gb/objects.pack" 2>"$work/pack.err"
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    GROVE_BACKUP_PACK_WHY="git pack-objects failed: $(head -n 1 "$work/pack.err")"
    return 2
  fi
  if ! git index-pack -o "$work/check.idx" "$gb/objects.pack" >/dev/null 2>"$work/pack.err"; then
    GROVE_BACKUP_PACK_WHY="the objects pack does not verify: $(head -n 1 "$work/pack.err")"
    return 2
  fi
  rm -f "$work/check.idx"
}

# .what = stage 2 of a tree unit: the checkout state — this tree's own git dir files and reflogs
# usage: grove_backup_stage_checkout <git dir> <common dir> <stage .grove-backup dir> <kind> <head ref>
# rc 0 staged · 2 a copy failed (GROVE_BACKUP_PACK_WHY)
# .why each copy is asked: a unit that silently lacks its index or HEAD would ship under a ✓,
#   and its restore would lay a tree with none. an entry a live git act removed between the
#   test and the copy (ORIG_HEAD, MERGE_HEAD) is no fault: the tree simply no longer holds it
grove_backup_stage_checkout() {
  local gd="$1" cd="$2" gb="$3" kind="$4" head_ref="$5" rel
  for rel in "${GROVE_BACKUP_UNIT_GIT_STATE[@]}" logs/HEAD; do
    [[ -e "$gd/$rel" ]] || continue
    grove_backup_stage_copy "$gd/$rel" "$gb/checkout/$rel" || return 2
  done
  [[ -d "$cd/logs/refs" ]] || return 0
  # a clone keeps every ref's reflog; a worktree keeps its own branch's, and the stash's
  if [[ "$kind" == clone ]]; then
    grove_backup_stage_copy "$cd/logs/refs" "$gb/checkout/logs/refs" || return 2
    return 0
  fi
  for rel in "${head_ref#refs/}" stash; do
    [[ -n "$rel" && -f "$cd/logs/refs/$rel" ]] || continue
    grove_backup_stage_copy "$cd/logs/refs/$rel" "$gb/checkout/logs/refs/$rel" || return 2
  done
  return 0
}

# .what = copy one git dir entry into the stage; a source gone since its test is no fault
# usage: grove_backup_stage_copy <src> <dst>   · rc 0 · 1 a fault (GROVE_BACKUP_PACK_WHY)
grove_backup_stage_copy() {
  local src="$1" dst="$2"
  mkdir -p -- "$(dirname "$dst")" && cp -a -- "$src" "$dst" && return 0
  [[ -e "$src" || -L "$src" ]] || return 0
  GROVE_BACKUP_PACK_WHY="${src##*/.git/} could not be staged"
  return 1
}

# .what = stage 3 of a tree unit: the repo config — branch upstreams and remotes, only the
#   keys grove_backup_config_key_is_carried allows, every url cleaned — plus its
#   info/exclude and its live hooks
# usage: grove_backup_stage_repo_config <path> <common dir> <stage .grove-backup dir> <the manifest's origin>
# .why origin's url is written as the manifest names it, the url git resolves: a raw value a
#   `url.insteadOf` rewrites would differ from it, and the restore drops a url that differs
# .why `git config --get-regexp` exits 1 when no key matches (a repo with no origin and no
#   upstream), and the agent runs under pipefail: so 1 reads as an empty list, and only a
#   higher code (an unreadable config) fails the stage
grove_backup_stage_repo_config() {
  local path="$1" cd="$2" gb="$3" origin="$4" key value hook
  { grove_backup_git "$path" config --get-regexp '^(branch|remote)\.' 2>/dev/null; [[ $? -le 1 ]]; } \
    | while read -r key value; do
        grove_backup_config_key_is_carried "$key" || continue
        if [[ "${key,,}" == remote.origin.url ]]; then
          [[ -n "$origin" ]] || continue
          value="$origin"
        fi
        [[ "$key" == *.url || "$key" == *.pushurl ]] && value="$(grove_backup_url_clean "$value")"
        printf '%s %s\n' "$key" "$value" || exit 1
      done >"$gb/repo/config.list" \
    || { GROVE_BACKUP_PACK_WHY="the repo config could not be staged"; return 2; }
  # the CONTENT of each, never the file: a hook a clone links in (a shared hooks dir) rides as
  #   the bytes it resolves to, so no link ever lands in .grove-backup, where the reader
  #   refuses one (grove_backup_unit_members_are_plain)
  if [[ -f "$cd/info/exclude" ]]; then
    cat -- "$cd/info/exclude" >"$gb/repo/exclude" \
      || { GROVE_BACKUP_PACK_WHY="info/exclude could not be staged"; return 2; }
  fi
  for hook in "$cd"/hooks/*; do
    [[ "$hook" != *.sample ]] || continue
    [[ -f "$hook" ]] || { [[ -L "$hook" ]] && echo "   ⚠️ ${path##*/} · hook ${hook##*/} links to no file; it does not ride" >&2; continue; }
    { mkdir -p "$gb/repo/hooks" && cat -- "$hook" >"$gb/repo/hooks/${hook##*/}"; } \
      || { GROVE_BACKUP_PACK_WHY="hook ${hook##*/} could not be staged"; return 2; }
  done
  return 0
}

# .what = stage 4 of a tree unit: the index's blob of each staged file, since no ref reaches it
# usage: grove_backup_stage_staged <path> <stage .grove-backup dir> <head sha, or empty>
grove_backup_stage_staged() {
  local path="$1" gb="$2" head_sha="$3" rel
  grove_backup_git "$path" diff -z --cached --name-only --no-renames ${head_sha:+HEAD} 2>/dev/null \
    | while IFS= read -r -d '' rel; do
        grove_backup_name_is_secret_shaped "$rel" && continue
        grove_backup_git "$path" cat-file -e ":$rel" 2>/dev/null || continue
        { mkdir -p -- "$gb/staged/$(dirname -- "$rel")" && grove_backup_git "$path" cat-file blob ":$rel" >"$gb/staged/$rel"; } \
          || exit 1
      done \
    || { GROVE_BACKUP_PACK_WHY="a staged copy could not be written to the stage"; return 2; }
  return 0
}

######################################################################
# .what = pack one tree into a gz temp file; writes the sha256 of its tar to <out.gz>.sha
#
# .why the hash is of the uncompressed tar: a gzip upgrade changes every
#   compressed byte and none of the content
# .why deterministic (`--sort=name`, numeric owner, sorted lists, the stage's
#   mtimes pinned): an unchanged tree must hash the same on every pass, or the
#   skip on the bucket's latest object never fires
#
# usage: grove_backup_pack_tree <kind> <path> <out.gz> <work dir> <point in time: true|false>
# rc 0 ok · 2 fault (GROVE_BACKUP_PACK_WHY) · 4 its bytes do not fit the disk (named) ·
#   sets GROVE_BACKUP_ORIGIN_CHECKED
######################################################################
grove_backup_pack_tree() {
  local kind="$1" path="$2" out="$3" work="$4" pit="$5"
  local stage="$work/stage" gb gd cd head_sha head_ref origin origin_rc checked rc sha rel need
  # 🛑 no shape glob reaches tar: a glob matches a DIR too, so `src/credentials/` would ride
  #   out silently under a ✓. each cut is an exact file path, computed and named below
  local -a excludes=(--no-anchored --exclude=node_modules --anchored)
  grove_backup_scratch_clear "$stage" "$work/unit.tar"
  gb="$stage/.grove-backup"
  mkdir -p "$gb/checkout" "$gb/repo" "$gb/staged" || { GROVE_BACKUP_PACK_WHY="the stage could not be made"; return 2; }

  gd="$(grove_backup_git "$path" rev-parse --absolute-git-dir 2>/dev/null)" \
    || { GROVE_BACKUP_PACK_WHY="git does not read this tree"; return 2; }
  cd="$(grove_backup_git "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  head_sha="$(grove_backup_git "$path" rev-parse -q --verify HEAD 2>/dev/null)"
  head_ref="$(grove_backup_git "$path" symbolic-ref -q HEAD 2>/dev/null)"
  origin="$(grove_backup_url_clean "$(grove_backup_git "$path" remote get-url origin 2>/dev/null)")"

  # 1. the objects origin lacks
  # .why an origin no restore reads (a relative path, an unknown scheme) never fails the unit:
  #   it packs as a repo with no origin, every commit in it, so the tree still comes back whole
  if [[ -n "$origin" ]] && ! grove_backup_url_is_plain "$origin"; then
    echo "   ⚠️ ${path##*/} · its origin is no url a restore reads; it rides as a repo with no origin, every commit in it" >&2
    origin=""
    : >"$work/origin.shas"
    origin_rc=1
  else
    grove_backup_origin_shas "$path" "$work/origin.shas"
    origin_rc=$?
  fi
  checked=true
  [[ "$origin_rc" -eq 2 ]] && checked=false
  GROVE_BACKUP_ORIGIN_CHECKED="$checked"
  grove_backup_stage_objects "$path" "$kind" "$gb" "$work" || return 2

  # 2–4. the checkout state, the repo config, the staged copies
  grove_backup_stage_checkout "$gd" "$cd" "$gb" "$kind" "$head_ref" || return 2
  grove_backup_stage_repo_config "$path" "$cd" "$gb" "$origin" || return 2
  grove_backup_stage_staged "$path" "$gb" "$head_sha" || return 2

  # 5. the files, less the dirs a build rebuilds and each plaintext credential
  grove_backup_tree_files "$path" "$work/files" "$([[ -n "$head_sha" ]] && echo yes || echo no)"
  while IFS= read -r -d '' rel; do excludes+=("--exclude=$rel"); done < <(grove_backup_tree_rebuilt_dirs "$path")
  grove_backup_tree_secret_cuts "$path" "$work/files" "$work/cuts"
  grove_backup_staged_secret_cuts "$gb/staged" >>"$work/cuts"
  grove_backup_staged_secret_cuts "$gb/repo" .grove-backup/repo/ >>"$work/cuts"
  while IFS= read -r -d '' rel; do excludes+=("--exclude=$rel"); done <"$work/cuts"

  # the disk: this unit's bytes land three times (the tar, the admit's unpack, then its gz),
  #   and must leave the floor free
  need=$(( 3 * ( $(grove_backup_files_kb "$path" "$work/files") + $(du -k "$gb/objects.pack" | cut -f1) ) ))
  grove_backup_disk_fits "$work" "$need" || { GROVE_BACKUP_PACK_WHY="disk · $GROVE_BACKUP_DISK_WHY"; return 4; }

  # 6. the manifest
  jq -n \
    --arg kind "$kind" --arg head_sha "$head_sha" --arg head_ref "$head_ref" --arg origin "$origin" \
    --argjson checked "$checked" --argjson pit "$pit" --argjson version "$GROVE_BACKUP_UNIT_VERSION" \
    --rawfile deletes <(if [[ -n "$head_sha" ]]; then grove_backup_git "$path" diff -z --name-only --no-renames --diff-filter=D HEAD; fi) \
    --rawfile staged <(cd "$gb/staged" && find . -type f -printf '%P\0' | sort -z) \
    --rawfile cut <(LC_ALL=C sort -zu "$work/cuts") \
    '{ version: $version, kind: $kind,
       head_sha: (if $head_sha == "" then null else $head_sha end),
       head_ref: (if $head_ref == "" then null else $head_ref end),
       origin: (if $origin == "" then null else $origin end),
       origin_checked: $checked,
       deletes: ($deletes | split("\u0000") | map(select(. != ""))),
       staged: ($staged | split("\u0000") | map(select(. != ""))),
       cut: ($cut | split("\u0000") | map(select(. != ""))),
       point_in_time: $pit }' >"$gb/meta.json" \
    || { GROVE_BACKUP_PACK_WHY="the manifest could not be written"; return 2; }

  # the stage is written fresh each pack, so its mtimes are pack-time noise: pin them
  tar --no-wildcards -C "$stage" --sort=name --numeric-owner --mtime=@0 -cf "$work/unit.tar" .grove-backup 2>"$work/tar.err" \
    || { GROVE_BACKUP_PACK_WHY="tar failed: $(head -n 1 "$work/tar.err")"; return 2; }
  if [[ -s "$work/files" ]]; then
    tar --no-wildcards "${excludes[@]}" -C "$path" --sort=name --numeric-owner \
      -rf "$work/unit.tar" --null -T "$work/files" 2>"$work/tar.err"
    rc=$?
    # 1 = a file changed as tar read it: the settle check after the pack judges that
    if [[ "$rc" -ge 2 ]]; then
      GROVE_BACKUP_PACK_WHY="tar failed: $(grep -v 'changed as we read it\|removed before we read it' "$work/tar.err" | head -n 1)"
      return 2
    fi
  fi

  # the reader's own admit, asked of exactly what will leave: a unit the restore would refuse
  #   is a fault here, named, never a ✓ on a tree that cannot come back
  grove_backup_pack_admit "$work/unit.tar" "$work/admit" tree || return 2

  gzip -n <"$work/unit.tar" >"$out" 2>"$work/gz.err" \
    || { GROVE_BACKUP_PACK_WHY="the temp tar could not be written: $(head -n 1 "$work/gz.err")"; return 2; }
  sha="$(sha256sum <"$work/unit.tar")"
  grove_backup_scratch_clear "$stage" "$work/unit.tar"
  printf '%s\n' "${sha%% *}" >"$out.sha"
}

######################################################################
# .what = is each path tar saw change one a live brain changes as a matter of course?
#
# .why a live conversation APPENDS to its `.jsonl` files and adds new ones to its
#   dirs, every minute. to fail the unit on that would fail `.claude` on every
#   run of every busy grove — a check that cries wolf (inventory b10)
#
# .the rule, `.claude` only
#   - a `*.jsonl` file: an append; the unit lands with its last line maybe torn
#   - a dir: an entry came or went; the new entry rides the next run
#   - aught else (a settings file rewritten mid-read): b9's retry
#
# usage: grove_backup_pack_change_is_live <unit path> <changed path>…
######################################################################
grove_backup_pack_change_is_live() {
  local path="$1" changed
  shift
  [[ "$path" == */.claude ]] || return 1
  for changed in "$@"; do
    [[ "$changed" == *.jsonl ]] && continue
    [[ -d "$path/$changed" ]] && continue
    return 1
  done
  return 0
}

######################################################################
# .what = tar one FILES unit (a home dir, an orphan, a set-aside) into a gz temp file,
#         then hash its UNCOMPRESSED bytes
#
#   .grove-backup/meta.json   { version, kind, cut } — the restore names each cut path
#   ./<path>                  each file the unit holds, less its cuts
#
# .why deterministic (`--sort=name`, numeric owner, `gzip -n`, the manifest's mtime pinned):
#   an untouched unit must hash the same on every pass, or the skip never fires
# .why a temp FILE and not a stream to s3: the skip needs the hash before the put
#
# usage: grove_backup_pack_home <home> <path> <out.gz> <kind>
# writes the sha256 to <out>.sha; rc 0 ok · 1 changed while read (retry-worthy) · 2 fault
# sets GROVE_BACKUP_PACK_WHY on rc 1 or 2
######################################################################
grove_backup_pack_home() {
  local home="$1" path="$2" out="$3" kind="$4"
  local errf="$out.tarerr" gzerr="$out.gzerr" cuts="$out.cuts" stage="$out.stage" tar_rc gz_rc sha
  local -a flags changed codes

  # the cuts, then the manifest that names them
  grove_backup_files_secret_cuts "$home" "$path" "$cuts"
  grove_backup_scratch_clear "$stage" && mkdir -p "$stage/.grove-backup" || { GROVE_BACKUP_PACK_WHY="the stage could not be made"; return 2; }
  jq -n --arg kind "$kind" --argjson version "$GROVE_BACKUP_UNIT_VERSION" --rawfile cut "$cuts" \
    '{ version: $version, kind: $kind, cut: ($cut | split("\u0000") | map(select(. != ""))) }' \
    >"$stage/.grove-backup/meta.json" || { GROVE_BACKUP_PACK_WHY="the manifest could not be written"; return 2; }
  touch -d @0 "$stage/.grove-backup/meta.json" "$stage/.grove-backup"
  mapfile -t flags < <(grove_backup_pack_excludes "$home" "$path" "$cuts")

  # ⚠️ both exit codes in ONE read: an assignment is a command, so a second
  #   `${PIPESTATUS[1]}` after `tar_rc=${PIPESTATUS[0]}` reads a reset array
  # .why the manifest leads, from its own stage: the excludes name `./<path>` members only
  tar --no-wildcards --sort=name --numeric-owner -cf - -C "$stage" .grove-backup "${flags[@]}" -C "$path" . 2>"$errf" \
    | gzip -n 2>"$gzerr" >"$out"
  codes=("${PIPESTATUS[@]}")
  tar_rc="${codes[0]}"
  gz_rc="${codes[1]}"
  grove_backup_scratch_clear "$stage" "$cuts"

  if [[ "$gz_rc" -ne 0 ]]; then
    GROVE_BACKUP_PACK_WHY="the temp tar could not be written: $(head -n 1 "$gzerr")"
    return 2
  fi
  if [[ "$tar_rc" -ge 2 ]]; then
    GROVE_BACKUP_PACK_WHY="tar failed: $(grep -v 'changed as we read it\|removed before we read it' "$errf" | head -n 1)"
    return 2
  fi
  if [[ "$tar_rc" -eq 1 ]]; then
    mapfile -t changed < <(sed -n -e 's#^tar: \./\(.*\): file changed as we read it$#\1#p' \
                                  -e 's#^tar: \./\(.*\): [Ff]ile removed before we read it$#\1#p' "$errf")
    if [[ "${#changed[@]}" -eq 0 ]] || ! grove_backup_pack_change_is_live "$path" "${changed[@]}"; then
      GROVE_BACKUP_PACK_WHY="changed as it was read: ${changed[0]:-$(head -n 1 "$errf")}"
      return 1
    fi
  fi

  # the reader's own admit, asked of exactly what will leave (as the tree pack asks): a name
  #   the restore refuses would land a ✓ on a unit that cannot come back
  grove_backup_pack_admit "$out" "$out.admit" files || return 2

  sha="$(gzip -dc "$out" | sha256sum)"
  printf '%s\n' "${sha%% *}" >"$out.sha"
}

######################################################################
# the status — one file, world-readable, the one source every surface renders
#
#   { version, grove, began, at, verdict: ok|failed, cause, fix,
#     units, put, skipped, failed, failures: [{unit, why}], origin_unchecked, last_ok }
#
# .why `last_ok` is carried across a failed run: STALE is judged from the last
#   GOOD run, so a box that fails every hour still ages toward ✗ STALE
# .why `origin_unchecked` (GROVE_BACKUP_ORIGIN_UNCHECKED) counts the trees whose origin did
#   not answer this pass: each packed against this box's view of origin, and packs again
#   every pass until it answers, so a lapsed git credential reads here, not in the journal
######################################################################
grove_backup_status_write() {
  local began="$1" verdict="$2" cause="$3" fix="$4" units="$5" put="$6" skipped="$7" failures_file="$8"
  local file at last_ok tmp
  file="$(grove_backup_status_file)"
  at="$(grove_backup_now)"
  last_ok="$(jq -r '.last_ok // empty' "$file" 2>/dev/null)"
  [[ "$verdict" == ok ]] && last_ok="$(grove_backup_iso "$at")"

  tmp="$file.tmp.$$"
  jq -n \
    --arg grove "${GROVE_BACKUP_GROVE:-}" \
    --arg began "$(grove_backup_iso "$began")" \
    --arg at "$(grove_backup_iso "$at")" \
    --arg verdict "$verdict" --arg cause "$cause" --arg fix "$fix" \
    --argjson units "$units" --argjson put "$put" --argjson skipped "$skipped" \
    --arg last_ok "$last_ok" --argjson unchecked "${GROVE_BACKUP_ORIGIN_UNCHECKED:-0}" \
    --slurpfile failures "$failures_file" \
    '{ version: 1,
       grove: (if $grove == "" then null else $grove end),
       began: $began, at: $at, verdict: $verdict,
       cause: (if $cause == "" then null else $cause end),
       fix: (if $fix == "" then null else $fix end),
       units: $units, put: $put, skipped: $skipped,
       failed: ($failures | length), failures: $failures,
       origin_unchecked: $unchecked,
       last_ok: (if $last_ok == "" then null else $last_ok end) }' >"$tmp" || return 1
  chmod 644 "$tmp" && mv -f "$tmp" "$file"
}

# .what = an age in seconds, as a human reads it: 20m · 3h · 2d
grove_backup_age() {
  local secs="$1"
  [[ "$secs" -lt 0 ]] && secs=0
  [[ "$secs" -lt 3600 ]] && { printf '%dm' $((secs / 60)); return; }
  [[ "$secs" -lt 172800 ]] && { printf '%dh' $((secs / 3600)); return; }
  printf '%dd' $((secs / 86400))
}

# .what = seconds since an iso stamp this library wrote
grove_backup_age_of() {
  local then
  then="$(date -u -d "${1/Z/ UTC}" +%s 2>/dev/null)" || return 1
  printf '%d' $(( $(grove_backup_now) - then ))
}

######################################################################
# .what = the ONE line every surface prints — verify, `rhx grove.backup.get`,
#         and infra's `git.grove.stats` (which reads the same file)
#
#   ✓ 20m ago · 3 put · 9 skipped
#   ✗ FAILED · <cause> · 4m · last ok 5d ago      ✗ FAILED · <cause> · 4m · never ok
#   ✗ STALE · last ok 9h ago        ✗ STALE · never
#   ⏳ the first run is at work      ⏳ a pass is at work · last ok 9h ago
#   ✗ NOT ENROLLED
#
# usage: grove_backup_status_line [enrolled]   # enrolled = the timer is in place
# rc 0 on ✓, 1 on all else
######################################################################
# .what = is a backup run at work now? (a oneshot unit reads `activating` while it runs)
grove_backup_run_active() {
  [[ "$(systemctl show -p ActiveState --value grove-backup.service 2>/dev/null)" == activating ]]
}

grove_backup_status_line() {
  local enrolled="${1:-}" file verdict cause at last_ok put skipped age ok_age ok_secs
  file="$(grove_backup_status_file)"

  # 🛑 a pass writes its status only at its end, and a box's first pass packs
  #   every tree. without this arm, every surface read `✗ STALE · never` over a
  #   healthy first pass
  if [[ ! -f "$file" ]] && grove_backup_run_active; then
    echo "⏳ the first run is at work"
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    [[ "$enrolled" == enrolled ]] && { echo "✗ STALE · never"; return 1; }
    echo "✗ NOT ENROLLED"
    return 1
  fi

  verdict="$(jq -r '.verdict // "?"' "$file" 2>/dev/null)"
  cause="$(jq -r '.cause // "?"' "$file" 2>/dev/null)"
  at="$(jq -r '.at // empty' "$file" 2>/dev/null)"
  last_ok="$(jq -r '.last_ok // empty' "$file" 2>/dev/null)"
  put="$(jq -r '.put // 0' "$file" 2>/dev/null)"
  skipped="$(jq -r '.skipped // 0' "$file" 2>/dev/null)"

  # a failed pass names when the backup last SUCCEEDED: the timer rewrites the failed
  #   pass's own end time every 3 hours, so that age alone says naught of what is safe
  if [[ "$verdict" != ok ]]; then
    age="$(grove_backup_age_of "$at")" && age=" · $(grove_backup_age "$age")" || age=""
    ok_age=" · never ok"
    if [[ -n "$last_ok" ]] && ok_secs="$(grove_backup_age_of "$last_ok")"; then
      ok_age=" · last ok $(grove_backup_age "$ok_secs") ago"
    fi
    echo "✗ FAILED · ${cause}${age}${ok_age}"
    return 1
  fi

  age="$(grove_backup_age_of "$last_ok")" || { echo "✗ FAILED · the status file is unreadable: $file"; return 1; }
  # a long pass at work is no stale backup, up to GROVE_BACKUP_PASS_BOUND_SECS: past it,
  #   even a pass at work has run too long to vouch for, and the line goes ✗
  if [[ "$age" -gt "$GROVE_BACKUP_STALE_SECS" && "$age" -le "$GROVE_BACKUP_PASS_BOUND_SECS" ]] && grove_backup_run_active; then
    echo "⏳ a pass is at work · last ok $(grove_backup_age "$age") ago"
    return 1
  fi
  if [[ "$age" -gt "$GROVE_BACKUP_STALE_SECS" ]]; then
    echo "✗ STALE · last ok $(grove_backup_age "$age") ago"
    return 1
  fi
  echo "✓ $(grove_backup_age "$age") ago · $put put · $skipped skipped"
}
