#!/usr/bin/env bash
######################################################################
# .what = prove `2.8.tmux`'s pin upsert converges, declines, or refuses, and
#         that no refusal ever touches the prior tmux a crew runs on
#
# .why this play exists
#   - a grove's crews all hang off one tmux binary; an upsert that leaves that
#     path half-written, or swaps it in place under a live server, ends every
#     crew at once — the very defect the pin exists to cure (vision cases 3, 7, 8)
#
# .the arms — each in a subshell, over a temp stand-in for the pin path
#   - P. a tmux at the pin already on PATH        → rc 0, no fetch
#   - D. a seat with no root                      → rc 0 (🌙), no fetch
#   - T. the toolchain does not install           → ✋, no fetch
#   - F. the fetch fails                          → ✋ names the url
#   - M. the bytes miss the digest                → ✋, no build attempted
#   - B. the build fails                          → ✋ names the build log
#   - W. no temp dir for the build                → ✋, prior kept
#   - G. no dir for the build log                 → ✋, prior kept
#   - X. the swap is refused                      → ✋, no stage file left behind
#   - S. a build lands                            → rc 0, the new bytes at the path
#   - L. a swap under a LIVE process              → the process lives on, on the
#                                                   old inode; the path holds the new
#   in every ✋ arm the stand-in keeps the prior bytes
#
# .what is real and what is stubbed
#   - REAL: the upsert orchestrator, its four steps, `web_verify_sha256`,
#     `tar`, `install`, `mv`
#   - stubbed: `web_fetch` (it copies fixture bytes, so no network is read),
#     `pkg_install` and `bundle.root.owns` (no apt, no sudo); `sudo` runs its
#     command as this seat, minus the `-o root -g root` it cannot satisfy
#   - a fake `tmux` leads PATH, so the upsert sees whichever build an arm names
#
# usage:
#   rhx play.run --play prove.tmux-pin-upsert-fails-safe
#
# exit:
#   0 = every arm holds
#   1 = an arm failed, or the bundle builds no pin — each named
#   2 = no checkout, or the bundle could not be sourced
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
_dir="$GROVE_SRC/grove.provision/2.shell/2.8.tmux"

echo "🔎 prove.tmux-pin-upsert-fails-safe"
echo "   └─ root: $_root"
echo ""

# shellcheck source=/dev/null
source "$GROVE_SRC/grove.web.sh" || { echo "   ✋ ConstraintError: could not source grove.web.sh" >&2; exit 2; }
for _f in _.sh provision.upsert.sh; do
  # shellcheck source=/dev/null
  source "$_dir/$_f" || { echo "   ✋ ConstraintError: could not source $_dir/$_f" >&2; exit 2; }
done
for _fn in grove_provision_2_8_tmux_pin_upsert grove_provision_2_8_tmux_pin_install; do
  declare -F "$_fn" >/dev/null || { echo "   💥 MalfunctionError: no $_fn — the bundle builds no pin" >&2; exit 1; }
done

FIX="$(mktemp -d "${TMPDIR:-/tmp}/prove.tmux-pin-upsert.XXXXXX")"
BAIT_PID=""
_teardown() {
  [[ -n "$BAIT_PID" ]] && kill "$BAIT_PID" 2>/dev/null
  rm -rf "$FIX"
}
trap _teardown EXIT

PRIOR="$FIX/prior/tmux"
LOG_REL=".local/state/grove.provision/2.8.tmux.build.log"
PRIOR_BYTES="the prior build"

######################################################################
# the stubs — no network, no apt, no root
######################################################################
web_fetch() {
  touch "$FIX/fetched"
  [[ "${FETCH_FAILS:-}" == yes ]] && return 1
  cp "$FIX/bytes" "$3"
}
pkg_install() { return 0; }
bundle.root.owns() { return 0; }
grove_provision_2_8_tmux_pin_dst() { printf '%s' "$PRIOR"; }

# .what = run the given command as this seat, minus the root owner flags
sudo() {
  local args=() skip=0 arg
  for arg in "$@"; do
    [[ "$skip" -gt 0 ]] && { skip=$(( skip - 1 )); continue; }
    [[ "$arg" == -o || "$arg" == -g ]] && { skip=1; continue; }
    args+=("$arg")
  done
  "${args[@]}"
}

# .what = a fake `tmux` on PATH that answers `-V` with the given version
_fake() {
  printf '#!/usr/bin/env bash\n[[ "${1:-}" == -V ]] && echo "tmux %s"\nexit 0\n' "$1" > "$FIX/bin/tmux"
  chmod +x "$FIX/bin/tmux"
}

# .what = a fresh world per arm: the prior bytes, an empty home, an adrift tmux
_reset() {
  rm -rf "$FIX/home" "$FIX/fetched" "$FIX/prior"
  mkdir -p "$FIX/home" "$FIX/prior" "$FIX/bin"
  printf '%s\n' "$PRIOR_BYTES" > "$PRIOR"
  printf 'not a tarball\n' > "$FIX/bytes"
  _fake 3.2a
}

# .what = the digest of the fixture bytes, so an arm can pass the integrity check
_bytes_digest() { printf 'sha256:%s' "$(sha256sum "$FIX/bytes" | cut -d' ' -f1)"; }

# .what = run the upsert as a grove sees it; stdout and stderr in one
_upsert() { PATH="$FIX/bin:$PATH" HOME="$FIX/home" grove_provision_2_8_tmux_pin_upsert 2>&1; }

failed=0

# .what = grade one arm: its exit, a phrase its output must hold, and the prior bytes
#   usage: _grade <label> <rc> <want rc> <output> <phrase> <prior: kept|replaced>
_grade() {
  local label="$1" rc="$2" want="$3" out="$4" phrase="$5" prior="$6"
  local held=yes
  [[ "$rc" -eq "$want" ]] || held="rc=$rc, want $want"
  [[ "$held" == yes && "$out" != *"$phrase"* ]] && held="no '$phrase' in the output"
  [[ "$held" == yes && "$prior" == kept && "$(cat "$PRIOR" 2>/dev/null)" != "$PRIOR_BYTES" ]] \
    && held="the prior tmux CHANGED"
  [[ "$held" == yes ]] && { echo "   ├─ $label ✔"; return 0; }
  echo "   ├─ $label: $held" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  return 1
}

# .what = an arm that must not reach the wire
_unfetched() {
  [[ ! -e "$FIX/fetched" ]] && return 0
  echo "   │  └─ $1: the wire was read, and this arm owed no fetch" >&2
  return 1
}

######################################################################
# P. a tmux at the pin already on PATH
######################################################################
_reset; _fake "$GROVE_UPGRADE_2_8_TMUX_VERSION"
out="$(_upsert)"; rc=$?
_grade "P. already at the pin: skip" "$rc" 0 "$out" "already at the pin" kept && _unfetched P \
  || failed=$(( failed + 1 ))

######################################################################
# D. a seat with no root declines
######################################################################
_reset
out="$( bundle.root.owns() { echo "   🌙 no root on this seat"; return 1; }; _upsert )"; rc=$?
_grade "D. no root: decline" "$rc" 0 "$out" "no root" kept && _unfetched D \
  || failed=$(( failed + 1 ))

######################################################################
# T. the toolchain does not install
######################################################################
_reset
out="$( pkg_install() { return 1; }; _upsert )"; rc=$?
_grade "T. no toolchain: ✋" "$rc" 1 "$out" "toolchain did not install" kept && _unfetched T \
  || failed=$(( failed + 1 ))

######################################################################
# F. the fetch fails
######################################################################
_reset
out="$( FETCH_FAILS=yes _upsert )"; rc=$?
_grade "F. fetch fails: ✋" "$rc" 1 "$out" "could not fetch" kept \
  || failed=$(( failed + 1 ))

######################################################################
# M. the bytes miss the digest — the bytes must never reach a compiler
######################################################################
_reset
out="$( GROVE_UPGRADE_2_8_TMUX_SHA256="sha256:$(printf '0%.0s' {1..64})"; _upsert )"; rc=$?
_grade "M. digest miss: ✋" "$rc" 1 "$out" "did NOT match its declared digest" kept \
  || failed=$(( failed + 1 ))
[[ ! -e "$FIX/home/$LOG_REL" ]] \
  || { echo "   │  └─ M: a build log exists — the bytes reached a compiler" >&2; failed=$(( failed + 1 )); }

######################################################################
# B. the build fails (the bytes pass the digest, and are no tarball)
######################################################################
_reset
out="$( GROVE_UPGRADE_2_8_TMUX_SHA256="$(_bytes_digest)"; _upsert )"; rc=$?
_grade "B. build fails: ✋ names its log" "$rc" 1 "$out" "$LOG_REL" kept \
  || failed=$(( failed + 1 ))

######################################################################
# W. no temp dir for the build
######################################################################
_reset
out="$( GROVE_UPGRADE_2_8_TMUX_SHA256="$(_bytes_digest)"; web_tempdir() { return 1; }; _upsert )"; rc=$?
_grade "W. no temp dir: ✋" "$rc" 1 "$out" "no temp dir for the tmux build" kept \
  || failed=$(( failed + 1 ))

######################################################################
# G. no dir for the build log (a FILE sits where its parent dir must go)
######################################################################
_reset
printf 'not a dir\n' > "$FIX/home/.local"
out="$( GROVE_UPGRADE_2_8_TMUX_SHA256="$(_bytes_digest)"; _upsert )"; rc=$?
_grade "G. no log dir: ✋" "$rc" 1 "$out" "no dir for the tmux build log" kept \
  || failed=$(( failed + 1 ))

######################################################################
# X. the swap is refused — no stage file may be left beside the pin
######################################################################
_reset
out="$(
  GROVE_UPGRADE_2_8_TMUX_SHA256="$(_bytes_digest)"
  grove_provision_2_8_tmux_pin_build() { mkdir -p "$4/tmux-$GROVE_UPGRADE_2_8_TMUX_VERSION"; printf 'new\n' > "$4/tmux-$GROVE_UPGRADE_2_8_TMUX_VERSION/tmux"; }
  sudo() { [[ "$1" == rm ]] && { "$@"; return; }; return 1; }
  _upsert
)"; rc=$?
_grade "X. swap refused: ✋" "$rc" 1 "$out" "could not be placed" kept \
  || failed=$(( failed + 1 ))
[[ ! -e "$PRIOR.grove-provision.new" ]] \
  || { echo "   │  └─ X: a stage file was left beside the pin" >&2; failed=$(( failed + 1 )); }

######################################################################
# S. a build lands
######################################################################
_reset
out="$(
  GROVE_UPGRADE_2_8_TMUX_SHA256="$(_bytes_digest)"
  grove_provision_2_8_tmux_pin_build() { mkdir -p "$4/tmux-$GROVE_UPGRADE_2_8_TMUX_VERSION"; printf 'the new build\n' > "$4/tmux-$GROVE_UPGRADE_2_8_TMUX_VERSION/tmux"; }
  _upsert
)"; rc=$?
_grade "S. a build lands: the new bytes at the pin path" "$rc" 0 "$out" "built →" replaced \
  || failed=$(( failed + 1 ))
[[ "$(cat "$PRIOR" 2>/dev/null)" == "the new build" ]] \
  || { echo "   │  └─ S: the pin path does not hold the new build" >&2; failed=$(( failed + 1 )); }

######################################################################
# L. a swap under a LIVE process — a crew server must keep the binary it runs
######################################################################
_arm_live() {
  _reset
  # a cp onto the extant stand-in keeps its 0644 mode, so the bait is placed fresh
  rm -f "$PRIOR"
  install -m 0755 "$(command -v sleep)" "$PRIOR"
  "$PRIOR" 600 &
  BAIT_PID=$!
  # the bait must have EXEC'd the prior binary, so it holds the text the swap
  # meets; a live pid alone proves only the fork. polled, never one fixed sleep
  local tick
  for tick in $(seq 1 20); do
    [[ "$(readlink "/proc/$BAIT_PID/exe" 2>/dev/null)" == "$PRIOR" ]] && break
    sleep 0.25
  done
  [[ "$(readlink "/proc/$BAIT_PID/exe" 2>/dev/null)" == "$PRIOR" ]] \
    || { echo "   ├─ L: 💥 MalfunctionError: the bait did not exec the prior build within 5s — no world measured" >&2; return 1; }

  printf 'the new build\n' > "$FIX/new"
  local out rc
  out="$(grove_provision_2_8_tmux_pin_install --from "$FIX/new" --into "$PRIOR" 2>&1)"; rc=$?
  [[ "$rc" -eq 0 ]] || { echo "   ├─ L: the swap failed (rc=$rc): $out" >&2; return 1; }
  kill -0 "$BAIT_PID" 2>/dev/null || { echo "   ├─ L: the live process DIED at the swap" >&2; return 1; }
  [[ "$(readlink "/proc/$BAIT_PID/exe")" == *"(deleted)" ]] \
    || { echo "   ├─ L: the live process does not run the old inode" >&2; return 1; }
  [[ "$(cat "$PRIOR")" == "the new build" ]] \
    || { echo "   ├─ L: the pin path does not hold the new build" >&2; return 1; }
  echo "   └─ L. swap under a live process: it lives on the old inode, the path holds the new ✔"
}
_arm_live || failed=$(( failed + 1 ))

echo ""
[[ "$failed" -eq 0 ]] || { echo "   💥 MalfunctionError: $failed arm(s) failed" >&2; exit 1; }
echo "   ✔ the pin upsert converges, declines, or refuses — and a refusal never touches the prior tmux"
