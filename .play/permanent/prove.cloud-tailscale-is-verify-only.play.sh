#!/usr/bin/env bash
######################################################################
# .what = prove `5.23.tailscale` makes no write on a cloud grove that holds
#         `jq` (its one non-tailscale dependency), and fails
#         fast with the provisioner named where tailscale is absent
#
# .why
#   - the clamp for `define.invariant.grove-tailscale-has-one-owner`
#   - a write here would hide a provisioner's failed build
#   - the LOGIC needs no grove: stub `sudo`, `systemctl`, `apt-get`, and
#     `tailscale` log every call into a fixture, and PATH holds only them
#     plus the read tools the phases use
#
# .why a laptop arm
#   - it proves the stubs SEE a write: the laptop path must reach root, so a
#     clamp that stayed green there would be blind
#
# guarantee:
#   - READ-ONLY outside its own mktemp dir, removed on exit
#   - each arm runs in a subshell, so no env or stub leaks between arms
#   - every arm's rc, output, and writes join a transcript, snapped beside this play
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE="$HERE/src/grove.provision/5.devtools/5.23.tailscale"

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

failed=0
pass() { echo "   • $1 ✔"; }
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }

echo "🌲 prove.cloud-tailscale-is-verify-only"

####################################################################
# the bins — read tools linked in, write tools stubbed to log
####################################################################
mkbin() {
  # $1 = dir, $2 = 'with-tailscale' | 'without-tailscale', $3 = 'no-jq' to leave jq out
  # bash is load-bear: each stub's shebang is `env bash`, so a PATH with no bash
  #   leaves every stub unrunnable — a write would fail silently, and log naught
  local dir="$1" tool real tools=(bash jq timeout grep head cat sed rm mktemp)
  [[ "${3:-}" == no-jq ]] && tools=(bash timeout grep head cat sed rm mktemp)
  mkdir -p "$dir"
  for tool in "${tools[@]}"; do
    real="$(command -v "$tool")" || { fail "the read tool '$tool' is absent on this box"; return 1; }
    ln -s "$real" "$dir/$tool"
  done
  printf '#!/usr/bin/env bash\necho "sudo $*" >> "%s/calls"\nexit 0\n' "$fixture" > "$dir/sudo"
  printf '#!/usr/bin/env bash\necho "apt-get $*" >> "%s/calls"\nexit 0\n' "$fixture" > "$dir/apt-get"
  # systemctl: a read answers "not active"; any other verb is a write, logged
  printf '#!/usr/bin/env bash\ncase "$1" in is-enabled|is-active) exit 1 ;; esac\necho "systemctl $*" >> "%s/calls"\nexit 0\n' "$fixture" > "$dir/systemctl"
  if [[ "$2" == with-tailscale ]]; then
    # tailscale: `status --json` and `debug prefs` read; any other verb is a write, logged
    printf '#!/usr/bin/env bash\ncase "$1 ${2:-}" in\n  "status --json") echo "{\\"BackendState\\":\\"NeedsLogin\\"}"; exit 0 ;;\n  "debug prefs") echo "{\\"ShieldsUp\\":false}"; exit 0 ;;\n  "version "*) echo "0.0.0-stub"; exit 0 ;;\nesac\necho "tailscale $*" >> "%s/calls"\nexit 0\n' "$fixture" > "$dir/tailscale"
  fi
  chmod +x "$dir"/sudo "$dir"/apt-get "$dir"/systemctl
  [[ -e "$dir/tailscale" ]] && chmod +x "$dir/tailscale"
  return 0
}
mkbin "$fixture/bin.with" with-tailscale || exit 1
mkbin "$fixture/bin.without" without-tailscale || exit 1
mkbin "$fixture/bin.nojq" without-tailscale no-jq || exit 1

# canary — a stub that cannot run logs naught, and every "no write" arm would pass hollow
for b in with without nojq; do
  : > "$fixture/calls"
  ( PATH="$fixture/bin.$b" sudo canary )
  grep -q 'sudo canary' "$fixture/calls" || { fail "bin.${b} · a stub write left no log — the arms below would prove naught"; exit 1; }
done
pass "every stub bin logs a write"

####################################################################
# one arm — the bundle's phases, under a tier and a bin, in a subshell
####################################################################
run_arm() {
  # $1 = GROVE_ENV_SERVER, $2 = bin dir, $3 = phase function
  : > "$fixture/calls"
  (
    export PATH="$2"
    export GROVE_ENV_SERVER="$1"
    unset SSH_CONNECTION SSH_TTY
    # the runtime seams the phases reach, stubbed: root is OFFERED (return 0)
    #   so a write the guard failed to stop would land in the log
    bundle.root.owns() { echo "bundle.root.owns $1" >> "$fixture/calls"; return 0; }
    pkg_assert_apt()   { return 0; }
    pkg_refresh()      { echo "pkg_refresh" >> "$fixture/calls"; return 0; }
    pkg_install()      { echo "pkg_install $*" >> "$fixture/calls"; return 0; }
    # a fixed dir, so the snapshot holds no per-run path
    web_tempdir()      { echo "web_tempdir" >> "$fixture/calls"; printf '%s' "$fixture/tmp"; }
    web_fetch()        { echo "web_fetch $*" >> "$fixture/calls"; return 1; }
    web_verify_gpg_fingerprints() { return 1; }
    grove_env_platform_file() { printf '%s' "$fixture/no-such-platform"; }
    # shellcheck source=/dev/null
    source "$BUNDLE/_.sh"
    # shellcheck source=/dev/null
    for f in provision.upsert provision.verify configure.upsert configure.verify; do source "$BUNDLE/$f.sh"; done
    "$3" > "$fixture/out" 2>&1
    echo "$?" > "$fixture/rc"
  )
  # every arm's rc, words, and writes join one transcript, snapped at the end — the
  #   asserts below prove the claims; the snapshot proves every byte a human reads
  local writes
  writes="$(cat "$fixture/calls")"; writes="${writes//$'\n'/ · }"; [[ -n "$writes" ]] || writes=none
  transcript+="## $1 · ${3#grove_provision_5_23_tailscale_} · bin.${2##*/bin.}"$'\n'
  transcript+="rc=$(cat "$fixture/rc")"$'\n'"$(cat "$fixture/out")"$'\n'"writes: ${writes}"$'\n\n'
  transcript="${transcript//$fixture/<fixture>}"
  [[ -n "$codename" ]] && transcript="${transcript//$codename/<codename>}"
  return 0
}
transcript=""
# the os codename differs per box, so the snapshot masks it
codename="$(. /etc/os-release 2>/dev/null && printf '%s' "${UBUNTU_CODENAME:-}")"
mkdir -p "$fixture/tmp"

####################################################################
# cloud — every write phase, with and without a client: the log stays empty
####################################################################
for tier in cloud@aws.ec2 cloud@hetzner.hetzbot; do
  for bin in with without; do
    for phase in provision_upsert configure_upsert; do
      run_arm "$tier" "$fixture/bin.$bin" "grove_provision_5_23_tailscale_${phase}"
      if [[ -s "$fixture/calls" ]]; then
        fail "${tier} · ${phase} · client ${bin} → wrote: $(tr '\n' ';' < "$fixture/calls" 2>/dev/null || cat "$fixture/calls")"
      else
        pass "${tier} · ${phase} · client ${bin} → no write"
      fi
    done
  done
done

####################################################################
# cloud — no jq: jq is the ONE write, never a tailscale artifact
####################################################################
run_arm cloud@aws.ec2 "$fixture/bin.nojq" grove_provision_5_23_tailscale_provision_upsert
calls="$(cat "$fixture/calls")"
[[ "$calls" == "pkg_install jq" ]] && pass "cloud · provision upsert · no jq → installs jq, and no tailscale artifact"
[[ "$calls" != "pkg_install jq" ]] && fail "cloud · provision upsert · no jq → wrote '${calls}', expected only 'pkg_install jq'"

####################################################################
# cloud — an absent client fails fast, and names the provisioner
####################################################################
run_arm cloud@aws.ec2 "$fixture/bin.without" grove_provision_5_23_tailscale_provision_verify
[[ "$(cat "$fixture/rc")" == 1 ]] && pass "cloud · provision verify · no client → rc=1"
[[ "$(cat "$fixture/rc")" != 1 ]] && fail "cloud · provision verify · no client → rc=$(cat "$fixture/rc"), expected 1"
grep -q 'provisioner' "$fixture/out" && pass "cloud · provision verify · the fix names the provisioner"
grep -q 'provisioner' "$fixture/out" || fail "cloud · provision verify · the fix does not name the provisioner; it said: $(tr '\n' '|' < "$fixture/out")"
grep -q 'grove.provision --what 5.23.tailscale' "$fixture/out" \
  && fail "cloud · provision verify · the fix offers a rerun of this bundle, which installs naught here"
grep -q 'apt source' "$fixture/out" \
  && fail "cloud · provision verify · this repo's apt source was judged on a provisioner's grove"

run_arm cloud@aws.ec2 "$fixture/bin.with" grove_provision_5_23_tailscale_configure_verify
[[ "$(cat "$fixture/rc")" == 1 ]] && pass "cloud · configure verify · not joined → rc=1"
[[ "$(cat "$fixture/rc")" != 1 ]] && fail "cloud · configure verify · not joined → rc=$(cat "$fixture/rc"), expected 1"
grep -q 'provisioner' "$fixture/out" && pass "cloud · configure verify · the fix names the provisioner"
grep -q 'provisioner' "$fixture/out" || fail "cloud · configure verify · the fix does not name the provisioner; it said: $(tr '\n' '|' < "$fixture/out")"

####################################################################
# laptop — the control: the stubs must SEE the install write
####################################################################
run_arm local@unix "$fixture/bin.without" grove_provision_5_23_tailscale_provision_upsert
grep -q 'bundle.root.owns' "$fixture/calls" \
  && pass "laptop · provision upsert reaches root — the stubs see a write"
grep -q 'bundle.root.owns' "$fixture/calls" \
  || fail "laptop · provision upsert reached no root — this clamp would be blind"

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
play_snap_verify dir="$HERE/.play/permanent/prove.cloud-tailscale-is-verify-only.snap" name=transcript actual="${transcript%$'\n\n'}" \
  || failed=1

[[ "$failed" -eq 0 ]] && echo "🌲 all claims held ✔"
exit "$failed"
