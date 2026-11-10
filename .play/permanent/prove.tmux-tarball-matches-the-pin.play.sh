#!/usr/bin/env bash
######################################################################
# .what = prove the tarball at `2.8.tmux`'s pinned url hashes to its pinned digest
#
# .why this play exists
#   - tmux publishes no signature, and github states no digest for the asset
#   - the digest in `_.sh` was read from a second party (homebrew-core)
#   - ⇒ this play fetches the bytes through the same wire the upsert uses and
#     checks them against that digest, so a bad pin is caught before an apply
#   - then it builds those bytes with the bundle's own `_pin_build` — the tar,
#     configure, make path a stubbed arm cannot reach — and asks the build its name
#
# usage:
#   rhx play.run --play prove.tmux-tarball-matches-the-pin
#
# exit:
#   0 = the bytes match the pin, and they build a tmux that names the pin and keeps
#       its symbols
#   1 = no pin declared, the bytes do NOT match, or they do not build into a tmux
#       that names the pin
#   2 = no checkout, a source failed, the fetch failed, or this box lacks the build
#       toolchain — so no claim was graded
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
_root="$(_root_of)" || { echo "   ✋ ConstraintError: no checkout found" >&2; exit 2; }

export GROVE_SRC="$_root/src"

echo "🔎 prove.tmux-tarball-matches-the-pin"
echo "   └─ root: $_root"
echo ""

# shellcheck source=/dev/null
source "$GROVE_SRC/grove.web.sh" || { echo "   ✋ ConstraintError: could not source grove.web.sh" >&2; exit 2; }
# shellcheck source=/dev/null
source "$GROVE_SRC/grove.provision/2.shell/2.8.tmux/_.sh" || { echo "   ✋ ConstraintError: could not source 2.8.tmux/_.sh" >&2; exit 2; }

if [[ -z "${GROVE_UPGRADE_2_8_TMUX_URL:-}" || -z "${GROVE_UPGRADE_2_8_TMUX_SHA256:-}" ]]; then
  echo "   💥 MalfunctionError: the bundle declares no tmux url or digest — no pin to grade" >&2
  exit 1
fi

tmp="$(web_tempdir prove-tmux)" || { echo "   ✋ ConstraintError: no temp dir for the fetch — no claim graded" >&2; exit 2; }
trap 'rm -rf "$tmp"' EXIT

echo "   ├─ url:    $GROVE_UPGRADE_2_8_TMUX_URL"
echo "   ├─ digest: $GROVE_UPGRADE_2_8_TMUX_SHA256"

if ! web_fetch "$GROVE_UPGRADE_2_8_TMUX_URL" --into "$tmp/tmux.tar.gz"; then
  echo "   └─ ✋ ConstraintError: the fetch failed; no claim graded" >&2
  exit 2
fi

if ! web_verify_sha256 --file "$tmp/tmux.tar.gz" --sha256 "$GROVE_UPGRADE_2_8_TMUX_SHA256"; then
  echo "   └─ 💥 MalfunctionError: the bytes do NOT match the pin" >&2
  exit 1
fi
echo "   ├─ ✔ the bytes match the pin"

######################################################################
# the build — the bundle's own `_pin_build`, on the verified bytes, in this temp dir.
#   no root is needed: the build places no file, and its log lands under a temp HOME
######################################################################
# shellcheck source=/dev/null
source "$GROVE_SRC/grove.provision/2.shell/2.8.tmux/provision.upsert.sh" \
  || { echo "   ✋ ConstraintError: could not source 2.8.tmux/provision.upsert.sh" >&2; exit 2; }

command -v cc >/dev/null && pkg-config --exists libevent ncurses || {
  echo "   └─ ✋ ConstraintError: this box lacks the build toolchain, so the build claim cannot be graded" >&2
  echo "      fix: sudo -v && rhx grove.provision --what 2.8.tmux --mode apply" >&2
  exit 2
}

mkdir -p "$tmp/home"
HOME="$tmp/home" grove_provision_2_8_tmux_pin_build --tarball "$tmp/tmux.tar.gz" --into "$tmp" || {
  echo "   └─ 💥 MalfunctionError: the verified bytes did not build" >&2
  exit 1
}

built="$tmp/tmux-$GROVE_UPGRADE_2_8_TMUX_VERSION/tmux"
named="$(timeout -k 2 5 "$built" -V </dev/null)"
[[ "$named" == "tmux $GROVE_UPGRADE_2_8_TMUX_VERSION" ]] || {
  echo "   └─ 💥 MalfunctionError: the build names itself '${named:-naught}', not 'tmux $GROVE_UPGRADE_2_8_TMUX_VERSION'" >&2
  exit 1
}
echo "   ├─ ✔ the build names itself '$named'"

# the build keeps its symbols, so a core's stack names the fault site (case 6 [t7])
[[ "$(file -b "$built")" == *"not stripped"* ]] || {
  echo "   └─ 💥 MalfunctionError: the build is stripped, so a core's stack would name no function" >&2
  exit 1
}
echo "   ├─ ✔ the build keeps its symbols, so a core names its fault site"

# a read, never a grade: does each build link utf8proc, which sets how wide a glyph measures?
_links_utf8proc() { ldd "$1" | grep -q utf8proc && printf 'yes' || printf 'no'; }
_distro_links="absent"
[[ -x /usr/bin/tmux ]] && _distro_links="$(_links_utf8proc /usr/bin/tmux)"
_pin_links="$(_links_utf8proc "$built")"
echo "   └─ utf8proc linked: the pin=$_pin_links, the distro=$_distro_links"

# the snap pins the pin itself — its url, digest, and the name its build gives — so a bump
#   shows in review; the distro's utf8proc link varies by box, so its row is masked
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"
play_snap_assert arm=P rendered="$(printf '%s\n' \
  "   • url: $GROVE_UPGRADE_2_8_TMUX_URL" \
  "   • digest: $GROVE_UPGRADE_2_8_TMUX_SHA256" \
  "   • the bytes match the pin ✔" \
  "   • the build names itself '$named' ✔" \
  "   • the build keeps its symbols ✔" \
  "   • utf8proc linked by the pin: $_pin_links" \
  "   • utf8proc linked by the distro: <varies by box>")" || exit 1
exit 0
