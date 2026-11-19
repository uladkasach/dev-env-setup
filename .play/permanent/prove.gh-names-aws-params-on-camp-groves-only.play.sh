#!/usr/bin/env bash
######################################################################
# .what = prove 5.4.gh names aws.params on a CAMP grove (any platform), and
#         names no aws.params on a local or house grove — whose fix names
#         `--vault os.secure` instead
#
# .why  = the gate is the TIER, never the platform
#         (`rule.require.aws-params-on-camp-groves-only`). a camp grove carries the
#         camp identity by mandate — ec2 through its instance role, hetzner through
#         infra's IAM Roles Anywhere signer — so its token is the fleet's one
#         `aws.params` entry. a local or house grove has no camp identity, and a
#         fix-text that named aws.params there would send a human to write the pat
#         into whatever account the shell holds
#
# guarantee:
#   - hermetic: gh and rhx are stubs; no network, no rack, no root
#   - both sides bite: the camp arms must name aws.params, the others must not
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GH="$HERE/src/grove.provision/5.devtools/5.4.gh"
RACK="$HERE/src/grove.provision/5.devtools/5.12.rack"

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT

failed=0
pass() { echo "   • $1 ✔"; }
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }

echo "🌲 prove.gh-names-aws-params-on-camp-groves-only"

bin="$fixture/bin"
mkdir -p "$bin"
for tool in bash env grep head cat sed id; do
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
    source "$HERE/src/grove.env.sh"   # the seat predicates, as the entrypoint loads them
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

# off camp — a local or house grove: no aws.params anywhere, the fix names os.secure
# ⚠️ local, house, and cloud are PEER tiers: a house grove is `house@<platform>`
for tier in house@unix local@cicd; do
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

# the laptop — the human seat: no aws.params either, and with no terminal on THIS
#   run (stdin is /dev/null) no login prompt opens; the verify's fix is `gh auth login`
run_arm local@unix grove_provision_5_4_gh_configure_upsert
if [[ "$(cat "$fixture/rc")" == 1 ]] && grep -qF "no terminal is attached to THIS" "$fixture/out" \
   && ! grep -q 'aws.params' "$fixture/out" "$fixture/calls"; then
  pass "local@unix · configure_upsert → no aws.params, and no prompt opens with no terminal"
else
  fail "local@unix · configure_upsert → rc=$(cat "$fixture/rc"): $(tr '\n' '|' < "$fixture/out")"
fi
run_arm local@unix grove_provision_5_4_gh_configure_verify
if [[ "$(cat "$fixture/rc")" == 1 ]] && grep -qF "fix: gh auth login" "$fixture/out" \
   && ! grep -q 'aws.params' "$fixture/out" "$fixture/calls"; then
  pass "local@unix · configure_verify → no aws.params, and the fix is gh auth login"
else
  fail "local@unix · configure_verify → rc=$(cat "$fixture/rc"): $(tr '\n' '|' < "$fixture/out")"
fi

# on camp — every platform names aws.params, hetzner as much as ec2
for tier in cloud@aws.ec2 cloud@hetzner.hetzbot; do
  run_arm "$tier" grove_provision_5_4_gh_configure_verify
  if grep -q -- '--vault aws.params' "$fixture/out" && ! grep -q -- '--vault os.secure' "$fixture/out"; then
    pass "${tier} · configure_verify → names aws.params, a camp grove's vault"
  else
    fail "${tier} · a camp grove's fix named no aws.params: $(tr '\n' '|' < "$fixture/out")"
  fi
done

####################################################################
# 5.12.rack off camp — the github entry is DECLINED in its own words, and a
#   stale aws.params entry is still caught. no ssm read, no aws.params write
####################################################################
rbin="$fixture/bin.rack"
mkdir -p "$rbin" "$fixture/state"
for tool in bash env grep head cat sed id jq git mkdir rm wc timeout dirname; do
  real="$(command -v "$tool")" || { fail "the read tool '$tool' is absent on this box"; exit 1; }
  ln -s "$real" "$rbin/$tool"
done
# rhx: `keyrack list --json` answers the rack (empty, or a stale aws.params entry
#   on a state flag); `list` and `init` answer clean; any other call is logged
cat > "$rbin/rhx" <<STUB
#!/usr/bin/env bash
echo "rhx \$*" >> "$fixture/calls"
case "\$1 \$2" in
  "keyrack list")
    if [[ " \$* " == *" --json "* ]]; then
      [[ -f "$fixture/state/stale" ]] && { echo '[{"slug":"@all.camp.GITHUB_TOKEN","vault":"aws.params"}]'; exit 0; }
      echo '[]'; exit 0
    fi
    exit 0 ;;
  "keyrack init") exit 0 ;;
esac
exit 1
STUB
# aws: no identity answers on a local or house grove
printf '#!/usr/bin/env bash\necho "aws $*" >> "%s/calls"\nexit 255\n' "$fixture" > "$rbin/aws"
chmod +x "$rbin/rhx" "$rbin/aws"

run_rack_arm() {
  # $1 = GROVE_ENV_SERVER, $2 = phase function, $3 = arm label suffix
  : > "$fixture/calls"
  (
    export PATH="$rbin"
    export GROVE_ENV_SERVER="$1"
    # shellcheck source=/dev/null
    source "$HERE/src/grove.env.sh"
    # shellcheck source=/dev/null
    source "$RACK/_.sh"
    grove_provision_5_12_rack_gitroot() { printf '%s' "$fixture/rack"; }
    for f in configure.upsert configure.verify; do
      # shellcheck source=/dev/null
      source "$RACK/$f.sh"
    done
    "$2" > "$fixture/out" 2>&1 < /dev/null
    echo "$?" > "$fixture/rc"
  )
  transcript+="## $1 · $2${3:+ · $3}"$'\n'"rc=$(cat "$fixture/rc")"$'\n'"$(sed "s#$fixture#<fixture>#g" "$fixture/out")"$'\n\n'
}

for tier in local@unix house@unix local@cicd; do
  run_rack_arm "$tier" grove_provision_5_12_rack_configure_upsert
  label="5.12.rack · ${tier} · configure_upsert"
  if [[ "$(cat "$fixture/rc")" != 0 ]]; then
    fail "${label} → rc=$(cat "$fixture/rc"), expected 0 (a decline): $(tr '\n' '|' < "$fixture/out")"
  elif ! grep -qF "lives in aws.params, which only a camp grove may reach" "$fixture/out"; then
    fail "${label} → no decline names the camp-grove gate: $(tr '\n' '|' < "$fixture/out")"
  elif grep -q 'ssm\|--vault aws.params' "$fixture/calls"; then
    fail "${label} → reached ssm or wrote aws.params: $(tr '\n' '|' < "$fixture/calls")"
  else
    pass "${label} → declined by name; no ssm read, no aws.params write"
  fi

  run_rack_arm "$tier" grove_provision_5_12_rack_configure_verify
  label="5.12.rack · ${tier} · configure_verify"
  if [[ "$(cat "$fixture/rc")" == 0 ]] && grep -qF "is not a camp grove" "$fixture/out" \
     && grep -qF "no stale aws.params entry" "$fixture/out"; then
    pass "${label} → declined by name, and reads no stale entry"
  else
    fail "${label} → rc=$(cat "$fixture/rc"): $(tr '\n' '|' < "$fixture/out")"
  fi
done

# a stale aws.params entry off camp is a defect the verify must name
touch "$fixture/state/stale"
run_rack_arm local@unix grove_provision_5_12_rack_configure_verify "a stale aws.params entry"
if [[ "$(cat "$fixture/rc")" == 1 ]] && grep -qF "still names @all.camp.GITHUB_TOKEN in aws.params" "$fixture/out" \
   && grep -qF "fix: rhx grove.provision --what 5.12.rack --mode apply" "$fixture/out"; then
  pass "5.12.rack · local@unix · configure_verify · stale → ✋ with the fix, rc 1"
else
  fail "5.12.rack · a stale entry off camp was not named: rc=$(cat "$fixture/rc"): $(tr '\n' '|' < "$fixture/out")"
fi
rm -f "$fixture/state/stale"

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.gh-names-aws-params-on-camp-groves-only.snap" name=transcript actual="$transcript" \
  || failed=1

echo ""
if [[ $failed -ne 0 ]]; then
  echo "💥 MalfunctionError: prove.gh-names-aws-params-on-camp-groves-only: a claim did not hold" >&2
  exit 1
fi
echo "🌲 all claims held ✔"
