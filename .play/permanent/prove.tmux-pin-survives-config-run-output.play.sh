#!/usr/bin/env bash
######################################################################
# .what = prove which tmux builds survive a fresh server whose config's
#         `run-shell` prints output, and the box's real ~/.tmux.conf
#
# .why this play exists
#   - a grove's crews lost every seat at once: the shared tmux SERVER
#     segfaulted, ~110 times in hours, at one offset in the jammy package
#     (`tmux 3.2a-4ubuntu0.2`), often as a fresh server that died at once
#   - tmux's own CHANGES for 3.3a reads: "Do not crash when run-shell produces
#     output from a config file" — and this repo's conf ends with
#     `run '~/.tmux/plugins/tpm/tpm'`
#   - ⇒ this play is the reproduction: each arm starts ONE fresh server on an
#     isolated socket dir, then asks whether it is still alive
#
# .the arms
#   - A. `run-shell 'echo …'` in a throwaway conf — the CHANGES line, alone
#   - B. the box's real ~/.tmux.conf — the conf the crews actually load
#   each arm runs against every tmux build present on the box: the pinned
#   build (`/usr/local/bin/tmux`) and the distro package (`/usr/bin/tmux`)
#
# .what it does to the box
#   - every server lives under a private `TMUX_TMPDIR`, so no live crew socket
#     is reachable from it; each is killed, and the dir removed, on EXIT
#   - a server that segfaults leaves a kernel log line and, where
#     systemd-coredump is present, a core. both are the evidence sought
#
# usage:
#   rhx play.run --play prove.tmux-pin-survives-config-run-output
#
# exit:
#   0 = the pinned build survives every arm
#   1 = the pinned build died in an arm
#   2 = no pinned build, or no ~/.tmux.conf, on this box — no claim was proven
######################################################################

set -uo pipefail

######################################################################
# the pin's path is SOURCED from the bundle that owns it, never copied
######################################################################
# .what = the checkout under proof — `PROVE_ROOT` (the red half), this play's own, or the cwd
_root_of() {
  [[ -n "${PROVE_ROOT:-}" ]] && { printf '%s' "$PROVE_ROOT"; return 0; }
  local self; self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
  [[ -n "$self" && -f "$self/src/grove.provision._.sh" ]] && { printf '%s' "$self"; return 0; }
  [[ -f "$PWD/src/grove.provision._.sh" ]] && { printf '%s' "$PWD"; return 0; }
  return 1
}
_root="$(_root_of)" || { echo "   ✋ no checkout found" >&2; exit 2; }
# shellcheck source=/dev/null
source "$_root/src/grove.provision/2.shell/2.8.tmux/_.sh" \
  || { echo "   ✋ could not source 2.8.tmux/_.sh" >&2; exit 2; }
declare -F grove_provision_2_8_tmux_pin_dst >/dev/null \
  || { echo "   ✋ the bundle declares no pin — there is no build to prove" >&2; exit 1; }

PIN_BIN="$(grove_provision_2_8_tmux_pin_dst)"
DISTRO_BIN="/usr/bin/tmux"   # the jammy package path; a reproduction arm, never graded
CONF_REAL="$HOME/.tmux.conf"

echo "🔎 prove.tmux-pin-survives-config-run-output"
echo "   └─ subject: a fresh tmux server, per build, per conf"
echo ""

[[ -x "$PIN_BIN" ]] || {
  echo "   ✋ no pinned tmux at $PIN_BIN" >&2
  echo "      fix: sudo -v && rhx grove.provision --what 2.8.tmux --mode apply" >&2
  exit 2
}

# the real conf IS the claim's second arm; without it the pin is half-proven
[[ -f "$CONF_REAL" ]] || {
  echo "   ✋ no ~/.tmux.conf, so the arm the crews load cannot run" >&2
  echo "      fix: rhx grove.provision --what 2.8.tmux --mode apply" >&2
  exit 2
}

######################################################################
# the private socket dir, and its unconditional teardown
######################################################################
PROBE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/prove.tmux.XXXXXX")"
export TMUX_TMPDIR="$PROBE_DIR"
unset TMUX

_teardown() {
  local bin
  for bin in "$PIN_BIN" "$DISTRO_BIN"; do
    [[ -x "$bin" ]] && timeout -k 2 5 "$bin" kill-server </dev/null >/dev/null 2>&1
  done
  rm -rf "$PROBE_DIR"
}
trap _teardown EXIT

CONF_ECHO="$PROBE_DIR/echo.conf"
printf "run-shell 'echo probe-output'\n" > "$CONF_ECHO"

######################################################################
# .what = start one fresh server, then ask whether it is still alive
#
# stdout: `alive <server version>` | `died` | `nostart`
#   the pinned arms pass only on `alive <pin>`: a server that lives but whose
#   `#{version}` read comes back empty would leave configure.verify's 🌙 blind
#
# .why a POLL and never one fixed sleep
#   - the crash this play reproduces lands as the conf's `run-shell` returns,
#     which on a busy box can trail the start by more than a fixed wait
#   - ⇒ the server is asked once a quarter-second for 3s; a death in that span
#     ends the poll early, and a survivor is read only after the span closes
######################################################################
_probe() {
  local bin="$1" conf="$2" sock="$3" tick
  timeout -k 2 10 "$bin" -L "$sock" -f "$conf" new-session -d -s probe </dev/null >/dev/null 2>&1 \
    || { echo nostart; return 0; }

  for tick in $(seq 1 12); do
    timeout -k 2 5 "$bin" -L "$sock" has-session -t probe </dev/null >/dev/null 2>&1 \
      || { echo died; return 0; }
    sleep 0.25
  done

  # the SERVER's own version, read with no client attached — the exact read
  # `2.8.tmux`'s configure.verify makes per live socket (vision case 10)
  echo "alive $(timeout -k 2 5 "$bin" -L "$sock" display-message -p '#{version}' </dev/null 2>/dev/null)"
  timeout -k 2 5 "$bin" -L "$sock" kill-server </dev/null >/dev/null 2>&1
}

fails=0

for bin in "$PIN_BIN" "$DISTRO_BIN"; do
  [[ -x "$bin" ]] || { echo "   🌙 $bin absent; its arms are skipped"; continue; }
  ver="$(timeout -k 2 5 "$bin" -V </dev/null 2>/dev/null)"
  echo "   ├─ $bin ($ver)"

  for arm in echo real; do
    conf="$CONF_ECHO"; [[ "$arm" == real ]] && conf="$CONF_REAL"
    verdict="$(_probe "$bin" "$conf" "probe_${arm}_$$")"
    echo "   │  ├─ arm $arm: $verdict"

    # only the PINNED build's survival is this play's claim; the distro arms
    # are the reproduction, reported but never graded
    [[ "$bin" == "$PIN_BIN" && "$verdict" != "alive $GROVE_UPGRADE_2_8_TMUX_VERSION" ]] \
      && fails=$(( fails + 1 ))
  done
done

echo ""
[[ "$fails" -eq 0 ]] || { echo "   ✋ the pinned build died in $fails arm(s)" >&2; exit 1; }
echo "   ✔ the pinned build survives every arm"
exit 0
