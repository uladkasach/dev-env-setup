#!/usr/bin/env bash
######################################################################
# .what = the shared preamble every brains.auth skill proxy needs:
#         locate this worktree's brains.auth.sh, source it, and strip
#         the `--skill <value>` token the rhx wrapper injects.
#
# .why  = three proxies each carried a byte-identical copy of this block —
#         the same value-guard, and the same six-line comment that explains
#         it. that crosses the rule of three, and the duplicated part is not
#         decoration: it is a HANG GUARD. a fourth proxy copied carelessly,
#         or a "tidy-up" that trimmed the guard from one copy, restores an
#         infinite silent spin in exactly the command whose copy was touched.
#         one definition cannot drift from itself.
#
# .note = this file is SOURCED, never executed. it leaves EXACTLY two names
#         behind for the caller, and no others:
#           $BRAINS_AUTH_SRC — the sourced brains.auth.sh path
#           ${ARGS[@]}       — the caller's args, minus the --skill token
#         the transient walk variables are unset before the source line, so a
#         proxy or the harness inherits no incidental globals from here.
#
# usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/brains.auth.bootstrap.sh"
#   _brains_auth_usage "${ARGS[@]}"
######################################################################

# .note = ${BASH_SOURCE[0]} is THIS file, so the path holds no matter which
#   proxy sourced it, and no matter the caller's cwd.
#
# ⚠️ the root is found by LANDMARK, never by a hop count. it used to be
#   `$dir/../../../..` — four `..` steps chosen because this file sits at
#   `.agent/repo=.this/role=any/skills/`, which is four levels down. that count
#   was correct (`role=any` is ONE directory, not two — a reviewer read it as
#   two and filed a blocker, which is the tell), but "correct" is the wrong
#   property to lean on: it holds only for THIS layout, it re-derives from a
#   directory convention nobody promised to keep, and a rename or one more
#   level breaks every entry point at once with a message that names a path
#   rather than a cause.
#   so we walk up and stop at the directory that actually holds what we want.
#   the search states the intent, cannot be off by one, and survives any
#   reshuffle of the levels between here and the root.
#
# ⚠️ the landmark is the FILE's collocated bundle path — `brains.auth.sh` is
#   owned by the `2.7.aliases` bundle, which is where its own configure phase
#   copies it from. a rename of that bundle dir must update this landmark too.
_BRAINS_AUTH_BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_BRAINS_AUTH_REL='src/grove.provision/2.shell/2.7.aliases/brains.auth.sh'
BRAINS_AUTH_SRC=''
_BRAINS_AUTH_WALK="$_BRAINS_AUTH_BOOTSTRAP_DIR"
while [[ "$_BRAINS_AUTH_WALK" != / ]]; do
  if [[ -f "$_BRAINS_AUTH_WALK/$_BRAINS_AUTH_REL" ]]; then
    BRAINS_AUTH_SRC="$_BRAINS_AUTH_WALK/$_BRAINS_AUTH_REL"
    break
  fi
  _BRAINS_AUTH_WALK="$(dirname "$_BRAINS_AUTH_WALK")"
done

[[ -n "$BRAINS_AUTH_SRC" ]] || {
  echo "💥 no $_BRAINS_AUTH_REL in any parent of ${_BRAINS_AUTH_BOOTSTRAP_DIR}" >&2
  echo "   this file must live inside a checkout that carries $_BRAINS_AUTH_REL" >&2
  exit 1
}

# ⚠️ this file is SOURCED, so an unqualified assignment lands in the CALLER's namespace and
#   stays there. the two walk variables above are transient path-resolution state, not output
#   — `local` is unavailable at a file's top level, so the cleanup has to be explicit. left
#   behind they are incidental globals a reader of a "source" preamble would not expect, free
#   to collide with a later definition in the same shell. only the two documented outputs
#   survive this line: $BRAINS_AUTH_SRC and ${ARGS[@]}.
#   the unset comes AFTER the landmark check on purpose — that failure message names
#   $_BRAINS_AUTH_BOOTSTRAP_DIR, so an earlier cleanup would print a blank path in the one
#   case the path is the whole answer.
unset _BRAINS_AUTH_BOOTSTRAP_DIR _BRAINS_AUTH_WALK

# drop the --skill token the rhx wrapper prepends; forward the rest verbatim
# ⚠️ the value guard carries real weight here; it is not defensive decoration. `shift 2`
#   with only ONE argument left is a NO-OP in bash — the positional params stay untouched
#   and the non-zero return goes unread — so `$1` would still be `--skill` on the next pass
#   and this loop would spin forever, silently, until someone hits ctrl+c. a lone `--skill`
#   at the end of the args is the whole of what it takes. so we fail fast on it instead.
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)
      [[ $# -ge 2 ]] || { echo "✋ --skill needs a value" >&2; exit 2; }
      shift 2
      ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

# shellcheck disable=SC1090
source "$BRAINS_AUTH_SRC"
