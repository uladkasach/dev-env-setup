#!/usr/bin/env bash
######################################################################
# brains.claude.changelog.get — the full claude-code changelog across a pin bump
#
# .what = fetch the release notes of every claude-code release in (from, into],
#         oldest first, into one markdown file, and print where it landed
#
# .why  = the repo's CHANGELOG.md keeps only the newest few releases, so a bump
#         across dozens of versions reads as "silent" where it is not. the
#         GitHub releases carry every version's notes. a pin bump is a decision
#         (5.3.brains/_.sh), and it deserves the whole record, never a sample
#
# usage:
#   rhx brains.claude.changelog.get --from 2.1.280 --into 2.1.330
#   rhx brains.claude.changelog.get --from 2.1.280 --into 2.1.330 --out .temp/claude.changelog.md
#
# options:
#   --from  the version you run today (excluded)
#   --into  the version you bump to (included)
#   --out   where to write (default .temp/claude.changelog.<from>-<into>.md; .temp is gitignored)
#
# guarantee:
#   - READ-ONLY on the box: one file written at --out, no other
#   - fails loud if any release in range has no notes, or gh cannot reach github
#   - exit 0 = written · 1 = malfunction (gh) · 2 = constraint (bad args, empty range)
######################################################################
set -uo pipefail

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "brains.claude.changelog.get"
  echo ""
  echo "usage:"
  echo "  rhx brains.claude.changelog.get --from <semver> --into <semver> [--out <path>]"
  exit 0
fi

FROM=""
INTO=""
OUT=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --from) FROM="$2"; shift 2 ;;
    --into) INTO="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "✋ ConstraintError: unknown argument: $1" >&2; exit 2 ;;
  esac
done

semver='^[0-9]+\.[0-9]+\.[0-9]+$'
[[ "$FROM" =~ $semver && "$INTO" =~ $semver ]] \
  || { echo "✋ ConstraintError: --from and --into take a semver, e.g. --from 2.1.280 --into 2.1.330" >&2; exit 2; }
OUT="${OUT:-.temp/claude.changelog.$FROM-$INTO.md}"

# every release tag, then keep those in (from, into], oldest first
tags="$(gh release list --repo anthropics/claude-code --limit 1000 --json tagName --jq '.[].tagName' 2>&1)" \
  || { echo "💥 MalfunctionError: gh could not list anthropics/claude-code releases" >&2; echo "   └─ $tags" >&2; exit 1; }
inrange="$(sed 's/^v//' <<< "$tags" | grep -E "$semver" | sort -V \
  | awk -v f="$FROM" -v t="$INTO" '
      function cmp(a, b,   x, y, i) { split(a, x, "."); split(b, y, ".");
        for (i = 1; i <= 3; i++) { if (x[i] + 0 < y[i] + 0) return -1; if (x[i] + 0 > y[i] + 0) return 1 } return 0 }
      cmp($0, f) > 0 && cmp($0, t) <= 0')"
[[ -n "$inrange" ]] || { echo "✋ ConstraintError: no release in ($FROM, $INTO]" >&2; exit 2; }

mkdir -p "$(dirname "$OUT")"
{
  echo "# claude-code changelog: $FROM → $INTO"
  echo ""
  echo "source: github.com/anthropics/claude-code/releases, oldest first"
  echo ""
} > "$OUT"

count=0
while IFS= read -r v; do
  body="$(gh release view "v$v" --repo anthropics/claude-code --json body --jq '.body' 2>&1)" \
    || { echo "💥 MalfunctionError: gh could not read release v$v" >&2; echo "   └─ $body" >&2; exit 1; }
  [[ -n "$body" ]] || { echo "💥 MalfunctionError: release v$v has no notes" >&2; exit 1; }
  { echo "## $v"; echo ""; echo "$body"; echo ""; } >> "$OUT"
  count=$((count + 1))
done <<< "$inrange"

echo "🔭 brains.claude.changelog.get"
echo "   ├─ range:    ($FROM, $INTO]"
echo "   ├─ releases: $count"
echo "   ├─ lines:    $(wc -l < "$OUT")"
echo "   └─ written:  $OUT"
