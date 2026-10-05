#!/usr/bin/env bash
######################################################################
# brains.claude.strings — find text inside the installed claude cli
#
# .what = search the claude binary this box runs for a pattern, and print
#         each hit with a bounded window of the text around it
#
# .why  = claude ships as one native binary with its js embedded, and its
#         private surfaces — undocumented endpoints, response fields, flags —
#         are named nowhere else. `brains.auth` reads one of those surfaces
#         (`hazard.claude-usage-endpoint-is-undocumented`), so the ONLY way to
#         learn what a field means, or which endpoint carries a fact the usage
#         read lacks, is to read what the cli itself asks for
#         ⇒ a raw `grep -a` on a 200MB binary is the adhoc form this replaces
#           (`rule.forbid.adhoc-shell`)
#
# usage:
#   rhx brains.claude.strings --pattern 'rate_limit_reset'
#   rhx brains.claude.strings --pattern '/api/oauth/[a-z_/]+' --window 0
#   rhx brains.claude.strings --pattern 'reset' --limit 50
#
# options:
#   --pattern  an extended regex (grep -E) to find — required
#   --window   chars of context on each side of a hit (default 120)
#   --limit    max hits printed (default 40); a cap, so a broad pattern
#              cannot flood the caller
#
# guarantee:
#   - READ-ONLY: it reads the binary and writes naught
#   - exit 0 = hits printed
#   - exit 1 = malfunction (no claude binary found)
#   - exit 2 = constraint (bad args), or no hit at all
######################################################################
set -uo pipefail

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "brains.claude.strings"
  echo ""
  echo "usage:"
  echo "  rhx brains.claude.strings --pattern <ere> [--window N] [--limit N]"
  exit 0
fi

PATTERN=""
WINDOW=120
LIMIT=40
while [[ $# -gt 0 ]]; do
  case $1 in
    --pattern) PATTERN="$2"; shift 2 ;;
    --window) WINDOW="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "✋ ConstraintError: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$PATTERN" ]] || { echo "✋ ConstraintError: --pattern is required" >&2; exit 2; }
[[ "$WINDOW" =~ ^[0-9]+$ && "$LIMIT" =~ ^[0-9]+$ ]] \
  || { echo "✋ ConstraintError: --window and --limit take whole numbers" >&2; exit 2; }

####################################################################
# the binary the box's `claude` actually runs — the pnpm shim's package, whose
# `bin/claude.exe` holds the embedded js. the shim is the one PATH hands a human
####################################################################
shim="$(command -v claude 2>/dev/null)"
[[ -n "$shim" ]] || { echo "💥 MalfunctionError: no claude on PATH (5.3.brains installs it)" >&2; exit 1; }
pkg="$(dirname "$(readlink -f "$shim")")"
bin=""
for candidate in "$pkg/bin/claude.exe" "$pkg/../bin/claude.exe" "$pkg/claude.exe" "$pkg/cli.js"; do
  [[ -f "$candidate" ]] && { bin="$(readlink -f "$candidate")"; break; }
done
if [[ -z "$bin" ]]; then
  # the shim may live in a pnpm bin dir; find the package beside the global store
  bin="$(ls -1 "${PNPM_HOME:-$HOME/.local/share/pnpm}"/global/5/.pnpm/@anthropic-ai+claude-code@*/node_modules/@anthropic-ai/claude-code/bin/claude.exe 2>/dev/null | tail -1)"
fi
[[ -n "$bin" && -f "$bin" ]] || { echo "💥 MalfunctionError: no claude binary found from shim $shim" >&2; exit 1; }

echo "🔭 brains.claude.strings"
echo "   ├─ binary:  $bin"
echo "   ├─ pattern: $PATTERN"
echo "   └─ hits (window ±$WINDOW, cap $LIMIT)"

hits="$(LC_ALL=C grep -a -o -E ".{0,$WINDOW}(${PATTERN}).{0,$WINDOW}" "$bin" 2>/dev/null \
          | LC_ALL=C tr -c '[:print:]\n' '.' \
          | awk '!seen[$0]++' \
          | head -n "$LIMIT")"

if [[ -z "$hits" ]]; then
  echo "      (none)"
  exit 2
fi
printf '%s\n' "$hits" | sed 's/^/      │ /'
