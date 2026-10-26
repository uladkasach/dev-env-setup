#!/usr/bin/env bash
######################################################################
# .what = rehearse `.github/workflows/test.plays.yml` on this box: run each play its
#         matrix names under a fresh, empty HOME, with a PATH that lacks what a stock
#         runner lacks
#
# .why  = the workflow is the gate a PR shows. a play that leans on this seat — a dotfile,
#         a pinned binary, a cache — passes here and fails there, and a push is the slow
#         way to learn which. this reads the SAME list the workflow runs, so the two
#         cannot drift
#
# .the bare seat
#   - HOME: a fresh temp dir, so no dotfile, cache, keyrack or registry of this seat leaks in
#   - PATH: a shadow of the stock bin dirs, minus zsh, tmux, nvim, sudo, node, npm, npx,
#     pnpm, corepack, rhx, rhachet, fnm, coredumpctl, kitty and earlyoom
#   - env: cleared, then HOME, PATH, TMPDIR, LANG=C.UTF-8 and USER=runner
#   - SIGPIPE ignored, as the runner hands it to every step: a writer whose reader exits
#     early then prints `write error: Broken pipe` rather than die quietly
#   ⚠️ an approximation, never the runner: the kernel, the process tree, and the git and
#     coreutils versions are this box's. a green rehearsal lowers the risk of a red run; only
#     the run itself proves the run
#
# usage:
#   rhx test.plays.rehearse
#   rhx test.plays.rehearse --play prove.org-scoped-rows   # one play from the matrix
#
# exit:
#   0 = every play named passed on the bare seat
#   1 = a play failed
#   2 = bad args, or the workflow names no play
######################################################################
set -uo pipefail

ONLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --play)
      [[ $# -ge 2 ]] || { echo "✋ ConstraintError: --play needs a slug" >&2; exit 2; }
      ONLY="$2"; shift 2 ;;
    --skill|--repo|--role) shift; [[ $# -gt 0 ]] && shift ;;
    -h|--help) sed -n '/^# usage:/,/^#####/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//;$d'; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg '$1'" >&2; echo "   usage: rhx test.plays.rehearse [--play <slug>]" >&2; exit 2 ;;
  esac
done

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SELF_DIR" rev-parse --show-toplevel)"
WF="$ROOT/.github/workflows/test.plays.yml"
RUNNER="$ROOT/.agent/repo=.this/role=any/skills/play.run.sh"

# the list is the workflow's own matrix — one declaration, read here
mapfile -t SLUGS < <(awk '/^ *- prove\./ { print $2 }' "$WF")
[[ ${#SLUGS[@]} -gt 0 ]] || { echo "✋ ConstraintError: $WF names no play" >&2; exit 2; }
if [[ -n "$ONLY" ]]; then
  [[ " ${SLUGS[*]} " == *" $ONLY "* ]] || { echo "✋ ConstraintError: '$ONLY' is not in the matrix of $WF" >&2; exit 2; }
  SLUGS=("$ONLY")
fi

FIX="$(mktemp -d "${TMPDIR:-/tmp}/test.plays.rehearse.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/bin" "$FIX/home" "$FIX/tmp"

# the shadow bin: every command on the stock dirs, first one wins, minus what a runner lacks
DROP=" zsh tmux nvim sudo node npm npx pnpm corepack rhx rhachet fnm coredumpctl kitty earlyoom "
for dir in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin; do
  [[ -d "$dir" ]] || continue
  for f in "$dir"/*; do
    n="${f##*/}"
    [[ "$DROP" == *" $n "* ]] && continue
    [[ -e "$FIX/bin/$n" ]] || ln -s "$f" "$FIX/bin/$n"
  done
done

echo "🐢 lets ride"
echo ""
echo "🐚 test.plays.rehearse"
echo "   ├─ matrix: ${#SLUGS[@]} play(s) from .github/workflows/test.plays.yml"
echo "   ├─ seat: fresh HOME; a PATH with no${DROP% }"
FAILED=()
trap '' PIPE
for slug in "${SLUGS[@]}"; do
  out="$(cd "$ROOT" && env -i HOME="$FIX/home" PATH="$FIX/bin" TMPDIR="$FIX/tmp" LANG=C.UTF-8 USER=runner \
    bash "$RUNNER" --play "$slug" 2>&1)"
  rc=$?
  if [[ "$rc" == 0 ]]; then echo "   ├─ ✔ $slug"; continue; fi
  echo "   ├─ ✋ $slug → rc=$rc"
  printf '%s\n' "$out" | tail -n 30 | sed 's/^/   │     /'
  FAILED+=("$slug")
done
if [[ ${#FAILED[@]} -eq 0 ]]; then
  echo "   └─ ✔ every matrix play passes on a bare seat"
  exit 0
fi
echo "   └─ 💥 MalfunctionError: ${#FAILED[@]} matrix play(s) fail on a bare seat: ${FAILED[*]}" >&2
exit 1
