#!/usr/bin/env bash
######################################################################
# .what = prove 5.23.tailscale's verdicts across tier × daemon state × prefs
#
# .why  = #174's two invariants and its done-bar, clamped where a refactor
#         could break them under a green run:
#         - a laptop never carries a tag; a grove never joins untagged
#         - a joined, shielded laptop's rerun writes naught and asks naught
#         - a failed apt refresh is retried by the next run, never skipped
#
# .how  = the daemon is a stub that answers from two fixture files — the
#         `status --json` answer and the `debug prefs` answer — so each row
#         sets a state, runs one phase, and reads back rc, words, and writes
#
# guarantee:
#   - hermetic: no root, no network, no real tailscale; writes are logged
#   - a canary row proves the stubs run, so no row can pass hollow
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE="$HERE/src/grove.provision/5.devtools/5.23.tailscale"

fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

failed=0
pass() { echo "   • $1 ✔"; }
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }

echo "🌲 prove.tailscale-caselist"

####################################################################
# the bin — read tools linked in, write tools stubbed to log
####################################################################
bin="$fixture/bin"
mkdir -p "$bin"
for tool in bash jq timeout grep head cat sed rm mktemp mkdir awk sort; do
  real="$(command -v "$tool")" || { fail "the read tool '$tool' is absent on this box"; exit 1; }
  ln -s "$real" "$bin/$tool"
done
# sudo runs naught; it logs the write it was asked for, and moves the daemon as the
#   real one would:
#   - a shields-up set lands in the prefs — unless the row asks for a daemon that
#     ignores it (ROW_SET_IGNORED), the one way to reach the post-set 💥
#   - an `up` acts as the row's control server says (ROW_UP): `url` mints a login
#     url, `joined` joins at once, `silent` offers no url and says why
cat > "$bin/sudo" <<STUB
#!/usr/bin/env bash
echo "sudo \$*" >> "$fixture/calls"
if [[ "\$*" == *"tailscale set --shields-up"* && -z "\${ROW_SET_IGNORED:-}" ]]; then
  printf '%s' '{"ShieldsUp":true}' > "$fixture/prefs.json"
fi
if [[ "\$*" == *"tailscale up"* ]]; then
  case "\${ROW_UP:-}" in
    url)    printf '%s' '{"BackendState":"NeedsLogin","AuthURL":"https://login.example.com/a/minted"}' > "$fixture/status.json" ;;
    joined) printf '%s' '{"BackendState":"Running","Self":{"Tags":[]},"Peer":{"a":{"Tags":["tag:camp"]}}}' > "$fixture/status.json" ;;
    silent) echo "backend error: the control server refused the stub's key" ;;
  esac
fi
exit 0
STUB
printf '#!/usr/bin/env bash\ncase "$1" in is-enabled|is-active) [ -n "${ROW_UNIT_UP:-}" ] && exit 0; exit 1 ;; esac\necho "systemctl $*" >> "%s/calls"\nexit 0\n' "$fixture" > "$bin/systemctl"
# tailscale: the two reads answer from the fixture files; any other verb is a write
printf '#!/usr/bin/env bash\ncase "$1 ${2:-}" in\n  "status --json") cat "%s/status.json"; exit 0 ;;\n  "debug prefs") cat "%s/prefs.json"; exit 0 ;;\n  "version "*) echo "0.0.0-stub"; exit 0 ;;\nesac\necho "tailscale $*" >> "%s/calls"\nexit 0\n' \
  "$fixture" "$fixture" "$fixture" > "$bin/tailscale"
# gpg: every key it is shown carries one primary that is NOT the pin — so the real
#   `web_verify_gpg_fingerprints` runs, and prints both sets, as it would on a rotation
printf '#!/usr/bin/env bash\nprintf "pub:-:4096:1:00000000DEADBEEF:0:::-:::scESC::::::23::0:\\nfpr:::::::::00000000000000000000000000000000DEADBEEF:\\n"\n' > "$bin/gpg"
chmod +x "$bin/sudo" "$bin/systemctl" "$bin/tailscale" "$bin/gpg"

# the same bin with no client — the package-absent rows
noclient="$fixture/bin.noclient"
mkdir -p "$noclient"
for f in "$bin"/*; do [[ "$(basename "$f")" == tailscale ]] || ln -s "$f" "$noclient/$(basename "$f")"; done

# canary — a stub that cannot run logs naught, and every "no write" row would pass hollow
: > "$fixture/calls"
( PATH="$bin" sudo canary )
grep -q 'sudo canary' "$fixture/calls" || { fail "a stub write left no log — every row below would prove naught"; exit 1; }
pass "the stubs run and log"

####################################################################
# one row — set the daemon, run one phase under a tier, read it back
####################################################################
# $1 = tier · $2 = status json · $3 = prefs json · $4 = phase · $5 = root offered (yes|no)
#   ROW_KEEP=1 leaves the daemon as the last row left it, so rows chain into a journey
ln_real="$(command -v ln)"
run_row() {
  : > "$fixture/calls"
  rm -f "$noclient/tailscale"
  if [[ -z "${ROW_KEEP:-}" ]]; then
    printf '%s' "$2" > "$fixture/status.json"
    printf '%s' "$3" > "$fixture/prefs.json"
  fi
  (
    export PATH="${ROW_BIN:-$bin}"
    export GROVE_ENV_SERVER="$1"
    unset SSH_CONNECTION SSH_TTY
    [[ -n "${ROW_SSH:-}" ]] && export SSH_CONNECTION="$ROW_SSH"
    [[ -n "${ROW_SET_IGNORED:-}" ]] && export ROW_SET_IGNORED
    [[ -n "${ROW_UP:-}" ]] && export ROW_UP
    [[ -n "${ROW_UNIT_UP:-}" ]] && export ROW_UNIT_UP
    : > "$fixture/asks"
    if [[ "$5" == yes ]]; then
      # root is granted, and each ask is logged apart from the writes, so a row can
      #   prove it never asked
      bundle.root.owns() { echo "bundle.root.owns $1" >> "$fixture/asks"; return 0; }
    else
      # the REAL runtime decline, so the snap holds the fix-text a human reads.
      #   `slug` is what `bundle.upgrade` would have set for this phase
      # shellcheck source=/dev/null
      source "$HERE/src/bundle.upgrade.sh"
      pkg_can_sudo() { return 1; }
      slug="5.23.tailscale.${4/_/.}"
    fi
    pkg_assert_apt() { return 0; }
    pkg_refresh()    { echo "pkg_refresh" >> "$fixture/calls"; return 0; }
    # an install lands the stub client on the row's PATH, as apt would — unless the
    #   row asks for a hollow one (ROW_INSTALL_HOLLOW), which reports success and lands none
    pkg_install()    {
      echo "pkg_install $*" >> "$fixture/calls"
      [[ -n "${ROW_INSTALL_HOLLOW:-}" ]] || "$ln_real" -sf "$bin/tailscale" "$noclient/tailscale"
      return 0
    }
    # a fixed dir, so the snapshot holds no per-run path
    web_tempdir()    { mkdir -p "$fixture/tmp"; printf '%s' "$fixture/tmp"; }
    web_fetch()      { echo "web_fetch" >> "$fixture/calls"; return 1; }
    web_verify_gpg_fingerprints() { return 1; }
    grove_env_platform_file() { printf '%s' "$fixture/no-such-platform"; }
    # shellcheck source=/dev/null
    source "$BUNDLE/_.sh"
    for f in provision.upsert provision.verify configure.upsert configure.verify; do
      # shellcheck source=/dev/null
      source "$BUNDLE/$f.sh"
    done
    # the key and list live in the fixture, never /etc — so a row never reads
    #   this box's own declared source, and the source starts absent
    grove_provision_5_23_tailscale_keydst()  { printf '%s' "$fixture/tailscale.gpg"; }
    grove_provision_5_23_tailscale_listdst() { printf '%s' "$fixture/tailscale.list"; }
    [[ -n "${ROW_SOURCE_OK:-}" ]] && grove_provision_5_23_tailscale_source_ok() { return 0; }
    # a fetch that lands a key file, so the fingerprint check is what decides
    #   the REAL fingerprint check runs here, against the stub gpg above, so the
    #   transcript holds the two sets a human compares
    if [[ -n "${ROW_FETCH_OK:-}" ]]; then
      unset -f web_verify_gpg_fingerprints
      # shellcheck source=/dev/null
      source "$HERE/src/grove.web.sh"
      web_tempdir()    { mkdir -p "$fixture/tmp"; printf '%s' "$fixture/tmp"; }
      web_fetch() { echo "web_fetch" >> "$fixture/calls"; printf 'key' > "${@: -1}"; return 0; }
    fi
    # a fetch whose key matches the pin, so the source is declared
    if [[ -n "${ROW_SIGNED:-}" ]]; then
      web_fetch() { echo "web_fetch" >> "$fixture/calls"; printf 'key' > "${@: -1}"; return 0; }
      web_verify_gpg_fingerprints() { return 0; }
    fi
    "grove_provision_5_23_tailscale_$4" > "$fixture/out" 2>&1
    echo "$?" > "$fixture/rc"
  )
}

# every row's full output joins one transcript, snapped at the end — the asserts
#   below prove the words that matter; the snapshot proves every other byte
transcript=""
codename="$(. /etc/os-release 2>/dev/null && printf '%s' "${UBUNTU_CODENAME:-}")"
mask() {
  local text="$1"
  text="${text//$fixture/<fixture>}"
  [[ -n "$codename" ]] && text="${text//$codename/<codename>}"
  printf '%s' "$text"
}

# $1 = label · $2 = rc wanted · $3 = words the output must hold ('' = any) · $4 = writes (none|some|<words>)
expect() {
  local rc out calls writes
  rc="$(cat "$fixture/rc")"; out="$(cat "$fixture/out")"; calls="$(cat "$fixture/calls")"
  # one ` · ` between writes, and `none` for a row that wrote naught
  writes="$(mask "$calls")"; writes="${writes//$'\n'/ · }"; [[ -n "$writes" ]] || writes=none
  transcript+="## $1"$'\n'"rc=${rc}"$'\n'"$(mask "$out")"$'\n'"writes: ${writes}"$'\n\n'
  [[ "$rc" == "$2" ]] || { fail "$1 → rc=${rc}, wanted $2; it said: $(tr '\n' '|' <<< "$out")"; return; }
  if [[ -n "$3" ]] && ! grep -qF -- "$3" <<< "$out"; then
    fail "$1 → the output lacks '$3'; it said: $(tr '\n' '|' <<< "$out")"; return
  fi
  case "$4" in
    none) [[ -z "$calls" ]] || { fail "$1 → wrote: $(tr '\n' ';' <<< "$calls")"; return; } ;;
    some) [[ -n "$calls" ]] || { fail "$1 → wrote naught, a write was owed"; return; } ;;
    *)    grep -qF -- "$4" <<< "$calls" || { fail "$1 → no '$4' among writes: $(tr '\n' ';' <<< "$calls")"; return; } ;;
  esac
  pass "$1"
}

# the daemon's answers, by row
member_joined='{"BackendState":"Running","Self":{"Tags":[]},"Peer":{"a":{"Tags":["tag:camp"]}}}'
member_alone='{"BackendState":"Running","Self":{"Tags":[]},"Peer":{}}'
member_tagged='{"BackendState":"Running","Self":{"Tags":["tag:camp"]},"Peer":{}}'
grove_joined='{"BackendState":"Running","Self":{"Tags":["tag:camp"]},"Peer":{}}'
grove_untagged='{"BackendState":"Running","Self":{"Tags":[]},"Peer":{}}'
grove_othertag='{"BackendState":"Running","Self":{"Tags":["tag:other"]},"Peer":{}}'
state() { printf '{"BackendState":"%s"}' "$1"; }
up='{"ShieldsUp":true}'; down='{"ShieldsUp":false}'; unread='not json'

####################################################################
# the laptop — a member, untagged, shielded
####################################################################
run_row local@unix "$member_joined" "$up" configure_upsert yes
expect "laptop · joined + shields up · upsert → no work, no write" 0 "shields up" none
run_row local@unix "$member_joined" "$up" configure_verify yes
expect "laptop · joined + shields up · verify → ✔" 0 "✔ joined as a member" none
run_row local@unix "$member_joined" "$down" configure_upsert yes
expect "laptop · shields down · upsert → sets shields up" 0 "shields up" "tailscale set --shields-up"
ROW_SET_IGNORED=1 run_row local@unix "$member_joined" "$down" configure_upsert yes
expect "laptop · shields down, the set does not take · upsert → 💥, never 'up'" 1 "MalfunctionError" "tailscale set --shields-up"
run_row local@unix "$member_joined" "$down" configure_verify yes
expect "laptop · shields down · verify → ✋" 1 "shields down" none
run_row local@unix "$member_joined" "$unread" configure_verify yes
expect "laptop · prefs unread · verify → 💥, never 'up'" 1 "MalfunctionError" none
run_row local@unix "$member_tagged" "$up" configure_verify yes
expect "laptop · tagged · verify → ✋ (a laptop never takes tag:camp)" 1 "this laptop carries tags" none
run_row local@unix "$member_alone" "$up" configure_verify yes
expect "laptop · no camp peer · verify → ✋" 1 "no camp grove" none
run_row local@unix "$(state Stopped)" "$up" configure_upsert yes
expect "laptop · Stopped · upsert → left as it is, no write" 0 "taken down on purpose" none
run_row local@unix "$(state Stopped)" "$up" configure_verify yes
expect "laptop · Stopped · verify → ✋ with the restore" 1 "restore it" none
run_row local@unix "$(state Starting)" "$up" configure_upsert yes
expect "laptop · Starting · upsert → no join, no write" 0 "has not settled" none
run_row local@unix "$(state Starting)" "$up" configure_verify yes
expect "laptop · Starting · verify → ✋, rerun in a moment" 1 "has not settled" none
run_row local@unix "$(state NeedsMachineAuth)" "$up" configure_upsert yes
expect "laptop · NeedsMachineAuth · upsert → ✋, no write" 1 "tailnet admin" none
run_row local@unix "$(state InUseOtherUser)" "$up" configure_upsert yes
expect "laptop · InUseOtherUser · upsert → ✋, no write" 1 "another login" none
run_row local@unix "$(state NeedsLogin)" "$up" configure_upsert no
expect "laptop · NeedsLogin, no root · upsert → declines, no write" 0 "sudo -v && rhx grove.provision --what 5.23.tailscale --mode apply" none
ROW_SSH="<host> 22 <host> 22" run_row local@unix "$(state NeedsLogin)" "$up" configure_upsert yes
expect "laptop · NeedsLogin over ssh · upsert → ✋, no url, no write" 1 "SSH_CONNECTION is set" none

run_row local@unix '{"BackendState":"NeedsLogin","AuthURL":"https://login.example.com/a/held"}' "$up" configure_verify yes
expect "laptop · sign-in owed, url held · verify → ✋ and shows the held url" 1 "https://login.example.com/a/held" none
run_row local@unix "$(state NeedsLogin)" "$up" configure_verify yes
expect "laptop · sign-in owed, no url yet · verify → ✋, names the fix that mints one" 1 "no url is minted yet" none

####################################################################
# the member join — the url a human reads on the first day (case 1)
####################################################################
ROW_UP=url run_row local@unix "$(state NeedsLogin)" "$up" configure_upsert yes
expect "laptop · NeedsLogin · upsert → one shielded up, prints the minted url" 0 "https://login.example.com/a/minted" "tailscale up --shields-up"
ROW_UP=joined run_row local@unix "$(state NeedsLogin)" "$up" configure_upsert yes
expect "laptop · NeedsLogin, the up joins at once · upsert → joined as a member, shields up" 0 "joined as a member" "tailscale up --shields-up"
ROW_UP=silent run_row local@unix "$(state NeedsLogin)" "$up" configure_upsert yes
expect "laptop · NeedsLogin, no url offered · upsert → 💥 with the client's words" 1 "the control server refused the stub's key" "tailscale up --shields-up"
run_row local@unix '{"BackendState":"NeedsLogin","AuthURL":"https://login.example.com/a/held"}' "$up" configure_upsert yes
expect "laptop · sign-in owed, url held · upsert → shows the held url, no second up" 0 "https://login.example.com/a/held" none

####################################################################
# the first day, as one journey — each turn reads the daemon the last one left
####################################################################
run_row local@unix "$(state NeedsLogin)" "$up" configure_upsert no
expect "journey 1 · an agent shell · upsert → declines, no write" 0 "sudo -v && rhx grove.provision" none
ROW_KEEP=1 ROW_UP=url run_row local@unix "" "" configure_upsert yes
expect "journey 2 · the human, with root · upsert → mints the url" 0 "https://login.example.com/a/minted" "tailscale up --shields-up"
# the sign-in is the human's act in a browser; the daemon then reads as joined
printf '%s' "$member_joined" > "$fixture/status.json"
ROW_KEEP=1 run_row local@unix "" "" configure_upsert yes
expect "journey 3 · after the sign-in · upsert → no work, no second up" 0 "shields up" none
ROW_KEEP=1 run_row local@unix "" "" configure_verify yes
expect "journey 4 · after the sign-in · verify → ✔" 0 "✔ joined as a member" none

####################################################################
# the pin — a key whose fingerprint differs installs naught
####################################################################
ROW_FETCH_OK=1 ROW_BIN="$noclient" run_row local@unix "$(state NoState)" "$up" provision_upsert yes
expect "laptop · key differs from the pin · upsert → ✋, source not declared" 1 "is NOT installed" "web_fetch"
grep -q 'sudo' "$fixture/calls" \
  && fail "laptop · key differs from the pin · a root write ran: $(tr '\n' ';' < "$fixture/calls")" \
  || pass "laptop · key differs from the pin · no root write (no key, no list, no package)"

####################################################################
# the alterpaths — an unread daemon, a foreign install, a dead unit
####################################################################
run_row local@unix "$unread" "$up" configure_upsert yes
expect "laptop · daemon state unread · upsert → 💥, never 'up'" 1 "could not read the tailscale daemon's state" none

# a client from another source: the signed source is declared, the package never reinstalled
ROW_SIGNED=1 run_row local@unix "$member_joined" "$up" provision_upsert yes
expect "laptop · tailscale from another source · upsert → declares the signed source" 0 "" "sudo tee"
grep -q 'pkg_install tailscale' "$fixture/calls" \
  && fail "laptop · tailscale from another source · the live client was reinstalled" \
  || pass "laptop · tailscale from another source · no reinstall"

# the stub systemctl reads every unit as neither enabled nor active
ROW_SOURCE_OK=1 run_row local@unix "$member_joined" "$up" provision_verify yes
expect "laptop · tailscaled masked or down · verify → ✋, names systemctl status" 1 "systemctl status tailscaled" none

####################################################################
# the refresh — a source declared last run, with no package, refreshes again
####################################################################
ROW_SOURCE_OK=1 ROW_BIN="$noclient" run_row local@unix "$(state NoState)" "$up" provision_upsert yes
expect "laptop · source declared, package absent · upsert → refreshes, installs, names the version" 0 "tailscale installed (0.0.0-stub)" "pkg_install tailscale"
grep -q 'pkg_refresh' "$fixture/calls" \
  && pass "laptop · source declared, package absent · the refresh ran before the install" \
  || fail "laptop · source declared, package absent · no refresh: $(tr '\n' ';' < "$fixture/calls")"
ROW_INSTALL_HOLLOW=1 ROW_SOURCE_OK=1 ROW_BIN="$noclient" run_row local@unix "$(state NoState)" "$up" provision_upsert yes
expect "laptop · the install lands no client · upsert → 💥, never 'installed ()'" 1 "answers naught" "pkg_install tailscale"

####################################################################
# case 2, the provision half — a laptop with source, client, and unit all present
####################################################################
ROW_UNIT_UP=1 ROW_SOURCE_OK=1 run_row local@unix "$member_joined" "$up" provision_upsert yes
expect "case 2 · all present · provision upsert → no work, no write" 0 "tailscale already installed — no work" none
[[ -s "$fixture/asks" ]] \
  && fail "case 2 · all present · provision upsert asked for root: $(tr '\n' ';' < "$fixture/asks")" \
  || pass "case 2 · all present · provision upsert asks naught (no root ask)"
ROW_UNIT_UP=1 ROW_SOURCE_OK=1 run_row local@unix "$member_joined" "$up" provision_verify yes
expect "case 2 · all present · provision verify → ✔" 0 "tailscaled enabled and active ✔" none

####################################################################
# case 3, before install — an agent shell on a bare laptop has no root
####################################################################
ROW_BIN="$noclient" run_row local@unix "$(state NoState)" "$up" provision_upsert no
expect "case 3 [t0] · bare laptop, agent shell, no root · upsert → declines, no fetch, no write" 0 "sudo -v && rhx grove.provision" none
ROW_BIN="$noclient" run_row local@unix "$(state NoState)" "$up" provision_verify no
expect "case 3 [t0] · bare laptop, no client, no source · verify → ✋, names the fix" 1 "tailscale is not on PATH" none

####################################################################
# the grove — tagged tag:camp, never a member, never written to
####################################################################
for tier in cloud@aws.ec2 cloud@hetzner.hetzbot; do
  run_row "$tier" "$grove_joined" "$down" configure_upsert yes
  expect "${tier} · joined tag:camp · upsert → no write" 0 "" none
  run_row "$tier" "$grove_joined" "$down" configure_verify yes
  expect "${tier} · joined tag:camp · verify → ✔" 0 "✔ joined · tags = tag:camp" none
  ROW_UNIT_UP=1 run_row "$tier" "$grove_joined" "$down" provision_verify yes
  expect "${tier} · client and unit present · provision verify → ✔" 0 "tailscaled enabled and active ✔" none
  run_row "$tier" "$grove_untagged" "$down" configure_verify yes
  expect "${tier} · joined untagged · verify → ✋ (a grove never joins as a member)" 1 "joined untagged, as a USER" none
  run_row "$tier" "$grove_othertag" "$down" configure_verify yes
  expect "${tier} · other tags · verify → ✋" 1 "not exactly" none
  run_row "$tier" "$(state Starting)" "$down" configure_verify yes
  expect "${tier} · Starting · verify → ✋" 1 "has not settled" none
  # a grove its provisioner has not joined yet — no `up` here, ever; the ✋ names who owes it
  run_row "$tier" "$(state NeedsLogin)" "$down" configure_upsert yes
  expect "${tier} · not joined · upsert → no up, no write" 0 "joined by its provisioner" none
  run_row "$tier" "$(state NeedsLogin)" "$down" configure_verify yes
  expect "${tier} · not joined · verify → ✋, names the provisioner's join" 1 "provisioner" none
done

# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
# the last row's blank separator is dropped, so the snap ends on its last line
play_snap_verify dir="$HERE/.play/permanent/prove.tailscale-caselist.snap" name=transcript actual="${transcript%$'\n\n'}" \
  || failed=1

echo ""
if [[ $failed -ne 0 ]]; then
  echo "✋ prove.tailscale-caselist: a claim did not hold" >&2
  exit 1
fi
echo "🌲 all claims held ✔"
