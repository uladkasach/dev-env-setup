#!/usr/bin/env bash
######################################################################
# .what = give a file inside this repo its exec bit, so rhx can run it
#
# .why
#   - rhx runs a skill by its path, so a skill with no exec bit dies
#     `Permission denied` before its first line
#   - the Write tool lays a new file at 0644, and no paved path set the bit,
#     so every new skill needed a raw `chmod` (`rule.forbid.adhoc-shell`)
#
# usage:
#   rhx file.exec.set --path .agent/repo=.this/role=any/skills/<name>.sh [--path …]
#
# guarantee:
#   - acts only on a regular file inside this repo; refuses aught else, exit 2
#   - idempotent: a file that already holds the bit is reported, not rewritten
#   - sets u+x, g+x, o+x and no other mode bit
######################################################################
set -uo pipefail

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "file.exec.set — give a file inside this repo its exec bit"
  echo ""
  echo "usage:"
  echo "  rhx file.exec.set --path <file> [--path <file> …]"
  echo ""
  echo "it refuses a path outside this repo, a dir, or a symlink"
  exit 0
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "✋ ConstraintError: no git repo here" >&2
  echo "   └─ run it from inside the repo whose file it is" >&2
  exit 2
}

PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path) PATHS+=("${2:-}"); shift 2 ;;
    # rhachet injects these three into every skill it runs
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "✋ ConstraintError: unknown argument '$1'" >&2
       echo "   └─ see: rhx file.exec.set --help" >&2; exit 2 ;;
  esac
done

[[ "${#PATHS[@]}" -gt 0 ]] || { echo "✋ ConstraintError: name at least one --path" >&2; exit 2; }

# refuse the whole set before any write, so a bad path leaves no partial change
for p in "${PATHS[@]}"; do
  abs="$(realpath -m "$p")"
  [[ "$abs" == "$ROOT"/* ]] || { echo "✋ ConstraintError: $p is outside this repo ($ROOT)" >&2; exit 2; }
  [[ -L "$p" ]] && { echo "✋ ConstraintError: $p is a symlink; name the file it points at" >&2; exit 2; }
  [[ -f "$p" ]] || { echo "✋ ConstraintError: $p is no regular file" >&2; exit 2; }
done

echo "🐢 lets make it runnable..."
echo ""
echo "🐚 file.exec.set"
for i in "${!PATHS[@]}"; do
  p="${PATHS[$i]}"
  glyph="├─"; [[ "$i" -eq $(( ${#PATHS[@]} - 1 )) ]] && glyph="└─"
  if [[ -x "$p" ]]; then
    echo "   $glyph = ${p#"$ROOT"/} (already runnable)"
    continue
  fi
  chmod a+x "$p" || { echo "💥 MalfunctionError: chmod refused $p" >&2; exit 1; }
  echo "   $glyph + ${p#"$ROOT"/}"
done
