#!/usr/bin/env bash
######################################################################
# prove.codediff-refresh-stays-quiet — the explorer must not refresh
# itself while idle, and must rewrite only the rows that changed
#
# .what = drives `prove.codediff-refresh-stays-quiet.probe.lua` against
#         the SHIPPED nvim config, five arms, and judges seven rows:
#           idle_refreshes          — 0 on control
#           builds_per_noop_refresh — 0 on control: a refresh that finds no
#                                     change builds no tree
#           rows_per_noop_refresh   — 0 on control
#           rows_per_noop_rebuild   — 0 on control: forced to rebuild, it
#                                     still rewrites no row (the row diff)
#           rows_per_select         — 2 on control (old highlight + new)
#           rows_match_upstream     — > 0 rows compared on control
#           mismatches              — 0 on control: every row the shipped
#                                     prepare_node builds equals upstream's
#
# .why  = at ~1k changed files <C-g> froze the editor. two causes,
#         both measured (howto.tune-nvim-at-scale):
#           - `git status` took `.git/index.lock`, codediff's `.git/`
#             watcher woke on it, and ran `git status` again: a self-fed
#             refresh loop. fixed by `GIT_OPTIONAL_LOCKS=0` in init.lua
#           - codediff rewrote every row on every render, and a select
#             renders just to move the highlight. fixed by the row diff
#             render (`render_rows`) + the `prepare_node` memo in init.lua
#           - codediff refreshes on each BufEnter of the explorer and rebuilt
#             the tree for an unchanged file list: 160ms build + 123ms render
#             at 6,475 files. fixed by the no-change short-circuit in the
#             `refresh_mod.refresh` wrapper in init.lua
#         and the speed path itself is a place to render a WRONG row: the
#         tree-view basename proxy, the own `selected` decision, the memo.
#         so every row is compared against upstream's prepare_node
#
# .the arms — each old-* arm re-breaks one fix, so a green control arm
#   is proven to come from the fix rather than from a blind counter
#
#   control          as shipped                 → idle 0, noop builds 0, noop rows 0,
#                                                 rebuild rows 0, select 2, mismatches 0
#   old-locks        GIT_OPTIONAL_LOCKS unset   → idle > 0
#   old-noop-rebuild no-change short-circuit off → noop builds > 0
#   old-full-render  row cache dropped per call → rebuild rows > 0, select > 2
#   old-wrong-row    file rows' first hl bent   → mismatches > 0
#
#   ⚠️ an old-* arm that reads like control is a defect in THIS play:
#      its counter cannot see the break it exists to catch (term=bite)
#
# .the write — `rule.forbid.repair-plays` exception 2. the break lives
#   inside a headless nvim over a temp git repo, both gone on exit; the
#   rows land in a per-run temp dir a trap removes
#
# ⚠️ .what it does NOT prove
#   - redraw cost in a real terminal. headless nvim paints no screen
#   - select latency: `select_ms` is reported, never judged; at 200 files
#     it sits in run-to-run noise, so rows written is the stable signal
#   - collapse survival: reported, gates no arm — see the probe header
#
# usage:
#   rhx play.run --play prove.codediff-refresh-stays-quiet
######################################################################
set -uo pipefail

REPO="${GROVE_SRC:-$PWD/src}"
CONFIG="$REPO/grove.provision/4.terminal/4.5.nvim/init.lua"
PROBE="$(dirname "${BASH_SOURCE[0]}")/prove.codediff-refresh-stays-quiet.probe.lua"
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
grep -q "GIT_OPTIONAL_LOCKS = '0'" "$CONFIG" || {
  echo "✋ $CONFIG does not set GIT_OPTIONAL_LOCKS=0"
  echo "   ⇒ the fix under test is absent; control will read the loop"
}
command -v nvim >/dev/null || { echo "✋ no nvim on PATH"; exit 1; }
command -v git >/dev/null || { echo "✋ no git on PATH"; exit 1; }

OUTDIR="$(mktemp -d "${TMPDIR:-/tmp}/prove.codediff-quiet.XXXXXX")"

# judge one row: arm, key, comparator (eq|gt), want
judge() {
  local name="$1" key="$2" cmp="$3" want="$4" out="$OUTDIR/$1.out" saw
  # a key may lead its row or follow a space on it (`... mismatches=3 ...`)
  saw="$(grep -oP "(^| )$key=\K[0-9]+" "$out" | head -1)"
  if [[ -z "$saw" ]]; then
    echo "   │  💥 no $key row — this arm rendered NO verdict"
    FAILED=1
    return
  fi
  if { [[ "$cmp" == eq ]] && (( saw == want )); } || { [[ "$cmp" == gt ]] && (( saw > want )); }; then
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

echo "🔭 does the codediff explorer stay quiet when idle, and render once per refresh?"
echo ""

arm control         && {
  judge control idle_refreshes eq 0
  judge control builds_per_noop_refresh eq 0
  judge control rows_per_noop_refresh eq 0
  judge control rows_per_noop_rebuild eq 0
  judge control rows_per_select eq 2
  judge control rows_match_upstream gt 0
  judge control mismatches eq 0
}
arm old-locks        && judge old-locks idle_refreshes gt 0
arm old-noop-rebuild && judge old-noop-rebuild builds_per_noop_refresh gt 0
arm old-full-render  && { judge old-full-render rows_per_noop_rebuild gt 0; judge old-full-render rows_per_select gt 2; }
arm old-wrong-row   && judge old-wrong-row mismatches gt 0

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "🌲 the explorer stays quiet, and each fix is proven to be what holds it"
else
  echo "✋ the contract did NOT hold — read the arms above"
fi
exit "$FAILED"
