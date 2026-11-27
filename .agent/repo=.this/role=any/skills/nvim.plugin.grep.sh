#!/usr/bin/env bash
######################################################################
# .what = search the source of an installed nvim plugin (lazy.nvim's dir)
#
# .why  = a defect in a plugin's behavior is diagnosed by its source, and
#         that source lives outside this repo — where grepsafe will not
#         reach. this reads ONE plugin's dir, read-only, and naught else
#
# usage:
#   rhx nvim.plugin.grep --plugin image.nvim --pattern 'hijack_buffer'
#   rhx nvim.plugin.grep --plugin codediff.nvim --pattern 'stored_diff_result' --context 3
#   rhx nvim.plugin.grep --list                       # the installed plugins
#
# guarantee:
#   - reads only $XDG_DATA_HOME/nvim/lazy/<plugin>; never writes
#   - --plugin must name one dir there (no slashes, no '..')
#   - exit 0 = matched or listed · 1 = no match · 2 = bad input
######################################################################
set -uo pipefail

plugin="" pattern="" context=0 list=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plugin) plugin="$2"; shift 2 ;;
    --pattern) pattern="$2"; shift 2 ;;
    --context) context="$2"; shift 2 ;;
    --list) list=1; shift ;;
    --skill|--repo|--role) shift 2 ;;
    --help|-h) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "✋ ConstraintError: nvim.plugin.grep: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

root="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"

echo "🐢 sweet"
echo ""
echo "🔭 nvim.plugin.grep"

if (( list )); then
  echo "   └─ plugins in $root"
  for d in "$root"/*/; do echo "      ├─ $(basename "$d")"; done
  exit 0
fi

if [[ -z "$plugin" || "$plugin" == */* || "$plugin" == *..* || ! -d "$root/$plugin" ]]; then
  echo "   └─ ✋ ConstraintError: --plugin must name one dir in $root" >&2
  echo "      fix: rhx nvim.plugin.grep --list" >&2
  exit 2
fi
if [[ -z "$pattern" ]]; then
  echo "   └─ ✋ ConstraintError: --pattern required" >&2
  exit 2
fi
if [[ ! "$context" =~ ^[0-9]+$ ]]; then
  echo "   └─ ✋ ConstraintError: --context must be a whole number" >&2
  exit 2
fi

echo "   ├─ plugin: $plugin"
echo "   ├─ pattern: $pattern"
echo "   └─ results"
# rg's output is captured, never a tty, so it prints file:line:text per row
out="$(cd "$root/$plugin" && rg -n -C "$context" -e "$pattern" . 2>&1)"
code=$?
if (( code == 1 )); then echo "      └─ (no match)"; exit 1; fi
if (( code != 0 )); then echo "      └─ 💥 MalfunctionError: rg failed: $out" >&2; exit 1; fi
printf '%s\n' "$out" | sed 's/^/      │ /'
