#!/usr/bin/env bash
######################################################################
# .what = read rhachet's per-user STORAGE — the durable state a role
#         keeps OUTSIDE any checkout, under ~/.rhachet/storage/
#
# .why  = several skills write state there and no reader answers for
#         the store as a whole. `git.commit.uses get --global` and
#         `radio.uses get --global` each answer for their own slug, in
#         prose, one at a time — so "what does this box currently
#         allow?" has no single answer, and the honest way to see the
#         whole store was a raw `cat` of a path somebody remembered.
#
#         that raw `cat` is what `rule.forbid.adhoc-shell` forbids: an
#         absent skill is the defect to fix, never a licence to go
#         ad-hoc. this is the fix.
#
# 🛑 .why it is rooted at storage/ and MUST NOT widen
#         `~/.rhachet/keyrack/` is a SIBLING of `~/.rhachet/storage/`.
#         a reader rooted at `~/.rhachet` would put the RACK one glob
#         away from a tool whose whole job is to print file bodies.
#         rooting at `storage/` keeps the rack out of reach BY
#         CONSTRUCTION, rather than by a deny-pattern nobody re-reads.
#         ⇒ do not widen the root. write a sibling skill instead.
#
# 🛑 .why --at, and NOT --repo/--role
#         rhachet INJECTS `--repo`, `--role`, and `--skill` into every
#         skill it runs. a skill that claimed those names for its own
#         coordinates would read rhachet's injection as the caller's
#         address — `rhx rhachet.storage.get` would silently report on
#         `repo=.this/role=any` and answer a question nobody asked.
#         `git.repo.get` dodges the same collision by spelling its own
#         flag `--repos`.
#         ⇒ `--at` takes the on-disk segment VERBATIM, so no
#           translation is owed and no name collides.
#
# ⚠️ .why the BODY is behind a flag, and listing is the default
#         measured 2026-09-16: this store held 2403 files, most of
#         them long-form progress notes a role writes as it learns. a
#         body-by-default reader printed 1.3 MB for the question
#         "what does this box currently allow?" — an answer nobody can
#         read is not an answer.
#         ⇒ the default LISTS (path + bytes). `--body` prints. the
#           common case is a survey, so the survey is what is free
#           (`rule.prefer.defaults-match-common-case`).
#
# usage:
#   rhachet.storage.get                                    # list the whole store
#   rhachet.storage.get --at '*' --what '.meter/*' --body  # read every meter
#   rhachet.storage.get --at 'repo=ehmpathy/role=mechanic'
#   rhachet.storage.get --what '.meter/*' --body --json    # machine-readable
#
# options:
#   --at GLOB     which `repo=…/role=…` dir, spelled as it is on disk
#                 (default '*'; a `*` spans `/`)
#   --what GLOB   which path UNDER that dir (default '*')
#   --body        read + print each file's contents, not just its name
#   --json        emit one json object instead of the tree
#   --repo/--role/--skill  absorbed + ignored — rhachet injects these
#                          when invoked as `rhx rhachet.storage.get …`
#
# guarantee:
#   - READ ONLY. it never writes, moves, or removes a byte
#   - never reads outside ~/.rhachet/storage — the keyrack is a sibling
#     and is unreachable from here
#   - without `--body` it opens no file at all, so a survey of a large
#     store costs one stat per entry and never a read
#   - exits 0 with an empty report when the store holds no file, so an
#     absent store is an ANSWER rather than an error
######################################################################

set -euo pipefail

AT='*'
WHAT='*'
AS_JSON=0
AS_BODY=0
MAX_LINES=200
MAX_BYTES=65536

while [[ $# -gt 0 ]]; do
  case "$1" in
    --at)   AT="${2:-}";   shift 2 ;;
    --what) WHAT="${2:-}"; shift 2 ;;
    --body) AS_BODY=1;     shift ;;
    --json) AS_JSON=1;     shift ;;
    --repo|--role|--skill)
      # absorb the pairs rhachet injects; guard the value shift so a
      # trailing `--repo` cannot eat the next flag
      shift
      if [[ $# -gt 0 && "$1" != --* ]]; then shift; fi
      ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ⚠️ the traversal refusal below is belt-and-braces, and says so rather than
#    claim a protection it is not the source of. every path this skill reads
#    comes out of a `find` rooted INSIDE the store, so `..` can never appear
#    in one — the scope is structural. the refusal exists so a future edit
#    that swaps `find` for a caller-supplied path does not silently inherit a
#    hole (`rule.require.exemptions-name-their-trigger`, applied to a guard).
for _p in "$AT" "$WHAT"; do
  case "$_p" in
    '')    echo "✋ a pattern may not be empty (use '*' for all)" >&2; exit 2 ;;
    *..*)  echo "✋ '..' is refused in a pattern: $_p" >&2; exit 2 ;;
    /*)    echo "✋ a pattern is relative to the store; drop the leading '/': $_p" >&2; exit 2 ;;
  esac
done

# ⚠️ NO env override for the root, deliberately. an override would void the
#    keyrack-is-a-sibling guarantee above with no signal. a test redirects
#    `$HOME` instead, which moves the whole tree together and keeps the
#    guarantee true of wherever it lands.
ROOT="$HOME/.rhachet/storage"
ROOT_SAY="${ROOT/#$HOME/\~}"

# ── walk the store, keep what both globs accept
paths=()
sizes=()
bodies=()

if [[ -d "$ROOT" ]]; then
  while IFS= read -r -d '' f; do
    rel="${f#"$ROOT"/}"

    # split `repo=X/role=Y/rest…` into its address and its remainder.
    # a file that does NOT wear that shape is addressable only by `--at '*'`,
    # which is honest: this skill did not invent the layout and must not
    # pretend a stray file has coordinates it does not have.
    at_part=""
    what_part="$rel"
    if [[ "$rel" == repo=*/role=*/* ]]; then
      _s1="${rel%%/*}"        # repo=X
      _rest="${rel#*/}"       # role=Y/…
      _s2="${_rest%%/*}"      # role=Y
      at_part="${_s1}/${_s2}"
      what_part="${_rest#*/}"
    fi

    # unquoted RHS — these are GLOB matches, not string compares
    [[ "$at_part"   == $AT   ]] || continue
    [[ "$what_part" == $WHAT ]] || continue

    paths+=("$rel")
    sizes+=("$(stat -c %s "$f" 2>/dev/null || echo 0)")

    # ⚠️ the read is CONDITIONAL, not merely the print. a survey of a 2403-file
    #    store must not open 2403 files to then discard every body.
    if [[ "$AS_BODY" -eq 1 ]]; then
      bodies+=("$(head -c "$MAX_BYTES" "$f" 2>/dev/null || true)")
    else
      bodies+=("")
    fi
  done < <(find "$ROOT" -type f -print0 2>/dev/null | sort -z)
fi

count="${#paths[@]}"

# ── json surface
#
# ⚠️ `body` is present on every row and is "" without `--body`. an ABSENT key
#    would make a consumer's `.body` read `null`, which is indistinguishable
#    from a file that is genuinely empty — so the key is always there and the
#    `body_read` flag beside it says whether "" is a measurement or a skip.
if [[ "$AS_JSON" -eq 1 ]]; then
  lines=""
  for i in "${!paths[@]}"; do
    lines+="$(jq -cn \
      --arg p "${paths[$i]}" \
      --arg b "${bodies[$i]}" \
      --argjson s "${sizes[$i]}" \
      --argjson r "$AS_BODY" \
      '{path:$p, bytes:$s, body_read:($r==1), body:$b}')"$'\n'
  done
  printf '%s' "$lines" | jq -s --arg root "$ROOT" \
    '{root:$root, count:length, files:.}'
  exit 0
fi

# ── tree surface
_flags="--at '$AT' --what '$WHAT'"
[[ "$AS_BODY" -eq 1 ]] && _flags="$_flags --body"

echo "🐢 lets see whats stored..."
echo ""
echo "🐚 rhachet.storage.get $_flags"
echo "   ├─ root: $ROOT_SAY"
echo "   ├─ found: $count file(s)"
echo "   │"
echo "   └─ state"
echo "      ├─"
echo "      │"

if [[ "$count" -eq 0 ]]; then
  if [[ -d "$ROOT" ]]; then
    echo "      │  no file matched — the store holds none at this address"
  else
    echo "      │  the store is absent — no role has written state here yet"
  fi
  echo "      │"
  echo "      └─"
  exit 0
fi

for i in "${!paths[@]}"; do
  if [[ "$AS_BODY" -eq 1 ]]; then
    echo "      │  ${paths[$i]}"
    n=0
    while IFS= read -r l; do
      n=$((n + 1))
      if [[ "$n" -gt "$MAX_LINES" ]]; then
        echo "      │    … truncated at ${MAX_LINES} lines"
        break
      fi
      echo "      │    $l"
    done <<< "${bodies[$i]}"
    echo "      │"
  else
    printf '      │  %8s  %s\n' "${sizes[$i]}" "${paths[$i]}"
  fi
done

if [[ "$AS_BODY" -ne 1 ]]; then
  echo "      │"
fi
echo "      └─"

if [[ "$AS_BODY" -ne 1 && "$count" -gt 0 ]]; then
  echo ""
  echo "🥥 add --body to read them; narrow first with --at / --what"
fi
