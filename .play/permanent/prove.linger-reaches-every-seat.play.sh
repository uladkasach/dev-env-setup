#!/usr/bin/env bash
######################################################################
# .what = prove `1.6.7.linger` reads EVERY human seat, ✋s per unlingered one,
#         and grants linger seat by seat, read back before it reports ✔
#
# .why this play exists
#   - linger was a step inside `1.6.4.keyrackd`, which answered ✔ once `$USER`
#     lingered and never read another seat — so a crew seat could lack linger
#     with every verify green
#
# .the arms — a fixture passwd and a fixture logind dir, never the box's own
#   - R. a system uid and a nologin seat never enter the roster
#   - V1. verify, one seat of two lingers   → ✋ names the other, and only it
#   - V2. verify, both linger               → ✔
#   - U1. upsert, two unlingered seats      → each granted, each read back ✔
#   - U2. upsert, a grant that leaves no record → ✋ names the seat, rc 1
#   - U3, V3. a laptop (`local@unix`)       → the same grant, the same ✋ (parity)
#   - U4. upsert on a seat with no root     → decline, no grant asked
#   - U5. upsert, every seat lingers        → ✔, no grant asked
#
# .what is stubbed
#   - `sudo` runs its command as this seat; `loginctl enable-linger` writes the
#     fixture record that logind would; `bundle.root.owns` grants root
#
# usage:
#   rhx play.run --play prove.linger-reaches-every-seat
#
# exit:
#   0 = every arm holds
#   1 = an arm failed, or the bundle is absent
#   2 = no checkout found, or the bundle could not be sourced
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

_dir="$_root/src/grove.provision/1.system/1.6.procs/1.6.7.linger"

echo "🔎 prove.linger-reaches-every-seat"
echo "   └─ root: $_root"
echo ""

for _f in _.sh provision.verify.sh provision.upsert.sh; do
  [[ -f "$_dir/$_f" ]] || { echo "   ✋ ConstraintError: no $_dir/$_f — no bundle owns linger for every seat" >&2; exit 1; }
  # shellcheck source=/dev/null
  source "$_dir/$_f" || { echo "   ✋ ConstraintError: could not source $_dir/$_f" >&2; exit 2; }
done

FIX="$(mktemp -d "${TMPDIR:-/tmp}/prove.linger.XXXXXX")"
trap 'rm -rf "$FIX"' EXIT

cat > "$FIX/passwd" <<'PASSWD'
root:x:0:0:root:/root:/bin/bash
svc:x:998:998::/var/lib/svc:/bin/bash
seatone:x:1001:1001::/home/seatone:/bin/bash
seattwo:x:1002:1002::/home/seattwo:/usr/bin/zsh
quiet:x:1003:1003::/home/quiet:/usr/sbin/nologin
PASSWD
export GROVE_LINGER_PASSWD="$FIX/passwd" GROVE_LINGER_DIR="$FIX/linger"
export GROVE_ENV_SERVER="cloud@aws.ec2"

######################################################################
# the stubs — no root, no logind
######################################################################
sudo() { "$@"; }
loginctl() {
  printf '%s\n' "$2" >> "$FIX/granted"
  [[ "${GRANT_LEAVES_NO_RECORD:-}" == yes ]] && return 0
  touch "$GROVE_LINGER_DIR/$2"
}
bundle.root.owns() { return 0; }

# .what = a fresh logind dir that holds a record for each named seat
_lingered() {
  rm -rf "$GROVE_LINGER_DIR" "$FIX/granted"
  mkdir -p "$GROVE_LINGER_DIR"
  local seat
  for seat in "$@"; do touch "$GROVE_LINGER_DIR/$seat"; done
}

failed=0

# .what = grade one arm: its exit, and a phrase its output must (or must not) hold
#   usage: _grade <label> <rc> <want rc> <output> <phrase> [<absent phrase>]
_grade() {
  local label="$1" rc="$2" want="$3" out="$4" phrase="$5" absent="${6:-}"
  local held=yes
  [[ "$rc" -eq "$want" ]] || held="rc=$rc, want $want"
  [[ "$held" == yes && "$out" != *"$phrase"* ]] && held="no '$phrase' in the output"
  [[ "$held" == yes && -n "$absent" && "$out" == *"$absent"* ]] && held="'$absent' in the output"
  [[ "$held" == yes ]] && { echo "   ├─ $label ✔"; return 0; }
  echo "   ├─ $label: $held" >&2
  printf '%s\n' "$out" | sed 's/^/   │     /' >&2
  return 1
}

# .what = the seats a grant was asked for, space-joined
_granted() { tr '\n' ' ' < "$FIX/granted" 2>/dev/null; }

# .what = an arm that must ask no grant
_ungranted() {
  [[ ! -s "$FIX/granted" ]] && return 0
  echo "   │  └─ $1: a grant was asked ($(_granted)), and this arm owed none" >&2
  return 1
}

######################################################################
# R. the roster
######################################################################
roster="$(grove_provision_1_6_7_linger_roster | tr '\n' ' ')"
_grade "R. roster holds only the human seats ($roster)" 0 0 "$roster" "seatone seattwo " \
  || failed=$(( failed + 1 ))
[[ "$roster" == "seatone seattwo " ]] \
  || { echo "   │  └─ R: roster is '$roster', want 'seatone seattwo'" >&2; failed=$(( failed + 1 )); }

######################################################################
# V1, V2. the verify
######################################################################
_lingered seatone
out="$(grove_provision_1_6_7_linger_provision_verify 2>&1)"; rc=$?
_grade "V1. verify, seattwo unlingered: ✋ names seattwo, and only it" "$rc" 1 "$out" \
  "seattwo does not linger" "seatone does not linger" || failed=$(( failed + 1 ))

_lingered seatone seattwo
out="$(grove_provision_1_6_7_linger_provision_verify 2>&1)"; rc=$?
_grade "V2. verify, every seat lingers" "$rc" 0 "$out" "" || failed=$(( failed + 1 ))

######################################################################
# U1..U5. the upsert
######################################################################
_lingered
out="$(grove_provision_1_6_7_linger_provision_upsert 2>&1)"; rc=$?
_grade "U1. upsert grants each seat, read back" "$rc" 0 "$out" "seattwo lingers" || failed=$(( failed + 1 ))
[[ "$(_granted)" == "seatone seattwo " ]] \
  || { echo "   │  └─ U1: grants asked for '$(_granted)', want 'seatone seattwo'" >&2; failed=$(( failed + 1 )); }

_lingered seatone
out="$( GRANT_LEAVES_NO_RECORD=yes grove_provision_1_6_7_linger_provision_upsert 2>&1 )"; rc=$?
_grade "U2. a grant that leaves no record: ✋ names the seat" "$rc" 1 "$out" \
  "could not grant linger to seattwo" "could not grant linger to seatone" || failed=$(( failed + 1 ))

_lingered seatone
out="$( GROVE_ENV_SERVER=local@unix grove_provision_1_6_7_linger_provision_upsert 2>&1 )"; rc=$?
_grade "U3. a laptop: the same grant (parity)" "$rc" 0 "$out" "seattwo lingers" || failed=$(( failed + 1 ))
[[ "$(_granted)" == "seattwo " ]] \
  || { echo "   │  └─ U3: grants asked for '$(_granted)', want 'seattwo'" >&2; failed=$(( failed + 1 )); }

_lingered seatone
out="$( GROVE_ENV_SERVER=local@unix grove_provision_1_6_7_linger_provision_verify 2>&1 )"; rc=$?
_grade "V3. a laptop: the same ✋ (parity)" "$rc" 1 "$out" "seattwo does not linger" || failed=$(( failed + 1 ))

_lingered seatone
out="$( bundle.root.owns() { echo "   🌙 no root on this seat"; return 1; }
        grove_provision_1_6_7_linger_provision_upsert 2>&1 )"; rc=$?
_grade "U4. no root: decline" "$rc" 0 "$out" "no root" && _ungranted U4 || failed=$(( failed + 1 ))

_lingered seatone seattwo
out="$(grove_provision_1_6_7_linger_provision_upsert 2>&1)"; rc=$?
_grade "U5. converged: no grant" "$rc" 0 "$out" "every human seat lingers" && _ungranted U5 \
  || failed=$(( failed + 1 ))

echo ""
[[ "$failed" -eq 0 ]] || { echo "   ✋ ConstraintError: $failed arm(s) failed" >&2; exit 1; }
echo "   ✔ linger is read, granted, and refused per seat"
