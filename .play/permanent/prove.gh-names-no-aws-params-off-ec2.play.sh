#!/usr/bin/env bash
######################################################################
# .what = prove 5.4.gh names no aws.params, on a call or a fix, on a remote box
#         off ec2 — and that its fix names `--vault os.secure` there
#
# .why  = the hetzner probe routes a hetzner grove into every bundle. aws.params
#         is reachable from an ec2 box alone (`rule.forbid.aws-params-off-ec2`):
#         off ec2 a fix-text that names it sends a human to write the pat into
#         whatever account the shell holds. off ec2 the token lives in os.secure
#
# guarantee:
#   - hermetic: gh and rhx are stubs; no network, no rack, no root
#   - an ec2 control arm must name aws.params, so the check is proven to bite
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GH="$HERE/src/grove.provision/5.devtools/5.4.gh"
RACK="$HERE/src/grove.provision/5.devtools/5.12.rack"

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

failed=0
pass() { echo "   • $1 ✔"; }
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }

echo "🌲 prove.gh-names-no-aws-params-off-ec2"

bin="$fixture/bin"
mkdir -p "$bin"
for tool in bash env grep head cat sed; do
  real="$(command -v "$tool")" || { fail "the read tool '$tool' is absent on this box"; exit 1; }
  ln -s "$real" "$bin/$tool"
done
# gh: unauthed, every call refused. rhx: any call is a rack reach, logged
printf '#!/usr/bin/env bash\nexit 1\n' > "$bin/gh"
printf '#!/usr/bin/env bash\necho "rhx $*" >> "%s/calls"\nexit 1\n' "$fixture" > "$bin/rhx"
chmod +x "$bin/gh" "$bin/rhx"

# canary — a stub that cannot run logs naught, and the no-reach claim would pass hollow
: > "$fixture/calls"
( PATH="$bin" rhx canary )
grep -q 'rhx canary' "$fixture/calls" || { fail "a stub call left no log"; exit 1; }
pass "the stubs run and log"

run_arm() {
  # $1 = GROVE_ENV_SERVER, $2 = phase function
  : > "$fixture/calls"
  (
    export PATH="$bin"
    export GROVE_ENV_SERVER="$1"
    # shellcheck source=/dev/null
    source "$RACK/_.sh"
    grove_provision_5_12_rack_gitroot() { printf '%s' "$fixture"; }
    for f in _ configure.upsert configure.verify; do
      # shellcheck source=/dev/null
      source "$GH/$f.sh"
    done
    "$2" > "$fixture/out" 2>&1 < /dev/null
    echo "$?" > "$fixture/rc"
  )
  # every arm's full output joins one transcript, snapped at the end
  transcript+="## $1 · $2"$'\n'"rc=$(cat "$fixture/rc")"$'\n'"$(sed "s#$fixture#<fixture>#g" "$fixture/out")"$'\n\n'
}
transcript=""

for tier in cloud@hetzner.hetzbot local@house; do
  for phase in configure_upsert configure_verify; do
    run_arm "$tier" "grove_provision_5_4_gh_${phase}"
    label="${tier} · ${phase}"
    if [[ "$(cat "$fixture/rc")" != 1 ]]; then
      fail "${label} → rc=$(cat "$fixture/rc"), expected 1"
    elif grep -q 'aws.params' "$fixture/out" "$fixture/calls"; then
      fail "${label} → names aws.params: $(grep -h 'aws.params' "$fixture/out" "$fixture/calls" | tr '\n' '|')"
    elif ! grep -q -- '--vault os.secure' "$fixture/out"; then
      fail "${label} → its fix names no os.secure vault: $(tr '\n' '|' < "$fixture/out")"
    else
      pass "${label} → no aws.params, and the fix names --vault os.secure"
    fi
  done
done

# control — on ec2 the fix DOES name aws.params, so the check above can bite
run_arm cloud@aws.ec2 grove_provision_5_4_gh_configure_verify
grep -q -- '--vault aws.params' "$fixture/out" \
  && pass "cloud@aws.ec2 · configure_verify → names aws.params (the control)" \
  || fail "cloud@aws.ec2 · the control arm named no aws.params: $(tr '\n' '|' < "$fixture/out")"

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.gh-names-no-aws-params-off-ec2.snap" name=transcript actual="$transcript" \
  || failed=1

echo ""
if [[ $failed -ne 0 ]]; then
  echo "✋ prove.gh-names-no-aws-params-off-ec2: a claim did not hold" >&2
  exit 1
fi
echo "🌲 all claims held ✔"
