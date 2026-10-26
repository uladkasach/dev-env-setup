#!/usr/bin/env bash
######################################################################
# prove.a-bait-that-never-starts-fails-the-play — a play whose own bait never
# runs fails loud (exit 1, 💥), never declines
#
# .why this play exists
#   - a play that could not set up its bait proved naught. a decline (exit 2)
#     would sort it beside "this seat holds no subject" in `play.run --all`,
#     which reads as a non-failure (`rule.forbid.failhide`; fulcrum F16, struck)
#   - the clamp for that verdict: revert either play's bait branch to exit 2,
#     and its arm here goes red
#
# .the arms — each runs the REAL play with a stub `sleep` first on PATH
#   - the stub runs as `sleep` for the play's own polls, so the waits stay real
#   - each play copies `sleep` to make its bait; a copy runs under another name,
#     and there the stub exits at once, so the bait never execs or lives
#   - B1  prove.coredump-catches-a-crash          → exit 1, 💥 the bait did not exec
#   - B2  prove.reaper-spares-an-own-scope-server → exit 1, 💥 a bait did not start
#
# .the write — `rule.forbid.repair-plays` exception 2: one temp dir, which holds
#   the stub and each play's own temp dir; a trap removes it
#
# usage:
#   rhx play.run --play prove.a-bait-that-never-starts-fails-the-play
#
# exit:
#   0 = both arms hold
#   1 = an arm failed
#   2 = a play under proof declined for want of its subject (no coredumpctl, no
#       user manager) before it reached its bait, so that arm graded no claim
######################################################################
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_SLEEP="$(command -v sleep)"
FIX="$(mktemp -d "${TMPDIR:-/tmp}/prove.bait-fails.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT
FAILED=0
DECLINED=0

# shellcheck source=/dev/null
source "$HERE/.snap.operations.sh"

# the stub: as `sleep` it is the real sleep; under any other name (a bait's copy) it exits at once
mkdir -p "$FIX/bin" "$FIX/tmp"
printf '#!/bin/sh\ncase "${0##*/}" in sleep) exec %q "$@" ;; esac\nexit 0\n' "$REAL_SLEEP" > "$FIX/bin/sleep"
chmod +x "$FIX/bin/sleep"

echo "🔭 does a play whose bait never starts fail loud?"

# .what = run one play under the stub, then grade its exit, its 💥 line, and its snap
_arm() {
  local arm="$1" play="$2" phrase="$3" out rc
  out="$(env -u PLAY_RESNAP PATH="$FIX/bin:$PATH" TMPDIR="$FIX/tmp" \
    timeout -k 5 120 bash "$HERE/$play.play.sh" </dev/null 2>&1)"
  rc=$?

  # a play that declined for want of its subject never reached its bait
  if [[ "$rc" == 2 && "$out" != *"$phrase"* ]]; then
    echo "   ├─ 🌙 $arm: $play declined before its bait — no subject on this seat"
    printf '%s\n' "$out" | head -3 | sed 's/^/   │     /'
    DECLINED=1
    return 0
  fi

  if [[ "$rc" != 1 || "$out" != *"💥 MalfunctionError: $phrase"* ]]; then
    echo "   ├─ ✋ $arm: $play → rc=$rc (want 1), want '💥 MalfunctionError: $phrase'"
    printf '%s\n' "$out" | sed 's/^/   │     /'
    FAILED=1
    return 0
  fi

  play_snap_assert arm="$arm" rendered="$out" mask="$FIX" || { FAILED=1; return 0; }
  echo "   ├─ ✔ $arm: $play → exit 1, says '💥 MalfunctionError: $phrase'"
}

_arm B1 prove.coredump-catches-a-crash "the bait did not exec within 5s"
_arm B2 prove.reaper-spares-an-own-scope-server "a bait did not start within 5s"

[[ "$FAILED" == 1 ]] && { echo "   └─ 💥 MalfunctionError: a play whose bait never ran did not fail loud" >&2; exit 1; }
[[ "$DECLINED" == 1 ]] && { echo "   └─ 🌙 an arm declined — its play found no subject on this seat"; exit 2; }
echo "   └─ ✔ each play fails loud when its own bait never runs"
exit 0
