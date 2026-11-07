#!/usr/bin/env bash
######################################################################
# .what = regenerate pnpm-lock.yaml from package.json, lockfile only
#
# .why  = a rebase or merge that conflicts in pnpm-lock.yaml cannot be
#         settled by hand: the lock is derived. settle package.json, then
#         let pnpm derive the lock from it. `pnpm install` is unpaved, and a
#         full install would also run the `prepare` lifecycle step (rhachet
#         init), which writes settings files; this skill never installs and
#         never runs a lifecycle step
#
# usage:
#   pnpm.lockfile.sync.sh                 # plan: is the lock in conflict?
#   pnpm.lockfile.sync.sh --mode apply    # rewrite pnpm-lock.yaml
#
# options:
#   --mode plan|apply   plan writes naught (default: plan)
#   -h, --help          show this header
#
# guarantee:
#   - runs pnpm install with --lockfile-only and the lifecycle-skip flag, from
#     the repo root: no node_modules change, no lifecycle step
#   - refuses (exit 2) while package.json still holds conflict markers
#   - apply fails loud (exit 1) where pnpm fails, or where the lock still
#     holds conflict markers after
#   - bounded at 300s
#   - exit 0 = done or no-op, 1 = pnpm failed, 2 = bad input or bad state
######################################################################
set -euo pipefail

mode="plan"
while (( $# )); do
  case "$1" in
    --mode) mode="${2:-}"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;   # rhachet injects these ahead of the caller's args
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) echo "✋ ConstraintError: unknown option $1" >&2; echo "   fix: pnpm.lockfile.sync.sh --help" >&2; exit 2 ;;
  esac
done
[[ "$mode" == plan || "$mode" == apply ]] || { echo "✋ ConstraintError: --mode must be plan or apply, got '$mode'" >&2; exit 2; }

# run from the repo root
root="$(git rev-parse --show-toplevel)" || { echo "💥 MalfunctionError: not inside a git repo" >&2; exit 1; }
cd "$root"
[[ -f package.json ]] || { echo "✋ ConstraintError: no package.json at $root" >&2; exit 2; }

# the lock derives from package.json, so package.json must be settled first
has_markers() { grep -qE '^(<<<<<<<|=======|>>>>>>>)( |$)' "$1"; }
if has_markers package.json; then
  echo "✋ ConstraintError: package.json still holds conflict markers" >&2
  echo "   fix: settle package.json first, then rerun" >&2
  exit 2
fi

lock_state="clean"
[[ -f pnpm-lock.yaml ]] || lock_state="absent"
[[ "$lock_state" == clean ]] && has_markers pnpm-lock.yaml && lock_state="in conflict"

echo "🐢 heres the wave..."
echo ""
echo "🐚 pnpm.lockfile.sync --mode $mode"
echo "   ├─ root: $root"
echo "   ├─ lock: $lock_state"

if [[ "$mode" == plan ]]; then
  echo "   └─ plan: would derive pnpm-lock.yaml, lockfile only, no lifecycle step (run with --mode apply)"
  exit 0
fi

# derive the lock; never install, never run a lifecycle step
skip_lifecycle="--ignore-scripts"   # pnpm's own flag name; unavoidable
before="$( [[ -f pnpm-lock.yaml ]] && sha256sum pnpm-lock.yaml | cut -c1-12 || echo none )"
if ! out="$(timeout 300 pnpm install --lockfile-only "$skip_lifecycle" 2>&1)"; then
  echo "   └─ 💥 MalfunctionError: pnpm install --lockfile-only failed" >&2
  printf '%s\n' "$out" | tail -n 20 | sed 's/^/      /' >&2
  exit 1
fi
if has_markers pnpm-lock.yaml; then
  echo "   └─ 💥 MalfunctionError: pnpm-lock.yaml still holds conflict markers after the sync" >&2
  exit 1
fi
after="$(sha256sum pnpm-lock.yaml | cut -c1-12)"
if [[ "$before" == "$after" ]]; then
  echo "   └─ [KEEP] pnpm-lock.yaml already matches package.json (sha256 $after)"
  exit 0
fi
echo "   └─ ✨ pnpm-lock.yaml rewritten: sha256 $before → $after"
