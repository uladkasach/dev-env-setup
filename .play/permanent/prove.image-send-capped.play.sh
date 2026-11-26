#!/usr/bin/env bash
######################################################################
# prove.image-send-capped — over ssh, a photo crosses the wire within a pixel
# budget, and kitty stretches it over the same cells
#
# .what = drives `prove.image-send-capped.probe.lua` against the SHIPPED nvim
#         config, once per arm
#           remote → capped, rect_matches_png, fills_pane, aspect all hit
#           local  → capped misses: a window-sized png, as shipped. that is the
#                    defect shape, so the clamp is seen to bite
#         and prints the bytes each arm would send
#
# .the write — `rule.forbid.repair-plays` exception 2. a headless nvim and a temp
#   photo, both gone on exit; rows land in a temp dir a trap removes
#
# usage:
#   rhx play.run --play prove.image-send-capped
######################################################################
set -uo pipefail

# the checkout: this play's own tree, else the shell's, else a grove's pushed .wip tree.
# a grove send lands the play ALONE in ~/.local/state/grove.play, so the probe beside
# it is read from the checkout too (the order of prove.every-bundle-is-dispatched)
_self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || _self=""
if   [[ -n "${GROVE_SRC:-}" ]];                                          then _root="$(dirname "$GROVE_SRC")"
elif [[ -n "$_self" && -f "$_self/src/grove.provision._.sh" ]];          then _root="$_self"
elif [[ -f "$PWD/src/grove.provision._.sh" ]];                           then _root="$PWD"
elif [[ -f "$HOME/git/more/dev-env-setup.wip/src/grove.provision._.sh" ]]; then _root="$HOME/git/more/dev-env-setup.wip"
else                                                                         _root="$HOME/git/more/dev-env-setup"
fi
CONFIG="$_root/src/grove.provision/4.terminal/4.5.nvim/init.lua"
PROBE="$_root/.play/permanent/prove.image-send-capped.probe.lua"
# the skill by path: a grove seat runs this from ~, where rhx links no role of this repo
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

OUTDIR="$(mktemp -d "${TMPDIR:-/tmp}/prove.image-send.XXXXXX")"

verdict() { [[ -f "$OUTDIR/$1.out" ]] && grep -oP "^$2=\K[a-z0-9x]+" "$OUTDIR/$1.out" | head -1; }

# the arm's ssh env is the variable under test, so each arm runs in its own env
arm() {
  local name="$1" out="$OUTDIR/$1.out"
  if [[ "$name" == remote ]]; then
    SSH_TTY=/dev/pts/0 headless --probe "$PROBE" --config "$CONFIG" --arm "$name" --out "$OUTDIR" --within 180 > "$OUTDIR/$name.log" 2>&1
  else
    ( unset SSH_TTY SSH_CLIENT SSH_CONNECTION
      headless --probe "$PROBE" --config "$CONFIG" --arm "$name" --out "$OUTDIR" --within 180 > "$OUTDIR/$name.log" 2>&1 )
  fi
  if [[ ! -f "$out" ]]; then
    echo "   💥 arm '$name' wrote no result — the runner said:"
    tail -n 12 "$OUTDIR/$name.log" | while IFS= read -r l; do echo "   │    $l"; done
    FAILED=1; return 1
  fi
  echo "   ├─ arm '$name'"
  while IFS= read -r r || [[ -n "$r" ]]; do echo "   │    $r"; done < "$out"
  if grep -q '^world=absent' "$out"; then echo "   │  💥 the FIXTURE did not take"; FAILED=1; return 1; fi
}

echo "🔭 over ssh, does a photo cross the wire within its pixel budget?"
echo ""

if arm remote; then
  for r in capped rect_matches_png fills_pane aspect; do
    v="$(verdict remote "$r")"
    if [[ "$v" == hit ]]; then echo "   │  ✔ $r"; else echo "   │  ✋ $r=${v:-none}"; FAILED=1; fi
  done
fi
if arm local; then
  v="$(verdict local capped)"
  if [[ "$v" == miss ]]; then echo "   │  ✔ local sends the window-sized png, so the clamp bites"
  else echo "   │  ✋ capped=${v:-none} on a local box — this probe cannot see the defect"; FAILED=1; fi
  for r in fills_pane aspect; do
    v="$(verdict local "$r")"
    if [[ "$v" == hit ]]; then echo "   │  ✔ $r"; else echo "   │  ✋ $r=${v:-none}"; FAILED=1; fi
  done
fi

rb="$(verdict remote sent_bytes)"; lb="$(verdict local sent_bytes)"
if [[ -n "$rb" && -n "$lb" && "$rb" -gt 0 ]]; then
  echo "   │"
  echo "   └─ bytes per send: $lb shipped → $rb capped ($(( lb / rb ))x fewer, before base64)"
fi

echo ""
if [[ "$FAILED" -eq 0 ]]; then echo "🌲 over ssh a photo is sent within budget and fills its cells; the clamp is seen to bite"
else echo "✋ the contract did NOT hold — read the arms above"; fi
exit "$FAILED"
