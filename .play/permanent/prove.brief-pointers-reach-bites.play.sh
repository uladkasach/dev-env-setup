#!/usr/bin/env bash
######################################################################
# .what = prove `prove.brief-pointers-reach` still reddens on a planted dead
#         `src/` pointer, and still skips a `src/` glued to a word or a `$`
#
# .why  = the pointer play skips any `src/` token that opens with a word or a
#         `$` (`$src/x.sh`, `bundle_src/x.sh`), since such a token names a local
#         dir, never a root path. a skip in the one check whose job is to fail is
#         a loosened assertion until a fixture shows both halves:
#           - a bare `src/<moved>.sh` still draws a ✋, with its fix named
#           - a glued token draws none
#
# guarantee:
#   - HERMETIC: a temp git repo with its own `.agent/` and `src/`; the play is
#     copied into it, so its own-location root resolves to the fixture
#   - each run is bounded (`timeout -k 2 60`)
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

repo="$(mktemp -d)"
trap 'rm -rf "$repo"' EXIT

mkdir -p "$repo/.play/permanent" "$repo/.agent/repo=.this/role=any" "$repo/src/a"
cp "$HERE/.play/permanent/prove.brief-pointers-reach.play.sh" "$repo/.play/permanent/"
printf 'a role\n' >"$repo/.agent/repo=.this/role=any/readme.md"
printf '#!/usr/bin/env bash\n' >"$repo/src/a/moved.sh"
git -C "$repo" init -q

failed=0
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }
claim() { local label="$1"; shift; if "$@"; then echo "   • $label ✔"; else fail "$label"; fi; }

# one run of the pointer play inside the fixture — $1 = the notes body
OUT="" RC=0
run_with() {
  printf '%s\n' "$1" >"$repo/notes.md"
  git -C "$repo" add .agent src notes.md
  OUT="$(cd "$repo" && timeout -k 2 60 bash .play/permanent/prove.brief-pointers-reach.play.sh </dev/null 2>&1)" && RC=0 || RC=$?
}
has() { [[ "$OUT" == *"$1"* ]]; }
lacks() { [[ "$OUT" != *"$1"* ]]; }

echo "🌲 prove.brief-pointers-reach-bites"

# a bare root path at a moved file: the ✋, with the one live path as its fix
run_with 'see src/moved.sh for the body'
claim "a planted dead pointer · rc 1"           test "$RC" -eq 1
claim "a planted dead pointer · named"          has "src/moved.sh"
claim "a planted dead pointer · its fix named"  has "fix: src/a/moved.sh"

# glued tokens name a local dir: no ✋. one live pointer keeps the scan non-empty
# shellcheck disable=SC2016
run_with 'source "$src/moved.sh"; bundle_src/moved.sh; ${src}/moved.sh; live: src/a/moved.sh'
claim "glued tokens · rc 0"                     test "$RC" -eq 0
claim "glued tokens · no row is dead"           lacks "reach no file"
claim "glued tokens · the live pointer is read" has "1 path-shaped pointer(s) read"

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"
