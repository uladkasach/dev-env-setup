#!/usr/bin/env bash
######################################################################
# .what = what a branch carries, grouped by dir: files, adds, dels per dir
#
# .why  = a pr that reads "190 files" for a small fix owes an answer to
#         "what rides in it?" — by dir, with counts, against the same base
#         the pr diff uses (the merge base), so stale-base drift and the
#         branch's own work are never confused
#
# usage:
#   git.branch.diff.dirs.sh --base <sha|ref>              # depth 2 (default)
#   git.branch.diff.dirs.sh --base <sha|ref> --depth 3
#   git.branch.diff.dirs.sh --base <sha|ref> --head <ref>
#
# guarantee:
#   - read-only: git diff --numstat only, no fetch, no write
#   - totals line equals `git diff --shortstat <base> <head>`
#   - a binary file counts as a file with 0 adds, 0 dels
#   - exit 0 = answered, 1 = git failed, 2 = bad input
######################################################################
set -euo pipefail

base="" head="HEAD" depth=2
while (( $# )); do
  case "$1" in
    --base) base="${2:-}"; shift 2 ;;
    --head) head="${2:-}"; shift 2 ;;
    --depth) depth="${2:-}"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;   # rhachet injects these ahead of the caller's args
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    *) echo "✋ ConstraintError: unknown option $1" >&2; echo "   fix: git.branch.diff.dirs.sh --help" >&2; exit 2 ;;
  esac
done

# reject absent or malformed input
[[ -n "$base" ]] || { echo "✋ ConstraintError: --base is required (the pr's merge base)" >&2; echo "   fix: gh pr view <n> --json baseRefOid --jq .baseRefOid" >&2; exit 2; }
[[ "$depth" =~ ^[1-9][0-9]*$ ]] || { echo "✋ ConstraintError: --depth must be a positive integer, got '$depth'" >&2; exit 2; }

# read the numstat; a git failure is a malfunction, never an empty answer
if ! numstat="$(git diff --numstat "$base" "$head")"; then
  echo "💥 MalfunctionError: git diff --numstat $base $head failed" >&2
  exit 1
fi

echo "🐢 heres what rides"
echo ""
echo "🐚 git.branch.diff.dirs --base $base --head $head --depth $depth"
printf '%s\n' "$numstat" | awk -F'\t' -v depth="$depth" '
  NF < 3 { next }
  {
    a = ($1 == "-") ? 0 : $1; d = ($2 == "-") ? 0 : $2
    n = split($3, seg, "/"); k = seg[1]
    for (i = 2; i <= depth && i < n; i++) k = k "/" seg[i]
    if (n > 1 && depth >= n) k = k "/"
    files[k]++; adds[k] += a; dels[k] += d
    tf++; ta += a; td += d
  }
  END {
    cnt = 0
    for (k in files) keys[++cnt] = k
    # sort by files desc, then name
    for (i = 1; i <= cnt; i++) for (j = i + 1; j <= cnt; j++)
      if (files[keys[j]] > files[keys[i]] || (files[keys[j]] == files[keys[i]] && keys[j] < keys[i])) { t = keys[i]; keys[i] = keys[j]; keys[j] = t }
    printf "   ├─ total: %d files, +%d -%d\n", tf, ta, td
    printf "   └─ by dir\n"
    for (i = 1; i <= cnt; i++) {
      g = (i == cnt) ? "└─" : "├─"
      printf "      %s %4d files  +%-6d -%-5d %s\n", g, files[keys[i]], adds[keys[i]], dels[keys[i]], keys[i]
    }
  }'