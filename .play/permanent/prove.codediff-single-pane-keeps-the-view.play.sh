#!/usr/bin/env bash
######################################################################
# prove.codediff-single-pane-keeps-the-view — a deleted file after an
# untracked one must not kill the diff view
#
# .what = drives `prove.codediff-single-pane-keeps-the-view.probe.lua` against
#         the SHIPPED nvim config, in two arms, and judges three rows:
#           session_after_deleted  — alive on control, dead on old-single-pane
#           session_after_modified — alive on control
#           panes_after_modified   — 2 on control
#
# .why  = codediff closes one pane for a deleted / added / untracked file. two
#         such selects of opposite kinds closed the last diff window, the session
#         was torn down, and no later select opened any diff — silently. fixed by
#         the side_by_side wrapper in init.lua, which restores both panes first
#
# .the write — `rule.forbid.repair-plays` exception 2. the break lives inside a
#   headless nvim over a temp git repo, both gone on exit; the rows land in a
#   per-run temp dir a trap removes
#
# ⚠️ .what it does NOT prove
#   - the <CR> keymap path: the probe calls explorer.on_file_select, the funnel
#     <CR> reaches for a non-image file
#   - the two-revision path (show_deleted_virtual_file / show_added_virtual_file)
#
# usage:
#   rhx play.run --play prove.codediff-single-pane-keeps-the-view
######################################################################
set -uo pipefail

REPO="${GROVE_SRC:-$PWD/src}"
CONFIG="$REPO/grove.provision/4.terminal/4.5.nvim/init.lua"
PROBE="$(dirname "${BASH_SOURCE[0]}")/prove.codediff-single-pane-keeps-the-view.probe.lua"
OUTDIR=""
FAILED=0

cleanup() {
  [[ -n "$OUTDIR" ]] && rm -rf "$OUTDIR"
  echo ""
  if [[ -n "$OUTDIR" && -e "$OUTDIR" ]]; then
    echo "   ✋ the rows dir SURVIVED — $OUTDIR"
  else
    echo "   🧹 restored: no residue"
  fi
}
trap cleanup EXIT

[[ -r "$CONFIG" ]] || { echo "✋ no config at $CONFIG"; exit 1; }
[[ -r "$PROBE" ]] || { echo "✋ no probe at $PROBE"; exit 1; }
command -v nvim >/dev/null || { echo "✋ no nvim on PATH"; exit 1; }
command -v git >/dev/null || { echo "✋ no git on PATH"; exit 1; }

OUTDIR="$(mktemp -d "${TMPDIR:-/tmp}/prove.codediff-single.XXXXXX")"

# judge one row: arm, key, expected value (exact string)
judge() {
  local name="$1" key="$2" want="$3" out="$OUTDIR/$1.out" saw
  saw="$(grep -oP "(^| )$key=\K[^ ]+" "$out" | head -1)"
  if [[ -z "$saw" ]]; then
    echo "   │  💥 no $key row — this arm rendered NO verdict"; FAILED=1; return
  fi
  if [[ "$saw" == "$want" ]]; then
    echo "   │  ✔ $key=$saw"
  else
    echo "   │  ✋ $key=$saw, expected $want"; FAILED=1
  fi
}

arm() {
  local name="$1" out="$OUTDIR/$1.out"
  rhx nvim.test.headless \
    --probe "$PROBE" --config "$CONFIG" \
    --arm "$name" --out "$OUTDIR" --within 120 > /dev/null 2>&1
  if [[ ! -f "$out" ]]; then
    echo "   💥 arm '$name' wrote no result — this row asked NO question"; FAILED=1; return 1
  fi
  echo "   ├─ arm '$name'"
  while IFS= read -r row || [[ -n "$row" ]]; do echo "   │    $row"; done < "$out"
  if grep -q '^world=absent' "$out"; then
    echo "   │  💥 the FIXTURE did not take — this arm measured a world nobody built"; FAILED=1; return 1
  fi
}

echo "🔭 does the diff view survive a deleted file after an untracked one?"
echo ""

arm control && {
  judge control session_after_deleted alive
  judge control session_after_modified alive
  judge control panes_after_modified 2
}
arm old-single-pane && judge old-single-pane session_after_deleted dead

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 the diff view survives single-pane selects, and the clamp is seen to bite"
else
  echo "✋ the contract did NOT hold — read the arms above"
fi
exit "$FAILED"
