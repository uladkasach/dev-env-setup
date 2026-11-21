#!/usr/bin/env bash
######################################################################
# .what = press the SHIPPED copy_notify.py kitten's ctrl+c over a real
#         shell → tmux client → tmux server → nvim tree, and prove its
#         clipboard write leaves the handler before any forward work
#
# .why  = kitty sends a clipboard offer to the compositor only when its
#         event loop next turns. the handler blocks that turn, and the
#         forward costs a /proc walk plus a tmux call (timeout 1s)
#
#         measured 2026-11-21: a mouse drag over tmux scrollback, ctrl+c,
#         then an instant switch to another terminal → the toast fired and
#         the clipboard never changed. focus moved before the offer went
#         out, and wayland drops an offer from an unfocused client
#
# .the arms — each old arm must go red, or this play is blind (term=bite)
#   kitty-api           real kitty imports `add_timer` the kitten needs
#   shipped             clipboard first · no forward work before return ·
#                       forward still lands on nvim after the tick ·
#                       the walk names the same pids, with ZERO full-box reads
#   old-inline-forward  the forward run inside the handler → work_before_return=yes
#   old-full-walk       the full /proc map → stat_reads > subtree_size
#
# .the shape — the same nest as prove.copy-kitten-finds-the-client
#   the probe server (-L copyflush-<pid>) runs nvim; an outer server runs a
#   shell that runs `tmux -L … attach`. the outer pane's shell stands in for
#   the shell a kitty window launches, so its tree is the one kitty walks
#
# .it writes two scratch tmux servers; a trap removes both
#
# usage:
#   rhx play.run --play prove.copy-kitten-flushes-before-forward
######################################################################
set -uo pipefail

REPO="${GROVE_SRC:-$PWD/src}"
KITTEN="$REPO/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/copy_notify.py"
PROBE="$(dirname "${BASH_SOURCE[0]}")/prove.copy-kitten-flushes-before-forward.probe.py"
SOCK="copyflush-$$"
OUTER="copyflush-outer-$$"
FAILED=0

cleanup() {
  tmux -L "$SOCK" kill-server 2>/dev/null
  tmux -L "$OUTER" kill-server 2>/dev/null
  # a killed server can leave its socket FILE, which `rhx tmux.sockets.get` then names STALE
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$SOCK" "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$OUTER"
  echo ""
  if tmux -L "$SOCK" has-session 2>/dev/null || tmux -L "$OUTER" has-session 2>/dev/null; then
    echo "   ✋ a probe tmux SURVIVED"
  else
    echo "   🧹 restored: both probe servers down"
  fi
}
trap cleanup EXIT

# refuse a subject we would have to invent
[[ -r "$KITTEN" ]] || { echo "✋ no kitten at $KITTEN"; exit 1; }
[[ -r "$PROBE" ]] || { echo "✋ no probe at $PROBE"; exit 1; }
for bin in tmux nvim python3 kitty; do
  command -v "$bin" >/dev/null || { echo "✋ no $bin on PATH"; exit 1; }
done

# want <name> <rows> <key> <value>
want() {
  local name="$1" rows="$2" key="$3" value="$4" saw
  saw="$(grep -oP "^$key=\K.*" <<<"$rows")"
  if [[ "$saw" == "$value" ]]; then
    echo "   │  ✔ $key=$saw"
  else
    echo "   │  ✋ $key=${saw:-<no row>}, expected $value"
    FAILED=1
  fi
}

echo "🔭 does ctrl+c's clipboard write leave the handler before the forward?"
echo ""

# the api the fix stands on, asked of the real kitty — the probe stubs it
echo "   kitty-api — real kitty holds add_timer(callback, interval, repeats)"
api="$(kitty +runpy 'from kitty.fast_data_types import add_timer; print("callable" if callable(add_timer) else "absent")' 2>&1)"
if [[ "$api" == "callable" ]]; then
  echo "   │  ✔ add_timer is callable in kitty $(kitty --version | awk '{print $2}')"
else
  echo "   │  ✋ add_timer: ${api:-<no answer>}"
  FAILED=1
fi
echo ""

# the tree: outer shell → tmux client → inner server → nvim
tmux -L "$SOCK" new-session -d -s inner -x 100 -y 30 "nvim --clean"
tmux -L "$OUTER" new-session -d -s outer -x 100 -y 30 "bash -c 'tmux -L $SOCK attach -t inner; true'"

# wait on the facts themselves, never a clock: the client is attached, nvim runs
for _ in $(seq 50); do
  [[ -n "$(tmux -L "$SOCK" list-clients -F '#{client_pid}' 2>/dev/null | head -1)" ]] && break
  sleep 0.1
done
for _ in $(seq 50); do
  [[ "$(tmux -L "$SOCK" display -p -t inner '#{pane_current_command}')" == "nvim" ]] && break
  sleep 0.1
done
ROOT="$(tmux -L "$OUTER" display -p -t outer '#{pane_pid}')"
if [[ -z "$(tmux -L "$SOCK" list-clients -F '#{client_pid}' 2>/dev/null)" || -z "$ROOT" ]]; then
  echo "   💥 no client attached; the arms below would ask NO question"
  exit 1
fi

echo "   shipped — the kitten as it ships"
rows="$(python3 "$PROBE" "$KITTEN" "$ROOT" shipped)"
want shipped "$rows" clipboard_first yes
want shipped "$rows" work_before_return no
want shipped "$rows" forwarded yes
want shipped "$rows" subtree_matches yes
want shipped "$rows" stat_reads 0
echo ""

echo "   old-inline-forward — the forward inside the handler → must hold the offer back"
rows="$(python3 "$PROBE" "$KITTEN" "$ROOT" old-inline-forward)"
want old-inline-forward "$rows" work_before_return yes
echo ""

echo "   old-full-walk — every /proc/<pid>/stat on the box → must read past the window"
rows="$(python3 "$PROBE" "$KITTEN" "$ROOT" old-full-walk)"
reads="$(grep -oP '^stat_reads=\K.*' <<<"$rows")"
size="$(grep -oP '^subtree_size=\K.*' <<<"$rows")"
if [[ -n "$reads" && -n "$size" && "$reads" -gt "$size" ]]; then
  echo "   │  ✔ stat_reads=$reads > subtree_size=$size (the whole box, for a $size-pid window)"
else
  echo "   │  ✋ stat_reads=${reads:-<no row>}, subtree_size=${size:-<no row>} — the cost claim is blind"
  FAILED=1
fi

echo ""
[[ "$FAILED" -eq 0 ]] \
  && echo "🌲 the clipboard offer leaves the handler first, the forward still lands, and the walk stays inside the window" \
  || echo "✋ the contract did NOT hold — read the arms above"
exit "$FAILED"
