#!/usr/bin/env bash
######################################################################
# .what = put a key logger in front of the chain — kitty → tmux → app, or
#         kitty → app — in a fresh window, and record the bytes a human's
#         physical keypress delivers
#
# .why  = a keybind that is right in source and dead under a finger has two
#         causes that look identical from the config: the map is wrong, or the
#         bytes never arrive in that shape. only a live chain reports the
#         second (howto.probe-the-key-chain-with-a-live-logger)
#
#         one command opens the window AND starts the logger, so no send can
#         race a shell that is not up yet, and the logger stops itself after
#         --presses keys, so no later command is ever typed into it
#
# usage:
#   rhx term.keys.probe --via tmux                 # kitty → tmux → logger
#   rhx term.keys.probe --via bare                 # kitty → logger, no tmux
#   rhx term.keys.probe --via tmux --ask claude    # ask what claude-code asks
#   rhx term.keys.probe --via tmux --what 'env -u TMUX claude' --cwd /tmp
#                                                  # any app, in the same chain
#   rhx term.keys.probe --read                     # print the log
#   rhx term.keys.probe --send 'say BANANA' --send Enter   # tmux keys into the last probe
#   rhx term.keys.probe --send C-Enter                     # one tmux key name per --send
#   rhx term.keys.probe --stop                     # end the last tmux probe and its window
#
# options:
#   --via      tmux | bare — the chain under test (required, except with --read)
#   --ask      mok2 (default) | claude | none — the keyboard mode the logger
#              requests: mok2 = modifyOtherKeys 2 (`CSI >4;2m`); claude = the
#              exact ask claude-code 2.1.330 makes (`CSI <u`, `CSI >5u`, `CSI >4;2m`)
#   --presses  how many key bursts to record before the logger exits (default 4)
#   --keys     comma list of labels shown for each press (default: the enter family)
#   --what     run this command instead of the logger, in the same chain
#   --cwd      where --what runs (default: this repo)
#   --read     print the log from past probes, and the live pane of the last
#              tmux probe while its session lives
#   --send     type into the last tmux probe via `tmux send-keys`: a tmux key name
#              (Enter, C-Enter, Escape) or literal text; repeat for a sequence
#   --stop     end the last tmux probe session; its window closes with it
#
# ⚠️ --send starts at TMUX, so it skips the kitty hop. it proves what an APP does with
#    a key; only a human's press proves what kitty delivers (the byte logger)
#
# guarantee:
#   - opens ONE window; the logger exits on its own after --presses bursts,
#     and the window closes with it
#   - writes only under .temp/term.keys.probe/ (gitignored)
#   - never sends keys itself: a human's finger is the instrument
#   - exit 0 = opened (or read) · 1 = kitty failed to open · 2 = bad input, or no display
######################################################################
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
REPO="$(git -C "$(dirname "$SELF")" rev-parse --show-toplevel 2>/dev/null || pwd)"
LOGDIR="$REPO/.temp/term.keys.probe"
LOG="$LOGDIR/probe.log"

# the logger itself — runs INSIDE the window, never from rhx directly
if [[ "${1:-}" == "--as-logger" ]]; then
  ask="$2" presses="$3" keys="$4"
  case "$ask" in
    mok2) printf '\033[>4;2m' ;;
    claude) printf '\033[<u\033[>5u\033[>4;2m' ;;
  esac
  in_tmux="no"; [[ -n "${TMUX:-}" ]] && in_tmux="yes"
  echo "--- $(date -Is) ask=$ask in_tmux=$in_tmux term=${TERM:-} presses=$presses" >> "$LOG"
  echo "🔭 term.keys.probe — ask=$ask, inside tmux: $in_tmux"
  echo "   press each key ONCE, with a pause between:"
  IFS=',' read -r -a labels <<< "$keys"
  i=0
  for l in "${labels[@]}"; do i=$((i + 1)); echo "     $i. $l"; done
  echo "   the window closes itself after $presses presses"
  echo ""
  stty -echo -icanon min 1 time 0
  trap 'printf "\033[<u\033[>4;0m"; stty sane' EXIT
  n=0
  while (( n < presses )); do
    IFS= read -r -s -n1 -d '' c || break
    burst="$c"
    while IFS= read -r -s -n1 -d '' -t 0.05 more; do burst+="$more"; done
    n=$((n + 1))
    hex="$(printf '%s' "$burst" | od -An -tx1 | tr -s ' \n' ' ' | sed 's/^ //; s/ $//')"
    label="${labels[$((n - 1))]:-press $n}"
    echo "press $n ($label): $hex" | tee -a "$LOG"
  done
  echo ""
  echo "✔ recorded — this window closes in 2s"
  sleep 2
  exit 0
fi

VIA="" ASK="mok2" PRESSES=4 KEYS="enter,ctrl+enter,shift+enter,ctrl+j" WHAT="" CWD="$REPO" READ=0 STOP=0
SENDS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --via) VIA="$2"; shift 2 ;;
    --ask) ASK="$2"; shift 2 ;;
    --presses) PRESSES="$2"; shift 2 ;;
    --keys) KEYS="$2"; shift 2 ;;
    --what) WHAT="$2"; shift 2 ;;
    --cwd) CWD="$2"; shift 2 ;;
    --read) READ=1; shift ;;
    --stop) STOP=1; shift ;;
    --send) SENDS+=("$2"); shift 2 ;;
    --skill|--repo|--role) shift 2 ;;
    -h|--help|help) sed -n '2,/^####*$/p' "$SELF" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✋ ConstraintError: unknown argument: $1" >&2; echo "   see: rhx term.keys.probe --help" >&2; exit 2 ;;
  esac
done

if (( STOP )); then
  # the tmux session holds the window: end it, and kitty closes the window with it
  session="$(cat "$LOGDIR/session" 2>/dev/null || true)"
  if [[ -z "$session" ]] || ! env -u TMUX tmux has-session -t "$session" 2>/dev/null; then
    echo "🔭 term.keys.probe --stop"
    echo "   └─ no live tmux probe — naught to stop ✔"
    exit 0
  fi
  env -u TMUX tmux kill-session -t "$session" || { echo "💥 MalfunctionError: tmux refused to end $session" >&2; exit 1; }
  echo "🔭 term.keys.probe --stop"
  echo "   └─ ended $session; its window closed with it ✔"
  exit 0
fi

if (( ${#SENDS[@]} )); then
  session="$(cat "$LOGDIR/session" 2>/dev/null || true)"
  if [[ -z "$session" ]] || ! env -u TMUX tmux has-session -t "$session" 2>/dev/null; then
    echo "✋ ConstraintError: no live tmux probe to send into" >&2
    echo "   run: rhx term.keys.probe --via tmux --what '<app>'" >&2
    exit 2
  fi
  for k in "${SENDS[@]}"; do
    # a known tmux key name goes as a key; all else goes as literal text
    if [[ "$k" =~ ^(Enter|Escape|Tab|BSpace|Space|Up|Down|Left|Right|C-[A-Za-z]+|M-[A-Za-z]+|S-[A-Za-z]+)$ ]]; then
      env -u TMUX tmux send-keys -t "$session" "$k" || { echo "💥 MalfunctionError: tmux refused key $k" >&2; exit 1; }
    else
      env -u TMUX tmux send-keys -t "$session" -l "$k" || { echo "💥 MalfunctionError: tmux refused text" >&2; exit 1; }
    fi
    sleep 0.3
  done
  echo "🔭 term.keys.probe --send → $session"
  for k in "${SENDS[@]}"; do echo "   ├─ $k"; done
  echo "   └─ then:  rhx term.keys.probe --read"
  exit 0
fi

if (( READ )); then
  # the screen of the last tmux probe, while its session lives — so an app run via
  # --what (claude, nvim) can be read without a human to describe it
  session="$(cat "$LOGDIR/session" 2>/dev/null || true)"
  live=0
  [[ -n "$session" ]] && env -u TMUX tmux has-session -t "$session" 2>/dev/null && live=1

  if [[ ! -s "$LOG" ]] && (( ! live )); then
    echo "✋ ConstraintError: no probe log at $LOG, and no live probe session" >&2
    echo "   run: rhx term.keys.probe --via tmux" >&2
    exit 2
  fi

  echo "🔭 term.keys.probe --read"
  if [[ -s "$LOG" ]]; then
    echo ""
    echo "--- the byte log: $LOG"
    cat "$LOG"
  fi
  if (( live )); then
    echo ""
    echo "--- the live pane of tmux session $session"
    env -u TMUX tmux capture-pane -p -J -t "$session"
  fi
  exit 0
fi

[[ "$VIA" == tmux || "$VIA" == bare ]] || { echo "✋ ConstraintError: --via takes tmux or bare" >&2; exit 2; }
[[ "$ASK" == mok2 || "$ASK" == claude || "$ASK" == none ]] || { echo "✋ ConstraintError: --ask takes mok2, claude, or none" >&2; exit 2; }
[[ "$PRESSES" =~ ^[1-9][0-9]?$ ]] || { echo "✋ ConstraintError: --presses takes 1-99" >&2; exit 2; }
[[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]] || { echo "✋ ConstraintError: no display — this opens a window on the human's desktop" >&2; exit 2; }
command -v kitty >/dev/null 2>&1 || { echo "✋ ConstraintError: kitty is absent from PATH" >&2; echo "   fix: rhx grove.provision --what 4.3.2.emulator --mode apply" >&2; exit 2; }

mkdir -p "$LOGDIR"
if [[ -n "$WHAT" ]]; then
  # unset INSIDE too: an extant tmux server hands a new session the server's env, not ours
  inner=(env -u CLAUDE_CONFIG_DIR bash -lc "cd $(printf '%q' "$CWD") && $WHAT")
  label="--what $WHAT"
else
  inner=(bash "$SELF" --as-logger "$ASK" "$PRESSES" "$KEYS")
  label="logger, ask=$ASK, $PRESSES presses"
fi

# a nested tmux refuses to start where $TMUX is set, and a bare chain must not
# inherit one — so the window starts clean, and tmux sets its own
# 📜 2026-11-24: a claude under --what inherited a CLAUDE_CONFIG_DIR, so it read an actor
#    dir's keybindings, never ~/.claude's — the probe tested a config it did not name
launch=(env -u TMUX -u TMUX_PANE -u CLAUDE_CONFIG_DIR kitty --detach --title "term.keys.probe ($VIA)")
if [[ "$VIA" == tmux ]]; then
  session="keyprobe-$(date +%H%M%S)"
  echo "$session" > "$LOGDIR/session"
  launch+=(tmux new-session -s "$session" "${inner[@]}")
else
  launch+=("${inner[@]}")
fi
"${launch[@]}" >/dev/null 2>&1 \
  || { echo "💥 MalfunctionError: kitty did not open the probe window" >&2; exit 1; }

echo "🔭 term.keys.probe --via $VIA"
echo "   ├─ chain: kitty → $([[ "$VIA" == tmux ]] && echo "tmux → ")$label"
[[ -z "$WHAT" ]] && echo "   ├─ the window closes itself after $PRESSES presses"
# a window can open behind others or on another workspace; a tmux probe can always be reached
[[ "$VIA" == tmux ]] && echo "   ├─ cannot see the window? in any kitty tab: tmux attach -t $session"
echo "   └─ then:  rhx term.keys.probe --read"
