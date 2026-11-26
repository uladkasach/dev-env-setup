#!/usr/bin/env bash
######################################################################
# prove.image-zoom-widens — ctrl+= on a TALL image diff widens the picture
# until it fills the pane, the way an image viewer zooms
#
# .what = drives `prove.image-zoom-widens.probe.lua` against the SHIPPED nvim
#         config: a 260x1173 page in a codediff image diff, zoomed 1x → 8x.
#         then pans it with j and the mouse wheel.
#         owes: widens, never_shrinks, within_pane, fills_width,
#               pan_keys_move, pan_wheel_moves, pan_sends_none (a pan inside the
#               band sends no picture), pan_long_reaches_end + pan_long_few_sends
#
# .why  = 📜 2026-10-26, a 1300x5865 invoice on a grove duct: every zoom step
#         painted the same ~30-cell column, because the crop kept the image's
#         own shape. zoom had no play, so it broke twice without a signal.
#         📜 same day: each j re-sent the whole png over ssh (a slow load per
#         keypress), and the wheel did naught
#
# .the write — `rule.forbid.repair-plays` exception 2. a headless nvim over a temp
#   git repo, both gone on exit; rows land in a temp dir a trap removes
#
# usage:
#   rhx play.run --play prove.image-zoom-widens
#   CONFIG=<other init.lua> rhx play.run --play prove.image-zoom-widens   # the clamp's bite
######################################################################
set -uo pipefail

# the checkout: this play's own tree, else the shell's, else a grove's pushed .wip tree
_self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || _self=""
if   [[ -n "$_self" && -f "$_self/src/grove.provision._.sh" ]];          then _root="$_self"
elif [[ -f "$PWD/src/grove.provision._.sh" ]];                           then _root="$PWD"
elif [[ -f "$HOME/git/more/dev-env-setup.wip/src/grove.provision._.sh" ]]; then _root="$HOME/git/more/dev-env-setup.wip"
else                                                                         _root="$HOME/git/more/dev-env-setup"
fi
CONFIG="${CONFIG:-$_root/src/grove.provision/4.terminal/4.5.nvim/init.lua}"
PROBE="$_root/.play/permanent/prove.image-zoom-widens.probe.lua"
headless() { bash "$_root/.agent/repo=.this/role=any/skills/nvim.test.headless.sh" "$@"; }
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

OUTDIR="$(mktemp -d "${TMPDIR:-/tmp}/prove.image-zoom.XXXXXX")"
out="$OUTDIR/control.out"

echo "🔭 does ctrl+= widen a tall image diff until it fills the pane?"
echo ""

headless --probe "$PROBE" --config "$CONFIG" --arm control --out "$OUTDIR" --within 180 > "$OUTDIR/control.log" 2>&1
if [[ ! -f "$out" ]]; then
  echo "   💥 the probe wrote no result — the runner said:"
  tail -n 12 "$OUTDIR/control.log" | while IFS= read -r l; do echo "   │    $l"; done
  exit 1
fi
while IFS= read -r r || [[ -n "$r" ]]; do echo "   │    $r"; done < "$out"
if grep -q '^world=absent' "$out"; then echo "   │  💥 the FIXTURE did not take"; exit 1; fi

for r in widens never_shrinks within_pane fills_width zoom_steps_send_none pan_keys_move pan_wheel_moves pan_sends_none pan_long_reaches_end pan_long_few_sends jump_gg_top jump_G_bottom jump_then_pan; do
  v="$(grep -oP "^$r=\K[a-z]+" "$out" | head -1)"
  if [[ "$v" == hit ]]; then echo "   │  ✔ $r"; else echo "   │  ✋ $r=${v:-none}"; FAILED=1; fi
done

echo ""
if [[ "$FAILED" -eq 0 ]]; then echo "🌲 a tall image diff widens with each zoom step until it fills the pane"
else echo "✋ the contract did NOT hold — read the rows above"; fi
exit "$FAILED"
