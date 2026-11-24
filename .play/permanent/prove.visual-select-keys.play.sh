#!/usr/bin/env bash
######################################################################
# .what = drive the EXACT bytes kitty emits for the super+v gesture, in every
#         holder, and read back what each press did:
#           1. tmux: super+v opens the nvim view in a popup over the pane
#           2. tmux copy-mode, however entered: the same keys
#           3. the nvim setup itself, headless, against the real init.lua
#           4. kitty with no tmux: the nvim overlay, in a real scratch kitty
#
# .why  = `tmux list-keys` proves a bind is DECLARED and says none of
#         whether it fires. the gesture is a chain — open, move, select, copy,
#         end, leave — and each link can drop the press with no error
#
# .the shape — two tmux servers, as prove.copy-gate-discriminates
#   - a key table is consulted for input from a CLIENT; `tmux send-keys`
#     writes to a PANE and consults no table
#   - ⇒ the probe server (-L visualsel) holds the binds; a pane in a second
#     scratch server (-L visualsel-outer) runs `attach` to it, and
#     `send-keys -H` writes raw bytes into that pane's pty — the probe
#     client's stdin. the outer pane's screen is what the human would see
#
# .the bytes, each one what kitty sends for the human's press
#   - super+v        1b 5b 39 39 39 39 7e   CSI 9999 ~  (visual_select.py)
#   - super+v again  1c 0e 3a 71 61 21 0d   ^\ ^N :qa!  (visual_select.py, popup open)
#   - right-alt+j/k  1b 5b 42 / 1b 5b 41    Down / Up   (keyd vimarrows)
#   - shift+v, j, q  56 / 6a / 71
#   - enter          0d
#   - ctrl+c         1b 5b 39 39 3b 36 75   CSI 99;6u   (copy_notify.py)
#   - ctrl+x         03                     ^C          (kitty.conf)
#   - escape         1b                     ESC, alone  (read after escape-time)
#
# 🛑 the human's clipboard is never touched
#   - the probe server starts with NO display in its env, so its nvim has no
#     clipboard provider and copies by OSC 52 — the path a grove takes
#   - an OSC 52 write lands at the probe's client terminal: the outer pane, on
#     a scratch server with no client of its own. there it stops, as a buffer
#     ⇒ which is also how the play SEES a copy leave tmux toward the desktop
#
# .it writes two scratch tmux servers, a scratch kitty, and temp files; a trap
#   and the stages remove each. net zero on the box, the clipboard included.
######################################################################
set -uo pipefail

SOCK=visualsel
OUTER_SOCK=visualsel-outer
OUTER=outer
FAILED=0
HERE="$(cd "$(dirname "$0")" && pwd)"

cleanup() {
  tmux -L "$SOCK" kill-server 2>/dev/null
  tmux -L "$OUTER_SOCK" kill-server 2>/dev/null
  tmux -L visualsel-kitty kill-server 2>/dev/null
  echo ""
  echo "   🧹 restored: every scratch server down"
}
trap cleanup EXIT

# 🛑 refuse a subject we would have to invent (rule.forbid.repair-plays, cond. 2)
[[ -f "$HOME/.tmux.conf" ]] || { echo "✋ no ~/.tmux.conf — the binds are not on this box"; exit 1; }
grep -q 'user-keys\[0\]' "$HOME/.tmux.conf" || { echo "✋ ~/.tmux.conf declares no user-keys[0] — apply 2.8.tmux first"; exit 1; }
[[ -f "$HOME/.config/nvim/visual_select.lua" ]] || { echo "✋ no ~/.config/nvim/visual_select.lua — apply 4.5.nvim first"; exit 1; }

press() { tmux -L "$OUTER_SOCK" send-keys -t "$OUTER" -H "$@"; sleep 0.6; }
state() { tmux -L "$SOCK" display -p -t inner "$1" 2>/dev/null; }
screen() { tmux -L "$OUTER_SOCK" capture-pane -p -t "$OUTER" | sed 's/[[:space:]]*$//'; }
buffer_of() { tmux -L "$1" show-buffer 2>/dev/null | tr '\n' ' ' | sed 's/ *$//'; }
# the nvim view is open while its status line (lualine's mode word) is drawn
view_open() { screen | grep -qE '^ (normal|v-line|visual) '; }
# a screen row that reads EXACTLY $1: no gutter left of it, no minimap right
row_bare() { screen | grep -qx "$1"; }

await_view() {
  local want="$1"
  for _ in $(seq 1 30); do
    if [[ "$want" == open ]] && view_open; then return 0; fi
    if [[ "$want" == closed ]] && ! view_open; then return 0; fi
    sleep 0.3
  done
  return 1
}

check() {
  local name="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    echo "   ✔ $name"
  else
    echo "   ✋ $name — got '$got', expected '$want'"
    FAILED=1
  fi
}

# the probe server: 200 numbered lines (past one 30-row screen), then a quiet shell
#   - no WAYLAND_DISPLAY / DISPLAY: its nvim then has no clipboard provider
tmux -L "$SOCK" kill-server 2>/dev/null
tmux -L "$OUTER_SOCK" kill-server 2>/dev/null
sleep 0.4
env -u WAYLAND_DISPLAY -u DISPLAY TERM=xterm-kitty tmux -L "$SOCK" -f "$HOME/.tmux.conf" \
  new-session -d -s inner -x 100 -y 30 \
  "bash --norc -c 'seq 1 200; PS1=\"\$ \" exec bash --norc -i'"
sleep 2.0
tmux -L "$SOCK" delete-buffer 2>/dev/null

# a client attaches to it, from a pane in a second scratch server that loads
# the same conf — so its `set-clipboard on` accepts the probe's OSC 52
env -u WAYLAND_DISPLAY -u DISPLAY TERM=xterm-kitty tmux -L "$OUTER_SOCK" -f "$HOME/.tmux.conf" \
  new-session -d -s "$OUTER" -x 100 -y 30 \
  "TERM=xterm-kitty tmux -L $SOCK attach -t inner"
sleep 2.0
tmux -L "$OUTER_SOCK" delete-buffer 2>/dev/null

######################################################################
echo "🔭 in tmux, does super+v open the nvim view over the pane's FULL history?"
echo ""

press 1b 5b 39 39 39 39 7e
await_view open; check "super+v opens the nvim view"        "$(view_open && echo open)" "open"
if ! view_open; then
  # what a human needs to read the miss: the bind tmux holds, and what it drew
  echo "      · bind: $(tmux -L "$SOCK" list-keys -T root User0 2>&1 | head -2)"
  echo "      · tmux $(tmux -L "$SOCK" display -p '#{version}')"
  echo "      · screen tail: $(screen | grep -v '^$' | tail -3 | tr '\n' '|')"
  # a bind's command error flashes on the status line once; the log keeps it
  echo "      · tmux log: $(tmux -L "$SOCK" show-messages 2>&1 | tail -3 | tr '\n' '|')"
  echo "      · sizes: $(tmux -L "$SOCK" display -p -t inner 'pane=#{pane_width}x#{pane_height} client=#{client_width}x#{client_height}')"
fi
check "the view shows the history, bare"                    "$(row_bare 200 && echo bare)" "bare"

press 67 67
check "the view reaches the first line (gg)"                "$(row_bare 1 && echo reached)" "reached"

# plain vim: shift+v selects, j extends, ctrl+c copies and ends the selection
press 56
press 6a
press 1b 5b 39 39 3b 36 75
check "ctrl+c sent the copy to the terminal (OSC 52)"       "$(buffer_of "$OUTER_SOCK")" "1 2"
[[ "$(buffer_of "$OUTER_SOCK")" == "1 2" ]] || echo "      · the view after ctrl+c: $(screen | grep -v '^$' | tail -2 | tr '\n' '|')"
check "ctrl+c ends the selection, as y does"                "$(screen | grep -qE '^ normal ' && echo ended)" "ended"

press 3a 71 61 21 0d
await_view closed; check ":qa! leaves the view"             "$(view_open && echo open || echo closed)" "closed"

# super+v AGAIN closes it through kitty (tmux runs no bind while a popup is
# open): the kitten types ctrl+\ ctrl+n :qa! — driven here from a selection,
# the reach to the popup itself is proven in the real-kitty stage below
press 1b 5b 39 39 39 39 7e; await_view open
press 56
press 1c 0e 3a 71 61 21 0d
await_view closed; check "kitty's quit keys leave from a selection" "$(view_open && echo open || echo closed)" "closed"

######################################################################
# copy-mode keeps tmux's stock vi keys, plus ctrl+c / ctrl+x / super+v,
# however it is entered: the wheel, ctrl+right-alt+k, or super+v on tmux < 3.3
echo ""
echo "🔭 does tmux copy-mode hold its stock keys, plus ctrl+c?"
echo ""
tmux -L "$SOCK" delete-buffer 2>/dev/null
tmux -L "$OUTER_SOCK" delete-buffer 2>/dev/null
enter_copy_mode() { tmux -L "$SOCK" copy-mode -t inner; sleep 0.4; }

enter_copy_mode
check "copy-mode entered"                   "$(state '#{pane_in_mode}:#{pane_mode}')" "1:copy-mode"

press 1b 5b 41
press 1b 5b 41
check "right-alt+k moves, with no selection" "$(state '#{selection_present}')" "0"

press 56
check "shift+v begins a selection"          "$(state '#{selection_present}')" "1"

press 1b 5b 41
press 1b 5b 39 39 3b 36 75
check "ctrl+c keeps copy-mode"              "$(state '#{pane_in_mode}')" "1"
check "ctrl+c keeps the selection"          "$(state '#{selection_present}')" "1"
check "ctrl+c copied the two lines"         "$(buffer_of "$SOCK")" "198 199"
check "ctrl+c sent the copy to the terminal" "$(buffer_of "$OUTER_SOCK")" "198 199"

press 1b
check "escape clears the selection (stock)" "$(state '#{pane_in_mode}:#{selection_present}')" "1:0"

press 56
press 0d
check "enter copies and leaves (stock)"     "$(state '#{pane_in_mode}')" "0"

enter_copy_mode
press 1b 5b 39 39 39 39 7e
check "super+v leaves copy-mode"            "$(state '#{pane_in_mode}')" "0"

enter_copy_mode
press 03
check "ctrl+x leaves copy-mode"             "$(state '#{pane_in_mode}')" "0"

enter_copy_mode
press 1b 5b 39 39 3b 36 75
check "ctrl+c with no selection leaves"     "$(state '#{pane_in_mode}')" "0"

enter_copy_mode
press 56
press 71
check "q leaves from a selection"           "$(state '#{pane_in_mode}')" "0"

######################################################################
# the nvim setup, headless, against the real init.lua; the probe's bare arm
# proves it can tell the setup from nvim's own keys
echo ""
echo "🔭 does the nvim setup bind every key, against the real init.lua?"
echo ""
probe_out="$(rhx nvim.test.headless --probe "$HERE/prove.visual-select-keys.probe.lua" --arm control --arm bare)"
probe_rc=$?
printf '%s\n' "$probe_out" | grep -E '=(hit|miss) |world=' | sed 's/^ *│ */   /'
if [[ "$probe_rc" -ne 0 ]] || printf '%s\n' "$probe_out" | grep -qE '=miss |world=absent'; then
  echo "   ✋ the setup dropped a press, or the probe could not run (rc $probe_rc)"
  FAILED=1
fi

######################################################################
# the overlay in a REAL kitty: a scratch instance on the human's own kitty.conf,
# its window printed past one screen, and a watcher inside it that calls the
# deployed kitten as super+v does (prove.visual-select-overlay.watcher.py).
# no key reaches the desktop; a window flashes open and closes
echo ""
echo "🔭 in a real kitty with no tmux, does the overlay open over the FULL history?"
echo ""
# run_kitty <mode> <window command> — one scratch kitty, its watcher's rows read back
KITTY_TMUX_SOCK=visualsel-kitty
run_kitty() {
  local mode="$1" cmd="$2" kout kpid line
  kout="$(mktemp -t visual-select-overlay.XXXXXX)"
  VISUAL_SELECT_PROOF_OUT="$kout" VISUAL_SELECT_PROOF_LINES=300 VISUAL_SELECT_PROOF_MODE="$mode" kitty \
    --config "$HOME/.config/kitty/kitty.conf" \
    -o "watcher=$HERE/prove.visual-select-overlay.watcher.py" \
    -o confirm_os_window_close=0 \
    --title 'visual select proof' \
    bash --norc -c "$cmd" 2>/dev/null &
  kpid=$!
  for _ in $(seq 1 80); do
    grep -q '^done=1' "$kout" 2>/dev/null && break
    sleep 0.5
  done
  kill "$kpid" 2>/dev/null
  grep -q '^done=1' "$kout" || { echo "   ✋ the watcher never reported"; FAILED=1; }
  while IFS= read -r line; do
    case "$line" in
      done=1) ;;
      *=hit\ *) echo "   ✔ $line" ;;
      *=miss\ *) echo "   ✋ $line"; FAILED=1 ;;
      *) echo "   · $line" ;;
    esac
  done < "$kout"
  rm -f "$kout" "$kout.count"
}

if [[ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
  echo "   ✋ no display — a scratch kitty needs one"
  FAILED=1
else
  run_kitty bare "seq 1 300; exec sleep 60"

  # the SAME kitten, now with a real tmux in the kitty window: tmux marks the
  # window (in_tmux), the kitten hands tmux the key, tmux opens the popup, the
  # popup's nvim marks the window (visual_select_tmux), and super+v again closes it
  echo ""
  echo "🔭 in a real kitty WITH tmux, does super+v open and close tmux's nvim view?"
  echo ""
  tmux -L "$KITTY_TMUX_SOCK" kill-server 2>/dev/null
  run_kitty tmux "TERM=xterm-kitty exec tmux -L $KITTY_TMUX_SOCK -f $HOME/.tmux.conf new-session \"seq 1 300; exec bash --norc -i\""
  tmux -L "$KITTY_TMUX_SOCK" kill-server 2>/dev/null
fi

echo ""
[[ "$FAILED" -eq 0 ]] \
  && echo "🌲 one plain vim view in every holder: open, select, copy, jump, leave" \
  || echo "✋ a link in the gesture dropped its press — read the stages above"
exit "$FAILED"
