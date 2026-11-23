#!/usr/bin/env bash
######################################################################
# .what = drive the 2.6.starship configure phases on a temp HOME, and fail unless the
#         bash init block lands once, a rerun writes naught, the human's own lines
#         stay, and the verify reads each of its two bashrc arms
#
# .why  = a bash terminal (a pane a tmux server opened before zsh was the login shell,
#         or a human who types `bash`) reads only ~/.bashrc, and drew a bare prompt.
#         📜 2026-11-20, a hetzner grove. the upsert findserts a marked block; this
#         proves the findsert converges, and snaps every line a human reads from it
#
# guarantee:
#   - HERMETIC: a temp HOME; no starship binary, so the verify's parse half reads
#     its own UNCHECKED arm, which is deterministic on any box
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE="$HERE/src/grove.provision/2.shell/2.6.starship"

home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT

failed=0
transcript=""
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }
claim() { local label="$1"; shift; if "$@"; then echo "   • $label ✔"; else fail "$label"; fi; }

OUT="" RC=0
# $1 = upsert|verify · $2 = the transcript header
phase() {
  OUT="$(timeout -k 2 20 env HOME="$home" GROVE_SRC="$HERE/src" bash -c \
    'source "$1/configure.upsert.sh"; source "$1/configure.verify.sh"; "grove_provision_2_6_starship_configure_$2"' \
    _ "$BUNDLE" "$1" </dev/null 2>&1)" && RC=0 || RC=$?
  # masked: the temp HOME and this checkout's own path, which names the box's user
  local shown="${OUT//$home/<home>}"
  transcript+="## $2 (exit $RC)"$'\n'"${shown//$HERE/<checkout>}"$'\n\n'
}
markers() { grep -cF "# grove.provision:2.6.starship" "$home/.bashrc"; }

echo "🌲 prove.starship-bashrc-converges"

# a seat's ~/.bashrc as debian lays it, plus a line of the human's own
printf '# ~/.bashrc: executed by bash(1) for non-login shells.\nalias ll="ls -l"\n' >"$home/.bashrc"

# the verify, before any apply: the config is absent, so its first arm refuses
phase verify "verify, before any apply"
claim "verify · an unconverged box refuses, rc 1" test "$RC" -eq 1

phase upsert "upsert 1, a ~/.bashrc with no init"
claim "upsert 1 · exits 0" test "$RC" -eq 0
claim "upsert 1 · lays the init block once" test "$(markers)" -eq 1
claim "upsert 1 · keeps the human's own line" grep -qxF 'alias ll="ls -l"' "$home/.bashrc"
claim "upsert 1 · the block inits starship in an interactive bash alone" \
  grep -qF '[[ $- == *i* && -t 1 && -x "$HOME/.local/bin/starship" ]] && eval "$("$HOME/.local/bin/starship" init bash)"' "$home/.bashrc"
claim "upsert 1 · the block parses" bash -n "$home/.bashrc"
before="$(cat "$home/.bashrc")"

phase upsert "upsert 2, a converged box"
claim "upsert 2 · names no work" test -n "$(grep -F 'already inits starship — no work' <<<"$OUT")"
claim "upsert 2 · the file is byte for byte the same" test "$(cat "$home/.bashrc")" = "$before"

phase verify "verify, converged"
claim "verify · a converged box reads the bashrc arm ✔, rc 0" \
  bash -c '[[ "$1" -eq 0 && "$2" == *"~/.bashrc inits starship ✔"* ]]' _ "$RC" "$OUT"

# the init block lost by a hand edit: the config still matches, the bashrc arm refuses
printf '# ~/.bashrc, rewritten by hand\n' >"$home/.bashrc"
phase verify "verify, a ~/.bashrc that lost the block"
claim "verify · a lost block refuses, rc 1, and names the apply" \
  bash -c '[[ "$1" -eq 1 && "$2" == *"~/.bashrc inits no starship"* && "$2" == *"rhx grove.provision --what 2.6.starship --mode apply"* ]]' _ "$RC" "$OUT"

# no ~/.bashrc at all: the upsert makes one, with the block
rm -f "$home/.bashrc"
phase upsert "upsert, a seat with no ~/.bashrc"
claim "upsert · a seat with no ~/.bashrc gets one, with the block once" test "$RC" -eq 0 -a "$(markers)" -eq 1

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.starship-bashrc-converges.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"
