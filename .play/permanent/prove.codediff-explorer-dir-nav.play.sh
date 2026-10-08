#!/usr/bin/env bash
######################################################################
# prove.codediff-explorer-dir-nav — ctrl+d j/k in the codediff explorer
# walks DIRECTORY edges: bottom, next top, previous bottom, top, and wrap
#
# .what = drives `prove.codediff-explorer-dir-nav.probe.lua` against the SHIPPED
#         nvim config. criteria: diff.boundary.nav, usecase.5
#           control     → j_bot j_next k_prev k_top j_wrap all hit
#           old-chunks  → j_bot misses: the diff-chunk reader sees no chunk in
#                         the tree, so the cursor does not move (the defect)
#
# .the write — `rule.forbid.repair-plays` exception 2. a headless nvim over a temp
#   git repo, both gone on exit; rows land in a temp dir a trap removes
#
# usage:
#   rhx play.run --play prove.codediff-explorer-dir-nav
######################################################################
set -uo pipefail

REPO="${GROVE_SRC:-$PWD/src}"
CONFIG="$REPO/grove.provision/4.terminal/4.5.nvim/init.lua"
PROBE="$(dirname "${BASH_SOURCE[0]}")/prove.codediff-explorer-dir-nav.probe.lua"
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

OUTDIR="$(mktemp -d "${TMPDIR:-/tmp}/prove.codediff-dirnav.XXXXXX")"

verdict() { grep -oP "^$2=\K[a-z]+" "$OUTDIR/$1.out" | head -1; }

arm() {
  local name="$1" out="$OUTDIR/$1.out"
  rhx nvim.test.headless --probe "$PROBE" --config "$CONFIG" --arm "$name" --out "$OUTDIR" --within 120 > /dev/null 2>&1
  if [[ ! -f "$out" ]]; then echo "   💥 arm '$name' wrote no result"; FAILED=1; return 1; fi
  echo "   ├─ arm '$name'"
  while IFS= read -r r || [[ -n "$r" ]]; do echo "   │    $r"; done < "$out"
  if grep -q '^world=absent' "$out"; then echo "   │  💥 the FIXTURE did not take"; FAILED=1; return 1; fi
}

echo "🔭 does ctrl+d j/k walk directory edges in the codediff explorer?"
echo ""

if arm control; then
  for p in j_bot j_next k_prev k_top j_wrap; do
    v="$(verdict control "$p")"
    if [[ "$v" == hit ]]; then echo "   │  ✔ $p"; else echo "   │  ✋ $p=${v:-none}"; FAILED=1; fi
  done
fi
if arm old-chunks; then
  v="$(verdict old-chunks j_bot)"
  if [[ "$v" == miss ]]; then echo "   │  ✔ j_bot misses under the old reader, so the clamp bites"
  else echo "   │  ✋ j_bot=${v:-none} under the old reader — this probe cannot see the defect"; FAILED=1; fi
fi

echo ""
if [[ "$FAILED" -eq 0 ]]; then echo "🌲 ctrl+d j/k walks directory edges, and the clamp is seen to bite"
else echo "✋ the contract did NOT hold — read the arms above"; fi
exit "$FAILED"
