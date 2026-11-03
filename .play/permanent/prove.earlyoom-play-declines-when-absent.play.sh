#!/usr/bin/env bash
######################################################################
# .what = drive prove.earlyoom-spares-the-session on a PATH without earlyoom,
#         then on a PATH with a stub earlyoom, and snap both answers
#
# .why  = a box that lacks earlyoom holds no subject, so the play must decline
#         (exit 2), never fail. a gate that declined always would hide the real
#         claim, so the stub row proves a present binary still reaches its arms
#
# guarantee:
#   - HERMETIC. it writes only inside its own mktemp dir, removed on exit
#   - the stub is no proof of earlyoom; it proves only the gate's two branches
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SUBJECT="$HERE/.play/permanent/prove.earlyoom-spares-the-session.play.sh"
[[ -r "$SUBJECT" ]] || { echo "✋ ConstraintError: the subject play is absent from $HERE" >&2; exit 2; }

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/tmp"

# the tools the subject calls, earlyoom aside
for tool in bash cp sleep mktemp rm cat timeout stdbuf grep head sed; do
  ln -s "$(command -v "$tool")" "$fixture/bin/$tool" || { echo "💥 MalfunctionError: no $tool on this box" >&2; exit 1; }
done

failed=0
transcript=""
cry() { echo "$1" >&2; transcript+="$1"$'\n'; }

echo "🌲 prove.earlyoom-play-declines-when-absent"

# one row — $1 = label · $2 = exit wanted · $3 = text the output must hold
row() {
  local label="$1" want="$2" holds="$3" out rc
  out="$(env -i HOME="$fixture" TMPDIR="$fixture/tmp" PATH="$fixture/bin" GROVE_SRC="$HERE/src" \
    "$fixture/bin/bash" "$SUBJECT" 2>&1)" && rc=0 || rc=$?
  # pids and scores differ per run; one token stands for each
  out="$(sed -E -e 's#pid [0-9]+#pid <pid>#g' -e 's#oom_score [0-9]+#oom_score <n>#g' <<< "${out//$fixture/<fixture>}")"
  transcript+=$'\n'"## $label"$'\n'"rc=$rc"$'\n'"$out"$'\n'
  if [[ "$rc" -eq "$want" && "$out" == *"$holds"* ]]; then
    echo "   • $label → rc=$rc ✔"
    return 0
  fi
  cry "   💥 MalfunctionError: $label → rc=$rc (want $want), holds '$holds': $([[ "$out" == *"$holds"* ]] && echo yes || echo no)"
  failed=1
}

row "earlyoom absent → declines" 2 "🌙 earlyoom is not on this box"

# a stub that names the bait the real binary would: the runtime bait under the
# declared policy (the one arm that passes --prefer), the session bait otherwise
printf '%s\n' '#!/usr/bin/env bash' \
  '[[ "${1:-}" == "-v" ]] && { echo "earlyoom stub"; exit 0; }' \
  'for a in "$@"; do [[ "$a" == --prefer* ]] && { echo "process 4243 uid 1000 \"node\""; exit 0; }; done' \
  'echo "process 4242 uid 1000 \"systemd\""' > "$fixture/bin/earlyoom"
chmod +x "$fixture/bin/earlyoom"

row "earlyoom present → reaches both arms" 0 "arm 'old-default'"

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.earlyoom-play-declines-when-absent.snap" name=transcript actual="$transcript" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"
