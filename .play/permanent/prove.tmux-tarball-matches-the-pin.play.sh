#!/usr/bin/env bash
######################################################################
# .what = prove the tarball at `2.8.tmux`'s pinned url hashes to its pinned digest
#
# .why this play exists
#   - tmux publishes no signature, and github states no digest for the asset
#   - the digest in `_.sh` was read from a second party (homebrew-core)
#   - ⇒ this play fetches the bytes through the same wire the upsert uses and
#     checks them against that digest, so a bad pin is caught before an apply
#
# usage:
#   rhx play.run --play prove.tmux-tarball-matches-the-pin
#
# exit:
#   0 = the bytes match the pin
#   1 = no pin declared, or the bytes do NOT match
#   2 = the fetch failed, so no claim was graded
######################################################################

set -uo pipefail

# .what = the checkout under proof — `PROVE_ROOT` (the red half), this play's own, or the cwd
_root_of() {
  [[ -n "${PROVE_ROOT:-}" ]] && { printf '%s' "$PROVE_ROOT"; return 0; }
  local self; self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
  [[ -n "$self" && -f "$self/src/grove.provision._.sh" ]] && { printf '%s' "$self"; return 0; }
  [[ -f "$PWD/src/grove.provision._.sh" ]] && { printf '%s' "$PWD"; return 0; }
  return 1
}
_root="$(_root_of)" || { echo "   ✋ no checkout found" >&2; exit 2; }

export GROVE_SRC="$_root/src"

echo "🔎 prove.tmux-tarball-matches-the-pin"
echo "   └─ root: $_root"
echo ""

# shellcheck source=/dev/null
source "$GROVE_SRC/grove.web.sh" || { echo "   ✋ could not source grove.web.sh" >&2; exit 2; }
# shellcheck source=/dev/null
source "$GROVE_SRC/grove.provision/2.shell/2.8.tmux/_.sh" || { echo "   ✋ could not source 2.8.tmux/_.sh" >&2; exit 2; }

if [[ -z "${GROVE_UPGRADE_2_8_TMUX_URL:-}" || -z "${GROVE_UPGRADE_2_8_TMUX_SHA256:-}" ]]; then
  echo "   ✋ the bundle declares no tmux url or digest — no pin to grade" >&2
  exit 1
fi

tmp="$(web_tempdir prove-tmux)" || exit 2
trap 'rm -rf "$tmp"' EXIT

echo "   ├─ url:    $GROVE_UPGRADE_2_8_TMUX_URL"
echo "   ├─ digest: $GROVE_UPGRADE_2_8_TMUX_SHA256"

if ! web_fetch "$GROVE_UPGRADE_2_8_TMUX_URL" --into "$tmp/tmux.tar.gz"; then
  echo "   └─ ✋ the fetch failed; no claim graded" >&2
  exit 2
fi

if web_verify_sha256 --file "$tmp/tmux.tar.gz" --sha256 "$GROVE_UPGRADE_2_8_TMUX_SHA256"; then
  echo "   └─ ✔ the bytes match the pin"
  exit 0
fi
echo "   └─ ✋ the bytes do NOT match the pin" >&2
exit 1
