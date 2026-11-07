#!/usr/bin/env bash
######################################################################
# .what = the grove backup's shared operations — one library, four callers
#
# .who reads it
#   - the agent, `grove-backup`, run as root by `grove-backup.service`
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

# a status older than this reads ✗ STALE: two missed hourly runs
GROVE_BACKUP_STALE_SECS=7200

# every aws call is bounded, so a hung endpoint fails one run and never holds the timer
GROVE_BACKUP_AWS_TIMEOUT_SECS=900

######################################################################
# the box facts — each a function, so a play can point it at a fixture
######################################################################
grove_backup_name_file()   { printf '/etc/grove/name'; }
grove_backup_bucket_file() { printf '/etc/grove/backup.bucket'; }
grove_backup_home_root()   { printf '/home'; }
grove_backup_state_dir()   { printf '/var/lib/grove-backup'; }
grove_backup_status_file() { printf '%s/status.json' "$(grove_backup_state_dir)"; }
grove_backup_now()         { date -u +%s; }
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

# the unit id of a key: drop `grove=<slug>/` and `/date=….tar.gz`
grove_backup_key_unit() {
  local key="${1#grove=*/}"
  printf '%s' "${key%/date=*}"
}

# clone | worktree | home, from a unit id
grove_backup_unit_kind() {
  local unit="$1" repo tree
  [[ "$unit" == */home=* ]] && { printf 'home'; return; }
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
# .what = every unit on this box → "kind<TAB>user<TAB>path<TAB>unit" lines
#
# .the walk
#   /home/<seat>/git/<org>/<repo>             a clone      (its `.git` is a dir)
#   /home/<seat>/git/<org>/_worktrees/<dir>   a worktree   (its `.git` is a link)
#   /home/<seat>/<dir>                        a home unit, one per scope dir
#                                             beside `~/git`
#
# .why every seat under the home root: `ground` and `camper` both hold work,
#   and a seat with no `~/git` simply adds no unit (inventory b14)
######################################################################
grove_backup_units_walk() {
  local root home user org org_name entry name wt dir hd
  root="$(grove_backup_home_root)"
  for home in "$root"/*/; do
    [[ -d "$home" ]] || continue
    home="${home%/}"
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
              [[ -e "$wt/.git" ]] || continue
              printf 'worktree\t%s\t%s\tuser=%s/org=%s/repo=%s/tree=%s\n' \
                "$user" "$wt" "$user" "$org_name" "$(grove_backup_worktree_repo "$wt")" "${wt##*/}"
            done
            continue
          fi
          [[ -d "$entry/.git" ]] || continue
          printf 'clone\t%s\t%s\tuser=%s/org=%s/repo=%s/tree=%s\n' \
            "$user" "$entry" "$user" "$org_name" "$name" "$name"
        done
      done
    done
  done
}

######################################################################
# .what = the tar flags that cut what a unit must not carry, one per line
#
# .the three cuts
#   - `node_modules` at any depth: rebuilt by an install, never work
#   - each scope exclude that falls inside this unit, ANCHORED at its root, so
#     `~/.claude/.credentials.json` cuts that one file and no file of that name
#     deeper down
#   - `dist` `build` `coverage` `.next`, only where git ignores them
#
# .why `git -c safe.directory=*`: the agent is root and the repo is a seat's, so
#   git refuses the repo as "dubious ownership" without it
######################################################################
grove_backup_pack_excludes() {
  local kind="$1" home="$2" path="$3" ex abs rel base want
  printf '%s\n' --no-anchored --exclude=node_modules --anchored

  for ex in "${GROVE_BACKUP_SCOPE_EXCLUDE[@]}"; do
    abs="$home/${ex#\~/}"
    abs="${abs%/}"
    [[ "$abs" == "$path"/* ]] || continue
    printf -- '--exclude=./%s\n' "${abs#"$path"/}"
  done

  [[ "$kind" == home ]] && return 0
  git -c safe.directory='*' -C "$path" ls-files --others --ignored --exclude-standard --directory -z 2>/dev/null \
    | while IFS= read -r -d '' rel; do
        rel="${rel%/}"
        base="${rel##*/}"
        for want in "${GROVE_BACKUP_REBUILT_DIRS[@]}"; do
          [[ "$base" == "$want" ]] && printf -- '--exclude=./%s\n' "$rel"
        done
      done
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
# .what = tar one unit into a gz temp file, then hash its UNCOMPRESSED bytes
#
# .why the hash is of the uncompressed tar: a gzip upgrade changes every
#   compressed byte and none of the content, so it would re-put every unit once
# .why the tar is deterministic (`--sort=name`, numeric owner, gnu format with
#   no atime): an untouched unit must hash the same on every run, or the skip
#   never fires
# .why a temp FILE and not a stream to s3: the skip needs the hash before the put
#
# prints the sha256; rc 0 ok · 1 changed while read (retry-worthy) · 2 fault
# sets GROVE_BACKUP_PACK_WHY on rc 1 or 2
######################################################################
grove_backup_pack() {
  local kind="$1" home="$2" path="$3" out="$4"
  local errf="$out.tarerr" gzerr="$out.gzerr" tar_rc gz_rc sha
  local -a flags changed codes

  mapfile -t flags < <(grove_backup_pack_excludes "$kind" "$home" "$path")

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
  printf '%s\n' "${sha%% *}"
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
#   ✗ NOT ENROLLED
#
# usage: grove_backup_status_line [enrolled]   # enrolled = the timer is in place
# rc 0 on ✓, 1 on ✗
######################################################################
grove_backup_status_line() {
  local enrolled="${1:-}" file verdict cause at last_ok put skipped age
  file="$(grove_backup_status_file)"

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
