#!/usr/bin/env bash
######################################################################
# .what = run the 4.3.1.terminfo upsert three times on one ~/.bashrc, and fail
#         unless the first lays one block, the next two write naught, and a
#         legacy block is pruned exactly once
#
# .why  = the current marker sits in the legacy list too, and the prune once
#         deleted it, so every apply re-appended the block and reported a change.
#         📜 2026-11-20, a hetzner grove: "pruned a legacy erase block"
#         on each apply of a converged box
#
# guarantee:
#   - HERMETIC: a temp HOME with its own ~/.bashrc; the upsert is sourced and
#     called as the runtime calls it, and touches no other file
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UPSERT="$HERE/src/grove.provision/4.terminal/4.3.kitty/4.3.1.terminfo/configure.upsert.sh"

home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT

failed=0
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }
claim() { local label="$1"; shift; if "$@"; then echo "   • $label ✔"; else fail "$label"; fi; }

OUT="" transcript=""
APPLY_N=0
# each apply's words and the ~/.bashrc it leaves, snapped: the human reads both
apply() {
  local rc
  APPLY_N=$(( APPLY_N + 1 ))
  OUT="$(timeout -k 2 20 env HOME="$home" bash -c 'source "$1"; grove_provision_4_3_1_terminfo_configure_upsert' _ "$UPSERT" </dev/null 2>&1)" && rc=0 || rc=$?
  transcript+="## apply $APPLY_N (exit $rc)"$'\n'"${OUT//$home/<home>}"$'\n'"### ~/.bashrc after"$'\n'"$(cat "$home/.bashrc")"$'\n\n'
}
markers() { grep -cF "# grove.provision:4.3.1.terminfo" "$home/.bashrc"; }
legacy() { grep -cF "# grove.provision:44.terminfo.kitty" "$home/.bashrc"; }

echo "🌲 prove.terminfo-upsert-converges"

# a box that carries the OLD block, as a pre-rename grove did
printf '# a human line\n# grove.provision:44.terminfo.kitty\n[[ -t 0 ]] && stty erase "^?"\n' >"$home/.bashrc"

apply
claim "apply 1 · prunes the legacy block"       test "$(legacy)" -eq 0
claim "apply 1 · lays the current block once"   test "$(markers)" -eq 1
claim "apply 1 · keeps the human's own line"    grep -qF "# a human line" "$home/.bashrc"
before="$(cat "$home/.bashrc")"

apply
claim "apply 2 · names no work"                 test -n "$(grep -F 'no work' <<<"$OUT")"
claim "apply 2 · prunes naught"                 test -z "$(grep -F 'pruned' <<<"$OUT")"
claim "apply 2 · the file is byte for byte the same" test "$(cat "$home/.bashrc")" = "$before"

apply
claim "apply 3 · still one block"               test "$(markers)" -eq 1
claim "apply 3 · still prunes naught"           test -z "$(grep -F 'pruned' <<<"$OUT")"

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.terminfo-upsert-converges.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"
