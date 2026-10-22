#!/usr/bin/env bash
######################################################################
# .what = report where a claude login landed, with no secret printed
#
# .why  = `brains.auth.set` lifts the refresh token out of an isolated
#         CLAUDE_CONFIG_DIR. when claude changes where it saves a login,
#         the lift reads "no refresh token captured", and the only way to
#         tell WHERE it went is to look at the dir — and at the global
#         login, which an isolated sign-in must never touch. this reads
#         both by shape alone: presence, mtime, token prefix, account.
#
# usage:
#   rhx brains.auth.creds.get                 # the global login (~/.claude)
#   rhx brains.auth.creds.get --dir <path>    # any claude config dir
#
# guarantee:
#   - read-only; never writes, never refreshes, never prints a token
#   - a token is reported only as its kind (sk-ant-ort / sk-ant-oat / other)
#   - exit 0 = reported, 2 = bad input
######################################################################

set -uo pipefail

# strip rhachet's own flags, keep the caller's
dir="$HOME/.claude"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill|--repo|--role) shift 2 ;;
    --dir)
      [[ $# -ge 2 ]] || { echo "✋ ConstraintError: --dir needs a path" >&2; exit 2; }
      dir="$2"; shift 2 ;;
    -h|--help)
      sed -n '3,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg '$1' (see --help)" >&2; exit 2 ;;
  esac
done

# the account record sits beside ~/.claude for the global login, inside the dir otherwise
acctfile="$dir/.claude.json"
[[ "$dir" == "$HOME/.claude" ]] && acctfile="$HOME/.claude.json"
creds="$dir/.credentials.json"

# a token's kind, by prefix alone
__kind_of() {
  case "$1" in
    '')           printf 'absent' ;;
    sk-ant-ort*)  printf 'sk-ant-ort (refresh)' ;;
    sk-ant-oat*)  printf 'sk-ant-oat (access)' ;;
    *)            printf 'other shape' ;;
  esac
}

# a file's mtime, or absent
__mtime_of() {
  [[ -e "$1" ]] || { printf 'absent'; return; }
  date -d "@$(stat -c %Y "$1")" '+%Y-%m-%d %H:%M:%S'
}

echo "🐢 sweet"
echo ""
echo "🔭 brains.auth.creds.get --dir $dir"
if [[ ! -d "$dir" ]]; then
  echo "   └─ dir: absent"
  exit 0
fi
echo "   ├─ files: $(ls -A "$dir" | tr '\n' ' ')"

# the credential file — kinds and dates only
echo "   ├─ .credentials.json"
echo "   │  ├─ mtime: $(__mtime_of "$creds")"
if [[ -f "$creds" ]]; then
  refresh="$(jq -r '.claudeAiOauth.refreshToken // empty' "$creds" 2>/dev/null)"
  access="$(jq -r '.claudeAiOauth.accessToken // empty' "$creds" 2>/dev/null)"
  sub="$(jq -r '.claudeAiOauth.subscriptionType // "?"' "$creds" 2>/dev/null)"
  keys="$(jq -r 'keys | join(",")' "$creds" 2>/dev/null)"
  echo "   │  ├─ top keys: ${keys:-unreadable}"
  echo "   │  ├─ refreshToken: $(__kind_of "$refresh")"
  echo "   │  ├─ accessToken: $(__kind_of "$access")"
  echo "   │  └─ subscription: $sub"
  unset refresh access
else
  echo "   │  └─ (no file)"
fi

# for the global login, ask the api who the live token truly belongs to. the account file
# below LAGS the token (it is written at a different moment), so only this read is authoritative.
# it never refreshes — whoami reads the access token as-is, and an expired one falls back.
if [[ "$dir" == "$HOME/.claude" ]]; then
  # shellcheck disable=SC1091
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/brains.auth.bootstrap.sh"
  who="$(_brains_auth_whoami "$(_brains_auth_ua)")"; wrc=$?
  case "$wrc" in
    0) verdict="verified by the api" ;;
    2) verdict="UNVERIFIED — from the lagged account file" ;;
    *) verdict="unknown" ;;
  esac
  echo "   ├─ live token belongs to: ${who#*$'\t'} ($verdict)"
fi

# the account record — which email this dir is signed in as
echo "   └─ account ($acctfile)"
echo "      ├─ mtime: $(__mtime_of "$acctfile")"
if [[ -f "$acctfile" ]]; then
  echo "      └─ email: $(jq -r '.oauthAccount.emailAddress // "none"' "$acctfile" 2>/dev/null)"
else
  echo "      └─ (no file)"
fi
