#!/usr/bin/env bash
######################################################################
# prove.codediff-line-pct — each codediff explorer file row shows the
# share of its lines the diff touched, and that % costs naught on an
# idle refresh
#
# .what = drives `prove.codediff-line-pct.probe.lua` against the SHIPPED
#         nvim config, three arms, and judges these rows:
#           expect_ok          — 6/6 on control: each fixture row shows the
#                                % the table in the probe header pins,
#                                the staged row read from the INDEX side
#           noop_numstats      — 0 on control: no change, no git ask
#           noop_reads         — 0 on control: no change, no file read
#           edit_numstats      — 1 on control: one file edited, one ask
#           edit_numstat_paths — that ask names mod.txt alone
#           edit_reads         — 1 on control: that file alone re-read
#           edit_rows_moved    — 1 on control: that row alone moved
#           mod_after          — 25% on control
#
# .why  = the % is git numstat + a line count per file. per refresh over
#         every file it would undo the quiet the explorer was tuned to at
#         ~1k diffs (prove.codediff-refresh-stays-quiet), so it is cached
#         per file on its work-tree stat, and the cache is what this proves
#
# .the arms — each old-* arm re-breaks one piece, so a green control arm
#   is proven to come from it rather than from a blind counter
#
#   control       as shipped              → the rows above
#   old-no-cache  cache wiped per refresh → noop_numstats > 0, noop_reads > 0
#   old-off       the % switched off      → pct_rows = 0
#
#   ⚠️ an old-* arm that reads like control is a defect in THIS play:
#      its counter cannot see the break it exists to catch (term=bite)
#
# .the write — `rule.forbid.repair-plays` exception 2. the break lives
#   inside a headless nvim over a temp git repo, both gone on exit; the
#   rows land in a per-run temp dir a trap removes
#
# ⚠️ .what it does NOT prove
#   - the look: the % is dim (CodeDiffLinePct → Comment); headless paints
#     no screen, so the hl is read by no row here
#   - since-main mode: the same pass with the base revision as the diff's
#     other side; this fixture opens status mode only
#
# usage:
#   rhx play.run --play prove.codediff-line-pct
######################################################################
set -uo pipefail

REPO="${GROVE_SRC:-$PWD/src}"
CONFIG="$REPO/grove.provision/4.terminal/4.5.nvim/init.lua"
PROBE="$(dirname "${BASH_SOURCE[0]}")/prove.codediff-line-pct.probe.lua"
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

# refuse a subject we would have to invent
[[ -r "$CONFIG" ]] || { echo "✋ no config at $CONFIG"; exit 1; }
[[ -r "$PROBE" ]] || { echo "✋ no probe at $PROBE — this play restates no part of it"; exit 1; }
command -v nvim >/dev/null || { echo "✋ no nvim on PATH"; exit 1; }
command -v git >/dev/null || { echo "✋ no git on PATH"; exit 1; }

OUTDIR="$(mktemp -d "${TMPDIR:-/tmp}/prove.codediff-line-pct.XXXXXX")"

# the value of one key off an arm's rows; a key may lead its row or follow a space
saw_of() { grep -oP "(^| )$2=\K[^ ]+" "$OUTDIR/$1.out" | head -1; }

# judge one row: arm, key, comparator (eq|gt|is), want
judge() {
  local name="$1" key="$2" cmp="$3" want="$4" saw
  saw="$(saw_of "$name" "$key")"
  if [[ -z "$saw" ]]; then
    echo "   │  💥 no $key row — this arm rendered NO verdict"
    FAILED=1
    return
  fi
  if { [[ "$cmp" == is ]] && [[ "$saw" == "$want" ]]; } \
    || { [[ "$cmp" == eq ]] && [[ "$saw" =~ ^[0-9]+$ ]] && (( saw == want )); } \
    || { [[ "$cmp" == gt ]] && [[ "$saw" =~ ^[0-9]+$ ]] && (( saw > want )); }; then
    echo "   │  ✔ $key=$saw ($cmp $want)"
  else
    echo "   │  ✋ $key=$saw, expected $cmp $want"
    FAILED=1
  fi
}

arm() {
  local name="$1" out="$OUTDIR/$1.out"
  rhx nvim.test.headless \
    --probe "$PROBE" --config "$CONFIG" \
    --arm "$name" --out "$OUTDIR" --within 120 > /dev/null 2>&1

  if [[ ! -f "$out" ]]; then
    echo "   💥 arm '$name' wrote no result — this row asked NO question"
    FAILED=1
    return 1
  fi
  echo "   ├─ arm '$name'"
  while IFS= read -r row || [[ -n "$row" ]]; do echo "   │    $row"; done < "$out"
  if grep -q '^world=absent' "$out"; then
    echo "   │  💥 the FIXTURE did not take — this arm measured a world nobody built"
    FAILED=1
    return 1
  fi
}

echo "🔭 does each codediff file row show its line-change %, at no cost when idle?"
echo ""

arm control && {
  judge control expect_ok is 6/6
  judge control noop_numstats eq 0
  judge control noop_reads eq 0
  judge control edit_numstats eq 1
  judge control edit_numstat_paths is mod.txt
  judge control edit_reads eq 1
  judge control edit_rows_moved eq 1
  judge control mod_after is 25%
}
arm old-no-cache && { judge old-no-cache noop_numstats gt 0; judge old-no-cache noop_reads gt 0; }
arm old-off      && judge old-off pct_rows eq 0

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 every row shows its %, and the cache is proven to be what keeps it quiet"
else
  echo "✋ the contract did NOT hold — read the arms above"
fi
exit "$FAILED"
