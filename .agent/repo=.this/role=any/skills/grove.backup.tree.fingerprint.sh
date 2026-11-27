#!/usr/bin/env bash
######################################################################
# .what = print one tree's fingerprint: what a backup unit must carry
#
# .why
#   - a restore laid aside is proven whole only when it equals the live
#     tree on what a unit carries: HEAD, every branch, the stash, and
#     each uncommitted file by content
#   - run it on the live tree and on the restored copy; equal digests =
#     the tree came back whole. the digest covers HEAD, the checked-out
#     branch, and each uncommitted file; branches and stash print too, but
#     a clone shares them across its worktrees, so they stay out of it
#
# usage:
#   rhx grove.backup.tree.fingerprint --path <tree dir>
#
# guarantee:
#   - read-only: runs only git reads and sha256sum, no hook, no write
#   - a path that holds no git tree refuses, exit 2
######################################################################
set -uo pipefail

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "grove.backup.tree.fingerprint — print one tree's fingerprint, to compare a restore with its source"
  echo ""
  echo "usage:"
  echo "  rhx grove.backup.tree.fingerprint --path <tree dir>"
  echo ""
  echo "run it on the live tree and on the copy laid aside; equal digests = the tree came back whole"
  exit 0
fi

DIR=""
while [[ $# -gt 0 ]]; do
  [[ "$1" =~ ^--(path|skill|repo|role)$ && $# -lt 2 ]] && {
    echo "✋ ConstraintError: $1 needs a value" >&2
    echo "   └─ see: rhx grove.backup.tree.fingerprint --help" >&2; exit 2; }
  case "$1" in
    --path) DIR="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "✋ ConstraintError: unknown argument '$1'" >&2
       echo "   └─ see: rhx grove.backup.tree.fingerprint --help" >&2; exit 2 ;;
  esac
done

[[ -n "$DIR" ]] || { echo "✋ ConstraintError: name the tree with --path" >&2; echo "   └─ see: rhx grove.backup.tree.fingerprint --help" >&2; exit 2; }
DIR="${DIR/#\~/$HOME}"

# git, read-only: no hook, any owner
g() { git -c safe.directory='*' -c core.hooksPath=/dev/null -C "$DIR" "$@"; }

g rev-parse --git-dir >/dev/null 2>&1 || {
  echo "✋ ConstraintError: '$DIR' holds no git tree" >&2
  echo "   └─ name the dir of a clone or a worktree" >&2; exit 2; }

head="$(g rev-parse HEAD 2>/dev/null || echo '(none)')"
branches="$(g for-each-ref --format='%(refname) %(objectname)' refs/heads | sort)"
stash="$(g stash list --format='%gs %H' 2>/dev/null)"

# each uncommitted path, with the sha256 of its bytes (absent for a delete)
dirty="$(g status --porcelain=v1 -z --untracked-files=all | tr '\0' '\n' | while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  path="${line:3}"
  # a link is its target string, never the bytes it reaches: a link to a box-local file
  # (`~/.claude/settings.json`) reads differently on every box, yet came back exact
  sum="(absent)"
  [[ -f "$DIR/$path" ]] && sum="$(sha256sum <"$DIR/$path" | cut -c1-16)"
  [[ -L "$DIR/$path" ]] && sum="link→$(readlink "$DIR/$path")"
  printf '%s %s %s\n' "${line:0:2}" "$sum" "$path"
done | sort -k3)"

# the digest covers what THIS tree owns: its HEAD, its checked-out branch, its uncommitted work.
# branches and stash are shared by every worktree of one clone, and a restore box's clone may hold
# other branches of its own, so they print for a human to read, never fold into the digest
checkout="$(g symbolic-ref -q HEAD 2>/dev/null || echo '(detached)')"
digest="$(printf '%s\n--\n%s\n--\n%s\n' "$head" "$checkout" "$dirty" | sha256sum | cut -c1-16)"

count() { [[ -z "$1" ]] && echo 0 || printf '%s\n' "$1" | wc -l; }

# .what = print a label's rows as child branches, under the trunk $1 the label sits on
children() {
  local trunk="$1" rows="$2" n i=0 line
  n="$(count "$rows")"
  [[ "$n" -eq 0 ]] && return 0
  while IFS= read -r line; do
    i=$((i + 1))
    [[ "$i" -eq "$n" ]] && printf '%s└─ %s\n' "$trunk" "$line" || printf '%s├─ %s\n' "$trunk" "$line"
  done <<<"$rows"
}

echo "🐢 lets read the tree..."
echo ""
echo "🗄️ grove.backup.tree.fingerprint --path $DIR"
echo "   ├─ digest: $digest"
echo "   ├─ head: $head"
echo "   ├─ checkout: $checkout"
echo "   ├─ branches: $(count "$branches")"
children "   │  " "$branches"
echo "   ├─ stash: $(count "$stash")"
children "   │  " "$stash"
echo "   └─ uncommitted: $(count "$dirty")"
children "      " "$dirty"
