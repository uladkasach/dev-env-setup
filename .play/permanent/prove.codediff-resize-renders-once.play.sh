#!/usr/bin/env bash
######################################################################
# prove.codediff-resize-renders-once — a held alt+h/alt+l re-renders the
# codediff explorer ONCE, at the final width, never once per step
#
# .what = drives `prove.codediff-resize-renders-once.probe.lua` against the
#         SHIPPED nvim config, two arms, and judges:
#           renders_per_burst — 1 on control, 5 on old-per-step
#           width_rendered    — equals width_after on control: the one render
#                               landed at the FINAL width
#
# .why  = codediff rendered the whole tree on every resize step: 1101 rows,
#         40-100ms each, 0 rows changed. a held key queued them all
#
# .the write — `rule.forbid.repair-plays` exception 2. a headless nvim over a
#   temp git repo, both gone on exit; rows land in a temp dir a trap removes
#
# ⚠️ .what it does NOT prove
#   - a real terminal fires WinResized on redraw; headless has no UI, so the
#     probe fires the event itself
#
# usage:
#   rhx play.run --play prove.codediff-resize-renders-once
######################################################################
set -uo pipefail

REPO="${GROVE_SRC:-$PWD/src}"
CONFIG="$REPO/grove.provision/4.terminal/4.5.nvim/init.lua"
PROBE="$(dirname "${BASH_SOURCE[0]}")/prove.codediff-resize-renders-once.probe.lua"
OUTDIR=""
FAILED=0

cleanup() {
  [[ -n "$OUTDIR" ]] && rm -rf "$OUTDIR"
  echo ""
  if [[ -n "$OUTDIR" && -e "$OUTDIR" ]]; then echo "   ✋ the rows dir SURVIVED — $OUTDIR"; else echo "   🧹 restored: no residue"; fi
}
trap cleanup EXIT

[[ -r "$CONFIG" ]] || { echo "✋ no config at $CONFIG"; exit 1; }
[[ -r "$PROBE" ]] || { echo "✋ no probe at $PROBE"; exit 1; }
command -v nvim >/dev/null || { echo "✋ no nvim on PATH"; exit 1; }

OUTDIR="$(mktemp -d "${TMPDIR:-/tmp}/prove.codediff-resize.XXXXXX")"

row() { grep -oP "(^| )$2=\K[^ ]+" "$OUTDIR/$1.out" | head -1; }

arm() {
  local name="$1" out="$OUTDIR/$1.out"
  rhx nvim.test.headless --probe "$PROBE" --config "$CONFIG" --arm "$name" --out "$OUTDIR" --within 120 > /dev/null 2>&1
  if [[ ! -f "$out" ]]; then echo "   💥 arm '$name' wrote no result"; FAILED=1; return 1; fi
  echo "   ├─ arm '$name'"
  while IFS= read -r r || [[ -n "$r" ]]; do echo "   │    $r"; done < "$out"
  if grep -q '^world=absent' "$out"; then echo "   │  💥 the FIXTURE did not take"; FAILED=1; return 1; fi
}

echo "🔭 does a held resize render the explorer once, at the final width?"
echo ""

if arm control; then
  n="$(row control renders_per_burst)"; wa="$(row control width_after)"; wr="$(row control width_rendered)"
  if [[ "$n" == 1 ]]; then echo "   │  ✔ renders_per_burst=1"; else echo "   │  ✋ renders_per_burst=${n:-none}, expected 1"; FAILED=1; fi
  if [[ -n "$wa" && "$wa" == "$wr" ]]; then echo "   │  ✔ rendered at the final width ($wr)"; else echo "   │  ✋ rendered at width ${wr:-none}, final width ${wa:-none}"; FAILED=1; fi
fi
if arm old-per-step; then
  n="$(row old-per-step renders_per_burst)"
  if [[ "$n" == 5 ]]; then echo "   │  ✔ renders_per_burst=5 — the old behavior is visible, so the clamp bites"
  else echo "   │  ✋ renders_per_burst=${n:-none}, expected 5 — this probe cannot see the defect"; FAILED=1; fi
fi

echo ""
if [[ "$FAILED" -eq 0 ]]; then echo "🌲 a resize burst renders the explorer once, and the clamp is seen to bite"
else echo "✋ the contract did NOT hold — read the arms above"; fi
exit "$FAILED"
