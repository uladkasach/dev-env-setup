#!/usr/bin/env bash
######################################################################
# prove.codediff-copy-path — ctrl+alt+r in a codediff tab copies the FILE's
# path, never the buffer label `CodeDiff Explorer [N]`
#
# .what = drives `prove.codediff-copy-path.probe.lua` against the SHIPPED nvim
#         config. criteria: codediff.copy-path
#           control    → file_row dir_row rev_pane plain_buf all hit
#           old-label  → file_row misses: it copies the explorer's label (the defect)
#
# .the write — `rule.forbid.repair-plays` exception 2. a headless nvim over a temp
#   git repo, both gone on exit; rows land in a temp dir a trap removes
#
# usage:
#   rhx play.run --play prove.codediff-copy-path
######################################################################
set -uo pipefail

REPO="${GROVE_SRC:-$PWD/src}"
CONFIG="$REPO/grove.provision/4.terminal/4.5.nvim/init.lua"
PROBE="$(dirname "${BASH_SOURCE[0]}")/prove.codediff-copy-path.probe.lua"
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

OUTDIR="$(mktemp -d "${TMPDIR:-/tmp}/prove.codediff-copy.XXXXXX")"

verdict() { grep -oP "^$2=\K[a-z]+" "$OUTDIR/$1.out" | head -1; }

arm() {
  local name="$1" out="$OUTDIR/$1.out"
  rhx nvim.test.headless --probe "$PROBE" --config "$CONFIG" --arm "$name" --out "$OUTDIR" --within 120 > /dev/null 2>&1
  if [[ ! -f "$out" ]]; then echo "   💥 arm '$name' wrote no result"; FAILED=1; return 1; fi
  echo "   ├─ arm '$name'"
  while IFS= read -r r || [[ -n "$r" ]]; do echo "   │    $r"; done < "$out"
  if grep -q '^world=absent' "$out"; then echo "   │  💥 the FIXTURE did not take"; FAILED=1; return 1; fi
}

echo "🔭 does ctrl+alt+r in a codediff tab copy the file's path?"
echo ""

if arm control; then
  for r in file_row dir_row rev_pane plain_buf; do
    v="$(verdict control "$r")"
    if [[ "$v" == hit ]]; then echo "   │  ✔ $r"; else echo "   │  ✋ $r=${v:-none}"; FAILED=1; fi
  done
fi
if arm old-label; then
  v="$(verdict old-label file_row)"
  if [[ "$v" == miss ]]; then echo "   │  ✔ file_row misses under the old read, so the clamp bites"
  else echo "   │  ✋ file_row=${v:-none} under the old read — this probe cannot see the defect"; FAILED=1; fi
fi

echo ""
if [[ "$FAILED" -eq 0 ]]; then echo "🌲 ctrl+alt+r copies the file's path, and the clamp is seen to bite"
else echo "✋ the contract did NOT hold — read the arms above"; fi
exit "$FAILED"
