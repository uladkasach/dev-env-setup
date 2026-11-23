#!/usr/bin/env bash
######################################################################
# .what = download the chromium build this repo's pinned playwright wants,
#         into ~/.cache/ms-playwright, so `rhx browser.start` can launch
#
# .why  = the browser build is the REPO's half: each playwright version pins
#         its own build (`chromium-<rev>`), and `browser.start` refuses with
#         "chromium not found" until that exact rev is on disk. the box-wide
#         half (the ~34 libs it dlopens) is root's, and belongs to the
#         `5.21.playwright` bundle — this skill never touches it
#
# usage:
#   rhx browser.chromium.set
#
# guarantee:
#   - runs the playwright this checkout resolves (node_modules), never a
#     global one, so the rev matches what the bhrowser role launches
#   - idempotent: playwright skips a build already on disk
#   - no sudo; libs absent → run `sudo -v && rhx grove.provision --what 5.21.playwright --mode apply`
#   - exit 0 = chromium present; 1 = the download failed; 2 = no playwright here
######################################################################
set -euo pipefail

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg: $1" >&2; exit 2 ;;
  esac
done

REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CLI="$REPO/node_modules/playwright/cli.js"
if [[ ! -r "$CLI" ]]; then
  echo "✋ ConstraintError: no playwright at $CLI" >&2
  echo "   └─ fix: npm ci, from $REPO" >&2
  exit 2
fi
VERSION="$(node -p "require('$REPO/node_modules/playwright/package.json').version")"

echo "🐢 lets fetch a browser"
echo ""
echo "🐚 browser.chromium.set"
echo "   ├─ playwright: $VERSION ($CLI)"
echo "   └─ install chromium"
if ! node "$CLI" install chromium 2>&1 | sed 's/^/      │ /'; then
  echo "💥 MalfunctionError: chromium download failed — read the lines above" >&2
  exit 1
fi
echo "      └─ ✔ chromium present in ~/.cache/ms-playwright"
