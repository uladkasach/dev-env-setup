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
#   - B. the 🌙 does not name `fresh`
#
# usage:
#   rhx play.run --play prove.tmux-verify-names-a-server-behind-the-pin
#
# exit:
#   0 = both arms hold
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

######################################################################
# the private socket dir, the pin first on PATH, and an unconditional teardown
######################################################################
PROBE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/prove.tmux-behind.XXXXXX")"
PIN_PATH="$PROBE_DIR/bin"
mkdir -p "$PIN_PATH"
ln -s "$PIN_BIN" "$PIN_PATH/tmux"
export TMUX_TMPDIR="$PROBE_DIR"
unset TMUX

_teardown() {
  timeout -k 2 5 "$PRIOR_BIN" -L prior kill-server </dev/null >/dev/null 2>&1
  timeout -k 2 5 "$PIN_BIN" -L fresh kill-server </dev/null >/dev/null 2>&1
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

# A. the prior server is named, at its own version
[[ "$out" == *"build older than the pin"* && "$out" == *"prior=$PRIOR_VER"* ]] && \
  echo "   ├─ A. the 🌙 names prior=$PRIOR_VER ✔"
[[ "$out" == *"build older than the pin"* && "$out" == *"prior=$PRIOR_VER"* ]] || {
  echo "   ├─ A. no 🌙 that names prior=$PRIOR_VER" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  failed=$(( failed + 1 ))
}

# B. the fresh server, on the pin, is not named
[[ "$out" != *"fresh="* ]] && echo "   └─ B. the fresh server, on the pin, is not named ✔"
[[ "$out" != *"fresh="* ]] || {
  echo "   └─ B. the fresh server was named, though it runs the pin" >&2
  failed=$(( failed + 1 ))
}

echo ""
[[ "$failed" -eq 0 ]] || { echo "   💥 MalfunctionError: $failed arm(s) failed" >&2; exit 1; }
echo "   ✔ the verify names each live server behind the pin, and only those"
