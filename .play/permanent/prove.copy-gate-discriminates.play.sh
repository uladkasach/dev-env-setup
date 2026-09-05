#!/usr/bin/env bash
######################################################################
# .what = drive the EXACT bytes kitty emits at a real tmux client, and
#         watch the copy gate fire on nvim and stay shut on a shell
#
# .why  = `tmux list-keys` proves the bind is DECLARED and says none of
#         whether it fires. a check seen green in one direction only is
#         half proven (gotcha.a-check-that-cries-wolf-gets-silenced).
#
# .the shape — why it nests two tmux servers
#   - a root key table is consulted for input from an attached CLIENT
#   - `tmux send-keys` writes to a PANE and consults no table at all
#   - ⇒ so a bare send-keys can NEVER exercise the bind under test
#   - the probe server (-L copygate) holds the gate; a pane in the duct's
#     own server runs `attach` to it, and `send-keys -H` writes the raw
#     CSI bytes into that pane's pty — which IS the probe client's stdin
#   - -H writes bytes, so the OUTER server's own bind cannot eat them
#
# .it writes a scratch tmux server + 3 temp files, and a trap removes
#   every one. net zero on the box.
######################################################################
set -uo pipefail

SOCK=copygate
HIT="$HOME/.copygate.hit"
INIT="$HOME/.copygate.init.lua"
DOC="$HOME/.copygate.txt"
OUTER=copygate-outer
FAILED=0

cleanup() {
  tmux -L "$SOCK" kill-server 2>/dev/null
  tmux kill-session -t "$OUTER" 2>/dev/null
  rm -f "$HIT" "$INIT" "$DOC"
  echo ""
  echo "   🧹 restored: probe server down, temp files removed"
  ls "$HIT" "$INIT" "$DOC" 2>/dev/null && echo "   ✋ a temp file SURVIVED" || echo "   ✔ no residue"
}
trap cleanup EXIT

# 🛑 refuse a subject we would have to invent (rule.forbid.repair-plays, cond. 2)
[[ -f "$HOME/.tmux.conf" ]] || { echo "✋ no ~/.tmux.conf — the gate is not on this box"; exit 1; }
grep -q 'C-S-c' "$HOME/.tmux.conf" || { echo "✋ ~/.tmux.conf declares no C-S-c bind"; exit 1; }

cat > "$INIT" <<'LUA'
-- the ONE claim under test: does <C-S-c> ARRIVE?
-- so the map writes a marker rather than a yank — a headless box has no
-- clipboard provider, and "+y would fail for a reason unrelated to the gate
vim.opt.compatible = false
vim.keymap.set({ 'n', 'v', 'i' }, '<C-S-c>', function()
  vim.fn.writefile({ 'HIT' }, os.getenv('HOME') .. '/.copygate.hit')
end)
LUA
echo "copygate probe" > "$DOC"

arm() {
  local name="$1" cmd="$2" want="$3" saw
  rm -f "$HIT"
  tmux -L "$SOCK" kill-server 2>/dev/null
  tmux kill-session -t "$OUTER" 2>/dev/null
  sleep 0.4

  # the probe server, which holds the gate under test
  TERM=xterm-kitty tmux -L "$SOCK" new-session -d -s inner -x 100 -y 30 "$cmd"
  tmux -L "$SOCK" source-file "$HOME/.tmux.conf" 2>/dev/null
  sleep 2.5

  # a client attaches to it, from a pane in the duct's own server
  tmux new-session -d -s "$OUTER" -x 100 -y 30 \
    "TERM=xterm-kitty tmux -L $SOCK attach -t inner"
  sleep 2.0

  local ran; ran="$(tmux -L "$SOCK" display -p -t inner '#{pane_current_command}' 2>/dev/null)"

  # ESC [ 9 9 ; 6 u — byte for byte what copy_notify.py writes
  tmux send-keys -t "$OUTER" -H 1b 5b 39 39 3b 36 75
  sleep 1.5

  [[ -f "$HIT" ]] && saw=arrived || saw=swallowed
  if [[ "$saw" == "$want" ]]; then
    echo "   ✔ $name — pane ran '$ran', key $saw (as declared)"
  else
    echo "   ✋ $name — pane ran '$ran', key $saw, expected $want"
    FAILED=1
  fi
}

echo "🔭 does the copy gate DISCRIMINATE?"
echo ""
echo "   the byte driven: ESC [ 9 9 ; 6 u   (CSI 99;6u = <C-S-c>)"
echo ""

arm "nvim in the pane      → the gate must PASS it" \
  "nvim -u $INIT $DOC" arrived

arm "a bare shell in the pane → the gate must SWALLOW it" \
  "bash --norc -i" swallowed

echo ""
[[ "$FAILED" -eq 0 ]] \
  && echo "🌲 the gate discriminates: it opens for nvim and shuts for a shell" \
  || echo "✋ the gate did NOT discriminate — read the arms above"
exit "$FAILED"
