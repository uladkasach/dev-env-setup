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
#
# usage:
#   rhx play.run --play prove.tmux-verify-refuses-an-unpinned-build
#
# exit:
#   0 = every arm holds
#   1 = an arm failed, and which is named
#   2 = the bundle is out of reach
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
  echo "   ✋ ConstraintError: the bundle declares no GROVE_UPGRADE_2_8_TMUX_VERSION — no pin to grade" >&2
  exit 1
}

FAKE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/prove.tmux-verify.XXXXXX")"
trap 'rm -rf "$FAKE_DIR"' EXIT

# .what = put a fake `tmux` that answers `-V` with the given version
_fake() {
  printf '#!/usr/bin/env bash\n[[ "${1:-}" == -V ]] && echo "tmux %s"\nexit 0\n' "$1" > "$FAKE_DIR/tmux"
  chmod +x "$FAKE_DIR/tmux"
}

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
  [[ "$out" == *"$phrase"* ]] && { echo "   ├─ $label ✔"; return 0; }
  echo "   ├─ $label: no '$phrase' in the output" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  return 1
}

out="$(_run 3.2a cloud@aws.ec2)"
_grade "A. cloud, 3.2a: ✋ names the pin" "$out" "not the pinned $GROVE_UPGRADE_2_8_TMUX_VERSION" \
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
out="$(PATH="$NO_TMUX" GROVE_ENV_SERVER=cloud@aws.ec2 grove_provision_2_8_tmux_provision_verify 2>&1)"
_grade "D. no tmux on PATH: ✋ says so" "$out" "tmux is not on PATH" \
  || failed=$(( failed + 1 ))
_grade "D. no tmux on PATH: ✋ names the fix" "$out" "--what 2.8.tmux --mode apply" \
  || failed=$(( failed + 1 ))

echo ""
[[ "$failed" -eq 0 ]] || { echo "   ✋ ConstraintError: $failed arm(s) failed" >&2; exit 1; }
echo "   ✔ the verify refuses every tmux but the pin, on a grove only"
