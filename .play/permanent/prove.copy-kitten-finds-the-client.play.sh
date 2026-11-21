#!/usr/bin/env bash
######################################################################
# .what = attach a real tmux client to a server on a NON-default socket,
#         run nvim in its pane, and ask the SHIPPED copy_notify.py kitten
#         what that client focuses
#
# .why  = ctrl+shift+c reaches nvim only if the kitten forwards it, and it
#         forwards only when its lookup reads `nvim` in the client's active
#         pane. `prove.copy-gate-discriminates` proves the tmux half and
#         never runs the kitten, so a lookup that cannot find the client
#         passes it green while the key dies at kitty.
#
#         measured 2026-10-21: the human's nvim ran on `duct-org-ehmpathy`;
#         the kitten asked `default` alone, found no client, failed closed.
#         every tmux layer read healthy the whole time.
#
# .the arms — the old arm must go red, or this play is blind (term=bite)
#   control           nvim on socket X       → focused=nvim, tmux_calls=1
#   control-shell     a shell on socket X    → focused=bash, tmux_calls=1
#   old-default-only  nvim, socket pinned to `default` → focused=EMPTY
#
#   tmux_calls=1 is the cost clamp: the kitten reads the server off the
#   client's own argv and asks it once — never a walk of every socket
#
# .the shape — the same nest as prove.copy-gate-discriminates
#   the probe server (-L copyfind-<pid>) runs the pane; a session on the
#   default server runs `tmux -L … attach`, so that outer pane's pty IS the
#   attached client's tty, which is what kitty's subtree read hands the kitten
#
# .it writes a scratch tmux server + one outer session; a trap removes both
#
# usage:
#   rhx play.run --play prove.copy-kitten-finds-the-client
######################################################################
set -uo pipefail

REPO="${GROVE_SRC:-$PWD/src}"
KITTEN="$REPO/grove.provision/4.terminal/4.3.kitty/4.3.2.emulator/copy_notify.py"
PROBE="$(dirname "${BASH_SOURCE[0]}")/prove.copy-kitten-finds-the-client.probe.py"
SOCK="copyfind-$$"
OUTER="copyfind-outer-$$"
FAILED=0

# the probe imports the SHIPPED kitten from the checkout; with bytecode on, python
#   writes `__pycache__/` beside it, inside `src/` — residue in the tree under test
export PYTHONDONTWRITEBYTECODE=1

# 🛑 every server this play touches lives under a PRIVATE socket dir
#   - the old arm asks `default` alone; with the shared dir that is the human's
#     LIVE server, and tmux answered its own current pane (`zsh`) for a tty it
#     holds no client of — so the arm read the human's session, never the lookup
#   - ⇒ here `default` is a server no one runs, so the old lookup can only
#     answer what it would for a client on any other socket: naught
#   - the kitten reads TMUX_TMPDIR itself, so it resolves the same dir
#   - the outer session sits on its own named socket, never `default`
TMUX_TMPDIR="$(mktemp -d -t copyfind-tmux.XXXXXX)"
export TMUX_TMPDIR

cleanup() {
  tmux -L "$SOCK" kill-server 2>/dev/null
  tmux -L "$OUTER" kill-server 2>/dev/null
  echo ""
  if tmux -L "$SOCK" has-session 2>/dev/null || tmux -L "$OUTER" has-session 2>/dev/null; then
    echo "   ✋ a probe tmux SURVIVED"
  else
    echo "   🧹 restored: probe server and outer session down"
  fi
  rm -rf "$TMUX_TMPDIR"
}
trap cleanup EXIT

# refuse a subject we would have to invent
[[ -r "$KITTEN" ]] || { echo "✋ no kitten at $KITTEN"; exit 1; }
[[ -r "$PROBE" ]] || { echo "✋ no probe at $PROBE"; exit 1; }
for bin in tmux nvim python3; do
  command -v "$bin" >/dev/null || { echo "✋ no $bin on PATH"; exit 1; }
done

# .what = stop one server, and return only once its socket is gone
# .why  = `kill-server` returns before the server exits. the next arm's new-session
#         then reached the DYING server and read `server exited unexpectedly`, so the
#         arm attached no client. 📜 measured 2026-11-18 inside `play.run --all`
server_down() {
  local sock="$1" path
  path="$TMUX_TMPDIR/tmux-$(id -u)/$sock"
  tmux -L "$sock" kill-server 2>/dev/null
  for _ in $(seq 50); do
    [[ -e "$path" ]] || return 0
    sleep 0.1
  done
  rm -f "$path"
}

arm() {
  local name="$1" cmd="$2" probe_arm="$3" want="$4" want_calls="$5" pid rows saw calls
  server_down "$SOCK"
  server_down "$OUTER"

  if ! tmux -L "$SOCK" new-session -d -s inner -x 100 -y 30 "$cmd" \
     || ! tmux -L "$OUTER" new-session -d -s outer -x 100 -y 30 "tmux -L $SOCK attach -t inner"; then
    echo "   💥 $name — a probe server would not start; this arm asked NO question"
    FAILED=1
    return
  fi

  # wait on the facts themselves, never a clock: the client is attached
  for _ in $(seq 50); do
    pid="$(tmux -L "$SOCK" list-clients -F '#{client_pid}' 2>/dev/null | head -1)"
    [[ -n "$pid" ]] && break
    sleep 0.1
  done
  if [[ -z "$pid" ]]; then
    echo "   💥 $name — no client attached; this arm asked NO question"
    FAILED=1
    return
  fi
  # and the pane runs what this arm asked for
  for _ in $(seq 50); do
    [[ "$(tmux -L "$SOCK" display -p -t inner '#{pane_current_command}')" == "${cmd%% *}" ]] && break
    sleep 0.1
  done

  rows="$(python3 "$PROBE" "$KITTEN" "$pid" "$probe_arm")"
  saw="$(grep -oP '^focused=\K.*' <<<"$rows")"
  calls="$(grep -oP '^tmux_calls=\K.*' <<<"$rows")"
  if [[ "$saw" == "$want" ]]; then
    echo "   ✔ $name — focused=$saw (as declared)"
  else
    echo "   ✋ $name — focused=${saw:-<no row>}, expected $want"
    FAILED=1
  fi
  # the cost of one press: the client's own server, asked once, never a walk
  if [[ -n "$want_calls" ]]; then
    if [[ "$calls" == "$want_calls" ]]; then
      echo "   │  ✔ tmux_calls=$calls (one press, one call)"
    else
      echo "   │  ✋ tmux_calls=${calls:-<no row>}, expected $want_calls"
      FAILED=1
    fi
  fi
}

echo "🔭 does the copy kitten find a client on a non-default tmux socket?"
echo ""
echo "   socket under test: $SOCK"
echo ""

arm "control           nvim in the pane   → must read nvim " "nvim --clean" control nvim 1
arm "control-shell     a shell in the pane → must read bash" "bash --norc -i" control bash 1
arm "old-default-only  the lookup asks 'default' alone → must read EMPTY" "nvim --clean" old-default-only EMPTY ""

echo ""
[[ "$FAILED" -eq 0 ]] \
  && echo "🌲 the kitten finds the client on any socket, and the old lookup is proven blind to it" \
  || echo "✋ the contract did NOT hold — read the arms above"
exit "$FAILED"
