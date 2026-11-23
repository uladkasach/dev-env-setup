#!/usr/bin/env bash
######################################################################
# .what = write a pnpm patch that swaps each named file whole: delete, then create
#
# .why
#   - a package can ship a file read-only (0555). pnpm's applier patches a file
#     in place, so its write throws EACCES, and pnpm reports it as a bare
#     ERR_PNPM_PATCH_FAILED, with no word on permissions
#   - a delete needs only a writable dir, and a create lays a fresh 0755 file,
#     so a whole-file swap applies where a hunk cannot. it also breaks any
#     hardlink into the pnpm store, so the store's copy stays pristine
#   - `pnpm patch-commit` writes hunks only, and no paved path wrote a swap
#
# usage:
#   rhx pnpm.patch.whole.set --package <name@version> --edit <dir> \
#     --path <file in the package> [--path …] [--mode plan|apply]
#
#   --edit is the dir `pnpm patch` handed out, with the files already edited
#   --path is package-relative, e.g. dist/x/y.sh
#
# guarantee:
#   - reads the pristine file from node_modules/.pnpm/<name@version>_* (never a
#     _patch_hash= dir); refuses if zero or two pristine dirs match
#   - writes patches/<name@version>.patch, upserted whole; plan by default
#   - refuses a --path that is absent from either side, or identical on both
#   - never runs pnpm; the human's next step is `pnpm install`
######################################################################
set -uo pipefail

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "pnpm.patch.whole.set — write a pnpm patch that swaps each file whole"
  echo ""
  echo "usage:"
  echo "  rhx pnpm.patch.whole.set --package <name@version> --edit <dir> --path <file> [--path …] [--mode plan|apply]"
  echo ""
  echo "  --package   e.g. rhachet-roles-ehmpathy@1.43.0"
  echo "  --edit      the dir \`pnpm patch\` handed out, already edited"
  echo "  --path      a package-relative file to swap; repeat per file"
  echo "  --mode      plan (default) shows the sections; apply writes the patch"
  exit 0
fi

fail() {
  echo "✋ ConstraintError: $1" >&2
  echo "   └─ $2" >&2
  exit 2
}

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || fail "no git repo here" "run it from the repo whose package.json pins the package"

PKG="" EDIT="" MODE="plan"
PATHS=()
while [[ $# -gt 0 ]]; do
  [[ "$1" =~ ^--(package|edit|path|mode|skill|repo|role)$ && $# -lt 2 ]] && fail "$1 needs a value" "see: rhx pnpm.patch.whole.set --help"
  case "$1" in
    --package) PKG="$2"; shift 2 ;;
    --edit) EDIT="$2"; shift 2 ;;
    --path) PATHS+=("$2"); shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) fail "unknown argument '$1'" "see: rhx pnpm.patch.whole.set --help" ;;
  esac
done

[[ "$PKG" == ?*@?* ]] || fail "--package must read <name@version>, got '$PKG'" "e.g. --package rhachet-roles-ehmpathy@1.43.0"
[[ -d "$EDIT" ]] || fail "--edit '$EDIT' is not a dir" "run \`pnpm patch $PKG --edit-dir <dir>\` first"
[[ "${#PATHS[@]}" -gt 0 ]] || fail "name at least one --path" "see: rhx pnpm.patch.whole.set --help"
[[ "$MODE" == "plan" || "$MODE" == "apply" ]] || fail "--mode must be plan or apply, got '$MODE'" "drop --mode for a plan"

# find the one pristine dir; a _patch_hash= dir holds a prior patch, never the source
NAME="${PKG%@*}"
PRISTINE=()
for d in "$ROOT"/node_modules/.pnpm/"$PKG"_* "$ROOT"/node_modules/.pnpm/"$PKG"; do
  [[ -d "$d/node_modules/$NAME" && "$d" != *_patch_hash=* ]] && PRISTINE+=("$d/node_modules/$NAME")
done
[[ "${#PRISTINE[@]}" -eq 1 ]] || fail "found ${#PRISTINE[@]} pristine dirs for $PKG under node_modules/.pnpm" "run \`pnpm install\` so exactly one unpatched copy sits there"
SRC="${PRISTINE[0]}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# .what = one git diff section, with its paths cut to a/<rel> and b/<rel> and no index line
# .why  = pnpm reads a package-relative path; the index hashes name a repo it never sees
diff_section() {
  local from="$1" to="$2" rel="$3" out="$4" line
  git diff --no-index --output="$out.raw" -- "$from" "$to"
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      "diff --git "*) printf 'diff --git a/%s b/%s\n' "$rel" "$rel" ;;
      "index "*) ;;
      "--- a/"*) printf -- '--- a/%s\n' "$rel" ;;
      "+++ b/"*) printf '+++ b/%s\n' "$rel" ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <"$out.raw" >"$out"
}

i=0
for rel in "${PATHS[@]}"; do
  [[ -f "$SRC/$rel" ]] || fail "'$rel' is absent from the pristine package" "name a path relative to $SRC"
  [[ -f "$EDIT/$rel" ]] || fail "'$rel' is absent from the edit dir" "name a path relative to $EDIT"
  cmp -s "$SRC/$rel" "$EDIT/$rel" && fail "'$rel' is unchanged in the edit dir" "edit it, or drop its --path"
  diff_section "$SRC/$rel" /dev/null "$rel" "$WORK/$i.del"
  diff_section /dev/null "$EDIT/$rel" "$rel" "$WORK/$i.new"
  i=$((i + 1))
done

OUT="$ROOT/patches/$PKG.patch"
for ((j = 0; j < i; j++)); do cat "$WORK/$j.del" "$WORK/$j.new"; done >"$WORK/patch"

echo "🐢 righteous"
echo ""
echo "🐚 pnpm.patch.whole.set --package $PKG --mode $MODE"
echo "   ├─ pristine: ${SRC#"$ROOT"/}"
echo "   ├─ patch: patches/$PKG.patch ($(wc -l <"$WORK/patch") lines)"
echo "   ├─ swaps"
for ((j = 0; j < i; j++)); do
  glyph='├─'; [[ $j -eq $((i - 1)) ]] && glyph='└─'
  echo "   │  $glyph ${PATHS[$j]}"
done
if [[ "$MODE" == "plan" ]]; then
  echo "   └─ plan only; rerun with --mode apply to write it"
  exit 0
fi
mkdir -p "$ROOT/patches"
cp "$WORK/patch" "$OUT"
echo "   └─ written; next: pnpm install"
