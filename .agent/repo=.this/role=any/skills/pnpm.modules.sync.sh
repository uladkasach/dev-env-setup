#!/usr/bin/env bash
######################################################################
# .what = install node_modules from pnpm-lock.yaml, lock frozen, no lifecycle step
#
# .why  = a patch in pnpm.patchedDependencies lands only on install, and a
#         lockfile-only sync (pnpm.lockfile.sync) never installs. a plain
#         `pnpm install` is unpaved, and it runs the `prepare` lifecycle step
#         (rhachet init), which writes host settings files. this skill installs
#         from the lock as it stands, applies every patch, and runs no
#         lifecycle step
#
# usage:
#   pnpm.modules.sync.sh                  # plan: what would run
#   pnpm.modules.sync.sh --mode apply     # install from the frozen lock
#
# options:
#   --mode plan|apply   plan writes naught (default: plan)
#   -h, --help          show this header
#
# guarantee:
#   - runs pnpm install with --frozen-lockfile and the lifecycle-skip flag,
#     from the repo root: pnpm-lock.yaml is never rewritten, no lifecycle step
#   - refuses (exit 2) while package.json or pnpm-lock.yaml hold conflict markers
#   - apply fails loud (exit 1) where pnpm fails, a stale lock included
#   - bounded at 600s
#   - exit 0 = done, 1 = pnpm failed, 2 = bad input or bad state
######################################################################
set -euo pipefail

mode="plan"
while (( $# )); do
  case "$1" in
    --mode) mode="${2:-}"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;   # rhachet injects these ahead of the caller's args
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
    *) echo "✋ ConstraintError: unknown option $1" >&2; echo "   fix: pnpm.modules.sync.sh --help" >&2; exit 2 ;;
  esac
done
[[ "$mode" == plan || "$mode" == apply ]] || { echo "✋ ConstraintError: --mode must be plan or apply, got '$mode'" >&2; exit 2; }

# run from the repo root
root="$(git rev-parse --show-toplevel)" || { echo "💥 MalfunctionError: not inside a git repo" >&2; exit 1; }
cd "$root"
for f in package.json pnpm-lock.yaml; do
  [[ -f "$f" ]] || { echo "✋ ConstraintError: no $f at $root" >&2; exit 2; }
done

# a lock or manifest mid-conflict cannot be installed from
has_markers() { grep -qE '^(<<<<<<<|=======|>>>>>>>)( |$)' "$1"; }
for f in package.json pnpm-lock.yaml; do
  if has_markers "$f"; then
    echo "✋ ConstraintError: $f still holds conflict markers" >&2
    echo "   fix: settle $f first (then pnpm.lockfile.sync --mode apply), then rerun" >&2
    exit 2
  fi
done

echo "🐢 heres the wave..."
echo ""
echo "🐚 pnpm.modules.sync --mode $mode"
echo "   ├─ root: $root"

if [[ "$mode" == plan ]]; then
  echo "   └─ plan: would install from the frozen lock, patches applied, no lifecycle step (run with --mode apply)"
  exit 0
fi

# install from the lock; never rewrite it, never run a lifecycle step
skip_lifecycle="--ignore-scripts"   # pnpm's own flag name; unavoidable
if ! out="$(timeout 600 pnpm install --frozen-lockfile "$skip_lifecycle" 2>&1)"; then
  echo "   └─ 💥 MalfunctionError: pnpm install --frozen-lockfile failed" >&2
  printf '%s\n' "$out" | tail -n 20 | sed 's/^/      /' >&2
  echo "      fix: a stale lock? run pnpm.lockfile.sync --mode apply, then rerun" >&2
  exit 1
fi
echo "   └─ ✨ node_modules matches pnpm-lock.yaml, patches applied"