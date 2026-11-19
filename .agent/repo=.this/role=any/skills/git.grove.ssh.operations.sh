#!/usr/bin/env bash
######################################################################
# .what = the ONE writer of every grove seat's ssh alias, in a file this repo
#         owns, which ssh reads BEFORE any other block
#
# .why  = a seat alias is the name every duct, push, send, and apply dials. a
#         block for that name in `~/.ssh/config` can be laid by ANOTHER writer
#         (infra lays its own), and ssh obeys the first value it reads. so the
#         registry declared one seat while the wire reached another, and no
#         command errored
#         📜 2026-11-15, grove-ahbode-hetzner-v20261022: infra's bare-name block
#            named `ground`, the registry named `camper`, and every camper send
#            for a week landed on ground
#
# 🛑 .why this is STRUCTURAL, not a check
#   - ssh takes, per option, the FIRST value it obtains, and an `Include` is read
#     where it stands. so an Include as the very FIRST line of `~/.ssh/config`
#     puts this file ahead of every other user block, and the system config is
#     read after the user's
#   - ⇒ for every alias this file declares, its User, HostName, and Port win,
#     whatever any other block for that name says
#   - another writer's bytes are never touched: a block of theirs stays where it
#     stands, and is merely never the first to answer
#   - `ssh -G` is then read back, so a defect in THIS writer is named, never a
#     silent misroute
#
# usage:
#   source git.grove.ssh.operations.sh
#   grove_ssh_alias_set alias=<name> host=<host> port=<port> user=<user> identity=<path>
#
# stdout: `[KEEP]` or `[SET]`, one line, for the caller's tree
# stderr: every non-zero exit names its cause here — a caller may say "its
#         reason is above" and be right
# exit:   0 = ssh will dial exactly the declared seat · 1 = io · 2 = bad args, or
#         ssh reads another seat for this alias after the write
######################################################################

# .what = is a registry host this laptop itself — an ssm tunnel's local end?
# .why  = wake, ready.verify, and trust.gen each pick their reach on it; one
#         reader, so a loopback form (`::1`) cannot reach one skill and not another
#   the whole 127.0.0.0/8 block is loopback, as `git grove set` and `git grove del` read it
#   an ADDRESS test, anchored: a dns name such as `127.example.com` is no loopback
grove_ssh_host_is_loopback() { [[ "$1" == "localhost" || "$1" == "::1" || "$1" =~ ^127(\.[0-9]{1,3}){3}$ ]]; }

# .what = is a registry host a grove's own name on the tailnet — no tunnel, no aws?
grove_ssh_host_is_tailnet() { [[ -n "$1" ]] && ! grove_ssh_host_is_loopback "$1"; }

# .what = one bounded ssh round trip through an alias (a communicator)
# .why  = the proof a tailnet grove is reachable; on a miss, stdout carries the
#         head of what ssh said, so the caller names the cause, never a bare rc
# .note = rc 2 = the box ANSWERED, and ssh refused its host key (a first contact, or
#         a rebuilt box). that is reach proven and trust not yet settled — the job
#         of `git.grove.trust.gen`, which runs AFTER the wake. so a wake must never
#         read it as silence, or a first boot could never reach its trust step
# .note = StrictHostKeyChecking=yes: a laptop's `accept-new` would let this probe write
#         an unattested key, and trust.gen would then read it as already trusted
grove_ssh_round_trip() {
  local said
  said="$(timeout -k 5 30 ssh -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=yes "$1" true </dev/null 2>&1 >/dev/null)" && return 0
  printf '%s\n' "$said" | head -4
  [[ "$said" == *"Host key verification failed"* ]] && return 2
  return 1
}

# .what = lay /etc/grove/platform over one seat, a findsert
#         absent → write (SET) · same → keep (KEEP) · different → refuse (DIFFERS)
# .why  = a declaration this boot did not write is never overwritten
# .note = on success it prints the one verdict word; on failure, all the seat said
#         (a `DIFFERS <have>` line, or the ssh / sudo fault), and a non-zero exit.
#         bounded: an ssh that cannot connect waits at most 60s; stdin is closed
grove_ssh_platform_findsert() {
  local seat="$1" want="$2" out rc=0
  out="$(timeout -k 5 60 ssh -o BatchMode=yes "$seat" \
    "f=/etc/grove/platform; want=$want
     if [ -f \"\$f\" ]; then
       have=\$(cat \"\$f\"); [ \"\$have\" = \"\$want\" ] && { echo KEEP; exit 0; }
       echo \"DIFFERS \$have\"; exit 3
     fi
     printf '%s\n' \"\$want\" | sudo -n install -D -m 0644 /dev/stdin \"\$f\" && echo SET" </dev/null 2>&1)" || rc=$?
  if (( rc != 0 )); then printf '%s' "$out"; return "$rc"; fi
  printf '%s' "${out##*$'\n'}"
}

######################################################################
# .what = make a grove seat's alias dial the registry's seat, then prove it —
#         the ONE call every skill makes before it dials a grove
#
# .why  = 📜 2026-11-18, grove-ahbode-hetzner-v20261022: only the wake and the
#         boot laid aliases, so a seat never woken on this laptop kept whatever
#         Host block another writer had laid. infra's named `ground`, the registry
#         named `camper`, and every camper send ran as ground. a check at some
#         dial sites left the rest open; a heal at every dial site leaves none
#
# .how
#   - a tailnet seat (a real host on record): lay the block where ssh reads first,
#     with the same writer the wake uses — idempotent, [KEEP] costs no write — and
#     read `ssh -G` back. a wrong seat is fixed here, never handed to a human
#   - an --alias seat (no host) or an ssm tunnel (a loopback host): its block is
#     another writer's or the wake's, since a tunnel's port moves per session.
#     prove only: refuse when ssh would dial another user than the registry's
#
# stdout: naught · stderr: one 🔧 line when a block was laid, else the refusal
# exit:   0 = ssh dials the registry's seat · 1 = io · 2 = another seat answers
######################################################################
grove_ssh_seat_ready() {
  local name="$1" reg alias user host port identity out seat
  reg="${GIT_FOREST_DIR:-$HOME/.git.forest}/groves/$name.json"
  # an unregistered name is the caller's lookup to refuse, in its own words
  [[ -f "$reg" ]] || return 0
  alias="$(jq -r '.sshAlias // .name' "$reg")"
  user="$(jq -r '.user // empty' "$reg")"
  host="$(jq -r '.host // empty' "$reg")"
  port="$(jq -r '.port // 22' "$reg")"

  if grove_ssh_host_is_tailnet "$host"; then
    identity="$(grove_ssh_alias_identity "$alias")"
    out="$(grove_ssh_alias_set alias="$alias" host="$host" port="$port" user="${user:-camper}" \
      identity="${identity:-$HOME/.ssh/id_ed25519}")" || return $?
    [[ "$out" == "[SET]"* ]] && echo "   🔧 alias '$alias' laid to the registry's seat (${out#* })" >&2
    return 0
  fi

  # no user declared → no seat to compare against, so no read
  [[ -z "$user" ]] && return 0
  seat="$(grove_ssh_seat_effective "$alias")"
  [[ "${seat%%@*}" == "$user" ]] && return 0
  echo "✋ ConstraintError: ssh alias '$alias' dials $seat, and the registry names user '$user'" >&2
  echo "   ⇒ its Host block is not this repo's to write (an --alias seat, or a tunnel the wake lays)" >&2
  echo "   fix: rhx git.grove.wake $name" >&2
  return 2
}

# .what = the file this repo owns, and the line that puts it first
grove_ssh_owned_config() { printf '%s/.ssh/config.d/grove.conf' "$HOME"; }
grove_ssh_include_line() { printf 'Include %s' "$(grove_ssh_owned_config)"; }

# .what = name an io fault on stderr, then fail
# .why  = each io step below can fail for a reason only the tool saw. the tool's own
#         words ride as $2, under the header, so they never land raw at column 0
grove_ssh_io_failed() {
  echo "💥 MalfunctionError: could not $1" >&2
  [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/   ⇒ it said: /' >&2
  return 1
}

# .what = grove_ssh_alias_set, its fault nested under the caller's own tree line
# .why  = the writer names its fault on stderr. passed through raw, that text lands
#         ABOVE the caller's line that explains it, outside the caller's tree
# usage: grove_ssh_alias_set_under head='   └─ ' alias=… host=… port=… user=… identity=…
#   success: GROVE_SSH_ALIAS_SAID holds the writer's stdout (`[SET] user@host:port`)
#   failure: `<head>alias … could not be set`, then the writer's stderr one level
#            under it; rc as the writer's
grove_ssh_alias_set_under() {
  local head="${1#head=}" err rc pad alias arg
  shift
  pad="${head//?/ }"
  for arg in "$@"; do [[ "$arg" == alias=* ]] && alias="${arg#alias=}"; done
  GROVE_SSH_ALIAS_SAID=""
  err="$(mktemp "${TMPDIR:-/tmp}/grove.alias.XXXXXX")" \
    || { echo "${head}💥 MalfunctionError: could not open a scratch file for the alias writer's stderr" >&2; return 1; }
  GROVE_SSH_ALIAS_SAID="$(grove_ssh_alias_set "$@" 2>"$err")"; rc=$?
  if (( rc != 0 )); then
    echo "${head}alias '${alias:-?}' could not be set to the registry's seat" >&2
    sed "s/^/${pad}/" "$err" >&2
  fi
  rm -f "$err"
  return "$rc"
}

# .what = every line of a file except one, exit 0 even when none is left
# .why  = `grep -v` exits 1 when it selects no line — an EMPTY file, which is the
#         fresh-box case. that is a valid answer here, never a fault; exit 2 still is
grove_ssh_lines_except() {
  local line="$1" file="$2" rc
  grep -vxF -- "$line" "$file"; rc=$?
  (( rc <= 1 ))
}

# .what = findsert the Include as the FIRST line of ~/.ssh/config
# 🛑 FIRST, never merely present: an Include below a `Host` block is read inside
#    that block's scope, and one below another block for the same alias loses to it
grove_ssh_include_first() {
  local cfg="$HOME/.ssh/config" own line tmp
  own="$(grove_ssh_owned_config)"
  line="$(grove_ssh_include_line)"
  mkdir -p "$HOME/.ssh" "$(dirname "$own")" || grove_ssh_io_failed "make $HOME/.ssh/config.d" || return 1
  chmod 700 "$HOME/.ssh" 2>/dev/null
  touch "$cfg" "$own" || grove_ssh_io_failed "create $cfg or $own" || return 1
  chmod 600 "$cfg" "$own" 2>/dev/null
  [[ "$(head -n 1 "$cfg")" == "$line" ]] && return 0

  # each tool's stderr is captured and passed to the io fault, never left raw
  local said
  tmp="$(mktemp "$HOME/.ssh/.config.grove.XXXXXX" 2>&1)" || grove_ssh_io_failed "make a tmp file in $HOME/.ssh" "$tmp" || return 1
  { printf '%s\n\n' "$line"; grove_ssh_lines_except "$line" "$cfg"; } > "$tmp" \
    || { rm -f "$tmp"; grove_ssh_io_failed "read $cfg"; return 1; }
  said="$(chmod 600 "$tmp" 2>&1 && mv -f "$tmp" "$cfg" 2>&1)" \
    || { rm -f "$tmp"; grove_ssh_io_failed "replace $cfg" "$said"; return 1; }
}

# .what = the `Host <alias>` block of a file, blank lines dropped
# .why  = the compare that decides [KEEP] vs [SET]; a stray newline is no difference
grove_ssh_host_block_of() {
  local file="$1" alias="$2"
  awk -v a="Host $alias" '
    $0 == a  { inblock = 1; print; next }
    /^Host /  { inblock = 0 }
    inblock && NF { print }
  ' "$file"
}

# .what = a file with one `Host <alias>` block removed, every other line kept
# .note = runs of blank lines collapse to one, so a rewrite never grows the file
grove_ssh_host_block_drop() {
  local file="$1" alias="$2"
  awk -v a="Host $alias" '
    $0 == a  { inblock = 1; next }
    /^Host /  { inblock = 0 }
    !inblock && !(NF == 0 && prevblank) { print; prevblank = (NF == 0) }
  ' "$file"
}

# .what = the IdentityFile this repo's block declares for an alias; empty where none
# .why  = `ssh -G` lists every DEFAULT key when no block names one, so its first line
#   proves no choice; the owned block is the one record of the key a wake was given
grove_ssh_alias_identity() {
  local cfg; cfg="$(grove_ssh_owned_config)"
  [[ -r "$cfg" ]] || return 0
  grove_ssh_host_block_of "$cfg" "$1" | awk '$1 == "IdentityFile" { print $2; exit }'
}

# .what = the block this repo declares for one seat
# .note = the keepalive stops an SSM tunnel's expiry under an idle session: an ssm
#   grove's alias rides a LOCAL port that session-manager-plugin relays, and
#   session manager ends a session after `idleSessionTimeout` (default 20m) of
#   SILENCE — which drops the port and kills the ssh with no error, as if the
#   box slept. 60s of traffic keeps it non-idle; 3 misses ends a truly dead one
grove_ssh_host_block_declared() {
  local alias="$1" host="$2" port="$3" user="$4" identity="$5"
  printf 'Host %s\n  HostName %s\n  Port %s\n  User %s\n  IdentityFile %s\n  ServerAliveInterval 60\n  ServerAliveCountMax 3\n  TCPKeepAlive yes' \
    "$alias" "$host" "$port" "$user" "$identity"
}

# .what = the `user@host:port` ssh WILL dial for an alias — what it reads, never
#         what a file says
grove_ssh_seat_effective() {
  # bounded, stdin closed: `ssh -G` runs any `Match exec` in the human's config
  timeout -k 5 10 ssh -G "$1" </dev/null 2>/dev/null | awk '
    $1 == "user"     && !u { u = $2 }
    $1 == "hostname" && !h { h = $2 }
    $1 == "port"     && !p { p = $2 }
    END { printf "%s@%s:%s", u, h, p }
  '
}

# .what = does every one of the five seat fields hold a value?
grove_ssh_alias_args_complete() {
  local field
  for field in "$@"; do [[ -n "$field" ]] || return 1; done
}

# .what = the one lock every writer of ~/.ssh/config and the owned file takes
# .note = `git grove del` (bash_aliases.sh) names the same path; the two must agree
grove_ssh_config_lock_path() { printf '%s/.ssh/.grove.conf.lock' "$HOME"; }

# .what = run one function with the ssh config lock held; its stdout passes through
# .why  = a writer that reads a file whole and swaps it whole must not overlap another
# exit:   the function's own · 1 when the lock cannot be taken within 30s
grove_ssh_config_locked() {
  local lock
  lock="$(grove_ssh_config_lock_path)"
  command -v flock >/dev/null 2>&1 || { grove_ssh_io_failed "lock $lock" "flock is absent (util-linux)"; return 1; }
  mkdir -p "$HOME/.ssh" || { grove_ssh_io_failed "make $HOME/.ssh"; return 1; }
  (
    flock -w 30 9 || { grove_ssh_io_failed "take $lock within 30s — another writer holds it"; exit 1; }
    "$@"
  ) 9>"$lock"
}

# .what = the Include first, then this alias's block replaced where it differs
# .note = runs only under `grove_ssh_config_locked`; prints [SET] or [KEEP]
__grove_ssh_alias_write() {
  local own="$1" alias="$2" declared="$3" tmp said
  grove_ssh_include_first || return 1
  if [[ "$(grove_ssh_host_block_of "$own" "$alias")" == "$declared" ]]; then
    echo "[KEEP]"; return 0
  fi
  # a block that differs is replaced; every other block is copied through
  tmp="$(mktemp "$HOME/.ssh/config.d/.grove.XXXXXX" 2>&1)" || grove_ssh_io_failed "make a tmp file in $HOME/.ssh/config.d" "$tmp" || return 1
  {
    grove_ssh_host_block_drop "$own" "$alias"
    [[ -s "$own" ]] && printf '\n'
    printf '%s\n' "$declared"
  } > "$tmp" || { rm -f "$tmp"; grove_ssh_io_failed "compose $own"; return 1; }
  said="$(chmod 600 "$tmp" 2>&1 && mv -f "$tmp" "$own" 2>&1)" || { rm -f "$tmp"; grove_ssh_io_failed "replace $own" "$said"; return 1; }
  echo "[SET]"
}

grove_ssh_alias_set() {
  local alias="" host="" port="" user="" identity="" arg
  for arg in "$@"; do
    case "$arg" in
      alias=*)    alias="${arg#alias=}" ;;
      host=*)     host="${arg#host=}" ;;
      port=*)     port="${arg#port=}" ;;
      user=*)     user="${arg#user=}" ;;
      identity=*) identity="${arg#identity=}" ;;
    esac
  done
  if ! grove_ssh_alias_args_complete "$alias" "$host" "$port" "$user" "$identity"; then
    echo "✋ ConstraintError: grove_ssh_alias_set needs alias=, host=, port=, user=, identity=" >&2
    return 2
  fi

  local own declared verdict seat want
  own="$(grove_ssh_owned_config)"
  declared="$(grove_ssh_host_block_declared "$alias" "$host" "$port" "$user" "$identity")"

  # 🛑 the read, the compose, and the swap run under ONE lock, held across every writer
  #    of these files (this one, and `git grove del`'s strip). each writer reads the whole
  #    file and swaps the whole file, so two at once lose the block of whichever read first.
  #    📜 2026-11-19: crews and boots write here from many shells at once
  verdict="$(grove_ssh_config_locked __grove_ssh_alias_write "$own" "$alias" "$declared")" || return 1

  # 🛑 the read-back: what ssh WILL use, never what the file says
  want="$user@$host:$port"
  seat="$(grove_ssh_seat_effective "$alias")"
  if [[ "$seat" != "$want" ]]; then
    echo "💥 MalfunctionError: alias '$alias' reaches $seat after the write; the registry names $want" >&2
    echo "   ⇒ the owned file is not read first — a defect in this writer, not on the box" >&2
    echo "   read why: head -n 3 ~/.ssh/config ; ssh -G $alias | grep -E '^(user|hostname|port) '" >&2
    return 1
  fi

  printf '%s %s\n' "$verdict" "$want"
}
