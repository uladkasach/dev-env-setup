#!/usr/bin/env bash
######################################################################
# .what = prove `2.8.tmux`'s live-server verify names each server that still
#         runs a build older than the pin (vision case 10)
#
# .why this play exists
#   - a pin swap replaces the binary on disk; a server already up keeps the
#     build it started on until it ends
#   - ⇒ the verify reads each server's OWN `#{version}`, and a 🌙 names those
#     behind the pin, so a crew knows its server still runs the crash-prone build
#
# .the world — two REAL servers on a private socket dir
#   - `prior`: started by the distro build (`/usr/bin/tmux`)
#   - `fresh`: started by the pinned build
#   - `tmux` on PATH is the pin, as on a converged grove
#
# .the arms
#   - A. the 🌙 names `prior` at its own version
#   - A2. its next step is a human's call, and it prints no command that ends a server
#   - B. the 🌙 does not name `fresh`
#   - D. the pin's client drives `prior` with a crew owner's verbs, and `prior` lives on
#   - E. a corpse socket (mute to every ask) is named once, by the mute 🌙
#   - F. a live server that names no build gets its own 🌙, never hidden by the mute count
#   - C. with `prior` gone, a ✔ counts the servers on the pin
#   - G. with `fresh` killed hard too, every socket is a corpse: no server up, no ✔ over none
#   - a prior build this play holds no snaps for declines (exit 2), never fails on an absent snap
#
# usage:
#   rhx play.run --play prove.tmux-verify-names-a-server-behind-the-pin
#
# exit:
#   0 = every arm holds
#   1 = an arm failed, and which is named
#   2 = no checkout, the bundle could not be sourced, or this box lacks a
#       build — no claim was graded
######################################################################

set -uo pipefail

# .what = the checkout under proof — `PROVE_ROOT` (the red half), this play's own, or the cwd
_root_of() {
  [[ -n "${PROVE_ROOT:-}" ]] && { printf '%s' "$PROVE_ROOT"; return 0; }
  local self; self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
  [[ -n "$self" && -f "$self/src/grove.provision._.sh" ]] && { printf '%s' "$self"; return 0; }
  [[ -f "$PWD/src/grove.provision._.sh" ]] && { printf '%s' "$PWD"; return 0; }
  return 1
}
_root="$(_root_of)" || { echo "   ✋ ConstraintError: no checkout found" >&2; exit 2; }

export GROVE_SRC="$_root/src"
# shellcheck source=/dev/null
source "$GROVE_SRC/grove.provision/2.shell/2.8.tmux/_.sh" \
  || { echo "   ✋ ConstraintError: could not source 2.8.tmux/_.sh" >&2; exit 2; }

echo "🔎 prove.tmux-verify-names-a-server-behind-the-pin"
echo "   └─ root: $_root"
echo ""

PIN_BIN="$(grove_provision_2_8_tmux_pin_dst)"
PRIOR_BIN="/usr/bin/tmux"
[[ -x "$PIN_BIN" ]] || { echo "   ✋ ConstraintError: no pinned tmux at $PIN_BIN — no fresh server to start" >&2; exit 2; }
[[ -x "$PRIOR_BIN" ]] || { echo "   ✋ ConstraintError: no distro tmux at $PRIOR_BIN — no prior server to start" >&2; exit 2; }
PRIOR_VER="$(timeout -k 2 5 "$PRIOR_BIN" -V </dev/null 2>/dev/null)"; PRIOR_VER="${PRIOR_VER#tmux }"
[[ -n "$PRIOR_VER" && "$PRIOR_VER" != "$GROVE_UPGRADE_2_8_TMUX_VERSION" ]] \
  || { echo "   ✋ ConstraintError: the distro tmux reads '$PRIOR_VER' — not a build behind the pin" >&2; exit 2; }

# the snaps are keyed by the prior build; a build with none on disk was never read by a human, so
#   this seat proves no claim until one is minted and reviewed — a decline, never a false red
SNAP_KEY_DIR="$(dirname "${BASH_SOURCE[0]}")/__snaps__/prove.tmux-verify-names-a-server-behind-the-pin"
[[ -f "$SNAP_KEY_DIR/A.prior-$PRIOR_VER.snap" || "${PLAY_RESNAP:-}" == 1 ]] || {
  echo "   🌙 no snaps for a prior build of $PRIOR_VER — this play holds snaps for each build a human read" >&2
  echo "      ⇒ mint them on this seat, then read each one: rhx play.run --play prove.tmux-verify-names-a-server-behind-the-pin --resnap" >&2
  exit 2
}

######################################################################
# the private socket dir, the pin first on PATH, and an unconditional teardown
######################################################################
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"

PROBE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/prove.tmux-behind.XXXXXX")"
PIN_PATH="$PROBE_DIR/bin"
mkdir -p "$PIN_PATH"
ln -s "$PIN_BIN" "$PIN_PATH/tmux"
export TMUX_TMPDIR="$PROBE_DIR"
unset TMUX

_teardown() {
  timeout -k 2 5 "$PRIOR_BIN" -L prior kill-server </dev/null >/dev/null 2>&1
  timeout -k 2 5 "$PIN_BIN" -L fresh kill-server </dev/null >/dev/null 2>&1
  timeout -k 2 5 "$PIN_BIN" -L shy kill-server </dev/null >/dev/null 2>&1
  rm -rf "$PROBE_DIR"
}
trap _teardown EXIT

timeout -k 2 10 "$PRIOR_BIN" -L prior -f /dev/null new-session -d -s probe </dev/null >/dev/null 2>&1 \
  || { echo "   ✋ ConstraintError: the prior server did not start" >&2; exit 2; }
timeout -k 2 10 "$PIN_BIN" -L fresh -f /dev/null new-session -d -s probe </dev/null >/dev/null 2>&1 \
  || { echo "   ✋ ConstraintError: the fresh server did not start" >&2; exit 2; }

out="$(PATH="$PIN_PATH:$PATH" GROVE_ENV_SERVER=cloud@aws.ec2 \
  grove_provision_2_8_tmux_verify_live_servers "$PROBE_DIR/no.conf" tmux-256color 2>&1)"

failed=0

# .what = snap one rendered verify, keyed by the prior build it ran against
#   - the prior server is the distro's tmux, and its version, default TERM, and pane count
#     differ per release (jammy, noble) — so each prior build holds its own snap
_snap() { play_snap_assert arm="$1.prior-$PRIOR_VER" rendered="$2" mask="$PROBE_DIR" || failed=$(( failed + 1 )); }

# A. the prior server is named, at its own version
[[ "$out" == *"build older than the pin"* && "$out" == *"prior=$PRIOR_VER"* ]] && \
  echo "   ├─ A. the 🌙 names prior=$PRIOR_VER ✔" && _snap A "$out"
[[ "$out" == *"build older than the pin"* && "$out" == *"prior=$PRIOR_VER"* ]] || {
  echo "   ├─ A. no 🌙 that names prior=$PRIOR_VER" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  failed=$(( failed + 1 ))
}

# A1. the prior server's default-terminal and its panes' TERM are each a ✋ of their own
#   (catalog rows 32, 33), graded by phrase so a careless resnap cannot absorb a lost refusal
[[ "$out" == *"hold a default-terminal the conf does NOT declare"* \
   && "$out" == *"hold a TERM the conf does NOT declare"* ]] \
  && echo "   ├─ A1. the server default-terminal ✋ and the pane TERM ✋ each render ✔"
[[ "$out" == *"hold a default-terminal the conf does NOT declare"* \
   && "$out" == *"hold a TERM the conf does NOT declare"* ]] || {
  echo "   ├─ A1. a default-terminal or pane TERM ✋ is absent" >&2
  failed=$(( failed + 1 ))
}

# A2. the 🌙 names its next step — a human's call — and hands the reader no command that
#   ends a server: the reader may be an agent inside a pane on that very server
if [[ "$out" == *"a human decides when those sessions may end"* && "$out" != *"kill-server"* ]]; then
  echo "   ├─ A2. the 🌙 names a human's call, and no kill command ✔"
else
  echo "   ├─ A2. the 🌙 names no human's call, or hands the reader a kill command" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  failed=$(( failed + 1 ))
fi

# B. the fresh server, on the pin, is not named — the snap pins every `servers:` row the
#   verify printed, so a fresh= that ever lands in one shows in review
[[ "$out" != *"fresh="* ]] && echo "   ├─ B. the fresh server, on the pin, is not named ✔" \
  && _snap B "$(printf '%s\n' "$out" | grep 'servers:')"
[[ "$out" != *"fresh="* ]] || {
  echo "   ├─ B. the fresh server was named, though it runs the pin" >&2
  failed=$(( failed + 1 ))
}

# D. the PIN's client drives the live prior server with a crew owner's verbs (case 10 [t1]–[t2],
#   case 3): after a swap, every verb a crew owner runs reaches its old server through 3.5a
_pin() { timeout -k 2 5 "$PIN_BIN" -L prior "$@" </dev/null; }
verbs_failed=""
_pin new-window -d -t probe -n verb >/dev/null 2>&1 || verbs_failed+=" new-window"
_pin send-keys -t probe:verb 'echo crew-verb-probe' Enter >/dev/null 2>&1 || verbs_failed+=" send-keys"
seen=""
for _ in $(seq 1 20); do
  [[ "$(_pin capture-pane -p -t probe:verb 2>/dev/null)" == *crew-verb-probe* ]] && { seen=yes; break; }
  sleep 0.25
done
[[ -n "$seen" ]] || verbs_failed+=" capture-pane"
[[ "$(_pin list-windows -t probe -F '#{window_name}' 2>/dev/null)" == *verb* ]] || verbs_failed+=" list-windows"
# an attach under a pty, then a detach — the round trip a crew owner's tab makes
timeout -k 2 5 script -qfec "$PIN_BIN -L prior attach -t probe \\; detach-client" /dev/null </dev/null >/dev/null 2>&1 \
  || verbs_failed+=" attach"
_pin has-session -t probe >/dev/null 2>&1 || verbs_failed+=" (the prior server did not survive)"
if [[ -z "$verbs_failed" ]]; then
  echo "   ├─ D. the pin's client drives the prior server: new-window, send-keys, capture-pane, list-windows, attach ✔"
  _snap D "$(printf '%s\n' \
    "   • client: the pin ($GROVE_UPGRADE_2_8_TMUX_VERSION) · server: prior ($PRIOR_VER)" \
    "   • verbs: new-window, send-keys, capture-pane, list-windows, attach ✔" \
    "   • the prior server lives on ✔")"
else
  echo "   ├─ D. the pin's client failed against the prior server:$verbs_failed" >&2
  failed=$(( failed + 1 ))
fi

# E + F. two corpses: a server killed hard leaves its socket file behind
#   - `corpse`: mute to every ask → the mute 🌙 names it once, and the build walk does not count it again
#   - `ghost`: a shim answers its status-right ask and not its build ask → a live server with no
#     build named, so the "did not name their build" 🌙 names it (the count the mute once hid)
_corpse() {
  timeout -k 2 10 "$PIN_BIN" -L "$1" -f /dev/null new-session -d -s probe </dev/null >/dev/null 2>&1 || return 1
  local pid; pid="$(timeout -k 2 5 "$PIN_BIN" -L "$1" display-message -p '#{pid}' </dev/null 2>/dev/null)"
  [[ -n "$pid" ]] && kill -9 "$pid" 2>/dev/null
  for _ in $(seq 1 20); do kill -0 "$pid" 2>/dev/null || return 0; sleep 0.1; done
  return 1
}
#   - `shy`: a live server whose status-right ask the shim fails, while it still names its build —
#     mute to the walk, never a corpse, so it must not cancel `ghost` out of the count
_corpse corpse && _corpse ghost \
  || { echo "   ✋ ConstraintError: the corpse servers did not start, or did not die" >&2; exit 2; }
timeout -k 2 10 "$PIN_BIN" -L shy -f /dev/null new-session -d -s probe </dev/null >/dev/null 2>&1 \
  || { echo "   ✋ ConstraintError: the shy server did not start" >&2; exit 2; }
SHIM_PATH="$PROBE_DIR/shim"
mkdir -p "$SHIM_PATH"
printf '%s\n' '#!/usr/bin/env bash' \
  "[[ \"\$1 \$2\" == '-L ghost' && \"\$3\" == show-options ]] && exit 0" \
  "[[ \"\$1 \$2\" == '-L shy' && \"\$3\" == show-options ]] && exit 1" \
  "exec '$PIN_BIN' \"\$@\"" > "$SHIM_PATH/tmux"
chmod +x "$SHIM_PATH/tmux"
out="$(PATH="$SHIM_PATH:$PIN_PATH:$PATH" GROVE_ENV_SERVER=cloud@aws.ec2 \
  grove_provision_2_8_tmux_verify_live_servers "$PROBE_DIR/no.conf" tmux-256color 2>&1)"
timeout -k 2 5 "$PIN_BIN" -L shy kill-server </dev/null >/dev/null 2>&1
if [[ "$out" == *"2 socket(s) did not answer"* && "$out" == *"read why: coredumpctl list tmux"* ]]; then
  echo "   ├─ E. the mute 🌙 counts the corpse and the shy server, each once, and names coredumpctl ✔"
  _snap E "$out"
else
  echo "   ├─ E. no mute 🌙 that counts the corpse and the shy server" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  failed=$(( failed + 1 ))
fi
if [[ "$out" == *"1 live server(s) did not name their build"* ]]; then
  echo "   ├─ F. a live server with no build named: its own 🌙, not hidden by the mute count ✔"
  _snap F "$(printf '%s\n' "$out" | grep -e 'did not answer' -e 'did not name their build')"
else
  echo "   ├─ F. no 🌙 that counts the one server with no build named" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  failed=$(( failed + 1 ))
fi
rm -f "$PROBE_DIR/tmux-$(id -u)/corpse" "$PROBE_DIR/tmux-$(id -u)/ghost"

# C. with the prior server gone, a clean read says so — never a silence a reader must infer from
timeout -k 2 5 "$PRIOR_BIN" -L prior kill-server </dev/null >/dev/null 2>&1
out="$(PATH="$PIN_PATH:$PATH" GROVE_ENV_SERVER=cloud@aws.ec2 \
  grove_provision_2_8_tmux_verify_live_servers "$PROBE_DIR/no.conf" tmux-256color 2>&1)"
if [[ "$out" == *"1 live server(s) run the pinned build ($GROVE_UPGRADE_2_8_TMUX_VERSION) ✔"* \
  && "$out" != *"older than the pin"* ]]; then
  echo "   ├─ C. every server on the pin: the ✔ names the count ✔"
  _snap C "$out"
else
  echo "   ├─ C. no ✔ that counts the servers on the pin" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  failed=$(( failed + 1 ))
fi

# G. every socket a corpse — the state a diagnoser meets after a crash with no revive: the read
#   says no server is up, names the corpse once, and grades no live claim over zero servers
fresh_pid="$(timeout -k 2 5 "$PIN_BIN" -L fresh display-message -p '#{pid}' </dev/null 2>/dev/null)"
[[ -n "$fresh_pid" ]] && kill -9 "$fresh_pid" 2>/dev/null
for _ in $(seq 1 20); do kill -0 "$fresh_pid" 2>/dev/null || break; sleep 0.1; done
out="$(PATH="$PIN_PATH:$PATH" GROVE_ENV_SERVER=cloud@aws.ec2 \
  grove_provision_2_8_tmux_verify_live_servers "$PROBE_DIR/no.conf" tmux-256color 2>&1)"
# the corpse count is pinned by the snap; the phrase grades the claim alone
if [[ "$out" == *"no tmux server up"* && "$out" == *"socket(s) did not answer"* \
  && "$out" != *"every live server holds"* && "$out" != *"✔"* ]]; then
  echo "   ├─ G. every socket a corpse: no server up, the corpses named once, no ✔ over none ✔"
  _snap G "$out"
else
  echo "   ├─ G. every socket a corpse, yet the read graded a live claim or missed the corpse" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  failed=$(( failed + 1 ))
fi

echo ""
[[ "$failed" -eq 0 ]] || { echo "   💥 MalfunctionError: $failed arm(s) failed" >&2; exit 1; }
echo "   ✔ the verify names each live server behind the pin, and only those"
