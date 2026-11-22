#!/usr/bin/env bash
######################################################################
# .what = show how git in a checkout would reach github: the remote url, the
#         credential helper it would run, and the file each value comes from
#
# .why  = a push that fails on a credential has three possible causes that
#         look alike: the remote's protocol (ssh asks no helper), the helper
#         git picks for that url, and an env var that overrides both. each
#         lives in a different file — the repo, ~/.gitconfig, an include, the
#         shell — so a read that names the ORIGIN of each value is the fix
#
# usage:
#   git.config.get.sh                  # the checkout at the cwd
#   git.config.get.sh --path <dir>     # any checkout, read-only (a peer tree)
#
# guarantee:
#   - read-only; runs `git config` reads and `git remote`, never a helper
#   - a token inside a url (https://<token>@github.com) is redacted
#   - GIT_* / GH_* env vars are named by presence only, never their values
#   - exit 0 = answered, 2 = not a git checkout
######################################################################
set -uo pipefail

DIR="$PWD"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) shift 2 ;;
    --path) DIR="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg: $1" >&2
       echo "   valid: --path <dir>  --help" >&2; exit 2 ;;
  esac
done

if ! git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "✋ ConstraintError: $DIR is not a git checkout" >&2
  echo "   fix: pass --path <a checkout>" >&2
  exit 2
fi

# .what = drop any userinfo from a url, so a token never reaches the screen
redact() { sed -E 's#://[^/@]+@#://<redacted>@#g'; }

echo "🐢 heres how git reaches github"
echo ""
echo "🐚 git.config.get"
echo "   ├─ checkout: $DIR"

# the remotes — an ssh url never consults an https credential helper
echo "   ├─ remotes"
git -C "$DIR" remote -v 2>/dev/null | redact | sed 's/^/   │  ├─ /'
echo "   │"

# every credential, url rewrite, and include, with the file it comes from
echo "   ├─ credential, url, and include keys (origin → key value)"
git -C "$DIR" config --show-origin --show-scope --get-regexp '^(credential|url|include|includeif)\.' 2>/dev/null \
  | redact | sed 's/^/   │  ├─ /'
echo "   │"

# the helper git would pick for this repo's own github url
url="$(git -C "$DIR" remote get-url --push origin 2>/dev/null)"
echo "   ├─ push url: $(printf '%s' "${url:-(no origin)}" | redact)"
if [[ "$url" == https://* ]]; then
  echo "   ├─ helper git runs for it: $(git -C "$DIR" config --get-urlmatch credential.helper "$url" 2>/dev/null || echo '(none)')"
else
  echo "   ├─ helper git runs for it: (none — not an https url, so no credential helper is asked)"
fi
echo "   │"

# the env that overrides config — names only
echo "   └─ env overrides present (names only)"
envs="$(env | cut -d= -f1 | grep -E '^(GIT_|GH_|GITHUB_TOKEN$)' | sort)"
if [[ -z "$envs" ]]; then
  echo "      └─ (none)"
else
  printf '%s\n' "$envs" | sed 's/^/      ├─ /'
fi