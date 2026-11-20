#!/usr/bin/env bash
######################################################################
# .what = prove 5.25.purpose findserts `~/.grove/purpose` the way the crew boot
#         gate reads it, and declines where it owns no marker
#
# .why  = the gate fails CLOSED on a box with no marker, so a rebuilt hetzner grove
#         that lost its home would refuse every queued sprout. the bundle is what
#         carries the marker across a rebuild — this proves it writes, converges,
#         and never overwrites a stated purpose
#
# .the rows
#   1. hetzner camp, no marker  — writes `work`; the gate-shaped read returns `work`
#   2. a second run             — a no-op
#   3. a stated `lab`           — kept
#   4. ec2, laptop, admin seat  — decline, no file written
#   5. verify on an absent marker — ✋ that names the fix
#
# .what it does to the box
#   - none: every write lands under a throwaway HOME, removed on exit
#
# usage:
#   rhx play.run --play prove.purpose-marker-is-findserted
#
# exit:
#   0 = every claim held · 1 = a claim failed · 2 = the subject is unreadable
######################################################################

set -uo pipefail

echo "🔎 prove.purpose-marker-is-findserted"
echo "   └─ subject: 5.25.purpose"
echo ""

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[[ -n "$ROOT" ]] || { echo "   └─ ✋ ConstraintError: not inside a git checkout" >&2; exit 2; }
BUNDLE="$ROOT/src/grove.provision/5.devtools/5.25.purpose"
[[ -f "$BUNDLE/_.sh" ]] || { echo "   └─ ✋ ConstraintError: the subject is absent: $BUNDLE" >&2; exit 2; }

failed=0; passed=0
claim() {
  local label="$1"; shift
  if "$@"; then echo "   ✔ $label"; passed=$((passed + 1)); return 0; fi
  echo "   💥 MalfunctionError: $label" >&2; failed=$((failed + 1))
}
has() { [[ "$1" == *"$2"* ]]; }

FIX="$(mktemp -d)" || { echo "   └─ 💥 MalfunctionError: could not build a fixture dir" >&2; exit 1; }
trap 'rm -rf "$FIX"' EXIT

# .what = run one phase under a fresh-or-kept fake HOME, as a given server and seat
#   - args: <home> <server> <seat> <phase fn>; prints the phase's output, then rc
phase() {
  local home="$1" server="$2" seat="$3" fn="$4"
  ( export HOME="$home" GROVE_ENV_SERVER="$server" GROVE_ENV_SEAT="$seat"
    # shellcheck disable=SC1091
    source "$ROOT/src/grove.env.sh" >/dev/null 2>&1
    for f in _.sh configure.upsert.sh configure.verify.sh; do
      # shellcheck disable=SC1090
      source "$BUNDLE/$f"
    done
    "$fn"; echo "rc=$?"
  ) 2>&1
}
gate_read() { HOME="$1" sh -c 'cat ~/.grove/purpose 2>/dev/null | head -1' | tr -d '[:space:]'; }

UP=grove_provision_5_25_purpose_configure_upsert
VE=grove_provision_5_25_purpose_configure_verify

######################################################################
# rows 1-3 — hetzner camp
######################################################################
H="$FIX/hetzner"; mkdir -p "$H"
out="$(phase "$H" cloud@hetzner.hetzbot camper "$UP")"
claim "1a. a home with no marker gets one" has "$out" "purpose declared 'work'"
claim "1b. the gate-shaped read returns work" [ "$(gate_read "$H")" == "work" ]
out="$(phase "$H" cloud@hetzner.hetzbot camper "$VE")"
claim "1c. verify passes" has "$out" "rc=0"
out="$(phase "$H" cloud@hetzner.hetzbot camper "$UP")"
claim "2.  a second run is a no-op" has "$out" "already 'work'"
printf 'lab\n' > "$H/.grove/purpose"
out="$(phase "$H" cloud@hetzner.hetzbot camper "$UP")"
claim "3a. a stated lab is reported as kept" has "$out" "kept"
claim "3b. and the file still reads lab" [ "$(gate_read "$H")" == "lab" ]

######################################################################
# row 4 — declines write no file
######################################################################
for row in "cloud@aws.ec2 camper ec2" "local@unix human laptop" "cloud@hetzner.hetzbot ground admin"; do
  read -r server seat label <<< "$row"
  D="$FIX/$label"; mkdir -p "$D"
  out="$(phase "$D" "$server" "$seat" "$UP")"
  claim "4.  $label declines, and writes no marker" bash -c '[[ "$1" == *"declined"* && ! -e "$2/.grove/purpose" ]]' _ "$out" "$D"
done

######################################################################
# row 5 — verify on an absent marker
######################################################################
A="$FIX/absent"; mkdir -p "$A"
out="$(phase "$A" cloud@hetzner.hetzbot camper "$VE")"
claim "5a. verify fails on an absent marker" has "$out" "rc=1"
claim "5b. and names the fix" has "$out" "--what 5.25.purpose --mode apply"

echo ""
echo "🌊 $passed held · $failed failed"
[[ "$failed" -eq 0 ]] || exit 1
exit 0
