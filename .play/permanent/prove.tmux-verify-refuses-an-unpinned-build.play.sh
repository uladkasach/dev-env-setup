#!/usr/bin/env bash
######################################################################
# .what = prove `2.8.tmux`'s verify refuses, on a grove, any tmux but the pin
#
# .why this play exists
#   - a grove ran the distro tmux 3.2a, whose server segfaulted and ended every
#     crew at once; the verify printed `tmux present (3.2a) ✔` over it
#   - ⇒ a verify that grades presence cannot see the defect the pin cures
#
# .the arms — a FAKE tmux first on PATH, so no real binary is graded
#   - A. cloud, `tmux 3.2a`  → the verify must ✋ and name the pin
#   - B. cloud, `tmux <pin>` → the binary claim must ✔
#   - C. laptop, `tmux 3.2a` → the binary claim must ✔ (the pin is grove-scoped)
#   - D. cloud, no tmux on PATH → the verify must ✋ and name the fix
#   - D2. cloud, the pin placed, PATH holds no tmux → the ✋ names PATH, never an apply
#   - E. laptop, a tmux mute to `-V` → the verify must ✋, never `present ✔`
#   - F. cloud, the pin placed but a 3.2a shadows it on PATH → the ✋ names the shadow
#   - T1 / T2. the pin passes, the conf's tpm is adrift / a carcass → each ✋ is snapped
#
# usage:
#   rhx play.run --play prove.tmux-verify-refuses-an-unpinned-build
#
# exit:
#   0 = every arm holds
#   1 = an arm failed, or the bundle declares no pin — each named
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

echo "🔎 prove.tmux-verify-refuses-an-unpinned-build"
echo "   └─ root: $_root"
echo ""

for _f in _.sh provision.verify.sh; do
  # shellcheck source=/dev/null
  source "$_dir/$_f" || { echo "   ✋ ConstraintError: could not source $_dir/$_f" >&2; exit 2; }
done

[[ -n "${GROVE_UPGRADE_2_8_TMUX_VERSION:-}" ]] || {
  echo "   💥 MalfunctionError: the bundle declares no GROVE_UPGRADE_2_8_TMUX_VERSION — no pin to grade" >&2
  exit 1
}

# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/.snap.operations.sh"

FAKE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/prove.tmux-verify.XXXXXX")"
trap 'rm -rf "$FAKE_DIR"' EXIT

# .what = put a fake `tmux` that answers `-V` with the given version
_fake() {
  printf '#!/usr/bin/env bash\n[[ "${1:-}" == -V ]] && echo "tmux %s"\nexit 0\n' "$1" > "$FAKE_DIR/tmux"
  chmod +x "$FAKE_DIR/tmux"
}

# .what = the tpm half reads a fixture, never this box's own ~/.tmux, so its rows snap alike
#   on every box; `TPM_STATE` picks the state an arm grades (`whole` unless an arm names one)
grove_provision_2_8_tmux_tpm_bin_of_conf() { printf '%s' "$FAKE_DIR/tpm/tpm"; }
grove_provision_2_8_tmux_tpm_state() { printf '%s' "${TPM_STATE:-whole}"; }

failed=0

# .what = run the verify under a fake tmux and a server tier; stdout+stderr in one
_run() {
  local ver="$1" server="$2"
  _fake "$ver"
  PATH="$FAKE_DIR:$PATH" GROVE_ENV_SERVER="$server" \
    grove_provision_2_8_tmux_provision_verify 2>&1
}

# .what = grade one arm: the phrase the verify's output must hold
_grade() {
  local label="$1" out="$2" phrase="$3"
  # the phrase holds → snap the whole message, keyed by the arm id (`A`, `D2`, …)
  [[ "$out" == *"$phrase"* ]] && {
    play_snap_assert arm="${label%%.*}" rendered="$out" mask="$FAKE_DIR" mask="$HOME" || return 1
    echo "   ├─ $label ✔"
    return 0
  }
  echo "   ├─ $label: no '$phrase' in the output" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  return 1
}

# A. no pin placed yet — the pin path holds no build (this box's own pin would shadow-test instead)
out="$(
  grove_provision_2_8_tmux_pin_dst() { printf '%s' "$FAKE_DIR/no-pin/tmux"; }
  _run 3.2a cloud@aws.ec2
)"
_grade "A. cloud, 3.2a: ✋ names the pin" "$out" "not the pinned $GROVE_UPGRADE_2_8_TMUX_VERSION" \
  || failed=$(( failed + 1 ))
_grade "A. cloud, 3.2a: ✋ names the fix" "$out" "fix: sudo -v && rhx grove.provision --what 2.8.tmux --mode apply" \
  || failed=$(( failed + 1 ))

out="$(_run "$GROVE_UPGRADE_2_8_TMUX_VERSION" cloud@aws.ec2)"
_grade "B. cloud, $GROVE_UPGRADE_2_8_TMUX_VERSION: the pin passes" "$out" "tmux present ($GROVE_UPGRADE_2_8_TMUX_VERSION" \
  || failed=$(( failed + 1 ))

out="$(_run 3.2a local@unix)"
_grade "C. laptop, 3.2a: passes (the pin is grove-scoped)" "$out" "tmux present (3.2a" \
  || failed=$(( failed + 1 ))

# D. no tmux at all: a PATH that holds every tool this box has, save tmux
#   - a link farm rather than a stubbed reader, so the real `command -v` answers
NO_TMUX="$FAKE_DIR/no-tmux"
mkdir -p "$NO_TMUX"
IFS=: read -ra _path_dirs <<<"$PATH"
for _d in "${_path_dirs[@]}"; do
  for _x in "$_d"/*; do
    [[ -x "$_x" && ! -d "$_x" ]] || continue
    [[ "${_x##*/}" == tmux ]] && continue
    [[ -e "$NO_TMUX/${_x##*/}" ]] || ln -s "$_x" "$NO_TMUX/${_x##*/}"
  done
done
#   - the pin path is a fixture too, so this box's own placed pin never changes the arm
out="$(
  grove_provision_2_8_tmux_pin_dst() { printf '%s' "$FAKE_DIR/no-pin/tmux"; }
  PATH="$NO_TMUX" GROVE_ENV_SERVER=cloud@aws.ec2 grove_provision_2_8_tmux_provision_verify 2>&1
)"
_grade "D. no tmux on PATH: ✋ says so" "$out" "tmux is not on PATH" \
  || failed=$(( failed + 1 ))
_grade "D. no tmux on PATH: ✋ names the fix" "$out" "--what 2.8.tmux --mode apply" \
  || failed=$(( failed + 1 ))

# D2. the pin is placed, and PATH holds no tmux — the ✋ names PATH, never an apply the upsert
#   would refuse (its arm O)
mkdir -p "$FAKE_DIR/pin"
printf '#!/usr/bin/env bash\n[[ "${1:-}" == -V ]] && echo "tmux %s"\nexit 0\n' "$GROVE_UPGRADE_2_8_TMUX_VERSION" > "$FAKE_DIR/pin/tmux"
chmod +x "$FAKE_DIR/pin/tmux"
out="$(
  grove_provision_2_8_tmux_pin_dst() { printf '%s' "$FAKE_DIR/pin/tmux"; }
  PATH="$NO_TMUX" GROVE_ENV_SERVER=cloud@aws.ec2 grove_provision_2_8_tmux_provision_verify 2>&1
)"
_grade "D2. a placed pin off PATH: ✋ names PATH" "$out" "fix: put $FAKE_DIR/pin on PATH" \
  || failed=$(( failed + 1 ))
if [[ "$out" == *"--what 2.8.tmux --mode apply"* ]]; then
  echo "   ├─ D2. a placed pin off PATH: the ✋ names an apply the upsert would refuse" >&2
  failed=$(( failed + 1 ))
else
  echo "   ├─ D2. a placed pin off PATH: no apply named ✔"
fi

# F. the pin sits at its path, and a 3.2a earlier on PATH shadows it — the ✋ names the shadow
out="$(
  grove_provision_2_8_tmux_pin_dst() { printf '%s' "$FAKE_DIR/pin/tmux"; }
  _run 3.2a cloud@aws.ec2
)"
_grade "F. a shadowed pin: ✋ names the shadow" "$out" "but PATH resolves $FAKE_DIR/tmux first" \
  || failed=$(( failed + 1 ))

# E. a laptop whose tmux answers `-V` with naught: a file on PATH, not a binary that runs
printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKE_DIR/tmux"
chmod +x "$FAKE_DIR/tmux"
out="$(PATH="$FAKE_DIR:$PATH" GROVE_ENV_SERVER=local@unix grove_provision_2_8_tmux_provision_verify 2>&1)"
_grade "E. a mute tmux: ✋ says it does not answer" "$out" "does not answer 'tmux -V'" \
  || failed=$(( failed + 1 ))
if [[ "$out" == *"tmux present ("* ]]; then
  echo "   ├─ E. a mute tmux: graded 'present ✔' over a binary that does not run" >&2
  failed=$(( failed + 1 ))
else
  echo "   ├─ E. a mute tmux: no 'present ✔' ✔"
fi

# T1. the pin passes, and the conf's tpm sits at another commit — the ✋ names the drift
out="$(TPM_STATE=adrift _run "$GROVE_UPGRADE_2_8_TMUX_VERSION" cloud@aws.ec2)"
_grade "T1. an adrift tpm: ✋ names the drift" "$out" "tpm is present but NOT at the commit this repo declares" \
  || failed=$(( failed + 1 ))

# T2. the pin passes, and the conf's tpm path holds a carcass — the ✋ names the path
out="$(TPM_STATE=half _run "$GROVE_UPGRADE_2_8_TMUX_VERSION" cloud@aws.ec2)"
_grade "T2. a half tpm: ✋ names the path the conf runs" "$out" "no usable tpm at the path the conf runs" \
  || failed=$(( failed + 1 ))

echo ""
[[ "$failed" -eq 0 ]] || { echo "   💥 MalfunctionError: $failed arm(s) failed" >&2; exit 1; }
echo "   ✔ the verify refuses every tmux but the pin, on a grove only"
