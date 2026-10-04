#!/usr/bin/env bash
######################################################################
# .what = ductwork — headless terminal streams via tmux
# .why  = start headless, attach later, send commands, read logs
#
# the address: --on takes a duct URI, and that is the ONLY format
#   duct://<host>/<tree>/<role>    remote — the host is the authority
#   duct:///<tree>/<role>          local  — an EMPTY authority means this machine
#                                           (three slashes, exactly like file:///)
#
#   what you read back is what you type in: every message prints the same URI
#   the flag accepts, so an address can be copied from output to input
#
# usage:
#   duct.open --on duct:///worktree/mechanic              # local: findsert headless
#   duct.open --on duct:///worktree/mechanic --mode headfull  # local: + attach (ctrl+x d to detach)
#   duct.open --on duct://grove-1/main/mechanic           # remote: findsert headless
#   duct.open --on duct://grove-1/main/mechanic --mode headfull  # remote: ssh + attach
#   duct.send --on duct:///worktree/mechanic --what "npm run build"
#   duct.send --on duct://grove-1/main/mechanic --what "npm run build"
#   duct.read --on duct:///worktree/mechanic
#   duct.read --on duct://grove-1/main/mechanic
#   duct.stop --on duct:///worktree/mechanic              # kill session
#   duct.stop --on duct://grove-1/main/mechanic
#   duct.list                                # list all ducts (from cache)
#   duct.list --on 'duct://grove-1/*'        # narrow by uri pattern (quote it!)
#   duct.list --on 'duct:///*'               # every duct on THIS machine
#   duct.list --on 'duct://grove-1/main/*'   # every role in one tree
#   duct.list --refresh                      # refresh cache from all hosts
#   duct.host.add user@host                  # register a host
#   duct.host.del user@host                  # unregister a host
#   duct.host.list                           # list hosts
#
# requires: tmux (sudo apt install tmux)
######################################################################

######################################################################
# registry: ~/.ductwork/hosts/{host}.json and ~/.ductwork/ducts/{session}.json
######################################################################

__duct_ensure_dirs() {
  DUCTWORK_DIR="${DUCTWORK_DIR:-$HOME/.ductwork}"
  mkdir -p "$DUCTWORK_DIR/hosts"
  mkdir -p "$DUCTWORK_DIR/ducts"
}

######################################################################
# .what = the ONE builder of a registry path. it owns the name grammar, and
#         refuses a name that cannot be one
# .why
#   - 🛑 a duct name arrives from a grove, assumed compromised — joined raw, a
#     session named `../../.claude/settings` overwrites the hooks file
#   - 🛑 it states the ALLOWED grammar, never a `..` deny-list: segments of
#     `[A-Za-z0-9._-]`, and no segment is `.` or `..`
#   - ⚠️ the refusal is a hard return, and callers must read it
#   - ⚠️ the verify's join count holds a NEW literal join, never an aliased one
# .refs = gotcha.2-7-ductwork.demo=sink-builder-and-seam, m1
#
# usage: file="$(__duct_as_registry_file ducts "$session")" || return $?
######################################################################
__duct_as_registry_file() {
  local kind="$1" name="$2" segment rest="$2"

  if [[ -z "$name" ]]; then
    echo "✋ duct: an empty name addresses no $kind entry" >&2
    return 2
  fi

  while [[ -n "$rest" ]]; do
    segment="${rest%%/*}"
    if [[ "$rest" == */* ]]; then rest="${rest#*/}"; else rest=""; fi
    # 🛑 the two refusals below relay a GROVE-CHOSEN value, so `printf` with the
    #    values as ARGUMENTS — never `echo`, never in the format. the refusal is
    #    the ONLY place this value prints, and zsh's `echo` expands a `\033` the
    #    byte sink correctly passed (.refs = gotcha.2-7-ductwork.demo=sink-builder-and-seam, m2)
    if [[ -z "$segment" || "$segment" == "." || "$segment" == ".." ]]; then
      printf "✋ duct: '%s' is not a %s name — the segment '%s' is not one\n" \
        "$name" "$kind" "$segment" >&2
      printf '   └─ a name is segments of [A-Za-z0-9._-], and no segment may be . or ..\n' >&2
      return 2
    fi
    if [[ "$segment" == *[!A-Za-z0-9._-]* ]]; then
      printf "✋ duct: '%s' is not a %s name — the segment '%s' holds a byte outside [A-Za-z0-9._-]\n" \
        "$name" "$kind" "$segment" >&2
      printf '   └─ a registry filename is derived from this name, so it must be one\n' >&2
      return 2
    fi
  done

  __duct_ensure_dirs
  printf '%s\n' "$DUCTWORK_DIR/$kind/$name.json"
}

######################################################################
# .what = the ONE sink for bytes a REMOTE box chose, on their way to a terminal
# .why
#   - 🛑 a terminal OBEYS bytes, and `set-clipboard on` lets an OSC 52 from a
#     grove write this human's clipboard — the next paste is the grove's command
#   - it strips by CLASS: every C0 but TAB and LF, plus ESC and C1
#   - it is a filter, never a check — a hash compare reads the RAW bytes
#   - 🛑 THREE stages, in order: `tr` (C0+DEL by byte), `iconv -c` (invalid
#     utf-8, so a raw C1), `sed` (U+0080..U+009F as characters). one `tr` over
#     `\177-\237` ate every box glyph and emoji, since that range is utf-8's
#     continuation bytes
#   - 🛑 it owns its own `pipefail`, in a subshell — a caller's options cannot
#     be known, and `local -` is a bash-ism
#   - ⚠️ `iconv` is glibc, so its absence is a broken box
# .refs = gotcha.2-7-ductwork.demo=sink-builder-and-seam, m3 — every
#   measurement, both directions; `2.7.aliases`'s configure.verify re-runs it
#
# usage:  ssh "$host" 'cat /some/log' | __duct_strip_escapes
######################################################################
__duct_strip_escapes() {
  (
    set -o pipefail
    LC_ALL=C tr -d '\000-\010\013\014\016-\037\177' \
      | iconv -c -f UTF-8 -t UTF-8 \
      | LC_ALL=C sed 's/\xC2[\x80-\x9F]//g'
  )
}

__duct_register_host() {
  local host="$1"
  local file
  file="$(__duct_as_registry_file hosts "$host")" || return $?
  local now
  now=$(date +%s)
  cat > "$file" <<EOF
{
  "lastSeen": ${now}000
}
EOF
}

__duct_unregister_host() {
  local host="$1"
  local file
  file="$(__duct_as_registry_file hosts "$host")" || return $?
  rm -f "$file"
}

__duct_register_duct() {
  local session="$1"
  local host="$2"
  local file
  file="$(__duct_as_registry_file ducts "$session")" || return $?
  # session may contain a slash (e.g. treename/role) -> nested path;
  # create the parent dir so the registry write does not fail.
  # ⚠️ safe only because the builder above proved every segment is a name —
  #    an unchecked one made this `mkdir -p` an arbitrary one
  mkdir -p "$(dirname "$file")"
  local now
  now=$(date +%s)
  cat > "$file" <<EOF
{
  "host": "$host",
  "createdAt": ${now}000
}
EOF
}

__duct_unregister_duct() {
  local session="$1"
  local file
  file="$(__duct_as_registry_file ducts "$session")" || return $?
  rm -f "$file"
  # session may be nested (treename/role) -> remove the now-empty parent dir
  rmdir --ignore-fail-on-non-empty "$(dirname "$file")" 2>/dev/null || true
}

__duct_get_duct_host() {
  local session="$1"
  local file
  file="$(__duct_as_registry_file ducts "$session")" || return $?
  if [[ -f "$file" ]]; then
    jq -r '.host // ""' "$file" 2>/dev/null
  fi
}

######################################################################
# .what = parse a duct URI into its host and session
#
#         duct://grove-1/main/mechanic  -> host=grove-1  session=main/mechanic
#         duct:///worktree/mechanic     -> host=""       session=worktree/mechanic
#
# .why  = the URI is the ONE format, and never a second scp-shaped slug
#         (`grove-1:main/mechanic`) on `--on` while the URI is printed back.
#         under two spellings a human reads `duct://grove-1/main/mechanic` and
#         cannot paste it into the flag that produced it; they re-shape it by
#         hand, from memory, every time. that is recall where recognition
#         belongs, and it is two spellings of one address —
#         `rule.require.ubiqlang`, failed on our own contract.
#
#         the slug shape is not earned. it looks inevitable because `host:x`
#         is the scp/rsync convention, but `--on` is not scp: it addresses a
#         DUCT, an object this repo declares, so it owes ssh no syntax.
#
# .the empty authority = this machine
#         `duct:///x` is the `file:///x` convention exactly: an empty authority
#         means local. that is what makes ONE format sufficient — the triple
#         slash disambiguates, so a URI round-trips with no second spelling.
#         ⚠️ a round-trip reads as ambiguous only where the empty authority is
#            collapsed rather than kept.
#
# .why it failsloud
#         a bare `worktree/mechanic` is an ERROR, not a local duct. to
#         accept it "for convenience" would restore the second format under
#         another name, and worse: `duct://grove-1/x` mistyped as
#         `grove-1/duct://x` would silently address a local duct named
#         `grove-1` — a send to the wrong machine that reports success.
######################################################################
__duct_parse_uri() {
  local uri="$1"

  if [[ "$uri" != duct://* ]]; then
    echo "✋ duct: --on takes a duct URI, got '$uri'" >&2
    echo "   ├─ remote: duct://<grove>/<tree>/<role>   e.g. duct://grove-1/main/mechanic" >&2
    echo "   ├─ local:  duct:///<tree>/<role>          e.g. duct:///worktree/mechanic" >&2
    echo "   └─ note:   local takes THREE slashes — an empty host means this machine" >&2
    return 2
  fi

  local rest="${uri#duct://}"

  if [[ "$rest" == /* ]]; then
    # empty authority -> this machine
    DUCT_HOST=""
    DUCT_SESSION="${rest#/}"
  else
    DUCT_HOST="${rest%%/*}"
    DUCT_SESSION="${rest#*/}"
  fi

  # a host with no path names no duct. caught here rather than left to tmux,
  # which would report `session 'grove-1' not found` and send a reader hunting
  # a session that was never named (rule.require.errors-name-the-fix)
  if [[ -z "$DUCT_SESSION" || "$rest" != */* ]]; then
    echo "✋ duct: '$uri' names a host but no duct" >&2
    echo "   └─ fix: add the session — duct://${DUCT_HOST}/main/mechanic" >&2
    return 2
  fi
}

######################################################################
# .what = read a duct URI as a SCOPE — name as much of the address as you know
#
#         duct://grove-1                -> host=grove-1  scope=""             (the grove)
#         duct://grove-1/main           -> host=grove-1  scope=main           (one tree)
#         duct://grove-1/main/mechanic  -> host=grove-1  scope=main/mechanic  (one duct)
#         duct:///                      -> host=""       scope=""             (this machine)
#
# .why  = an address that names LESS is not an error, it is a WIDER address —
#         exactly how a path already works, where a directory names its
#         contents. so `duct://grove-1` says "this grove" with no ceremony.
#
#         .why NO `/*` suffix (`duct://grove-1/*`): the star earns its keep
#         nowhere — `duct://grove-1` has no second sense to disambiguate from,
#         so the star is a token the human must remember AND quote against
#         their own shell's globber. a scope is a plain prefix, so it needs no
#         wildcard semantics to explain, and it has none.
#
# .note a trailing `/` or `/*` is accepted and means the same scope. a human
#       who types one out of habit is right, not wrong (rule.forbid.surprises)
#
# .why NOT the parser the acting verbs use: leniency here must never leak into
#       them. `duct.stop --on duct://grove-1` must stay an ERROR — under scope
#       rules it would read as "the whole grove", and a typo that drops a
#       session would kill every duct on the box. so the strict parser above
#       stands, and only `list` — which merely reports — reads a scope
######################################################################
__duct_parse_uri_scope() {
  local uri="$1"

  if [[ "$uri" != duct://* ]]; then
    echo "✋ duct: --on takes a duct URI, got '$uri'" >&2
    echo "   ├─ a grove:  duct://<grove>              e.g. duct://grove-1" >&2
    echo "   ├─ a tree:   duct://<grove>/<tree>       e.g. duct://grove-1/main" >&2
    echo "   └─ here:     duct:///                    (empty host = this machine)" >&2
    return 2
  fi

  local rest="${uri#duct://}"

  if [[ "$rest" == /* ]]; then
    DUCT_HOST=""
    DUCT_SCOPE="${rest#/}"
  else
    DUCT_HOST="${rest%%/*}"
    if [[ "$rest" == */* ]]; then DUCT_SCOPE="${rest#*/}"; else DUCT_SCOPE=""; fi
  fi

  # tolerate a habitual trailing `*` and `/`, in that order
  DUCT_SCOPE="${DUCT_SCOPE%\*}"
  DUCT_SCOPE="${DUCT_SCOPE%/}"
}

__duct_is_remote() {
  [[ -n "$DUCT_HOST" ]]
}

######################################################################
# .what = run ONE tmux command on the duct's host, every argument
#         delivered as literal bytes
#
# .why
#   - 🛑 ssh joins its args into one line for a far-side SHELL, so an
#     interpolated value is CODE — and a branch name or a remote pane cwd can
#     carry a quote
#   - 🛑 base64 is the fix at CAUSE: its alphabet holds no shell metacharacter,
#     so no deny-list is load-bear (`git.grove.send`'s refuses the wrong four)
#   - it is ONE function, so a new remote tmux call inherits the guarantee
#   - `--tty` and `--host` are flags, never a second function — each would
#     leave a second raw `ssh` seam for the next author to copy
# .refs = gotcha.2-7-ductwork.demo=sink-builder-and-seam, m4
#
# usage:
#   __duct_ssh_tmux send-keys -t "$DUCT_SESSION" "$what" Enter
#   __duct_ssh_tmux has-session -t "$DUCT_SESSION"
#   __duct_ssh_tmux --tty attach -t "$DUCT_SESSION"
#   __duct_ssh_tmux --host "$host" list-sessions -F '#{session_name}'
#
# .note = the flags are read in order, `--tty` then `--host`, and each is
#         optional. they are markers rather than a parse loop because this
#         helper takes tmux's OWN argv after them, and a loop would have to
#         guess where ours ends and tmux's begins.
######################################################################
__duct_ssh_tmux() {
  local arg b64 remote_cmd="tmux" want_tty="" host="$DUCT_HOST"
  if [[ "${1:-}" == "--tty" ]]; then
    want_tty=1
    shift
  fi
  if [[ "${1:-}" == "--host" ]]; then
    host="$2"
    shift 2
  fi
  for arg in "$@"; do
    b64="$(printf '%s' "$arg" | base64 | tr -d '\n')"
    remote_cmd+=" \"\$(printf %s '$b64' | base64 -d)\""
  done

  # 🛑 this helper is BOTH boundaries: it encodes what LEAVES and strips what
  #    ARRIVES, so a grove's answer (a pane cwd, a tty, a session name) is inert
  #    before any caller holds it. `--tty` is EXEMPT — an attach's stdout IS
  #    escapes, and the exposure is the one a human chose
  #    (.refs = gotcha.2-7-ductwork.demo=sink-builder-and-seam, m5)
  #
  # 🛑 the HOST is clamped first: ssh reads a positional that begins with `-` as
  #    an OPTION, and `-oProxyCommand=` runs a command on THIS box. termwork's
  #    `__term_as_ssh_host` is reused where loaded; the inline clamp covers a
  #    shell that sourced ductwork alone
  if command -v __term_as_ssh_host >/dev/null 2>&1; then
    host="$(__term_as_ssh_host "$host")" || return $?
  elif [[ -z "$host" || "$host" == -* ]]; then
    echo "✋ duct: '$host' is not a host — ssh reads a '-' at the front as an option" >&2
    echo "   └─ and one of them, -oProxyCommand=, runs a command on THIS box" >&2
    return 2
  fi

  if [[ -n "$want_tty" ]]; then
    ssh -t "$host" "$remote_cmd"
    return $?
  fi

  # 🛑 BOTH streams, and the status is SSH's. ssh runs with NO pipe on it: a
  #    pipe carries stdout only (stderr reached the terminal raw), and `$?` after
  #    a pipe is the SINK's — which read an asleep host as "session present".
  #    `pipefail` is no fix, since the host shell's options are not ours
  #   - stderr goes to a `mktemp` FILE, never `2> >(…)`: a process substitution
  #     is async, so the evidence would arrive sometimes
  #   - the `rm -f` is NOT a trap: a trap set in a function belongs to the
  #     human's interactive shell. the abort residue is a 0600 file `1.8.tmpfiles` sweeps
  #   (.refs = gotcha.2-7-ductwork.demo=sink-builder-and-seam, m6)
  local duct_err duct_out duct_rc=0
  duct_err="$(mktemp "${TMPDIR:-/tmp}/duct.ssh.err.XXXXXX" 2>/dev/null)" || {
    echo "💥 duct: could not open a scratch file for ssh's stderr" >&2
    echo "   └─ so the sanitize could not be honored, and ssh was NOT run" >&2
    return 255
  }

  duct_out="$(ssh "$host" "$remote_cmd" 2>"$duct_err")" || duct_rc=$?

  [[ -s "$duct_err" ]] && __duct_strip_escapes < "$duct_err" >&2
  rm -f "$duct_err"

  [[ -n "$duct_out" ]] && printf '%s\n' "$duct_out" | __duct_strip_escapes

  return "$duct_rc"
}

######################################################################
# .what = probe a remote duct, and CLASSIFY the outcome into its two causes
#
# .why  = `ssh <host> "tmux has-session"` fails for two very different reasons,
#         and a call site that collapses them prints one message for both:
#           - ssh could not connect      → the grove is down or asleep
#           - ssh ran, the session is absent → the duct was never opened
#
#         so a grove mid-hibernate answers `session 'grove-1:main/mechanic' not
#         found`, which sends a reader to hunt a lost tmux session while the
#         real fix is `grove.wake`. four sites want that classification, so it
#         lives here once rather than four times over
#         (rule.require.errors-name-the-fix, rule.require.solve-at-cause).
#
# .note = ssh exits 255 for its OWN failures (refused, closed, auth) and
#         otherwise passes the remote command's exit code through. that is what
#         makes the two causes separable at all.
#
# exit:
#   0   = reachable, and the session is present
#   1   = reachable, but the session is absent
#   255 = unreachable — ssh itself never got there
######################################################################
__duct_probe_remote_session() {
  # RETAIN ssh's stderr rather than discard it. a bare `2>/dev/null` here was a
  # failhide: it threw away the one piece of evidence that says WHICH failure
  # this is, and the caller then had to guess. ssh exits 255 for refused, timed
  # out, unknown host, bad key, AND host-key mismatch alike — so the exit code
  # alone cannot tell them apart, but ssh's own words can
  # (rule.forbid.failhide, rule.require.failloud)
  #
  # 🛑 the bytes this holds are ALREADY INERT — `__duct_ssh_tmux` strips both
  #    streams at capture. do NOT add a second strip here or at the replay
  #    (.refs = gotcha.2-7-ductwork.demo=sink-builder-and-seam, m7)
  DUCT_PROBE_STDERR=$(__duct_ssh_tmux has-session -t "$DUCT_SESSION" 2>&1 1>/dev/null)
  local code=$?
  [[ $code -eq 255 ]] && return 255
  [[ $code -ne 0 ]] && return 1
  return 0
}

# .what = one voice for "ssh never got there", carrying ssh's OWN words as the
#         evidence, plus the fix for each cause it could be
#
# .why  = to assert "the grove may be asleep" and name `grove.wake` is a GUESS:
#         only refused/timed-out means asleep. an unknown host, a wrong key, or
#         a host-key mismatch all exit 255 too, and `grove.wake` fixes none of
#         them. a confident wrong fix is the same defect this whole split sets
#         out to repair, just one layer smaller — so quote ssh, then offer the
#         fix per cause rather than assert one
__duct_say_unreachable() {
  local op="$1"
  local said="${DUCT_PROBE_STDERR:-}"

  ####################################################################
  # DIAGNOSE — match ssh's own words to ONE cause and name ONE fix.
  #
  # to print all four causes and let the human do the match is a lookup table,
  # not a diagnosis: we already hold the evidence, so to hand back a menu is to
  # make the reader redo work we could have done. a menu also dilutes the right
  # answer with three wrong ones.
  #
  # the fallback branch says "unmatched" outright rather than guess at the
  # nearest case — an unrecognized error must not be dressed as a known one
  # (rule.forbid.failhide)
  #
  # .exemption = the case patterns below quote OPENSSH's literal error text,
  #   including the word `resolve` that `rule.forbid.term=resolve` forbids.
  #   trigger: these are MATCHERS against another program's output, not our
  #   prose — reword one and the diagnosis silently stops matching, which is a
  #   worse defect than the word. openssh owns this vocabulary; we only read it.
  #   the same allowance the aws api's enum names already hold in this repo.
  ####################################################################
  local cause fix
  case "$said" in
    *"Connection refused"*|*"Connection timed out"*|*"Connection closed"*|*"No route to host"*|*"Operation timed out"*)
      cause="the grove is down, asleep, or its tunnel is dead"
      fix="rhx git.grove.wake <grove>" ;;
    *"REMOTE HOST IDENTIFICATION HAS CHANGED"*|*"Host key verification failed"*)
      cause="the endpoint answers with an identity we do not trust"
      fix="rhx git.grove.trust.gen --grove <grove>" ;;
    *"Permission denied"*)
      cause="the endpoint refused our key"
      fix="ssh -v '$DUCT_HOST'   # check the alias' IdentityFile" ;;
    *"Could not resolve hostname"*|*"Name or service not known"*|*"nodename nor servname"*)
      cause="'$DUCT_HOST' is not a host this machine knows"
      fix="rhx git.grove.wake <grove>   # writes the ssh alias" ;;
    *)
      cause="unmatched — ssh's words in the bucket are the only evidence"
      fix="ssh -v '$DUCT_HOST'   # verbose, to see where it stops" ;;
  esac

  # treestruct, with ssh's raw words held in a bucket. the bucket earns its
  # keep: the forwarded text is ANOTHER program's output, and a fenced region
  # says so — a reader never mistakes ssh's words for ours, and a multi-line
  # error keeps its shape instead of a smear into our prose
  # (rule.require.treestruct-output)
  echo "✋ duct.$op: cannot reach '$DUCT_HOST'" >&2
  echo "   ├─ what:  ssh itself failed, so the duct was never asked" >&2
  if [[ -n "$said" ]]; then
    echo "   ├─ ssh said" >&2
    echo "   │  ├─" >&2
    echo "   │  │" >&2
    # 🛑 `printf`, never `echo` — the VERB rule, not a second strip. zsh's `echo`
    #    expands a `\033` the sink correctly passed, and a pre-auth `Banner` lets
    #    an asleep grove choose these bytes (.refs = gotcha.2-7-ductwork.demo=sink-builder-and-seam, m2, m7)
    printf '%s\n' "$said" | sed 's/^/   │  │  /' >&2
    echo "   │  │" >&2
    echo "   │  └─" >&2
  fi
  echo "   ├─ cause: $cause" >&2
  echo "   ├─ fix:   $fix" >&2
  echo "   └─ note:  the session state is UNKNOWN — absent and present are both possible" >&2
}

duct.open() {
  local uri=""
  local mode="headless"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on) uri="$2"; shift 2 ;;
      --mode) mode="$2"; shift 2 ;;
      *) echo "✋ duct.open: unknown arg '$1'" >&2; return 2 ;;
    esac
  done
  if [[ -z "$uri" ]]; then
    echo "✋ duct.open: --on required" >&2
    return 2
  fi

  # `|| return` propagates a bad URI. without it the parser's error printed and
  # the verb carried on with an empty host+session — a failhide that would ssh
  # nowhere and blame the session (rule.forbid.failhide)
  __duct_parse_uri "$uri" || return 2

  if __duct_is_remote; then
    # remote: ssh to create/attach.
    #
    # the unreachable case must be caught BEFORE the create branch. without the
    # split, an asleep grove failed the probe, fell through to `new-session`,
    # failed that too, and reported "failed to create remote session" — which
    # blames the session for a box that was never reached
    __duct_probe_remote_session
    local probe=$?
    if [[ $probe -eq 255 ]]; then
      __duct_say_unreachable open
      return 1
    fi
    if [[ $probe -ne 0 ]]; then
      if ! __duct_ssh_tmux new-session -d -s "$DUCT_SESSION"; then
        echo "💥 duct.open: reached '$DUCT_HOST', but could not create session '$uri'" >&2
        return 1
      fi
      echo "🔧 $uri created (cloud)"
    else
      echo "🔧 $uri found (cloud)"
    fi

    # register host + duct
    __duct_register_host "$DUCT_HOST"
    __duct_register_duct "$DUCT_SESSION" "$DUCT_HOST"

    if [[ "$mode" == "headfull" ]]; then
      echo "🔧 $uri attach (ctrl+x d to detach)"
      __duct_ssh_tmux --tty attach -t "$DUCT_SESSION"
    fi
  else
    # local
    if ! tmux has-session -t "$DUCT_SESSION" 2>/dev/null; then
      if ! tmux new-session -d -s "$DUCT_SESSION"; then
        echo "💥 duct.open: failed to create session '$uri'" >&2
        return 1
      fi
      echo "🔧 $uri created (local)"
    else
      echo "🔧 $uri found (local)"
    fi

    # register duct with the EMPTY host — the canonical "this machine" form,
    # matching the uri's empty authority. a `"localhost"` here makes
    # `duct.list` print an address that takes the ssh path when pasted back
    __duct_register_duct "$DUCT_SESSION" ""

    if [[ "$mode" == "headfull" ]]; then
      echo "🔧 $uri attach (ctrl+x d to detach)"
      tmux attach -t "$DUCT_SESSION"
    fi
  fi
}

######################################################################
# .what = the command that holds a duct's pane right now
#
# .why  = `send-keys` is a KEYSTROKE, not a queued command. it goes wherever the
#         pane's foreground process reads stdin. at a prompt that is the shell,
#         which runs it. mid-`apt` that is apt, which swallows it.
#
#         so a duct has two states a caller must tell apart, and tmux already
#         knows which: `pane_current_command` IS the foreground command.
#
# echoes: the command name (e.g. `bash`, `apt`, `nvim`), or empty if unreadable
######################################################################
######################################################################
# 🛑 .the value is SUNK HERE, at the source, for BOTH branches
#
#    `#{pane_current_command}` is `argv[0]` of whatever the grove chose to run,
#    so it is remote-chosen bytes on the laptop's terminal — the same class as
#    `$said` and `$pane_cwd`, which `__duct_ssh_tmux:517` already enumerates.
#
# ⚠️ .why the sink rides the FUNCTION and not its three relay sites
#    the two branches below are NOT equally protected: the remote one is
#    byte-sunk by `__duct_ssh_tmux`, and the local one is a plain `tmux` with no
#    capture-time strip at all. a sink placed at the callers would be one strip
#    per message — three copies of one rule, free to drift (m.9). placed here it
#    is one, and `__duct_pane_is_idle` reads clean bytes too, which is right: a
#    command name that carries an escape must not be able to match `bash`.
#
# ⚠️ .the sink is NOT enough on its own — the verb matters too
#    the strip is a BYTE filter, so a name that spells an escape as the four
#    printable characters `\`,`0`,`3`,`3` passes it correctly and is re-authored
#    by zsh's builtin `echo`. every relay of this value therefore uses
#    `printf '%s'` (see `duct.send`'s BUSY block).
#
# echoes: the command name (e.g. `bash`, `apt`, `nvim`), or empty if unreadable
######################################################################
__duct_pane_command() {
  if __duct_is_remote; then
    __duct_ssh_tmux display-message -p -t "$DUCT_SESSION" '#{pane_current_command}' 2>/dev/null \
      | __duct_strip_escapes
  else
    tmux display-message -p -t "$DUCT_SESSION" '#{pane_current_command}' 2>/dev/null \
      | __duct_strip_escapes
  fi
}

# .what = is the pane sat at a shell prompt, ready to RUN what it is sent?
# .why  = the shells are the closed set that read a line and execute it. every
#         other command reads stdin for its OWN purpose, so a send reaches it as
#         input rather than as a command. a login shell may report `-bash`
__duct_pane_is_idle() {
  case "${1:-}" in
    bash|-bash|zsh|-zsh|sh|-sh|dash|ksh|fish) return 0 ;;
    *) return 1 ;;
  esac
}

duct.send() {
  local uri=""
  local what=""
  local await=0      # seconds to wait for the pane to fall idle
  local anyway=0     # send into a busy pane on purpose (answer a prompt)
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on) uri="$2"; shift 2 ;;
      --what) what="$2"; shift 2 ;;
      --await) await="${2:-300}"; shift 2 ;;
      --anyway) anyway=1; shift ;;
      *) echo "✋ duct.send: unknown arg '$1'" >&2; return 2 ;;
    esac
  done
  if [[ -z "$uri" ]]; then
    echo "✋ duct.send: --on required" >&2
    return 2
  fi
  if [[ -z "$what" ]]; then
    echo "✋ duct.send: --what required" >&2
    return 2
  fi

  # `|| return` propagates a bad URI. without it the parser's error printed and
  # the verb carried on with an empty host+session — a failhide that would ssh
  # nowhere and blame the session (rule.forbid.failhide)
  __duct_parse_uri "$uri" || return 2

  if __duct_is_remote; then
    __duct_probe_remote_session
    local probe=$?
    if [[ $probe -eq 255 ]]; then
      __duct_say_unreachable send
      return 2
    fi
    if [[ $probe -ne 0 ]]; then
      echo "✋ duct.send: reached '$DUCT_HOST', but session '$uri' is absent" >&2
      echo "   fix: open the duct first —" >&2
      echo "     duct.open --on '$uri'" >&2
      return 2
    fi
  else
    if ! tmux has-session -t "$DUCT_SESSION" 2>/dev/null; then
      echo "✋ duct.send: session '$uri' is absent on this machine" >&2
      echo "   fix: open the duct first — duct.open --on '$uri'" >&2
      return 2
    fi
  fi

  ####################################################################
  # the BUSY guard.
  #
  # a send to a busy pane does not queue — it lands in the held program's
  # STDIN. observed live: a `true` sent to a duct mid-`apt` was eaten by apt,
  # and surfaced in the scrollback spliced into apt's own progress line.
  #
  # that instance was harmless. the shape is not: the same slip puts any text
  # into whatever holds the terminal — an editor, an `rm -i` prompt, a `sudo`
  # password read. and it is SILENT, because tmux reports a delivered keystroke
  # as success whoever consumed it.
  #
  # so refuse by default and name the two ways forward
  # (rule.prefer.prevent-over-correct: make the wrong act hard, not merely
  # documented; rule.require.errors-name-the-fix).
  ####################################################################
  if [[ "$anyway" -eq 0 ]]; then
    local held elapsed=0
    held=$(__duct_pane_command)

    # --await: the pane is busy for a REASON; wait it out rather than refuse
    while [[ "$await" -gt 0 ]] && ! __duct_pane_is_idle "$held"; do
      [[ "$elapsed" -ge "$await" ]] && break
      sleep 2
      elapsed=$(( elapsed + 2 ))
      held=$(__duct_pane_command)
    done

    if [[ -n "$held" ]] && ! __duct_pane_is_idle "$held"; then
      ##################################################################
      # 🛑 `printf '%s'` for `$held`, never `echo` — it is the GROVE's `argv[0]`
      #
      #    `__duct_pane_command` sinks the bytes, and a sink cannot see an escape
      #    spelled as TEXT: the four printable characters `\`,`0`,`3`,`3` are
      #    inert to it and correctly pass. zsh's builtin `echo` then expands them
      #    into a real ESC, and `src/grove.provision/2.shell/2.5.zsh/zshrc.sh:204` sources this file into an
      #    interactive zsh — so the unsafe half is the half a human types.
      #
      #    this is the same pair `:808` and `:1656` hold — one cause, four
      #    effects (round 12's lesson, on the file that taught it).
      ##################################################################
      printf "✋ duct.send: '%s' is BUSY — '%s' holds the pane\n" "$uri" "$held" >&2
      echo "" >&2
      echo "   what: a send is a keystroke, not a queued command. it would land" >&2
      printf "         in %s's stdin, where tmux still reports it delivered\n" "$held" >&2
      echo "" >&2
      if [[ "$await" -gt 0 ]]; then
        echo "   note: waited ${elapsed}s and it is still busy" >&2
        echo "" >&2
      fi
      echo "   fix: wait for it, then send —" >&2
      echo "     duct.send --on '$uri' --await 600 --what '<cmd>'" >&2
      echo "" >&2
      printf "   or, to type INTO %s on purpose (answer its prompt) —\n" "$held" >&2
      echo "     duct.send --on '$uri' --anyway --what '<input>'" >&2
      return 2
    fi

    # an empty read means tmux could not be asked. do NOT treat that as idle —
    # that would be a failhide, and the send would be the very slip this guard
    # exists to prevent (rule.forbid.failhide)
    if [[ -z "$held" ]]; then
      echo "✋ duct.send: could not read what holds '$uri'" >&2
      echo "   what: tmux gave no pane_current_command, so BUSY and IDLE are" >&2
      echo "         both possible and a send may reach a program's stdin" >&2
      echo "   fix: look first — duct.read --on '$uri'" >&2
      echo "        then, if it is at a prompt — duct.send --on '$uri' --anyway ..." >&2
      return 2
    fi
  fi

  if __duct_is_remote; then
    # ⚠️ an interpolation of `$what` into the ssh string is the injection this
    #    whole family shares: a single quote in it closes the quote and runs
    #    the rest as shell. `__duct_ssh_tmux` states the fix and the reason
    #    once, for all ten call sites.
    if ! __duct_ssh_tmux send-keys -t "$DUCT_SESSION" "$what" Enter; then
      echo "💥 duct.send: failed to send to '$uri'" >&2
      return 1
    fi
  else
    if ! tmux send-keys -t "$DUCT_SESSION" "$what" Enter; then
      echo "💥 duct.send: failed to send to '$uri'" >&2
      return 1
    fi
  fi
  echo "🔧 $uri sent"
}

duct.read() {
  local uri=""
  local lines=500
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on) uri="$2"; shift 2 ;;
      --lines) lines="$2"; shift 2 ;;
      *) echo "✋ duct.read: unknown arg '$1'" >&2; return 2 ;;
    esac
  done
  if [[ -z "$uri" ]]; then
    echo "✋ duct.read: --on required" >&2
    return 2
  fi

  # `|| return` propagates a bad URI. without it the parser's error printed and
  # the verb carried on with an empty host+session — a failhide that would ssh
  # nowhere and blame the session (rule.forbid.failhide)
  __duct_parse_uri "$uri" || return 2

  if __duct_is_remote; then
    __duct_probe_remote_session
    local probe=$?
    if [[ $probe -eq 255 ]]; then
      __duct_say_unreachable read
      return 2
    fi
    if [[ $probe -ne 0 ]]; then
      echo "✋ duct.read: session '$uri' is absent" >&2
      echo "   ├─ what: ssh REACHED '$DUCT_HOST'; tmux holds no session by that name" >&2
      echo "   └─ fix:  rhx git.grove.send <grove> --what 'tmux list-sessions'" >&2
      return 2
    fi
    echo "🔭 $uri (cloud)"
    __duct_ssh_tmux capture-pane -t "$DUCT_SESSION" -p -S "-$lines"
  else
    if ! tmux has-session -t "$DUCT_SESSION" 2>/dev/null; then
      echo "✋ duct.read: session '$uri' is absent on this machine" >&2
      echo "   ├─ what: tmux holds no session by that name" >&2
      echo "   └─ fix:  tmux list-sessions   # what this machine holds" >&2
      return 2
    fi
    echo "🔭 $uri (local)"
    tmux capture-pane -t "$DUCT_SESSION" -p -S "-$lines"
  fi
}

######################################################################
# .what = is this host string THIS machine?
#
# .why  = "this machine" has TWO spellings, and uncast they disagree on
#         behavior:
#           ""           the uri's empty authority (duct:///x)
#           "localhost"  the registry + refresh token
#
#         uncast, `duct.list` prints `duct://localhost/x` for a duct opened as
#         `duct:///x`. that is not merely a cosmetic mismatch — it breaks the
#         one rule the uri exists to keep, that what you READ is what you TYPE.
#         pasted back, `duct://localhost/x` has a non-empty authority, so it
#         takes the SSH path (`ssh localhost`) rather than the direct tmux
#         path. same duct, different code path, and the difference is invisible.
#
#         the canonical form is EMPTY, because that is what the uri grammar
#         already declares. `localhost` is still ACCEPTED — a human may type
#         `--host localhost`, and the extant registry is full of it — but it is
#         cast to the canonical form on the way in, and never written out.
######################################################################
__duct_host_is_here() {
  [[ -z "$1" || "$1" == "localhost" ]]
}

# .what = cast any form of a host to its canonical one
# .why  = one caster, so every read/compare/write site agrees. an inline test at
#         each site is how the two forms diverged in the first place
__duct_as_host_canonical() {
  if __duct_host_is_here "$1"; then echo ""; else echo "$1"; fi
}

######################################################################
# .what = list the live tmux sessions a host holds
#
# .return 0 = the host ANSWERED; stdout holds its sessions, maybe zero of them
#         3 = the host was never reached; stdout says nought about its ducts
#
# .why 3 here but 2 at the verb: this is an INTERNAL signal, and it needs a code
#      that tmux's own exits cannot collide with — tmux uses 1 for "no server".
#      the VERBS translate it to exit 2, the declared constraint code, because
#      the caller is the one who fixes it (wake the grove)
#
# 🛑 .why a distinct code, and never a bare `ssh … 2>/dev/null`
#      under a bare call an empty stdout means BOTH "this grove holds no ducts"
#      and "the tunnel is down", and no caller can tell the two apart. worse,
#      `__duct_refresh_host` reads an empty list as "every registered duct is
#      stale" and DELETES them — so one blink of a tunnel wipes the registry for
#      a grove whose ducts are all alive, and `duct.list` reports a confident
#      `(none)` about a machine it never spoke to (rule.forbid.failhide).
#
# .how ssh reserves exit 255 for its OWN failures — dns, connect, auth. a
#      remote `tmux list-sessions` exits 0 with sessions or 1 with none, and
#      never 255, so 255 says unambiguously "the box was never reached".
#
# .note a LOCAL probe always answers: tmux with no server exits 1, which is an
#       answer of zero ducts, not a failure to ask
######################################################################
__duct_list_host_sessions() {
  local host="$1"
  if __duct_host_is_here "$host"; then
    tmux list-sessions -F "#{session_name}" 2>/dev/null
    return 0
  fi
  # NOT named `status`: zsh reserves `status` as a READ-ONLY special parameter
  # (its alias for `$?`), so `local status=0` dies with `read-only variable`.
  # bash has no such reservation, so the name passes there and fails only in
  # the human's shell — the same dialect trap as `${!a[@]}` and `${~want}`
  #
  # ⚠️ `--host`, because this walks the REGISTRY — the host here is not the
  #    parsed `$DUCT_HOST` the helper defaults to. the helper still returns
  #    ssh's own exit code, so the 255 read below is unchanged
  local out="" exitcode=0
  out=$(__duct_ssh_tmux --host "$host" list-sessions -F "#{session_name}" 2>/dev/null)
  exitcode=$?
  [[ "$exitcode" == 255 ]] && return 3
  [[ -n "$out" ]] && printf '%s\n' "$out"
  return 0
}

__duct_refresh_host() {
  local host="$1"
  __duct_ensure_dirs

  # cast first, so a refresh never re-writes the `localhost` form back into the
  # registry it is meant to clean
  host="$(__duct_as_host_canonical "$host")"

  # update host lastSeen
  if [[ -n "$host" ]]; then
    __duct_register_host "$host"
  fi

  ####################################################################
  # get live sessions
  #
  # .why the guard: everything below treats the live list as the TRUTH — a
  #      registered duct absent from it is reaped. that is only sound when the
  #      host actually answered. an unreachable host yields the same empty
  #      list, so without this guard a dropped tunnel reaps every duct the
  #      grove still holds, and the loss is silent and permanent
  ####################################################################
  local sessions="" reached=0
  sessions=$(__duct_list_host_sessions "$host"); reached=$?
  if [[ "$reached" != 0 ]]; then
    echo "✋ duct: could not reach '$host' — its ducts are left exactly as they were" >&2
    echo "   └─ fix: wake it — rhx git.grove.wake $host" >&2
    return 2
  fi

  ####################################################################
  # register each session
  #
  # 🛑 every name below is REMOTE-CHOSEN. `$sessions` is what a grove's tmux
  #    answered, and a grove is assumed compromised — so each one is checked
  #    against the registry name grammar before it can become a laptop path
  #    (`__duct_as_registry_file`, which carries the measurement).
  #
  # ⚠️ a refused name is REPORTED and skipped, never dropped in silence: it
  #    means the far side named a session this registry cannot hold, and a
  #    refresh that claims success while it skipped a row is a false ✔
  #    (`rule.forbid.failhide`)
  ####################################################################
  local session refused=0
  while IFS= read -r session; do
    [[ -z "$session" ]] && continue
    __duct_register_duct "$session" "$host" || refused=$((refused + 1))
  done <<< "$sessions"
  if [[ "$refused" != 0 ]]; then
    echo "   ⚠️ $host named $refused session(s) this registry refused — see the rows above" >&2
  fi

  # remove stale ducts for this host
  # recurse: ducts may be nested (ducts/tree/role.json) when session holds a
  # slash; derive session as the path relative to ducts/ so the tree prefix is
  # kept and the grep comparison against live sessions matches
  local f duct_session duct_host
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    # cast before the compare: `host` is canonical (empty for here), but a row
    # written earlier may say `localhost`. without this, a stale LOCAL duct
    # never matches its own host and is never reaped
    duct_host="$(__duct_as_host_canonical "$(jq -r '.host // ""' "$f" 2>/dev/null)")"
    [[ "$duct_host" != "$host" ]] && continue
    duct_session="${f#"$DUCTWORK_DIR"/ducts/}"
    duct_session="${duct_session%.json}"
    # 🛑 `--` and `printf`, both load-bear — measured 2026-09-01
    #    a session name may OPEN WITH A DASH: this file's own registry grammar
    #    admits it (`__duct_as_registry_file`, `[A-Za-z0-9._-]`), and the name
    #    itself came from a grove's `tmux list-sessions`. two defects follow,
    #    and both land in the DELETE direction — a LIVE duct gets reaped:
    #
    #      · without `--`, a pattern of `-n` is read as an OPTION. grep finds
    #        no pattern, exits 2, `! grep` is true, and the row is removed.
    #        measured across `-n -v -i -e -r`: every one lands on the delete.
    #      · without `printf`, `echo "$sessions"` empties the SUBJECT when the
    #        live list is exactly one session named `-n` — so every registered
    #        duct on this host reads as absent, and all of them are reaped.
    #
    #    ⚠️ the second half hides from the obvious probe: a MULTI-line list is
    #      safe, since bash's echo tests the whole argument against `-n`/`-e`
    #      — so a multi-session probe passes and says none of what the
    #      one-session case does.
    if ! printf '%s\n' "$sessions" | grep -qxF -- "$duct_session"; then
      rm -f "$f"
      rmdir --ignore-fail-on-non-empty "$(dirname "$f")" 2>/dev/null || true
    fi
  done < <(find "$DUCTWORK_DIR/ducts" -type f -name '*.json' 2>/dev/null)
}

######################################################################
# .what = list ducts, optionally narrowed to a duct URI SCOPE
#
#   duct.list                                every duct, from cache
#   duct.list --on duct://grove-1            every duct on a grove
#   duct.list --on duct://ubuntu@host        userinfo is part of the authority
#   duct.list --on duct:///                  every duct on THIS machine
#   duct.list --on duct://grove-1/main       every role in one tree
#   duct.list --on duct://grove-1/main/mechanic   one duct
#   duct.list --refresh                      re-read live state first
#
# .why a URI, not a bare host
#       `--on` takes a duct URI in every other verb. a `--host <machine>` flag
#       of its own would rest on the claim that "list narrows by MACHINE, a
#       different kind of value" — and that claim is wrong: a machine is not a
#       different kind of value, it is a duct URI with the session part left
#       off. `duct://grove-1` says that outright, and it composes — the same
#       address narrows to a tree (`/main`) with no new flag.
#
# .why no `*`
#       `duct://grove-1/*` earns its keep nowhere: `duct://grove-1` has no
#       second sense it needs disambiguated from, so the star is a token to
#       remember AND to quote against your own shell's globber — friction for
#       zero clarity. the address is simply a PREFIX: name as much as you know.
#
#       (a trailing `*` or `/` is still accepted, so habit costs no error.)
######################################################################
duct.list() {
  local scope=""
  local refresh=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on) scope="$2"; shift 2 ;;
      --host)
        echo "✋ duct.list: --host is retired; --on takes a duct URI" >&2
        echo "   └─ fix: duct.list --on duct://${2:-<host>}" >&2
        return 2
        ;;
      --refresh) refresh="1"; shift ;;
      *) echo "✋ duct.list: unknown arg '$1'" >&2; return 2 ;;
    esac
  done

  __duct_ensure_dirs

  # if a scope was given, query that machine live
  if [[ -n "$scope" ]]; then
    # a list reads its address as a SCOPE — as much as the human knew to name
    __duct_parse_uri_scope "$scope" || return 2
    local host="$DUCT_HOST" want="$DUCT_SCOPE"

    if [[ -n "$refresh" ]]; then
      __duct_refresh_host "$host"
    fi

    ##################################################################
    # a scope matches a duct that IS it, or that lives UNDER it
    #
    # .why the `/` in the second test: a bare prefix would let the scope
    #       `main` match a duct named `mainline/x`, since the text does start
    #       with `main`. an address names whole segments, so only a `/` may
    #       follow — `main` covers `main/mechanic`, never `mainline/…`
    #
    # .why no glob compare: `[[ "$name" == $want ]]` — an unquoted variable on
    #       the right — pattern-matches in bash but NOT in zsh, which reads a
    #       substituted value as literal text unless written `${~want}`. so
    #       that compare matches no duct at all in the human's shell and every
    #       list comes back `(none)` — the SAME dialect defect as the
    #       `${!a[@]}` one this function also guards. the cure is syntax that
    #       needs no dialect: here the `/` and the `*` sit in the SOURCE TEXT,
    #       and the variable stays quoted.
    ##################################################################
    local sessions="" found=0 reached=0
    sessions=$(__duct_list_host_sessions "$host"); reached=$?
    if [[ -z "$host" ]]; then echo "📡 (this machine)"; else echo "📡 $host"; fi

    # a machine we never reached gets NO verdict about its ducts. `(none)` here
    # would be a claim we cannot back — the grove may hold a dozen
    if [[ "$reached" != 0 ]]; then
      echo "   └─ ✋ unreachable — cannot say which ducts it holds"
      echo "      fix: wake it — rhx git.grove.wake $host"
      return 2
    fi

    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      if [[ -n "$want" ]]; then
        [[ "$name" == "$want" || "$name" == "$want"/* ]] || continue
      fi
      # 🛑 this is the SECOND reader of `$sessions`, and it is grove-chosen text.
      #    `__duct_refresh_host` puts every name through the registry grammar, so
      #    this branch must too — one set with two grammars is m.9, and a header
      #    that claims "every name below is checked" is then true of one reader
      #    and false of the other.
      #
      #    ⇒ reuse the ONE grammar rather than restate it here; a second copy is
      #    the defect itself. a refused name prints its own refusal on stderr and
      #    is SKIPPED, never rendered as a `duct://` address no other duct verb
      #    would accept.
      __duct_as_registry_file ducts "$name" >/dev/null || continue
      # printf, never echo: `$name` is grove-chosen (`term=relay`, property 2)
      printf '   ├─ duct://%s/%s\n' "$host" "$name"
      found=1
    done <<< "$sessions"
    [[ "$found" == 1 ]] || echo "   └─ (none)"
    return
  fi

  # refresh all hosts if requested
  if [[ -n "$refresh" ]]; then
    # refresh this machine (empty host = here)
    __duct_refresh_host ""
    ##################################################################
    # refresh remote hosts
    #
    # .why its own names: zsh's `local` IS `typeset`, and `typeset name` with
    #       no value, for a name that ALREADY holds one, PRINTS it. so a second
    #       `local f` further down this function echoes `f=/…/grove-1.json`
    #       into the duct list — debug noise nobody wrote, on the `--refresh`
    #       path only, since the plain path never sets `f` first.
    #
    #       the rule that kills it for good: declare each name exactly ONCE per
    #       function. bash tolerates the re-declare silently; zsh narrates it.
    ##################################################################
    #
    # .why `find`, not a `for … *.json` glob: when the glob matches NO file,
    #      bash leaves it as literal text (so `[[ -f ]]` skips it) but zsh's
    #      default `nomatch` makes it a HARD ERROR that aborts the whole
    #      function. a grove holds zero remote hosts, so `duct.list --refresh`
    #      dies on a grove under zsh — not one duct emitted, local or
    #      remote — while it passes on a laptop, which has a host file.
    #      `find` emits no line for no match, in every shell, with no option
    #      to set
    local host_file host_name
    while IFS= read -r host_file; do
      [[ -f "$host_file" ]] || continue
      host_name=$(basename "$host_file" .json)
      __duct_refresh_host "$host_name"
    done < <(find "$DUCTWORK_DIR/hosts" -type f -name '*.json' 2>/dev/null)
  fi

  ####################################################################
  # collect one `host|session` row per duct, then sort + group
  #
  # .why a PIPE delimiter, not a tab: a LOCAL duct's host is the EMPTY string
  #       (the uri's empty authority), so its row leads with the delimiter. a
  #       tab is IFS *whitespace* — `read` collapses leading runs of it — so
  #       `read -r h s` on "<TAB>dev" hands back h=dev, s="", and the
  #       `[[ -n "$s" ]]` guard then skips EVERY local duct. bare `duct.list`
  #       then prints no ducts and not even `(none)`, because the rows exist
  #       and are each dropped one by one.
  #
  #       a pipe is not IFS whitespace, so an empty leading field survives. no
  #       host or session may hold one — a host is authority text (alnum, `.`,
  #       `-`, `@`) and a session is `<tree>/<role>`.
  #
  # .why no associative array: the grouped-by-host shape begs for one, walked
  #       with `${!host_ducts[@]}`. that is BASH-ONLY syntax; zsh reads `${!x}`
  #       as an indirect expansion it does not support and dies with `bad
  #       substitution`. this file is sourced by an interactive ZSH, so such a
  #       `duct.list` is broken for every human who runs it while it passes in
  #       every bash check — a dialect split that hides in plain sight because
  #       the test shell is not the human's shell.
  #
  #       the tempting fix is a dialect branch (`${(k)a[@]}` vs `${!a[@]}`).
  #       a sort+group over plain rows needs NO branch at all, and the data is
  #       one line per duct — a scale at which a hash buys no speed. solved at
  #       cause: the array is the only reason a dialect matters.
  #
  # .note recurse: ducts may be nested (ducts/tree/role.json) when a session
  #       holds a slash; the session is the path relative to ducts/, so the tree
  #       prefix is kept
  ####################################################################
  local rows="" f duct_host duct_session
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    # a LOCAL duct records the EMPTY host, which is exactly the uri's empty
    # authority. the registry still holds `localhost` rows written before that
    # was settled, so they are cast on READ — an old row must not print an
    # address that behaves differently than the one it names
    duct_host="$(__duct_as_host_canonical "$(jq -r '.host // ""' "$f" 2>/dev/null)")"
    duct_session="${f#"$DUCTWORK_DIR"/ducts/}"
    duct_session="${duct_session%.json}"
    rows="${rows}${duct_host}|${duct_session}
"
  done < <(find "$DUCTWORK_DIR/ducts" -type f -name '*.json' 2>/dev/null)

  if [[ -z "$rows" ]]; then
    echo "📡 (none)"
    return
  fi

  # one pass over the sorted rows: a new host opens a group, the rest fall under
  # it. each duct prints as the URI you would type back into --on
  #
  # .why LC_ALL=C: the group depends on every row of one host sorted TOGETHER,
  #      which needs the delimiter to sort as a real character. a default
  #      locale collates punctuation as IGNORABLE on the first pass, so `|65`
  #      compared as `65` and `grove-1|main` as `grove1main` — the rows sorted
  #      by SESSION name and the hosts interleaved. the list then printed
  #      `📡 (this machine)` twice, once on each side of `📡 grove-1`, as if a
  #      duct had two homes. `LC_ALL=C` is a byte sort, where `|` is simply
  #      0x7C, so a host's rows are contiguous by construction
  #
  # ⚠️ .why `printf '%s\n'` and not `printf '%s'`
  #      `read` returns non-zero at EOF, so a final row with no newline after it
  #      is read and then DROPPED before the loop body runs — the last duct would
  #      simply not appear in the list, with no error to notice.
  #
  #      today `sort` hides that: it always terminates its output with a newline,
  #      so the bug is latent rather than live. it would surface the moment the
  #      sort is removed or moved — and it would surface as "a duct vanished",
  #      which reads as a duct problem, never as a parse one. the newline is
  #      cheap; the dependence on sort's behavior is not
  #      (gotcha.while-read-drops-the-last-line)
  local host_last="__unset__" h s
  printf '%s\n' "$rows" | LC_ALL=C sort | while IFS='|' read -r h s; do
    [[ -n "$s" ]] || continue
    if [[ "$h" != "$host_last" ]]; then
      if [[ -z "$h" ]]; then echo "📡 (this machine)"; else echo "📡 $h"; fi
      host_last="$h"
    fi
    echo "   ├─ duct://${h}/${s}"
  done
}

duct.stop() {
  local uri=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on) uri="$2"; shift 2 ;;
      *) echo "✋ duct.stop: unknown arg '$1'" >&2; return 2 ;;
    esac
  done
  if [[ -z "$uri" ]]; then
    echo "✋ duct.stop: --on required" >&2
    return 2
  fi

  # `|| return` propagates a bad URI. without it the parser's error printed and
  # the verb carried on with an empty host+session — a failhide that would ssh
  # nowhere and blame the session (rule.forbid.failhide)
  __duct_parse_uri "$uri" || return 2

  if __duct_is_remote; then
    __duct_probe_remote_session
    local probe=$?
    if [[ $probe -eq 255 ]]; then
      __duct_say_unreachable stop
      return 2
    fi
    if [[ $probe -ne 0 ]]; then
      # an already-absent target is NOT a constraint error: a stop whose target
      # is already absent has REACHED its goal, so a `return 2` here is wrong —
      # `rule.require.get-set-gen-verbs` puts stop/del in the
      # idempotent family ("remove if extant, no-op if absent"), and
      # `rule.require.idempotent-procedures` wants a re-run to be safe. a caller
      # that stops twice should not have to swallow an error to stay correct
      echo "• duct.stop: session '$uri' is already absent; skipped"
      return 0
    fi
    if ! __duct_ssh_tmux kill-session -t "$DUCT_SESSION"; then
      echo "💥 duct.stop: failed to stop '$uri'" >&2
      return 1
    fi
  else
    # idempotent, same as the remote branch: an already-absent target means the
    # stop has reached its goal (rule.require.get-set-gen-verbs)
    if ! tmux has-session -t "$DUCT_SESSION" 2>/dev/null; then
      echo "• duct.stop: session '$uri' is already absent; skipped"
      return 0
    fi
    if ! tmux kill-session -t "$DUCT_SESSION"; then
      echo "💥 duct.stop: failed to stop '$uri'" >&2
      return 1
    fi
  fi

  # unregister duct
  __duct_unregister_duct "$DUCT_SESSION"

  echo "🔧 $uri stopped"
}

######################################################################
# duct.reboot — replace the program a duct's pane holds, keep the duct
#
# .what = kill whatever holds the pane and spawn a fresh shell in it. the
#         session, the window, the duct's name, and the cwd all survive; only
#         the wedged program is replaced.
#
# .why  = a duct can be BUSY with a program that will never finish — a hung
#         `pnpm --version`, an nvim that stopped repaint, a build with no
#         timeout. `duct.send` then rightly refuses (`term=duct.idle`), and the
#         only other escape is `duct.stop` + `duct.open`, which throws away the
#         scrollback and the cwd along with the hang.
#
#         worse, the absence of this verb was used as an excuse: on 2026-07-29 a
#         robot hit a busy duct mid-diagnosis and reached for ~10 raw
#         `ssh grove-1 "…"` calls instead — the exact act
#         `rule.require.reach-a-grove-through-its-duct` forbids. the human's
#         answer was "if you ever have a duct stuck, just duct.reboot it".
#         **an absent escape hatch does not license a rule violation; it licenses
#         the escape hatch.**
#
# .why NOT idempotent, deliberately: `stop` is idempotent because an absent
#         target means the goal is reached. a reboot of an ABSENT duct has no
#         goal to reach — there is no pane to respawn, and to silently open one
#         would make `reboot` a second spelling of `open`. so it fails and names
#         `duct.open` as the fix (rule.require.errors-name-the-fix).
#
# .why capture the cwd FIRST: `respawn-pane` without `-c` lands the fresh shell
#         in the pane's ORIGINAL cwd, not its current one. a duct that has been
#         `cd`'d into a worktree would silently jump back to $HOME, and the next
#         command sent would run in the wrong tree. read `pane_current_path`
#         before the kill, and hand it back after.
#
#         adopted from nheuron's `duct.reboot`, with the remote branch added —
#         nheuron's is local-only because it has no grove to reach.
#
# usage:
#   duct.reboot --on duct:///main/mechanic
#   duct.reboot --on duct://grove-1/main/mechanic
######################################################################
duct.reboot() {
  local uri=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on) uri="$2"; shift 2 ;;
      *) echo "✋ duct.reboot: unknown arg '$1'" >&2; return 2 ;;
    esac
  done
  if [[ -z "$uri" ]]; then
    echo "✋ duct.reboot: --on required" >&2
    echo "   └─ e.g. duct.reboot --on duct://grove-1/main/mechanic" >&2
    return 2
  fi

  __duct_parse_uri "$uri" || return 2

  # NOT named `status`: zsh reserves `status` as a READ-ONLY special parameter
  local pane_cwd=""

  if __duct_is_remote; then
    __duct_probe_remote_session
    local probe=$?
    if [[ $probe -eq 255 ]]; then
      __duct_say_unreachable reboot
      return 2
    fi
    if [[ $probe -ne 0 ]]; then
      echo "✋ duct.reboot: '$uri' is absent — there is no pane to reboot" >&2
      echo "   └─ fix: duct.open --on $uri" >&2
      return 2
    fi
    # 🛑 $pane_cwd is read OFF THE REMOTE BOX, so it is the untrusted side in
    #    full — a compromised grove hands back its own string and the local
    #    shell would run it. that is the same trust inversion
    #    `rule.require.narrowest-terminal-grant` closes at the terminal, and
    #    `__duct_ssh_tmux` is what closes it here
    pane_cwd=$(__duct_ssh_tmux display-message -p -t "$DUCT_SESSION" '#{pane_current_path}' 2>/dev/null)
    if [[ -n "$pane_cwd" ]]; then
      __duct_ssh_tmux respawn-pane -k -c "$pane_cwd" -t "$DUCT_SESSION" || {
        echo "💥 duct.reboot: respawn failed on '$uri'" >&2; return 1; }
    else
      __duct_ssh_tmux respawn-pane -k -t "$DUCT_SESSION" || {
        echo "💥 duct.reboot: respawn failed on '$uri'" >&2; return 1; }
    fi
  else
    if ! tmux has-session -t "$DUCT_SESSION" 2>/dev/null; then
      echo "✋ duct.reboot: '$uri' is absent — there is no pane to reboot" >&2
      echo "   └─ fix: duct.open --on $uri" >&2
      return 2
    fi
    pane_cwd=$(tmux display-message -p -t "$DUCT_SESSION" '#{pane_current_path}' 2>/dev/null)
    if [[ -n "$pane_cwd" ]]; then
      tmux respawn-pane -k -c "$pane_cwd" -t "$DUCT_SESSION" || {
        echo "💥 duct.reboot: respawn failed on '$uri'" >&2; return 1; }
    else
      tmux respawn-pane -k -t "$DUCT_SESSION" || {
        echo "💥 duct.reboot: respawn failed on '$uri'" >&2; return 1; }
    fi
  fi

  echo "🔧 $uri rebooted"
  # 🛑 .$pane_cwd reaches a TERMINAL here, and the block at :1607 closed the
  #    other half of the same cause
  #    that block says the value is "the untrusted side in full" and names one
  #    hazard: *the local shell would RUN it*. correct, and closed by
  #    `__duct_ssh_tmux`. the twin it does not name is that the local TERMINAL
  #    would OBEY it — and a terminal obeys an OSC 52 with no shell involved.
  #
  #    ⇒ round 12's shape, one file over from where it was measured: a guard
  #      that names ONE hazard reads as a guard against THE hazard.
  #
  # ⚠️ BOTH halves are needed here, and each answers a different branch:
  #    · the sink — the LOCAL branch at :1626 reads a plain `tmux`, so its
  #      value passes through no capture-time strip at all. a pulled tree can
  #      author a directory NAME (the boundary drops five members, none by
  #      shape), a human `cd`s into it in a pane, and reboot prints it.
  #    · `printf` — the REMOTE branch's value IS byte-sunk by
  #      `__duct_ssh_tmux`, and zsh's `echo` would re-author an ESC out of the
  #      printable `\033` the sink correctly passed (see `:787`).
  [[ -n "$pane_cwd" ]] && \
    printf '   └─ fresh shell, cwd kept: %s\n' "$(printf '%s' "$pane_cwd" | __duct_strip_escapes)"
  return 0
}

######################################################################
# duct.refresh — force every attached client to repaint
#
# .what = tell each terminal attached to a duct to redraw its whole screen.
#         kills no program, keeps every byte of state.
#
# .why  = a duct can be perfectly healthy while the WINDOW that shows it paints a
#         stale frame — the usual cause is a TUI that exited mid-redraw and left
#         the client's model of the screen wrong. the session is fine; the
#         picture is not.
#
#         so this is the non-destructive twin of `duct.reboot`, and the pair
#         answers two different questions:
#
#         | symptom | verb | what dies |
#         |---------|------|-----------|
#         | the picture is wrong, the duct answers | `duct.refresh` | none |
#         | the duct will not answer, a program holds it | `duct.reboot` | that program |
#
#         reach for `refresh` FIRST: it is free and it cannot lose work. only
#         when the duct genuinely will not answer is `reboot` the right verb.
#
#         adopted from nheuron's `duct.refresh`, with the remote branch added.
#
# .why "no clients attached" is a SUCCESS, not an error: a headless duct on a
#         grove has no client by design (`--mode headless`). there is no picture
#         to fix, so the goal is already met — an error here would make the verb
#         unusable on exactly the machines this repo drives most.
#
# usage:
#   duct.refresh --on duct:///main/mechanic
######################################################################
duct.refresh() {
  local uri=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --on) uri="$2"; shift 2 ;;
      *) echo "✋ duct.refresh: unknown arg '$1'" >&2; return 2 ;;
    esac
  done
  if [[ -z "$uri" ]]; then
    echo "✋ duct.refresh: --on required" >&2
    echo "   └─ e.g. duct.refresh --on duct:///main/mechanic" >&2
    return 2
  fi

  __duct_parse_uri "$uri" || return 2

  # ⚠️ `tty` is the READ LOOP's variable and belongs here — this file is sourced
  #    into a human's interactive shell, so a name left undeclared persists in
  #    that shell after the function returns (`:1493-1500` legislates the class)
  local ttys="" count=0 tty=""

  if __duct_is_remote; then
    __duct_probe_remote_session
    local probe=$?
    if [[ $probe -eq 255 ]]; then
      __duct_say_unreachable refresh
      return 2
    fi
    if [[ $probe -ne 0 ]]; then
      echo "✋ duct.refresh: '$uri' is absent — there is no client to repaint" >&2
      echo "   └─ fix: duct.open --on $uri" >&2
      return 2
    fi
    ttys=$(__duct_ssh_tmux list-clients -t "$DUCT_SESSION" -F '#{client_tty}' 2>/dev/null)
  else
    if ! tmux has-session -t "$DUCT_SESSION" 2>/dev/null; then
      echo "✋ duct.refresh: '$uri' is absent — there is no client to repaint" >&2
      echo "   └─ fix: duct.open --on $uri" >&2
      return 2
    fi
    ttys=$(tmux list-clients -t "$DUCT_SESSION" -F '#{client_tty}' 2>/dev/null)
  fi

  if [[ -z "$ttys" ]]; then
    echo "🔧 $uri — no client attached, so no repaint is owed (headless is normal)"
    return 0
  fi

  # .why a `while read` over a heredoc string, not `mapfile`: `mapfile` is a
  #      bash builtin that zsh does not carry, and this file is sourced by BOTH
  #      shells (rule.forbid.bare-globs-in-dual-shell-files names the same class
  #      of dialect split). a read loop is the portable form
  while IFS= read -r tty; do
    [[ -n "$tty" ]] || continue
    if __duct_is_remote; then
      # ⚠️ `$tty` is READ OFF THE REMOTE BOX — it is `#{client_tty}` from the
      #    list-clients above, so it is the far side's word, not ours. same
      #    trust inversion as `$pane_cwd`; the helper is what makes it data
      __duct_ssh_tmux refresh-client -t "$tty" 2>/dev/null
    else
      tmux refresh-client -t "$tty" 2>/dev/null
    fi
    # 🛑 .the FOURTH site of the cause `:1110` names — `$said`, `$held`,
    #    `$pane_cwd`, and this one. every one prints with `printf`, never `echo`.
    #
    # ⚠️ .a CAPTURE repair is not a PRINT repair, and it reads like one
    #    `$ttys` is byte-sunk on capture — `__duct_ssh_tmux` sinks both streams —
    #    so a reader who asks "was this site handled?" finds a repair and stops.
    #    the sink is one half of a PAIR; the print verb is the other, and it must
    #    be asked separately of every remote-chosen value.
    #
    #    ⇒ the sink makes the bytes inert; `echo` in zsh makes them live
    #      again. `:865-876` measures it: the four printable characters
    #      `\`,`0`,`3`,`3` pass the sink CORRECTLY and zsh's builtin `echo`
    #      re-authors a real ESC out of them. `src/grove.provision/2.shell/2.5.zsh/zshrc.sh:204` sources this
    #      file into an interactive zsh, so that is the shell this function
    #      runs in when a human types `duct.refresh`.
    #
    # .the concrete cost
    #    tmux takes a client's ttyname FROM THE CLIENT, so any process that
    #    can reach the duct's socket on an owned grove chooses this string. a
    #    ttyname that spells `\033]52;c;<b64>\007` as printable text becomes a
    #    real OSC 52 here, and `src/grove.provision/2.shell/2.8.tmux/tmux.conf` sets `set-clipboard on` — so
    #    the next paste is a command the grove chose and the human vouches for.
    #
    # ⚠️ BOTH halves, for the same reason `duct.reboot` gives at `:1773`:
    #    · `printf` — covers the REMOTE branch, whose value the sink already
    #      passed as printable text
    #    · the strip — covers the LOCAL branch, which reads a plain `tmux` and
    #      so passed through no capture-time sink at all
    printf '   ├─ repainted %s\n' "$(printf '%s' "$tty" | __duct_strip_escapes)"
    count=$(( count + 1 ))
  done <<EOF
$ttys
EOF

  echo "🔧 $uri refreshed ($count client(s))"
  return 0
}

duct.host.add() {
  local host="$1"
  if [[ -z "$host" ]]; then
    echo "✋ duct.host.add: host required" >&2
    return 2
  fi
  __duct_register_host "$host"
  echo "📡 host $host added"
}

duct.host.del() {
  local host="$1"
  if [[ -z "$host" ]]; then
    echo "✋ duct.host.del: host required" >&2
    return 2
  fi
  __duct_ensure_dirs

  # remove host
  __duct_unregister_host "$host"

  # remove ducts for this host
  # recurse so nested ducts (ducts/tree/role.json) are found too
  local f duct_host
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    duct_host=$(jq -r '.host // ""' "$f" 2>/dev/null)
    if [[ "$duct_host" == "$host" ]]; then
      rm -f "$f"
      rmdir --ignore-fail-on-non-empty "$(dirname "$f")" 2>/dev/null || true
    fi
  done < <(find "$DUCTWORK_DIR/ducts" -type f -name '*.json' 2>/dev/null)

  echo "📡 host $host removed"
}

duct.host.list() {
  __duct_ensure_dirs

  local found=0
  local f h lastSeen ts

  # always show localhost
  echo "📡 localhost (local)"
  found=1

  # .why `find`, not a glob: an unmatched `*.json` is literal text in bash but
  #      a HARD ERROR in zsh (`nomatch`), which aborts the function. a machine
  #      with no remote host registered is the COMMON case here, so the glob
  #      form fails exactly when the list is most needed
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    h=$(basename "$f" .json)
    lastSeen=$(jq -r '.lastSeen // 0' "$f" 2>/dev/null)
    ts=$(date -d "@$((lastSeen / 1000))" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
    echo "📡 $h (last seen: $ts)"
    found=1
  done < <(find "$DUCTWORK_DIR/hosts" -type f -name '*.json' 2>/dev/null)

  if [[ $found -eq 0 ]]; then
    echo "📡 (no hosts)"
  fi
}
