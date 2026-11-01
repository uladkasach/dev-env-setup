#!/usr/bin/env bash
######################################################################
# .what = open a url in the human's firefox, as a new tab
#
# .why  = the box's browser launcher (`~/.local/bin/browser`) is what the
#         1.3.1.firefox bundle uses to hand a human a tab; this paves the
#         same door for a clone, so a url is never opened by a raw call
#
# usage:
#   firefox.open.sh --url 'https://color.firefox.com/?theme=...'
#
# guarantee:
#   - only accepts http(s) urls
#   - exit 0 = opened, 1 = launcher failed, 2 = bad input / no launcher
######################################################################

set -uo pipefail

# parse --url; rhx injects its own flags, so scan every arg
url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) url="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ ! "$url" =~ ^https?:// ]]; then
  echo "✋ ConstraintError: --url must be an http(s) url (got: '${url:-<empty>}')" >&2
  exit 2
fi

launcher="$HOME/.local/bin/browser"
if [[ ! -x "$launcher" ]]; then
  echo "✋ ConstraintError: no browser launcher at $launcher" >&2
  echo "   fix: rhx grove.provision --what 1.3.1.firefox --mode apply" >&2
  exit 2
fi

# open detached, so the tab outlives this call
if ! setsid "$launcher" "$url" >/dev/null 2>&1 </dev/null; then
  echo "💥 MalfunctionError: the launcher failed to open the url" >&2
  exit 1
fi

echo "🦊 firefox.open"
echo "   └─ opened: ${url:0:80}$([[ ${#url} -gt 80 ]] && echo '…')"
