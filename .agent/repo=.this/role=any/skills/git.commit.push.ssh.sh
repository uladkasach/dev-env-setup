#!/usr/bin/env bash
######################################################################
# .what = push this tree's commits with `rhx git.commit.push`, the one push
#         carried over ssh when the remote is https github
#
# .why  = a tree born on a camp grove keeps its https origin when it moves to
#         a laptop. git then asks the https helper, `git-credential-keyrack`,
#         which reads `@all.camp.GITHUB_TOKEN` — a slug a laptop never holds
#         (rule.require.aws-params-on-camp-groves-only). so every push declines
#   - laptop crews with an ssh origin push through the desktop ssh agent
#   - this gives an https tree that same road, scoped to ONE push: an
#     env-scoped `pushInsteadOf`, so the shared clone's remote, every config
#     file, and every peer worktree stay as they are
#   - fetch is untouched; only the push url is rewritten
#
# usage:
#   git.commit.push.ssh.sh                          # plan (git.commit.push's own plan)
#   git.commit.push.ssh.sh --mode apply             # push, findsert the pr, watch it
#   git.commit.push.ssh.sh --mode apply --auth as-human
#   (every flag passes through to `rhx git.commit.push`)
#
# guarantee:
#   - writes no git config; the rewrite lives in this process's env alone
#   - an ssh origin passes through unchanged (no rewrite owed)
#   - a non-github origin is refused (exit 2) — the rewrite would be wrong
#   - the push fails loud if the ssh agent cannot sign for github
######################################################################
set -uo pipefail

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

url="$(git remote get-url --push origin 2>/dev/null)" || {
  echo "✋ ConstraintError: this checkout has no origin remote" >&2
  echo "   fix: run from a checkout whose origin is on github" >&2
  exit 2
}

case "$url" in
  git@github.com:*|ssh://git@github.com/*)
    echo "🔑 origin is ssh already; no rewrite owed"
    exec rhx git.commit.push ${ARGS[@]+"${ARGS[@]}"}
    ;;
  https://github.com/*) ;;
  *)
    echo "✋ ConstraintError: origin is not github ($url)" >&2
    echo "   ⇒ the ssh rewrite names github.com alone, so it would not apply here" >&2
    echo "   fix: push with rhx git.commit.push directly" >&2
    exit 2
    ;;
esac

# one push over ssh: append to any env-scoped config the caller already set
ssh_base="git@github.com:"
n="${GIT_CONFIG_COUNT:-0}"
export "GIT_CONFIG_KEY_$n=url.${ssh_base}.pushInsteadOf"
export "GIT_CONFIG_VALUE_$n=https://github.com/"
export GIT_CONFIG_COUNT=$((n + 1))
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes}"

echo "🔑 push transport: ssh (origin https → push url git@github.com:, this push only)"
exec rhx git.commit.push ${ARGS[@]+"${ARGS[@]}"}
