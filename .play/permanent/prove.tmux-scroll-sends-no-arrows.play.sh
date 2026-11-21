#!/usr/bin/env bash
######################################################################
# .what = drive a REAL scroll — a wheel tick, and the ctrl+up/ctrl+down
#         keys kitty hands tmux — as the raw bytes a terminal sends, into
#         a tmux client that runs the SHIPPED tmux.conf, and read what the
#         pane's own app received
#
# .why  = a scroll over a tmux pane must reach the app as a mouse event
#         or not at all — never as an arrow key. claude-cli holds the
#         alternate screen, and an arrow at its prompt recalls an old
#         message. the human sees "scroll up sent an up arrow"
#
#         measured 2026-11-21: the wheel was clean even on stock tmux; the
#         leak was the keyboard scroll. `C-Up` on the alternate screen was
#         re-sent as `ESC [ 1 ; 5 A`, and `C-Down` had no bind at all
#
# .the arms — the old arm must go red, or this play is blind (term=bite)
#   wheel, alt, no mouse    a TUI that never asked (less shape) → no arrow
#   wheel, alt, mouse       a TUI that asked SGR (claude, nvim) → the wheel
#                           itself, and no arrow
#   wheel, main screen      a plain app → copy-mode, tmux scrolls its 50k
#   keys, alt, mouse        C-Up / C-Down → one SGR wheel tick each, AT THE
#                           CURSOR (1;1 here), and no arrow
#   keys, alt, no mouse     C-Up / C-Down → no key at all
#   keys, main screen       C-Up → copy-mode
#   old-key-bind            the C-Up bind as it stood before 2026-11-21 →
#                           the app MUST receive `ESC [ 1 ; 5 A`
#
# .the shape — the same nest as prove.copy-kitten-finds-the-client
#   the probe server (-L scroll-<pid>) runs the app under test; an outer
#   server runs `tmux -L … attach`, so the outer pane's pty IS the client's
#   terminal. `send-keys -H` into the outer pane writes the bytes kitty
#   would, so the client parses a real key or mouse event
#
# .the settle is a fact, never a clock: after the scroll, a `z` follows down
#   the same pipe. when the app logs `z`, every byte before it has landed
#
# .it writes two scratch tmux servers and a temp dir; a trap removes all,
#   socket files included
#
# usage:
#   rhx play.run --play prove.tmux-scroll-sends-no-arrows
######################################################################
set -uo pipefail

REPO="${GROVE_SRC:-$PWD/src}"
CONF="$REPO/grove.provision/2.shell/2.8.tmux/tmux.conf"
SOCK="scroll-$$"
OUTER="scroll-outer-$$"
SOCKDIR="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)"
TMPD="$(mktemp -d)"
OLD="$TMPD/old.conf"
LOGGER="$TMPD/logger.py"
FAILED=0

# the pane app: it holds the screen the way a TUI does, and logs every byte it reads
#   - INLINE, so the play is one file: `git.grove.send --play` lands the play
#     file alone, and a logger kept beside it would not travel
#   - argv[1] the log, one hex line per read; argv[2] alt | alt-mouse
#     (alt = claude-off / less shape; alt-mouse = SGR mouse asked, claude / nvim)
#   - the log's first line is `ready`, written once the modes are set
cat >"$LOGGER" <<'PY'
import os, sys, tty
log, screen = sys.argv[1], sys.argv[2]
fd = sys.stdin.fileno()
tty.setraw(fd)
modes = '\x1b[?1049h' + ('\x1b[?1000h\x1b[?1006h' if screen == 'alt-mouse' else '')
os.write(sys.stdout.fileno(), modes.encode())
with open(log, 'a') as fh:
    fh.write('ready\n')
while True:
    data = os.read(fd, 1024)
    if not data:
        break
    with open(log, 'a') as fh:
        fh.write(data.hex() + '\n')
PY

# what a terminal sends: SGR wheel ticks at column 10, row 5, and the two keys
WHEEL_UP='1b 5b 3c 36 34 3b 31 30 3b 35 4d'
WHEEL_DOWN='1b 5b 3c 36 35 3b 31 30 3b 35 4d'
KEY_UP='1b 5b 31 3b 35 41'
KEY_DOWN='1b 5b 31 3b 35 42'

# what the app must (or must never) read, as hex
TICK_UP_AT_CURSOR='1b5b3c36343b313b314d'
TICK_DOWN_AT_CURSOR='1b5b3c36353b313b314d'
ARROWS='1b5b41|1b5b42|1b4f41|1b4f42|1b5b313b3541|1b5b313b3542'

cleanup() {
  tmux -L "$SOCK" kill-server 2>/dev/null
  tmux -L "$OUTER" kill-server 2>/dev/null
  rm -f "$SOCKDIR/$SOCK" "$SOCKDIR/$OUTER"
  rm -rf "$TMPD"
  echo ""
  if tmux -L "$SOCK" has-session 2>/dev/null || tmux -L "$OUTER" has-session 2>/dev/null; then
    echo "   ✋ a probe tmux SURVIVED"
  else
    echo "   🧹 restored: both probe servers down, sockets and temp dir removed"
  fi
}
trap cleanup EXIT

# refuse a subject we would have to invent
[[ -r "$CONF" ]] || { echo "✋ no tmux.conf at $CONF — run from a checkout, or set GROVE_SRC"; exit 1; }
for bin in tmux python3; do
  command -v "$bin" >/dev/null || { echo "✋ no $bin on PATH"; exit 1; }
done

# the C-Up bind as it stood before 2026-11-21, on the same base conf
{
  cat "$CONF"
  echo "bind -n C-Up if -F '#{alternate_on}' 'send-keys C-Up' 'copy-mode -e ; send -N 3 -X scroll-up'"
} >"$OLD"

# down <socket> — the server is gone and its socket file with it
#   - a new server on a socket whose last server still exits dies at birth
#     ("server exited unexpectedly"), so the next arm waits on the fact
down() {
  tmux -L "$1" kill-server 2>/dev/null
  for _ in $(seq 50); do
    tmux -L "$1" has-session 2>/dev/null || break
    sleep 0.1
  done
  rm -f "$SOCKDIR/$1"
}

# start <conf> <pane command> — the nest, with the client attached
start() {
  local conf="$1" cmd="$2"
  down "$SOCK"
  down "$OUTER"
  tmux -L "$SOCK" -f "$conf" new-session -d -s inner -x 100 -y 30 "$cmd"
  tmux -L "$OUTER" -f /dev/null new-session -d -s outer -x 100 -y 30 "tmux -L $SOCK attach -t inner"
  for _ in $(seq 50); do
    [[ -n "$(tmux -L "$SOCK" list-clients -F '#{client_pid}' 2>/dev/null)" ]] && return 0
    sleep 0.1
  done
  return 1
}

# await <log> <regex> — the app logged a read that matches
await() {
  for _ in $(seq 50); do
    grep -qE "$2" "$1" 2>/dev/null && return 0
    sleep 0.1
  done
  return 1
}

# into <hex…> — bytes into the client's terminal, as kitty would write them
into() { tmux -L "$OUTER" send-keys -t outer -H $1; }

# saw <label> <log> <regex> <want: yes|no>
saw() {
  local label="$1" log="$2" re="$3" want="$4" got=no
  tr -d '\n' <"$log" | grep -qE "$re" && got=yes
  if [[ "$got" == "$want" ]]; then
    echo "   │  ✔ $label"
  else
    echo "   │  ✋ $label — saw=$got, expected $want"
    echo "   │     the app read: $(grep -v '^ready$' "$log" | tr '\n' ' ')"
    FAILED=1
  fi
}

# tui <name> <conf> <screen> <hex…> — one arm: an app on the alt screen, one press
#   - sets LOG to the app's log; the caller asserts on it
#   - 🛑 runs in THIS shell, never in `$(…)`: a FAILED=1 set in a subshell
#     never reaches the verdict, so a dead arm would read green
tui() {
  local name="$1" conf="$2" screen="$3" bytes="$4"
  LOG="$TMPD/arm-$RANDOM.log"
  : >"$LOG"
  echo "   $name"
  if ! start "$conf" "python3 $LOGGER $LOG $screen" || ! await "$LOG" '^ready$'; then
    echo "   │  💥 no client or no app; this arm asked NO question"
    FAILED=1
    return 1
  fi
  into "$bytes"
  tmux -L "$OUTER" send-keys -t outer -l z
  if ! await "$LOG" '7a$'; then
    echo "   │  💥 the settle key never landed; the app read naught after the press"
    FAILED=1
    return 1
  fi
}

# main_screen <name> <conf> <hex…> — a plain app; the press must enter copy-mode
main_screen() {
  local name="$1" conf="$2" bytes="$3" mode=0
  echo "   $name"
  if ! start "$conf" "cat"; then
    echo "   │  💥 no client attached; this arm asked NO question"
    FAILED=1
    return
  fi
  into "$bytes"
  for _ in $(seq 50); do
    mode="$(tmux -L "$SOCK" display -p -t inner '#{pane_in_mode}')"
    [[ "$mode" == 1 ]] && break
    sleep 0.1
  done
  if [[ "$mode" == 1 ]]; then
    echo "   │  ✔ copy-mode entered — tmux scrolls its own history"
  else
    echo "   │  ✋ pane_in_mode=$mode — the scroll no longer reaches tmux's history"
    FAILED=1
  fi
}

echo "🔭 does a scroll over a tmux pane ever arrive as an arrow key?"
echo ""

if tui "wheel, alt, no mouse — less shape" "$CONF" alt "$WHEEL_UP $WHEEL_UP $WHEEL_DOWN"; then
  saw "no arrow key" "$LOG" "$ARROWS" no
fi
if tui "wheel, alt, mouse — claude / nvim shape" "$CONF" alt-mouse "$WHEEL_UP $WHEEL_DOWN"; then
  saw "no arrow key" "$LOG" "$ARROWS" no
  saw "the wheel-up event itself arrived" "$LOG" '1b5b3c3634' yes
fi
main_screen "wheel, main screen — a plain app" "$CONF" "$WHEEL_UP"

if tui "ctrl+up, alt, mouse — claude / nvim shape" "$CONF" alt-mouse "$KEY_UP"; then
  saw "no arrow key" "$LOG" "$ARROWS" no
  saw "one wheel-up tick, at the cursor" "$LOG" "$TICK_UP_AT_CURSOR" yes
fi
if tui "ctrl+down, alt, mouse — claude / nvim shape" "$CONF" alt-mouse "$KEY_DOWN"; then
  saw "no arrow key" "$LOG" "$ARROWS" no
  saw "one wheel-down tick, at the cursor" "$LOG" "$TICK_DOWN_AT_CURSOR" yes
fi
if tui "ctrl+up + ctrl+down, alt, no mouse — less shape" "$CONF" alt "$KEY_UP $KEY_DOWN"; then
  saw "no arrow key" "$LOG" "$ARROWS" no
  # the app read `z` and naught else: the two presses reached no process
  if [[ "$(grep -v '^ready$' "$LOG" | tr -d '\n')" == 7a ]]; then
    echo "   │  ✔ no key at all — only the settle key arrived"
  else
    echo "   │  ✋ the app read more than the settle key: $(grep -v '^ready$' "$LOG" | tr '\n' ' ')"
    FAILED=1
  fi
fi
main_screen "ctrl+up, main screen — a plain app" "$CONF" "$KEY_UP"

if tui "old-key-bind — ctrl+up re-sent as-is → must read the arrow (the defect)" "$OLD" alt-mouse "$KEY_UP"; then
  saw "ESC [ 1 ; 5 A received — the defect, reproduced" "$LOG" '1b5b313b3541' yes
fi

echo ""
[[ "$FAILED" -eq 0 ]] \
  && echo "🌲 a scroll reaches a pane as a wheel tick or not at all, and the old bind is proven to send the arrow" \
  || echo "✋ the contract did NOT hold — read the arms above"
exit "$FAILED"
