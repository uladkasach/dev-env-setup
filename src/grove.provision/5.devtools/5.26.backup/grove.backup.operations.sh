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
GROVE_BACKUP_REBUILT_DIRS=(dist build coverage .next)

# a grove slug, and an s3 bucket name — a declaration that fails its shape is a fault
GROVE_BACKUP_SLUG_PATTERN='^[a-z0-9][a-z0-9-]{0,62}$'
GROVE_BACKUP_BUCKET_PATTERN='^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$'

# a status older than this reads ✗ STALE: eight missed passes of the 15-minute timer
GROVE_BACKUP_STALE_SECS=7200

# every aws call is bounded, so a hung endpoint fails one run and never holds the timer
GROVE_BACKUP_AWS_TIMEOUT_SECS=900

######################################################################
# the box facts — each a function, so a play can point it at a fixture
######################################################################
grove_backup_name_file()   { printf '/etc/grove/name'; }
grove_backup_bucket_file() { printf '/etc/grove/backup.bucket'; }
grove_backup_seat_home()   { printf '%s' "$HOME"; }
grove_backup_state_dir()   { printf '/var/lib/grove-backup'; }
grove_backup_status_file() { printf '%s/status.json' "$(grove_backup_state_dir)"; }
grove_backup_now()         { date -u +%s; }
# .why a stamp to the nanosecond: an edit in the same second as a pack start, but
#   before it, must never read as newer than the pack
grove_backup_now_precise() { date -u +%s.%N; }
grove_backup_today()       { date -u -d "@$(grove_backup_now)" +%F; }
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
  timeout "$GROVE_BACKUP_AWS_TIMEOUT_SECS" aws "$@" >"$out" 2>"$errf"
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
  [[ "$rc" -eq 124 ]] && GROVE_BACKUP_AWS_ERR="no answer from aws in ${GROVE_BACKUP_AWS_TIMEOUT_SECS}s"
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
grove_backup_s3_list() {
  local prefix="$1" out="$2" raw rc
  raw="$(mktemp)"
  grove_backup_aws s3:ListBucket "$raw" s3api list-objects-v2 \
    --bucket "$GROVE_BACKUP_BUCKET" --prefix "$prefix" \
    --query 'Contents[].[Key,LastModified,StorageClass]' --output text
  rc=$?
  # an empty list prints `None`, which is no key
  [[ "$rc" -eq 0 ]] && grep -v '^None$' "$raw" >"$out"
  rm -f "$raw"
  return "$rc"
}

# the grove prefixes at the bucket root → one `grove=<slug>/` per line in $1
grove_backup_s3_prefixes() {
  local out="$1" raw rc
  raw="$(mktemp)"
  grove_backup_aws s3:ListBucket "$raw" s3api list-objects-v2 \
    --bucket "$GROVE_BACKUP_BUCKET" --delimiter / \
    --query 'CommonPrefixes[].Prefix' --output text
  rc=$?
  [[ "$rc" -eq 0 ]] && tr '\t' '\n' <"$raw" | grep -v '^None$' | grep -v '^$' >"$out"
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
    GROVE_BACKUP_FIX="the credential probe failed: ${GROVE_BACKUP_AWS_ERR:-（no stderr）}"
    return 2
  fi
  return 0
}

# .what = the cause and fix for a grant the bucket refused (the fourth reach)
grove_backup_cause_denied() {
  GROVE_BACKUP_CAUSE="access denied: ${GROVE_BACKUP_AWS_VERB:-s3}"
  GROVE_BACKUP_FIX="owed by ahbode/infrastructure: the \`grove-s3\` grant (infra#63)"
}

######################################################################
# keys — the one shape every object takes
#
#   grove=<slug>/user=<seat>/org=<org>/repo=<repo>/tree=<dir>/date=<YYYY-MM-DD>.tar.gz
#   grove=<slug>/user=<seat>/home=<.claude|.rhachet>/date=<YYYY-MM-DD>.tar.gz
#
# .why `date=` marks the day a unit last CHANGED, never the day of the run: an
#   untouched clone is put once, ever (F8)
# .why a clone's `tree=` is its repo name: the clone is the tree its repo holds
######################################################################
grove_backup_key() { printf 'grove=%s/%s/date=%s.tar.gz' "$1" "$2" "$3"; }

# .what = "1 commit", "3 commits" — a count with its noun, singular at one
plural() { [[ "$1" -eq 1 ]] && printf '1 %s' "$2" || printf '%s %ss' "$1" "$2"; }

# .what = top-level bucket prefixes on stdin → one grove slug per line
# .why the bucket holds prefixes that are no grove's (infra keeps a `probe/` one);
#   read as a grove, each would render a row with no backup and a made-up date
grove_backup_groves_of_prefixes() {
  local p
  while IFS= read -r p; do
    [[ "$p" == grove=?*/ ]] || continue
    p="${p#grove=}"
    printf '%s\n' "${p%/}"
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
# .note `date=` sorts as text, so the last key per unit after a sort is its latest
grove_backup_units_latest() {
  local key class
  while IFS=$'\t' read -r key _ class; do
    printf '%s\t%s\t%s\n' "$(grove_backup_key_unit "$key")" "$key" "${class:-STANDARD}"
  done | sort -t$'\t' -k1,1 -k2,2 \
    | awk -F'\t' '{ latest[$1] = $0 } END { for (u in latest) print latest[u] }' \
    | sort -t$'\t' -k1,1
}

######################################################################
# .what = the repo a worktree belongs to, read from its `.git` link
#
# .why the worktree dir's own name says naught of its repo — `svc-quotes.feat-x`
#   could be any repo's. the link file is the box's own answer
# .why `_unlinked` and never a skip: a worktree whose link is broken still holds
#   files nobody pushed. it rides along under a name that says what it is
######################################################################
grove_backup_worktree_repo() {
  local line gitdir
  [[ -f "$1/.git" ]] || { printf '_unlinked'; return; }
  line="$(head -n 1 "$1/.git")"
  gitdir="${line#gitdir: }"
  [[ "$gitdir" == */.git/worktrees/* ]] || { printf '_unlinked'; return; }
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
# .what = every unit on this box → "kind<TAB>user<TAB>path<TAB>unit" lines
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
grove_backup_units_walk() {
  local home user org org_name entry name wt sa dir hd
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
            if [[ ! -e "$wt/.git" ]]; then
              printf 'orphan\t%s\t%s\tuser=%s/org=%s/orphan=%s\n' "$user" "$wt" "$user" "$org_name" "${wt##*/}"
              continue
            fi
            printf 'worktree\t%s\t%s\tuser=%s/org=%s/repo=%s/tree=%s\n' \
              "$user" "$wt" "$user" "$org_name" "$(grove_backup_worktree_repo "$wt")" "${wt##*/}"
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
        printf 'clone\t%s\t%s\tuser=%s/org=%s/repo=%s/tree=%s\n' \
          "$user" "$entry" "$user" "$org_name" "$name" "$name"
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
######################################################################
grove_backup_git() {
  local path="$1"
  shift
  git -c safe.directory='*' -c core.quotepath=off -C "$path" "$@"
}

# .what = a url with any `user:secret@` stripped, so no credential lands in a unit
grove_backup_url_clean() { printf '%s' "$1" | sed -E 's#^([a-z+]+://)[^/@]*@#\1#'; }

######################################################################
# .what = the tar flags that cut what a HOME unit must not carry, one per line
#
#   - `node_modules` at any depth: rebuilt by an install, never work
#   - each scope exclude that falls inside this unit, ANCHORED at its root, so
#     `~/.claude/.credentials.json` cuts that one file and no file of that name
#     deeper down
######################################################################
grove_backup_pack_excludes() {
  local home="$1" path="$2" ex abs
  printf '%s\n' --no-anchored --exclude=node_modules --anchored
  for ex in "${GROVE_BACKUP_SCOPE_EXCLUDE[@]}"; do
    abs="$home/${ex#\~/}"
    abs="${abs%/}"
    [[ "$abs" == "$path"/* ]] || continue
    printf -- '--exclude=./%s\n' "${abs#"$path"/}"
  done
}

######################################################################
# the change check — a quiet unit costs a metadata read, never a pack
######################################################################

# .what = one line that moves whenever a tree's git state moves: its local refs,
#         its HEAD, its index, its reflog, a rebase or merge mid-flight
# .why remote refs are left out: a fetch moves them and changes no work here
grove_backup_tree_fingerprint() {
  local path="$1" gd
  gd="$(grove_backup_git "$path" rev-parse --absolute-git-dir 2>/dev/null)" || { printf 'no-git'; return 0; }
  {
    grove_backup_git "$path" for-each-ref --format='%(objectname) %(refname)' refs/heads refs/stash refs/tags
    cat "$gd/HEAD" 2>/dev/null
    stat -c '%n %s %.9Y' "$gd/index" "$gd/logs/HEAD" "$gd/ORIG_HEAD" "$gd/MERGE_HEAD" "$gd/CHERRY_PICK_HEAD" 2>/dev/null
    ls -d "$gd/rebase-merge" "$gd/rebase-apply" 2>/dev/null
  } | sha256sum | cut -d' ' -f1
}

# .what = did any file or dir under <path> change since <stamp> was written?
# rc 0 = it moved · 1 = it is quiet
# .why ctime, never mtime: ctime moves on every content change, rename, and
#   delete (a delete moves its dir), and no tool can set it back
# .why `.git` is pruned: the fingerprint above reads the git state
grove_backup_unit_moved_since() {
  local path="$1" stamp="$2"
  [[ -f "$stamp" ]] || return 0
  [[ -n "$(find "$path" \( -name node_modules -o -name .git \) -prune -o -cnewer "$stamp" -print -quit 2>/dev/null)" ]]
}

# .what = did a pack read a still unit? rc 0 = settled · 1 = a file moved under it
# .why a `.jsonl` is skipped: a live conversation appends as a matter of course,
#   and it lands as a whole prefix of itself
grove_backup_pack_settled() {
  local path="$1" stamp="$2"
  [[ -z "$(find "$path" \( -name node_modules -o -name .git \) -prune -o \
             \( -type f -o -type l \) ! -name '*.jsonl' -cnewer "$stamp" -print -quit 2>/dev/null)" ]]
}

######################################################################
# the marks — each unit records its own last pass, the moment it lands
#
#   <state>/marks/<id>.json   { unit, at, sha, fingerprint, origin_checked }
#   <state>/marks/<id>.stamp  mtime = the pack start, to the nanosecond, for the ctime check
#
# .why `at` is the pack START: a file that changes while the unit packs is newer
#   than the stamp, so the next pass sees it
######################################################################
grove_backup_mark_id()   { printf '%s' "$1" | sha256sum | cut -c1-32; }
grove_backup_mark_file() { printf '%s/marks/%s.json' "$(grove_backup_state_dir)" "$(grove_backup_mark_id "$1")"; }
grove_backup_mark_get()  { jq -r --arg f "$2" '.[$f] // empty' "$(grove_backup_mark_file "$1")" 2>/dev/null; }

grove_backup_mark_set() {
  local unit="$1" at="$2" sha="$3" fp="$4" checked="$5" file tmp
  file="$(grove_backup_mark_file "$unit")"
  mkdir -p "$(dirname "$file")" || return 1
  tmp="$file.tmp.$$"
  jq -n --arg unit "$unit" --argjson at "$at" --arg sha "$sha" --arg fp "$fp" --argjson checked "$checked" \
    '{ unit: $unit, at: ($at | floor), sha: $sha, fingerprint: $fp, origin_checked: $checked }' >"$tmp" \
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
######################################################################

# .what = the shas origin holds now, that this repo also holds → one per line in $2
# rc 0 = origin answered · 1 = no origin · 2 = origin did not answer (this box's own
#   view of origin is written instead, so the pack stays small, and the unit packs again)
grove_backup_origin_shas() {
  local path="$1" out="$2" raw
  raw="$out.raw"
  grove_backup_git "$path" remote get-url origin >/dev/null 2>&1 || { : >"$out"; return 1; }
  if timeout 60 env GIT_TERMINAL_PROMPT=0 git -c safe.directory='*' -C "$path" ls-remote origin >"$raw" 2>/dev/null; then
    cut -f1 "$raw" | sort -u \
      | grove_backup_git "$path" cat-file --batch-check='%(objectname) %(objecttype)' 2>/dev/null \
      | awk '$2 == "commit" || $2 == "tag" { print $1 }' >"$out"
    rm -f "$raw"
    return 0
  fi
  rm -f "$raw"
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

# .what = the tree-relative paths a unit carries, NUL-separated, into $2
grove_backup_tree_files() {
  local path="$1" out="$2" has_head="$3" rel base want flag
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
          base="${rel%/}"; base="${base##*/}"
          for want in node_modules "${GROVE_BACKUP_REBUILT_DIRS[@]}"; do [[ "$base" == "$want" ]] && continue 2; done
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

######################################################################
# .what = pack one tree into a gz temp file; writes the sha256 of its tar to <out.gz>.sha
#
# .why the hash is of the uncompressed tar: a gzip upgrade changes every
#   compressed byte and none of the content
# .why deterministic (`--sort=name`, numeric owner, sorted lists): an unchanged
#   tree must hash the same on every pass, or the skip never fires
#
# usage: grove_backup_pack_tree <kind> <path> <out.gz> <work dir> <point in time: true|false>
# rc 0 ok · 2 fault (GROVE_BACKUP_PACK_WHY) · sets GROVE_BACKUP_ORIGIN_CHECKED
######################################################################
grove_backup_pack_tree() {
  local kind="$1" path="$2" out="$3" work="$4" pit="$5"
  local stage="$work/stage" gb gd cd head_sha head_ref origin origin_rc checked rc sha rel hook
  local -a excludes=(--no-anchored --exclude=node_modules --anchored)
  rm -rf "$stage" "$work/unit.tar"
  gb="$stage/.grove-backup"
  mkdir -p "$gb/checkout" "$gb/repo" "$gb/staged" || { GROVE_BACKUP_PACK_WHY="the stage could not be made"; return 2; }

  gd="$(grove_backup_git "$path" rev-parse --absolute-git-dir 2>/dev/null)" \
    || { GROVE_BACKUP_PACK_WHY="git does not read this tree"; return 2; }
  cd="$(grove_backup_git "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  head_sha="$(grove_backup_git "$path" rev-parse -q --verify HEAD 2>/dev/null)"
  head_ref="$(grove_backup_git "$path" symbolic-ref -q HEAD 2>/dev/null)"
  origin="$(grove_backup_url_clean "$(grove_backup_git "$path" remote get-url origin 2>/dev/null)")"

  # 1. the objects origin lacks
  grove_backup_origin_shas "$path" "$work/origin.shas"
  origin_rc=$?
  checked=true
  [[ "$origin_rc" -eq 2 ]] && checked=false
  GROVE_BACKUP_ORIGIN_CHECKED="$checked"
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

  # 2. the checkout state — this tree's own git dir files
  for rel in HEAD index ORIG_HEAD MERGE_HEAD MERGE_MSG CHERRY_PICK_HEAD rebase-merge rebase-apply; do
    [[ -e "$gd/$rel" ]] && cp -a "$gd/$rel" "$gb/checkout/$rel"
  done
  [[ -f "$gd/logs/HEAD" ]] && mkdir -p "$gb/checkout/logs" && cp -a "$gd/logs/HEAD" "$gb/checkout/logs/HEAD"
  if [[ -d "$cd/logs/refs" ]]; then
    mkdir -p "$gb/checkout/logs"
    if [[ "$kind" == clone ]]; then
      cp -a "$cd/logs/refs" "$gb/checkout/logs/refs"
    else
      for rel in "${head_ref#refs/}" stash; do
        [[ -n "$rel" && -f "$cd/logs/refs/$rel" ]] || continue
        mkdir -p "$gb/checkout/logs/refs/$(dirname "$rel")" && cp -a "$cd/logs/refs/$rel" "$gb/checkout/logs/refs/$rel"
      done
    fi
  fi

  # 3. the repo config — branch upstreams and remotes, with every url cleaned
  grove_backup_git "$path" config --get-regexp '^(branch|remote)\.' 2>/dev/null \
    | while read -r key value; do
        [[ "$key" == *.url || "$key" == *.pushurl ]] && value="$(grove_backup_url_clean "$value")"
        printf '%s %s\n' "$key" "$value"
      done >"$gb/repo/config.list"
  [[ -f "$cd/info/exclude" ]] && cp -a "$cd/info/exclude" "$gb/repo/exclude"
  for hook in "$cd"/hooks/*; do
    [[ -f "$hook" && "$hook" != *.sample ]] || continue
    mkdir -p "$gb/repo/hooks" && cp -a "$hook" "$gb/repo/hooks/"
  done

  # 4. the staged copies — the index's blob of each staged file, since no ref reaches it
  grove_backup_git "$path" diff -z --cached --name-only --no-renames ${head_sha:+HEAD} 2>/dev/null \
    | while IFS= read -r -d '' rel; do
        grove_backup_git "$path" cat-file -e ":$rel" 2>/dev/null || continue
        mkdir -p "$gb/staged/$(dirname "$rel")" && grove_backup_git "$path" cat-file blob ":$rel" >"$gb/staged/$rel"
      done

  # 5. the files, and the manifest
  grove_backup_tree_files "$path" "$work/files" "$([[ -n "$head_sha" ]] && echo yes || echo no)"
  grove_backup_git "$path" ls-files -z --others --ignored --exclude-standard --directory \
    | while IFS= read -r -d '' rel; do
        base="${rel%/}"; base="${base##*/}"
        for want in "${GROVE_BACKUP_REBUILT_DIRS[@]}"; do [[ "$base" == "$want" ]] && printf -- '--exclude=%s\n' "${rel%/}"; done
      done >"$work/excl"
  mapfile -t -O "${#excludes[@]}" excludes <"$work/excl"
  jq -n \
    --arg kind "$kind" --arg head_sha "$head_sha" --arg head_ref "$head_ref" --arg origin "$origin" \
    --argjson checked "$checked" --argjson pit "$pit" \
    --rawfile deletes <(if [[ -n "$head_sha" ]]; then grove_backup_git "$path" diff -z --name-only --no-renames --diff-filter=D HEAD; fi) \
    --rawfile staged <(cd "$gb/staged" && find . -type f -printf '%P\0' | sort -z) \
    '{ version: 2, kind: $kind,
       head_sha: (if $head_sha == "" then null else $head_sha end),
       head_ref: (if $head_ref == "" then null else $head_ref end),
       origin: (if $origin == "" then null else $origin end),
       origin_checked: $checked,
       deletes: ($deletes | split("\u0000") | map(select(. != ""))),
       staged: ($staged | split("\u0000") | map(select(. != ""))),
       point_in_time: $pit }' >"$gb/meta.json" \
    || { GROVE_BACKUP_PACK_WHY="the manifest could not be written"; return 2; }

  tar --no-wildcards -C "$stage" --sort=name --numeric-owner -cf "$work/unit.tar" .grove-backup 2>"$work/tar.err" \
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

  gzip -n <"$work/unit.tar" >"$out" 2>"$work/gz.err" \
    || { GROVE_BACKUP_PACK_WHY="the temp tar could not be written: $(head -n 1 "$work/gz.err")"; return 2; }
  sha="$(sha256sum <"$work/unit.tar")"
  rm -rf "$stage" "$work/unit.tar"
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
# .what = tar one HOME unit (`~/.claude`, `~/.rhachet`) into a gz temp file,
#         then hash its UNCOMPRESSED bytes
#
# .why deterministic (`--sort=name`, numeric owner, `gzip -n`): an untouched
#   unit must hash the same on every pass, or the skip never fires
# .why a temp FILE and not a stream to s3: the skip needs the hash before the put
#
# writes the sha256 to <out>.sha; rc 0 ok · 1 changed while read (retry-worthy) · 2 fault
# sets GROVE_BACKUP_PACK_WHY on rc 1 or 2
######################################################################
grove_backup_pack_home() {
  local home="$1" path="$2" out="$3"
  local errf="$out.tarerr" gzerr="$out.gzerr" tar_rc gz_rc sha
  local -a flags changed codes

  mapfile -t flags < <(grove_backup_pack_excludes "$home" "$path")

  # ⚠️ both exit codes in ONE read: an assignment is a command, so a second
  #   `${PIPESTATUS[1]}` after `tar_rc=${PIPESTATUS[0]}` reads a reset array
  tar --no-wildcards "${flags[@]}" -C "$path" --sort=name --numeric-owner -cf - . 2>"$errf" \
    | gzip -n 2>"$gzerr" >"$out"
  codes=("${PIPESTATUS[@]}")
  tar_rc="${codes[0]}"
  gz_rc="${codes[1]}"

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

  sha="$(gzip -dc "$out" | sha256sum)"
  printf '%s\n' "${sha%% *}" >"$out.sha"
}

######################################################################
# the status — one file, world-readable, the one source every surface renders
#
#   { version, grove, began, at, verdict: ok|failed, cause, fix,
#     units, put, skipped, failed, failures: [{unit, why}], last_ok }
#
# .why `last_ok` is carried across a failed run: STALE is judged from the last
#   GOOD run, so a box that fails every hour still ages toward ✗ STALE
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
    --arg last_ok "$last_ok" \
    --slurpfile failures "$failures_file" \
    '{ version: 1,
       grove: (if $grove == "" then null else $grove end),
       began: $began, at: $at, verdict: $verdict,
       cause: (if $cause == "" then null else $cause end),
       fix: (if $fix == "" then null else $fix end),
       units: $units, put: $put, skipped: $skipped,
       failed: ($failures | length), failures: $failures,
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
#   ✗ FAILED · <cause> · 3h
#   ✗ STALE · last ok 3h ago        ✗ STALE · never
#   ⏳ the first run is at work      ✗ NOT ENROLLED
#
# usage: grove_backup_status_line [enrolled]   # enrolled = the timer is in place
# rc 0 on ✓, 1 on all else
######################################################################
# .what = is a backup run at work now? (a oneshot unit reads `activating` while it runs)
grove_backup_run_active() {
  [[ "$(systemctl show -p ActiveState --value grove-backup.service 2>/dev/null)" == activating ]]
}

grove_backup_status_line() {
  local enrolled="${1:-}" file verdict cause at last_ok put skipped age
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

  if [[ "$verdict" != ok ]]; then
    age="$(grove_backup_age_of "$at")" && age=" · $(grove_backup_age "$age")" || age=""
    echo "✗ FAILED · ${cause}${age}"
    return 1
  fi

  age="$(grove_backup_age_of "$last_ok")" || { echo "✗ FAILED · the status file is unreadable: $file"; return 1; }
  if [[ "$age" -gt "$GROVE_BACKUP_STALE_SECS" ]]; then
    echo "✗ STALE · last ok $(grove_backup_age "$age") ago"
    return 1
  fi
  echo "✓ $(grove_backup_age "$age") ago · $put put · $skipped skipped"
}
