#!/usr/bin/env bash
######################################################################
# .what = set a pull request's description (its body) to a file's content
#
# .why  = `git.pull.comment.set` refuses the pr description by design — it
#         is no comment. a body that drifts from the branch (a stale mode,
#         a stale arm count, a "checkpoint" note on a done pr) misleads
#         every reviewer, so the body is brought to current truth with a
#         plan, an apply, and a read-back, never a raw `gh pr edit`
#
# usage:
#   git.pull.description.set.sh --pr 167 --from ./body.md                 # plan (default)
#   git.pull.description.set.sh --pr 167 --from ./body.md --mode apply
#   cat body.md | git.pull.description.set.sh --pr 167 --from @stdin --mode apply
#
# options:
#   --pr <n>              the pull request (required)
#   --from <path|@stdin>  the new body, written verbatim
#   --mode plan|apply     plan prints the current and new sizes + hashes (default: plan)
#   --auth as-human       who writes. the one supported value: the gh cli login.
#                         the seaturtle app's install gets a 403 on this repo's
#                         pr writes, so no as-ehmpath path is offered
#   -h, --help            show this header
#
# guarantee:
#   - plan writes naught
#   - apply reads the body back and compares sha256; a mismatch is exit 1
#   - an empty new body is refused (exit 2) — a blank pr body is never the intent
#   - exit 0 = done or no-op, 1 = gh failed or read-back mismatch, 2 = bad input
######################################################################
set -euo pipefail

pr="" from="" mode="plan" auth="as-human"
while (( $# )); do
  case "$1" in
    --pr) pr="${2:-}"; shift 2 ;;
    --from) from="${2:-}"; shift 2 ;;
    --mode) mode="${2:-}"; shift 2 ;;
    --auth) auth="${2:-}"; shift 2 ;;
    --skill|--repo|--role) shift 2 ;;   # rhachet injects these ahead of the caller's args
    -h|--help) sed -n '2,29p' "$0"; exit 0 ;;
    *) echo "✋ ConstraintError: unknown option $1" >&2; echo "   fix: git.pull.description.set.sh --help" >&2; exit 2 ;;
  esac
done

# reject absent or malformed input
[[ "$pr" =~ ^[0-9]+$ ]] || { echo "✋ ConstraintError: --pr must be a pull number, got '$pr'" >&2; exit 2; }
[[ -n "$from" ]] || { echo "✋ ConstraintError: --from is required (a path or @stdin)" >&2; exit 2; }
[[ "$mode" == plan || "$mode" == apply ]] || { echo "✋ ConstraintError: --mode must be plan or apply, got '$mode'" >&2; exit 2; }
[[ "$auth" == as-human ]] || { echo "✋ ConstraintError: --auth '$auth' is not offered; only as-human (the gh cli login)" >&2; echo "   why: the seaturtle app's install gets a 403 on this repo's pr writes" >&2; exit 2; }

# read the new body
if [[ "$from" == @stdin ]]; then body="$(cat)"; else
  [[ -f "$from" ]] || { echo "✋ ConstraintError: --from file not found: $from" >&2; exit 2; }
  body="$(cat "$from")"
fi
[[ -n "${body//[[:space:]]/}" ]] || { echo "✋ ConstraintError: the new body is empty; a blank pr body is never the intent" >&2; exit 2; }

# read the current body; a gh failure is a malfunction, never an empty body
if ! current="$(gh pr view "$pr" --json body --jq .body)"; then
  echo "💥 MalfunctionError: gh pr view $pr failed — is the gh cli logged in? (gh auth status)" >&2
  exit 1
fi
sha() { printf '%s' "$1" | sha256sum | cut -c1-12; }
url="$(gh pr view "$pr" --json url --jq .url)"

echo "🐢 heres the wave..."
echo ""
echo "🐚 git.pull.description.set --pr $pr --mode $mode --auth $auth"
echo "   ├─ url: $url"
echo "   ├─ current: ${#current} chars, sha256 $(sha "$current")"
echo "   ├─ new:     ${#body} chars, sha256 $(sha "$body")"

# no-op where the body already holds
if [[ "$current" == "$body" ]]; then echo "   └─ [KEEP] the body already holds this content"; exit 0; fi
if [[ "$mode" == plan ]]; then echo "   └─ plan: would replace the body (run with --mode apply)"; exit 0; fi

# write, then read back
if ! printf '%s' "$body" | gh pr edit "$pr" --body-file - >/dev/null; then
  echo "   └─ 💥 gh pr edit $pr failed" >&2; exit 1
fi
after="$(gh pr view "$pr" --json body --jq .body)"
if [[ "$(sha "$after")" != "$(sha "$body")" ]]; then
  echo "   └─ 💥 MalfunctionError: read-back sha256 $(sha "$after") differs from the sent $(sha "$body")" >&2; exit 1
fi
echo "   └─ ✨ body replaced; read-back sha256 $(sha "$after") matches"
