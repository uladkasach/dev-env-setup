#!/usr/bin/env bash
######################################################################
# .what = drive every writer of ~/.aws/config against a fixture hetzner
#         config, and prove camper's [default] survives each one
#
# .why
#   - on a hetzner grove, [default] is the one line that wires the box to
#     infra's signer; infra's identity skill owns it. a writer here that
#     rebuilt it would cut every profile that leans on it
#   - the live box sits behind the tailnet, so no laptop run can reach it.
#     the LOGIC needs no box: a fixture $HOME holds the config, and a stub
#     `curl` stands in for the signer's IMDSv2 answer
#
# .the writers driven
#   - `5.6.aws` configure.upsert — on hetzner, ec2, and a laptop
#   - `aws.reach.set` — plan (the body names the endpoint), the twin refusal,
#     and apply up to its rack half (the write lands; the rack half refuses in
#     a fixture with no rack root, which this play expects)
#   - `aws.reach.del` — apply up to its rack half, same bound
#   - `grove_aws_config_swap` — a [default] that moves mid-run is never put back
#
# .the infra rewrite it simulates
#   - infra's writer drops [default] and every line to the next `[` header,
#     then appends a new [default]. a fence whose begin comment sat in that
#     span loses it; every writer here must still own that block, never twin it
#
# guarantee:
#   - READ-ONLY outside its own mktemp dir, removed on exit
#   - each arm runs in a subshell, so no HOME, stub, or env leaks between arms
#   - no network, no rack, no aws call: `curl` and `aws` are stubbed per arm
######################################################################

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILLS="$HERE/.agent/repo=.this/role=any/skills"

fixture="$(mktemp -d)" || { echo "💥 MalfunctionError: could not make a temp dir" >&2; exit 1; }
trap 'rm -rf "$fixture"' EXIT

failed=0
pass() { echo "   • $1 ✔"; }
fail() { echo "   💥 MalfunctionError: $1" >&2; failed=1; }
check() { local label="$1"; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }

echo "🌲 prove.hetzner-default-profile-survives"

ENDPOINT='http://127.0.0.1:9911'

# .what = every writer's stdout + stderr, in arm order, for one transcript snap
# .why  = a human reads these lines from an apply; a drift must show in a pr diff
transcript=""
record() {
  local text="${2//$fixture/<fix>}"
  transcript+="## $1"$'\n'"$text"$'\n\n'
}

####################################################################
# fixtures
####################################################################

# .what = infra's [default], as its identity skill writes it
infra_default() {
  printf '[default]\n'
  printf 'region = us-east-1\n'
  printf 'ec2_metadata_service_endpoint = %s\n' "${1:-$ENDPOINT}"
}

# .what = a fresh seat config: a human's own profile, then infra's [default]
seed_config() {
  local home="$1" endpoint="${2:-$ENDPOINT}"
  rm -rf "$home"; mkdir -p "$home/.aws"
  {
    printf '[profile human.sso]\n'
    printf 'sso_session = acme\n'
    printf 'region = us-west-2\n'
    printf '\n'
    infra_default "$endpoint"
  } > "$home/.aws/config"
}

# .what = infra's rewrite: drop [default] to the next header, append a new one
#   $2 = the endpoint the new [default] names (default: $ENDPOINT)
infra_rewrite() {
  local cfg="$1/.aws/config"
  awk '
    /^\[/ { skip = ($0 ~ /^\[[[:space:]]*default[[:space:]]*\]/) }
    !skip { print }
  ' "$cfg" > "$cfg.new"
  infra_default "${2:-$ENDPOINT}" >> "$cfg.new"
  mv "$cfg.new" "$cfg"
}

# .what = the [default] section's raw lines, comments included — the strict read
raw_default() {
  awk '/^\[/ { inside = ($0 ~ /^\[[[:space:]]*default[[:space:]]*\]/) } inside && $0 !~ /^#/' "$1/.aws/config"
}

count_line() { grep -cFx "$2" "$1/.aws/config" || true; }

# .what = the line number of the first line in a file that equals a needle exactly
line_of() { awk -v n="$2" '$0 == n { print NR; exit }' "$1"; }

# .what = run 5.6.aws configure.upsert in a subshell, as `server`, under `home`
#   `curl` answers like an IMDSv2 endpoint, and logs each url it was asked
#   STUB_TOKEN / STUB_ROLE, when set (empty included), replace its two answers
run_5_6_aws() {
  local home="$1" server="$2"
  (
    export HOME="$home" GROVE_ENV_SERVER="$server"
    unset AWS_REGION AWS_DEFAULT_REGION
    # shellcheck source=/dev/null
    source "$HERE/src/grove.env.sh"   # the seat predicates, as the entrypoint loads them
    # shellcheck source=/dev/null
    source "$HERE/src/grove.aws.sh"
    # shellcheck source=/dev/null
    source "$HERE/src/grove.provision/5.devtools/5.6.aws/_.sh"   # the bundle's shared declarations
    # shellcheck source=/dev/null
    source "$HERE/src/grove.provision/5.devtools/5.6.aws/configure.upsert.sh"
    curl() {
      local a
      for a in "$@"; do
        case "$a" in
          */latest/api/token)                         printf '%s\n' "$a" >> "$home/curl.log"; printf '%s\n' "${STUB_TOKEN-tok}"; return 0 ;;
          */latest/meta-data/iam/security-credentials/) printf '%s\n' "$a" >> "$home/curl.log"; printf '%s\n' "${STUB_ROLE-grove-role}"; return 0 ;;
        esac
      done
      return 7
    }
    grove_provision_5_6_aws_configure_upsert
  )
}

####################################################################
# arm 1 — 5.6.aws on hetzner: ambient + endpoint, [default] untouched
####################################################################
H="$fixture/h1"
seed_config "$H"
before_default="$(raw_default "$H")"
out="$(run_5_6_aws "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "5.6.aws · hetzner first apply (rc $rc)" "$out"

check "5.6.aws · hetzner apply exits 0" test "$rc" -eq 0
check "5.6.aws · hetzner [default] byte-equal after apply" test "$(raw_default "$H")" == "$before_default"
check "5.6.aws · hetzner ambient names the endpoint [default] names" \
  test "$(count_line "$H" "ec2_metadata_service_endpoint = $ENDPOINT")" -eq 2
check "5.6.aws · hetzner writes one [profile ambient]" test "$(count_line "$H" '[profile ambient]')" -eq 1
check "5.6.aws · hetzner writes no second [default]" test "$(count_line "$H" '[default]')" -eq 1
check "5.6.aws · hetzner keeps the human's own profile" test "$(count_line "$H" '[profile human.sso]')" -eq 1
check "5.6.aws · hetzner asks the endpoint, never 169.254.169.254" \
  bash -c "grep -qF '$ENDPOINT/latest/api/token' '$H/curl.log' && ! grep -qF 169.254 '$H/curl.log'"
check "5.6.aws · hetzner findserts the empty credentials file" test -f "$H/.aws/credentials"
check "5.6.aws · hetzner reports [default] read, never written" bash -c "[[ \"\$1\" == *'[default] read, never written'* ]]" _ "$out"
hetzner_config="$(cat "$H/.aws/config")"

# a second apply writes no byte
cp "$H/.aws/config" "$fixture/h1.after1"
out="$(run_5_6_aws "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "5.6.aws · hetzner second apply (rc $rc)" "$out"
check "5.6.aws · hetzner second apply is byte-equal" cmp -s "$H/.aws/config" "$fixture/h1.after1"

####################################################################
# arm 2 — infra rewrites [default] after us, and eats our begin line
####################################################################
infra_rewrite "$H"
check "fixture · infra's rewrite ate the 5.6.aws begin line" \
  test "$(count_line "$H" '# grove: the ambient ec2 instance role, as a profile')" -eq 0
before_default="$(raw_default "$H")"
out="$(run_5_6_aws "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "5.6.aws · hetzner apply after infra's rewrite (rc $rc)" "$out"
check "5.6.aws · after infra's rewrite, apply exits 0" test "$rc" -eq 0
check "5.6.aws · after infra's rewrite, still ONE [profile ambient]" test "$(count_line "$H" '[profile ambient]')" -eq 1
check "5.6.aws · after infra's rewrite, [default] byte-equal" test "$(raw_default "$H")" == "$before_default"
check "5.6.aws · after infra's rewrite, one fence end line" test "$(count_line "$H" '# grove: end')" -eq 1

####################################################################
# arm 2b — infra moves the signer: the next apply re-mirrors [default]'s endpoint
#   (case=5 [t1]) — ambient follows [default], and [default] stays infra's bytes
####################################################################
MOVED='http://127.0.0.1:9912'
infra_rewrite "$H" "$MOVED"
before_default="$(raw_default "$H")"
out="$(run_5_6_aws "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "5.6.aws · hetzner apply after infra moved the signer (rc $rc)" "$out"
check "5.6.aws · signer moved, apply exits 0" test "$rc" -eq 0
check "5.6.aws · signer moved, ambient re-mirrors the new endpoint" \
  test "$(count_line "$H" "ec2_metadata_service_endpoint = $MOVED")" -eq 2
check "5.6.aws · signer moved, the old endpoint is named nowhere" \
  test "$(count_line "$H" "ec2_metadata_service_endpoint = $ENDPOINT")" -eq 0
check "5.6.aws · signer moved, [default] byte-equal" test "$(raw_default "$H")" == "$before_default"
check "5.6.aws · signer moved, still ONE [profile ambient]" test "$(count_line "$H" '[profile ambient]')" -eq 1

####################################################################
# arm 3 — hetzner with serve not wired: a ✋ that names infra, config untouched
#   a camp grove's identity is a MANDATED prereq on every seat, so its absence
#   fails the bundle loud rather than declines it quietly
####################################################################
H="$fixture/h3"
seed_config "$H"
awk '!/ec2_metadata_service_endpoint/' "$H/.aws/config" > "$H/x" && mv "$H/x" "$H/.aws/config"
cp "$H/.aws/config" "$fixture/h3.before"
out="$(run_5_6_aws "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
check "5.6.aws · serve not wired FAILS (rc 1) — the identity is a mandated prereq" test "$rc" -eq 1
check "5.6.aws · serve not wired names infra as the owner of the fix" bash -c "[[ \"\$1\" == *'fix (infra)'* ]]" _ "$out"
check "5.6.aws · serve not wired leaves ~/.aws/config byte-equal" cmp -s "$H/.aws/config" "$fixture/h3.before"
check "5.6.aws · serve not wired names the seat it read (\$HOME)" bash -c "[[ \"\$1\" == *\"\$2/.aws/config names no ec2_metadata_service_endpoint\"* ]]" _ "$out" "$H"
check "5.6.aws · serve not wired still findserts credentials" test -f "$H/.aws/credentials"
decline_text="${out//$H/<home>}"

####################################################################
# arm 4 — hetzner with a non-loopback endpoint: refused, never copied
####################################################################
H="$fixture/h4"
seed_config "$H" 'http://203.0.113.9:9911'
cp "$H/.aws/config" "$fixture/h4.before"
out="$(run_5_6_aws "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "5.6.aws · hetzner, a non-loopback endpoint (rc $rc)" "$out"
check "5.6.aws · a non-loopback endpoint is refused (rc 1)" test "$rc" -eq 1
check "5.6.aws · a non-loopback endpoint writes no byte" cmp -s "$H/.aws/config" "$fixture/h4.before"

####################################################################
# arm 5 — ec2 is unchanged: ambient + [default] in one fence, legacy fence replaced
####################################################################
H="$fixture/h5"
rm -rf "$H"; mkdir -p "$H/.aws"
{
  printf '[profile human.sso]\nregion = us-west-2\n'
  printf '# devenv: the ambient ec2 instance role, as a profile\n'
  printf '[profile ambient]\ncredential_source = Ec2InstanceMetadata\nregion = us-east-1\n\n'
  printf '[default]\ncredential_source = Ec2InstanceMetadata\nregion = us-east-1\n'
  printf '# devenv: end\n'
} > "$H/.aws/config"
out="$(run_5_6_aws "$H" cloud@aws.ec2 2>&1)"; rc=$?
record "5.6.aws · ec2 apply over a legacy fence (rc $rc)" "$out"
check "5.6.aws · ec2 apply exits 0" test "$rc" -eq 0
check "5.6.aws · ec2 replaces the legacy fence (one [profile ambient])" test "$(count_line "$H" '[profile ambient]')" -eq 1
check "5.6.aws · ec2 writes [default] inside its fence (one [default])" test "$(count_line "$H" '[default]')" -eq 1
check "5.6.aws · ec2 names no endpoint line" test "$(count_line "$H" "ec2_metadata_service_endpoint = $ENDPOINT")" -eq 0
check "5.6.aws · ec2 asks 169.254.169.254" grep -qF 'http://169.254.169.254/latest/api/token' "$H/curl.log"
cp "$H/.aws/config" "$fixture/h5.after1"
run_5_6_aws "$H" cloud@aws.ec2 >/dev/null 2>&1
check "5.6.aws · ec2 second apply is byte-equal" cmp -s "$H/.aws/config" "$fixture/h5.after1"
ec2_config="$(cat "$H/.aws/config")"

####################################################################
# arm 6 — a laptop declines: no config byte, no credentials file
####################################################################
H="$fixture/h6"
seed_config "$H"
cp "$H/.aws/config" "$fixture/h6.before"
out="$(run_5_6_aws "$H" local@unix 2>&1)"; rc=$?
record "5.6.aws · laptop (rc $rc)" "$out"
check "5.6.aws · laptop exits 0 (a decline)" test "$rc" -eq 0
check "5.6.aws · laptop writes no config byte" cmp -s "$H/.aws/config" "$fixture/h6.before"
check "5.6.aws · laptop writes no credentials file" test ! -e "$H/.aws/credentials"

####################################################################
# arm 6b — a camp grove on an unmapped platform: a ✋, never a decline
#   the camp identity is mandated on every camp grove, so a platform this repo
#   has no road for is a gap to teach, and it must not pass as a laptop does
####################################################################
H="$fixture/h6b"
seed_config "$H"
cp "$H/.aws/config" "$fixture/h6b.before"
out="$(run_5_6_aws "$H" cloud@other.platform 2>&1)"; rc=$?
record "5.6.aws · camp grove on an unmapped platform (rc $rc)" "$out"
check "5.6.aws · camp grove, unmapped platform FAILS (rc 1)" test "$rc" -eq 1
check "5.6.aws · camp grove, unmapped platform names the function to teach" bash -c "[[ \"\$1\" == *grove_aws_identity_endpoint* ]]" _ "$out"
check "5.6.aws · camp grove, unmapped platform writes no config byte" cmp -s "$H/.aws/config" "$fixture/h6b.before"

####################################################################
# arm 7 — the swap refuses when [default] moved after the read
####################################################################
H="$fixture/h7"
seed_config "$H"
got="$(
  export HOME="$H"
  # shellcheck source=/dev/null
  source "$HERE/src/grove.aws.sh"
  read_default="$(grove_aws_config_section cfg="$H/.aws/config" name=default)"
  tmp="$(grove_aws_config_tmp)"
  { cat "$H/.aws/config"; printf '\n[profile extra]\nregion = us-east-1\n'; } > "$tmp"
  # infra's skill runs between the read and the swap
  infra_rewrite "$H"
  awk '{ sub(/9911/, "9912"); print }' "$H/.aws/config" > "$H/x" && mv "$H/x" "$H/.aws/config"
  cp "$H/.aws/config" "$fixture/h7.mid"
  grove_aws_config_swap cfg="$H/.aws/config" new="$tmp" default_before="$read_default" default=keep
  echo "rc=$?"
)"
check "swap · a [default] moved mid-run is refused (rc 3)" test "$got" == "rc=3"
check "swap · the refused swap writes no byte" cmp -s "$H/.aws/config" "$fixture/h7.mid"
check "swap · the refused swap leaves no tmp file" bash -c "! ls -A '$H/.aws' | grep -q '^\.config\.grove\.'"

got="$(
  export HOME="$H"
  # shellcheck source=/dev/null
  source "$HERE/src/grove.aws.sh"
  read_default="$(grove_aws_config_section cfg="$H/.aws/config" name=default)"
  tmp="$(grove_aws_config_tmp)"
  awk '{ sub(/9912/, "1"); print }' "$H/.aws/config" > "$tmp"
  grove_aws_config_swap cfg="$H/.aws/config" new="$tmp" default_before="$read_default" default=keep
  echo "rc=$?"
)"
check "swap · a body that changes a [default] it does not own is refused (rc 4)" test "$got" == "rc=4"

####################################################################
# arm 8 — aws.reach.set on hetzner
####################################################################
# .what = run a reach skill as `server`, under `home`, from a cwd with no repo
#   `aws` is stubbed so no call leaves the box; the rack half then refuses in a
#   fixture with no rack root, after the config half has landed
run_reach() {
  local home="$1" server="$2" skill="$3"; shift 3
  (
    export HOME="$home" GROVE_ENV_SERVER="$server"
    mkdir -p "$home/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$home/bin/aws"; chmod +x "$home/bin/aws"
    export PATH="$home/bin:$PATH"
    cd "$home" && bash "$SKILLS/$skill.sh" "$@"
  )
}

H="$fixture/h8"
seed_config "$H"
out="$(run_reach "$H" cloud@hetzner.hetzbot aws.reach.set --org acme --env test --assume grove-hop --account 123456789012 --mode plan 2>&1)"; rc=$?
record "aws.reach.set · hetzner plan (rc $rc)" "$out"
check "aws.reach.set · hetzner plan exits 0" test "$rc" -eq 0
check "aws.reach.set · hetzner plan names the grove box kind" bash -c "[[ \"\$1\" == *'box:     grove (cloud@hetzner.hetzbot)'* ]]" _ "$out"
check "aws.reach.set · hetzner body carries the endpoint line" bash -c "[[ \"\$1\" == *'ec2_metadata_service_endpoint = $ENDPOINT'* ]]" _ "$out"
check "aws.reach.set · hetzner body keeps credential_source" bash -c "[[ \"\$1\" == *'credential_source = Ec2InstanceMetadata'* ]]" _ "$out"
check "aws.reach.set · hetzner plan names the vault the apply writes (os.direct)" bash -c "[[ \"\$1\" == *'--vault os.direct'* && \"\$1\" != *'--vault aws.config'* ]]" _ "$out"

before_default="$(raw_default "$H")"
out="$(run_reach "$H" cloud@hetzner.hetzbot aws.reach.set --org acme --env test --assume grove-hop --account 123456789012 --mode apply 2>&1)"; rc=$?
record "aws.reach.set · hetzner apply, up to the rack half (rc $rc)" "$out"
check "aws.reach.set · hetzner apply stops at the rack half in a fixture (rc 1)" test "$rc" -eq 1
check "aws.reach.set · hetzner apply wrote the fenced profile" test "$(count_line "$H" '[profile acme.test.ehmpath]')" -eq 1
check "aws.reach.set · hetzner apply left [default] byte-equal" test "$(raw_default "$H")" == "$before_default"
check "aws.reach.set · hetzner apply wrote no second [default]" test "$(count_line "$H" '[default]')" -eq 1

# infra eats the reach fence's begin line; a re-run neither twins nor refuses it
infra_rewrite "$H"
run_reach "$H" cloud@hetzner.hetzbot aws.reach.set --org acme --env test --assume grove-hop --account 123456789012 --mode apply >/dev/null 2>&1; rc=$?
# rc 1 = it passed the twin check and reached the rack half; rc 2 would mean it
#   read its OWN orphaned fence as a hand-laid twin, and refused every run after
check "aws.reach.set · after infra's rewrite, the re-run owns its orphan (rc 1, not a twin refusal)" test "$rc" -eq 1
check "aws.reach.set · after infra's rewrite, still ONE [profile acme.test.ehmpath]" \
  test "$(count_line "$H" '[profile acme.test.ehmpath]')" -eq 1

infra_rewrite "$H"
listed="$(
  export HOME="$H"
  # shellcheck source=/dev/null
  source "$SKILLS/aws.reach.operations.sh"
  aws_reach_fence_list
)"
check "aws.reach list · a fence whose begin line was eaten is still listed" test "$listed" == "acme.test.ehmpath"

# a hand-laid twin is refused before either half is written
H="$fixture/h8b"
seed_config "$H"
printf '\n[profile acme.test.ehmpath]\nregion = us-east-1\n' >> "$H/.aws/config"
cp "$H/.aws/config" "$fixture/h8b.before"
out="$(run_reach "$H" cloud@hetzner.hetzbot aws.reach.set --org acme --env test --assume grove-hop --account 123456789012 --mode apply 2>&1)"; rc=$?
record "aws.reach.set · hetzner, a hand-laid twin (rc $rc)" "$out"
check "aws.reach.set · an unfenced twin is refused (rc 2)" test "$rc" -eq 2
check "aws.reach.set · the twin refusal writes no byte" cmp -s "$H/.aws/config" "$fixture/h8b.before"
twin_at="$(line_of "$H/.aws/config" '[profile acme.test.ehmpath]')"
check "aws.reach.set · the twin refusal names the hand block's line range" \
  bash -c '[[ "$1" == *"lines $2-$(( $2 + 1 ))"* ]]' _ "$out" "$twin_at"

# a laptop over ssh with no declaration is refused by name, never read as a laptop
H="$fixture/h8c"
seed_config "$H"
out="$(
  export HOME="$H"; unset GROVE_ENV_SERVER DISPLAY WAYLAND_DISPLAY XDG_SESSION_TYPE
  export SSH_CONNECTION='192.0.2.1 50000 192.0.2.2 22'
  cd "$H" && bash -c '
    source "$1/aws.reach.operations.sh"; aws_reach_runtime_load
    grove_env_platform_file() { printf "%s" "$HOME/no-declaration"; }
    grove_env_probe_aws_ec2() { return 1; }; grove_env_probe_aws_ec2_imds() { return 1; }
    grove_env_derive; echo "rc=$?"' _ "$SKILLS" 2>/dev/null | tail -1
)"
check "aws.reach.set · an undeclared seat over ssh is refused by the derive (rc 2)" test "$out" == "rc=2"

####################################################################
# arm 8d — aws.reach.set on hetzner, the role trusts the box and refuses its
#   session tags: the composed refusal names the asker and every action owed
#   the rack half passes on a stub (a rack root dir, an `rhx` that answers the
#   profile); the stub `aws` refuses the hop's sts call as a roles-anywhere
#   session is refused, and answers the ambient profile's
####################################################################
H="$fixture/h8d"
seed_config "$H"
mkdir -p "$H/.local/state/keyrack.gitroot/.git" "$H/bin"
printf '#!/usr/bin/env bash\n[[ "$1 $2" == "keyrack get" ]] && { echo acme.test.ehmpath; exit 0; }\nexit 0\n' > "$H/bin/rhx"
printf '%s\n' '#!/usr/bin/env bash' \
  'case "$*" in' \
  '  *get-caller-identity*--profile\ ambient*) echo "arn:aws:sts::123456789012:assumed-role/grove-role/session"; exit 0 ;;' \
  '  *get-caller-identity*) echo "An error occurred (AccessDenied) when calling the AssumeRole operation: User: arn:aws:sts::123456789012:assumed-role/grove-role/session is not authorized to perform: sts:TagSession on resource: arn:aws:iam::111122223333:role/grove-hop" >&2; exit 254 ;;' \
  'esac' 'exit 0' > "$H/bin/aws.trust"
chmod +x "$H/bin/rhx" "$H/bin/aws.trust"
out="$(
  export HOME="$H" GROVE_ENV_SERVER=cloud@hetzner.hetzbot
  # run_reach lays an always-ok `aws`; this arm lays the refusal in its place
  mkdir -p "$H/trustbin" && cp "$H/bin/aws.trust" "$H/trustbin/aws"
  export PATH="$H/trustbin:$H/bin:$PATH"
  cd "$H" && bash "$SKILLS/aws.reach.set.sh" --org acme --env test --assume grove-hop --account 111122223333 --mode apply 2>&1
)"; rc=$?
record "aws.reach.set · hetzner apply, the role refuses the session's tags (rc $rc)" "$out"
check "aws.reach.set · a trust refusal is a 💥 (rc 1)" test "$rc" -eq 1
check "aws.reach.set · the refusal names the refused action" bash -c "[[ \"\$1\" == *'refuses what its session carries (sts:TagSession)'* ]]" _ "$out"
check "aws.reach.set · the refusal names the principal that asked" bash -c "[[ \"\$1\" == *'the principal that asked: arn:aws:sts::123456789012:assumed-role/grove-role/session'* ]]" _ "$out"
check "aws.reach.set · the refusal names every action owed, at once" bash -c "[[ \"\$1\" == *'\"sts:AssumeRole\", \"sts:SetSourceIdentity\", \"sts:TagSession\"'* ]]" _ "$out"
check "aws.reach.set · the refusal names the org whose infra owns the fix" bash -c "[[ \"\$1\" == *'an ask of acme/infrastructure'* ]]" _ "$out"

####################################################################
# arm 8e — aws.reach.set on hetzner, the hop's SOURCE does not answer (a dead
#   signer): the refusal names this box's identity, never infra's trust policy
####################################################################
H="$fixture/h8e"
seed_config "$H"
mkdir -p "$H/.local/state/keyrack.gitroot/.git" "$H/bin" "$H/deadbin"
printf '#!/usr/bin/env bash\n[[ "$1 $2" == "keyrack get" ]] && { echo acme.test.ehmpath; exit 0; }\nexit 0\n' > "$H/bin/rhx"
printf '%s\n' '#!/usr/bin/env bash' \
  'case "$*" in' \
  '  *get-caller-identity*) echo "Error when retrieving credentials from custom-process: connect: connection refused" >&2; exit 255 ;;' \
  'esac' 'exit 0' > "$H/deadbin/aws"
chmod +x "$H/bin/rhx" "$H/deadbin/aws"
out="$(
  export HOME="$H" GROVE_ENV_SERVER=cloud@hetzner.hetzbot PATH="$H/deadbin:$H/bin:$PATH"
  cd "$H" && bash "$SKILLS/aws.reach.set.sh" --org acme --env test --assume grove-hop --account 111122223333 --mode apply 2>&1
)"; rc=$?
record "aws.reach.set · hetzner apply, the hop's source does not answer (rc $rc)" "$out"
check "aws.reach.set · a dead source is a 💥 (rc 1)" test "$rc" -eq 1
check "aws.reach.set · a dead source names the source, never the role" \
  bash -c "[[ \"\$1\" == *'the hop'\"'\"'s SOURCE did not answer'* ]]" _ "$out"
check "aws.reach.set · a dead source is no ask of infra" \
  bash -c "[[ \"\$1\" != *'an ask of acme/infrastructure'* && \"\$1\" != *'trust policy'* ]]" _ "$out"
check "aws.reach.set · a dead source names the identity bundle" \
  bash -c "[[ \"\$1\" == *'rhx grove.provision --what 5.6.aws --mode plan'* ]]" _ "$out"

####################################################################
# arm 8f — aws.reach.set on hetzner, the headline road: the hop ANSWERS
#   the rack half passes on the 8d stub; sts answers the hop in the declared
#   account. apply ends ✔, a re-run reads `already current`, and an answer from
#   another account is the ✋ that --account exists for
####################################################################
H="$fixture/h8f"
seed_config "$H"
mkdir -p "$H/.local/state/keyrack.gitroot/.git" "$H/bin" "$H/okbin"
printf '#!/usr/bin/env bash\n[[ "$1 $2" == "keyrack get" ]] && { echo acme.test.ehmpath; exit 0; }\nexit 0\n' > "$H/bin/rhx"
printf '%s\n' '#!/usr/bin/env bash' \
  'case "$*" in' \
  '  *get-caller-identity*) printf "{\"Account\":\"%s\",\"Arn\":\"arn:aws:sts::%s:assumed-role/grove-hop/session\"}\n" "${STUB_ACCT:-111122223333}" "${STUB_ACCT:-111122223333}"; exit 0 ;;' \
  'esac' 'exit 0' > "$H/okbin/aws"
chmod +x "$H/bin/rhx" "$H/okbin/aws"
run_reach_ok() {
  (
    export HOME="$H" GROVE_ENV_SERVER=cloud@hetzner.hetzbot PATH="$H/okbin:$H/bin:$PATH"
    cd "$H" && bash "$SKILLS/aws.reach.set.sh" --org acme --env test --assume grove-hop --account 111122223333 --mode apply 2>&1
  )
}
before_default="$(raw_default "$H")"
out="$(run_reach_ok)"; rc=$?
record "aws.reach.set · hetzner apply, the hop answers (rc $rc)" "$out"
check "aws.reach.set · the hop answers: apply exits 0" test "$rc" -eq 0
check "aws.reach.set · it names the account the hop answered in" bash -c "[[ \"\$1\" == *'✔ answers, in account 111122223333'* ]]" _ "$out"
check "aws.reach.set · the headline apply left [default] byte-equal" test "$(raw_default "$H")" == "$before_default"
cp "$H/.aws/config" "$fixture/h8f.after"
out="$(run_reach_ok)"; rc=$?
record "aws.reach.set · hetzner apply again, the hop answers (rc $rc)" "$out"
check "aws.reach.set · a re-run exits 0 and reads already current" \
  bash -c "[[ \"\$2\" -eq 0 && \"\$1\" == *'already current for [profile acme.test.ehmpath]'* ]]" _ "$out" "$rc"
check "aws.reach.set · a re-run writes no byte" cmp -s "$H/.aws/config" "$fixture/h8f.after"
out="$(STUB_ACCT=999999999999 run_reach_ok)"; rc=$?
record "aws.reach.set · hetzner apply, the hop answers as another account (rc $rc)" "$out"
check "aws.reach.set · an answer from another account is a ✋ (rc 2)" test "$rc" -eq 2
check "aws.reach.set · it names the expected and the detected account" \
  bash -c "[[ \"\$1\" == *'expected: 111122223333'* && \"\$1\" == *'detected: 999999999999'* ]]" _ "$out"

####################################################################
# arm 8g — aws.reach.set on hetzner, the rack half on a FRESH box: the rack holds
#   no entry, so the set runs. `rhx` is a stateful stub — `keyrack get` reads a
#   state file, `keyrack set` writes the value it was fed (or, as STUB_RACK says,
#   drops it as a tty-read would, or refuses). a fresh hetzner box's first apply
####################################################################
H="$fixture/h8g"
seed_config "$H"
mkdir -p "$H/.local/state/keyrack.gitroot/.git" "$H/bin"
cp "$fixture/h8f/okbin/aws" "$H/bin/aws"
# the get line stands on its own printf line, so the rack census reads it as a stub
printf '%s\n' '#!/usr/bin/env bash' "S=\"$H/rack\"" '[[ "$1 $2" == "keyrack get" ]] && { [[ -s "$S" ]] && cat "$S"; exit 0; }' > "$H/bin/rhx"
printf '%s\n' \
  '[[ "$1 $2" == "keyrack set" ]] || exit 0' \
  'printf "%s\n" "$*" >> "$S.calls"; v="$(cat)"' \
  'case "${STUB_RACK:-ok}" in' \
  '  refuse) echo "keyrack: AWS_PROFILE is not declared for env=test" >&2; exit 1 ;;' \
  '  drop) : > "$S" ;;' \
  '  *) printf "%s\n" "$v" > "$S" ;;' \
  'esac; echo "✔ set"; exit 0' >> "$H/bin/rhx"
chmod +x "$H/bin/rhx" "$H/bin/aws"
run_reach_rack() {
  (
    export HOME="$H" GROVE_ENV_SERVER=cloud@hetzner.hetzbot PATH="$H/bin:$PATH"
    cd "$H" && bash "$SKILLS/aws.reach.set.sh" --org acme --env test --assume grove-hop --account 111122223333 --mode apply 2>&1
  )
}
out="$(STUB_RACK=refuse run_reach_rack)"; rc=$?
record "aws.reach.set · hetzner apply, an empty rack refuses the set (rc $rc)" "$out"
check "aws.reach.set · a refused set is a 💥 (rc 1)" test "$rc" -eq 1
check "aws.reach.set · a refused set names the keyrack.yml declaration owed" \
  bash -c "[[ \"\$1\" == *'keyrack refused the set'* && \"\$1\" == *'env.test:'* ]]" _ "$out"
out="$(STUB_RACK=drop run_reach_rack)"; rc=$?
record "aws.reach.set · hetzner apply, the set claims success and stores no value (rc $rc)" "$out"
check "aws.reach.set · a set the re-read disproves is a ✋ (rc 2)" test "$rc" -eq 2
check "aws.reach.set · it names the shadow cause and the hand fix" \
  bash -c "[[ \"\$1\" == *'the set reported success and the rack still answers'* && \"\$1\" == *'--vault os.direct'* ]]" _ "$out"
rm -f "$H/rack" "$H/rack.calls"
out="$(run_reach_rack)"; rc=$?
record "aws.reach.set · hetzner apply, an empty rack is set (rc $rc)" "$out"
check "aws.reach.set · empty rack: apply exits 0" test "$rc" -eq 0
check "aws.reach.set · empty rack: it says the rack did not answer yet" \
  bash -c "[[ \"\$1\" == *'rack does not answer acme.test.AWS_PROFILE yet'* ]]" _ "$out"
check "aws.reach.set · empty rack: one set, into os.direct" \
  bash -c '[[ $(grep -c "keyrack set" "$1") == 1 ]] && grep -q -- "--vault os.direct" "$1"' _ "$H/rack.calls"
check "aws.reach.set · empty rack: the re-read answers the profile" \
  bash -c "[[ \"\$1\" == *'rack now answers acme.test.AWS_PROFILE = acme.test.ehmpath ✔'* ]]" _ "$out"
out="$(run_reach_rack)"; rc=$?
check "aws.reach.set · empty rack: a re-run asks no second set" \
  bash -c '[[ "$2" -eq 0 && $(grep -c "keyrack set" "$1") == 1 ]]' _ "$H/rack.calls" "$rc"

####################################################################
# arm 9 — aws.reach.del on hetzner keeps [default]
####################################################################
H="$fixture/h8"
before_default="$(raw_default "$H")"
out="$(run_reach "$H" cloud@hetzner.hetzbot aws.reach.del --org acme --env test --mode apply 2>&1)"; rc=$?
record "aws.reach.del · hetzner apply, up to the rack half (rc $rc)" "$out"
check "aws.reach.del · hetzner apply removed the profile" test "$(count_line "$H" '[profile acme.test.ehmpath]')" -eq 0
check "aws.reach.del · hetzner apply left [default] byte-equal" test "$(raw_default "$H")" == "$before_default"
check "aws.reach.del · hetzner apply removed the orphan end line too" \
  test "$(count_line "$H" '# grove: reach acme.test.ehmpath — end')" -eq 0

####################################################################
# arm 9b — each writer's refused swap, and the endpoint's two silent answers
#   an `mv` that refuses ~/.aws/config alone makes grove_aws_config_swap rc 1, so
#   each writer's composed halt reaches the human whole. a separate process (the
#   reach skills) cannot be reached by a function override; a PATH stub can
####################################################################
# .what = an `mv` that refuses one target, the config, and moves all else
lay_failmv() {
  mkdir -p "$1"
  printf '%s\n' '#!/usr/bin/env bash' \
    'for last; do :; done' \
    '[[ "$last" == */.aws/config ]] && { echo "mv: cannot move to $last: Permission denied" >&2; exit 1; }' \
    'command -p mv "$@"' > "$1/mv"
  chmod +x "$1/mv"
}
no_tmp_left() { ! ls -A "$1/.aws" | grep -q '^\.config\.grove\.'; }

# 5.6.aws: the swap fails at the write
H="$fixture/h9b"
seed_config "$H"
cp "$H/.aws/config" "$fixture/h9b.before"
lay_failmv "$fixture/failmv"
out="$(PATH="$fixture/failmv:$PATH" run_5_6_aws "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "5.6.aws · hetzner, the swap's write fails (rc $rc)" "$out"
check "5.6.aws · a failed swap is a 💥 (rc 1)" test "$rc" -eq 1
check "5.6.aws · a failed swap names the config and the io cause" \
  bash -c '[[ "$1" == *"💥 MalfunctionError: ~/.aws/config was NOT written: the write failed (io)"* ]]' _ "$out"
check "5.6.aws · a failed swap writes no byte" cmp -s "$H/.aws/config" "$fixture/h9b.before"
check "5.6.aws · a failed swap leaves no tmp file" no_tmp_left "$H"

# 5.6.aws: the endpoint answers with no token, then with no role
out="$(STUB_TOKEN='' run_5_6_aws "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "5.6.aws · hetzner, the endpoint gives no token (rc $rc)" "$out"
check "5.6.aws · no token is a ✋ (rc 1)" test "$rc" -eq 1
check "5.6.aws · no token names the endpoint and infra's serve unit" \
  bash -c '[[ "$1" == *"ConstraintError: cloud@hetzner.hetzbot declares a platform identity at"*"and it gave no token"* && "$1" == *"infra'"'"'s signer serves on"* ]]' _ "$out"
check "5.6.aws · no token writes no byte" cmp -s "$H/.aws/config" "$fixture/h9b.before"

out="$(STUB_ROLE='' run_5_6_aws "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "5.6.aws · hetzner, the endpoint names no role (rc $rc)" "$out"
check "5.6.aws · no role is a ✋ (rc 1)" test "$rc" -eq 1
check "5.6.aws · no role says so, and names both platforms' fix" \
  bash -c '[[ "$1" == *"ConstraintError: the identity endpoint answers, but names NO role"* && "$1" == *"roles-anywhere profile"* ]]' _ "$out"
check "5.6.aws · no role writes no byte" cmp -s "$H/.aws/config" "$fixture/h9b.before"

# aws.reach.set: the swap fails at the write, before the rack half
H="$fixture/h9c"
seed_config "$H"
cp "$H/.aws/config" "$fixture/h9c.before"
lay_failmv "$H/bin"
out="$(run_reach "$H" cloud@hetzner.hetzbot aws.reach.set --org acme --env test --assume grove-hop --account 123456789012 --mode apply 2>&1)"; rc=$?
record "aws.reach.set · hetzner, the swap's write fails (rc $rc)" "$out"
check "aws.reach.set · a failed swap is a 💥 (rc 1)" test "$rc" -eq 1
check "aws.reach.set · a failed swap names the config and the io cause" \
  bash -c '[[ "$1" == *"💥 MalfunctionError: ~/.aws/config was NOT written: the write failed (io)"* ]]' _ "$out"
check "aws.reach.set · a failed swap writes no byte" cmp -s "$H/.aws/config" "$fixture/h9c.before"
check "aws.reach.set · a failed swap leaves no tmp file" no_tmp_left "$H"

# aws.reach.del: a fence laid first, then the swap fails at the write
H="$fixture/h9d"
seed_config "$H"
run_reach "$H" cloud@hetzner.hetzbot aws.reach.set --org acme --env test --assume grove-hop --account 123456789012 --mode apply >/dev/null 2>&1
check "fixture · aws.reach.del has a fence to drop" test "$(count_line "$H" '[profile acme.test.ehmpath]')" -eq 1
cp "$H/.aws/config" "$fixture/h9d.before"
lay_failmv "$H/bin"
out="$(run_reach "$H" cloud@hetzner.hetzbot aws.reach.del --org acme --env test --mode apply 2>&1)"; rc=$?
record "aws.reach.del · hetzner, the swap's write fails (rc $rc)" "$out"
check "aws.reach.del · a failed swap is a 💥 (rc 1)" test "$rc" -eq 1
check "aws.reach.del · a failed swap names the config and the io cause" \
  bash -c '[[ "$1" == *"💥 MalfunctionError: ~/.aws/config was NOT written: the write failed (io)"* ]]' _ "$out"
check "aws.reach.del · a failed swap keeps the fence it could not drop" cmp -s "$H/.aws/config" "$fixture/h9d.before"

####################################################################
# arm 10 — two writers alternate on ec2: a second round writes no byte
#   `5.6.aws` and `aws.reach.set` share the file. each one's write must set its
#   fence where it stands, else each apply moves the other's block, and a box
#   whose content never changes is rewritten on every apply
#   📜 2026-11-14, an ec2 camper: the config hash moved on every apply
####################################################################
H="$fixture/h10"
rm -rf "$H"; mkdir -p "$H/.aws"
printf '[profile human.sso]\nregion = us-west-2\n' > "$H/.aws/config"
round() {
  run_5_6_aws "$H" cloud@aws.ec2 >/dev/null 2>&1
  run_reach "$H" cloud@aws.ec2 aws.reach.set --org acme --env test --assume grove-hop --account 123456789012 --mode apply >/dev/null 2>&1
  run_reach "$H" cloud@aws.ec2 aws.reach.set --org acme --env prep --assume grove-hop --account 123456789012 --mode apply >/dev/null 2>&1
}
round
cp "$H/.aws/config" "$fixture/h10.round1"
round
check "two writers · a second round on ec2 is byte-equal" cmp -s "$H/.aws/config" "$fixture/h10.round1"
round
check "two writers · a third round is byte-equal" cmp -s "$H/.aws/config" "$fixture/h10.round1"
check "two writers · each profile once" bash -c '[[ $(grep -cFx "[profile ambient]" "$1") == 1 && $(grep -cFx "[profile acme.test.ehmpath]" "$1") == 1 && $(grep -cFx "[profile acme.prep.ehmpath]" "$1") == 1 ]]' _ "$H/.aws/config"
check "two writers · ec2 hops name no endpoint (case=4: the instance role answers)" \
  bash -c '! grep -q "ec2_metadata_service_endpoint" "$1"' _ "$H/.aws/config"
check "two writers · no blank-line run grows (none longer than one)" bash -c '! awk "/^\$/ { n++; if (n > 1) bad = 1; next } { n = 0 } END { exit !bad }" "$1"' _ "$H/.aws/config"

####################################################################
# arm 11 — 5.6.aws configure.verify, every road and every hetzner claim
#   `aws` answers the two live claims (export, bare region); `tmux` is stubbed
#   so the laptop's own duct server cannot leak into the transcript, and `zsh`
#   so the fresh-shell claim reads this fixture, never the laptop's own rc files
#   VSTUB = ok (default) · noexport · fail · noregion — how `aws` answers
#   VZSH  = the AWS_PROFILE a fresh zsh reports ('' by default)
####################################################################
run_5_6_aws_verify() {
  local home="$1" server="$2"
  (
    export HOME="$home" GROVE_ENV_SERVER="$server" VSTUB="${VSTUB:-ok}" VZSH="${VZSH:-}"
    unset AWS_PROFILE AWS_REGION AWS_DEFAULT_REGION
    # VPARENT = an AWS_PROFILE the human's own shell exports, which a child zsh inherits
    [[ -n "${VPARENT:-}" ]] && export AWS_PROFILE="$VPARENT"
    mkdir -p "$home/vbin"
    printf '%s\n' '#!/usr/bin/env bash' \
      'case "$*" in' \
      '  *export-credentials*)' \
      '    case "$VSTUB" in' \
      '      noexport) echo "export AWS_REGION=us-east-1" ;;' \
      '      fail) echo "Error: the custom-process credential provider failed: connect: connection refused" >&2; exit 255 ;;' \
      '      *) echo "export AWS_ACCESS_KEY_ID=<redacted>" ;;' \
      '    esac ;;' \
      '  *"configure get region"*) [[ "$VSTUB" == noregion ]] && exit 1; echo us-east-1 ;;' \
      'esac' > "$home/vbin/aws"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$home/vbin/tmux"
    # a real zsh INHERITS the caller's env, so this one does too: VZSH is what its
    #   rc files export; else it echoes back the AWS_PROFILE it was handed
    printf '#!/usr/bin/env bash\nprintf "%%s" "${VZSH:-${AWS_PROFILE:-}}"\n' > "$home/vbin/zsh"
    chmod +x "$home/vbin/aws" "$home/vbin/tmux" "$home/vbin/zsh"
    export PATH="$home/vbin:$PATH"
    # shellcheck source=/dev/null
    source "$HERE/src/grove.env.sh"
    # shellcheck source=/dev/null
    source "$HERE/src/grove.aws.sh"
    # shellcheck source=/dev/null
    source "$HERE/src/grove.provision/5.devtools/5.6.aws/_.sh"
    # shellcheck source=/dev/null
    source "$HERE/src/grove.provision/5.devtools/5.6.aws/configure.verify.sh"
    grove_provision_5_6_aws_configure_verify
  )
}

# a hetzner seat the upsert converged: every claim holds
H="$fixture/h11"
seed_config "$H"
run_5_6_aws "$H" cloud@hetzner.hetzbot >/dev/null 2>&1
out="$(run_5_6_aws_verify "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "5.6.aws verify · hetzner, converged (rc $rc)" "$out"
check "5.6.aws verify · hetzner converged passes (rc 0)" test "$rc" -eq 0
check "5.6.aws verify · names the mirror it checked" bash -c "[[ \"\$1\" == *\"[profile ambient] mirrors [default]'s endpoint ✔ ($ENDPOINT)\"* ]]" _ "$out"
check "5.6.aws verify · names [default] as infra's alone" bash -c "[[ \"\$1\" == *\"[default] is infra's alone ✔\"* ]]" _ "$out"

# infra's skill moved the signer: the mirror is stale
awk -v e="ec2_metadata_service_endpoint = $ENDPOINT" '
  /^\[/ { d = ($0 ~ /^\[default\]/) }
  d && $0 == e { print "ec2_metadata_service_endpoint = http://127.0.0.1:9912"; next } { print }
' "$H/.aws/config" > "$H/x" && mv "$H/x" "$H/.aws/config"
out="$(run_5_6_aws_verify "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "5.6.aws verify · hetzner, infra moved the signer (rc $rc)" "$out"
check "5.6.aws verify · a stale mirror is a ✋ (rc 1)" test "$rc" -eq 1
check "5.6.aws verify · it names both endpoints" bash -c "[[ \"\$1\" == *\"[profile ambient] names endpoint '$ENDPOINT', and [default] names 'http://127.0.0.1:9912'\"* ]]" _ "$out"

# a [default] inside this bundle's own fence shadows infra's
H="$fixture/h11b"
seed_config "$H"
run_5_6_aws "$H" cloud@hetzner.hetzbot >/dev/null 2>&1
awk '$0 == "# grove: end" && !done { print "[default]"; print "region = us-east-1"; done = 1 } { print }' \
  "$H/.aws/config" > "$H/x" && mv "$H/x" "$H/.aws/config"
out="$(run_5_6_aws_verify "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "5.6.aws verify · hetzner, a [default] inside this bundle's fence (rc $rc)" "$out"
check "5.6.aws verify · a fenced [default] is a ✋ (rc 1)" test "$rc" -eq 1
check "5.6.aws verify · it names the shadow" bash -c "[[ \"\$1\" == *\"this bundle's fence in\"*\"holds a [default] block\"* ]]" _ "$out"

# each claim's own ✋, on a hetzner seat: one fact broken per case
H="$fixture/h11v"
seed_config "$H"
out="$(run_5_6_aws_verify "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "5.6.aws verify · hetzner, the ambient profile is not declared (rc $rc)" "${out//$H/<home>}"
check "5.6.aws verify · undeclared is a ✋ that names the profile (rc 1)" \
  bash -c '[[ "$2" -eq 1 && "$1" == *"✋ ConstraintError: the '"'"'ambient'"'"' profile is NOT declared in ~/.aws/config"* ]]' _ "$out" "$rc"
run_5_6_aws "$H" cloud@hetzner.hetzbot >/dev/null 2>&1
v_case() {   # $1 = header, $2 = the ✋ it must name; the stub knobs ride the env
  local out rc
  out="$(run_5_6_aws_verify "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
  record "5.6.aws verify · hetzner, $1 (rc $rc)" "${out//$H/<home>}"
  check "5.6.aws verify · $1 is a ✋ that names it (rc 1)" \
    bash -c '[[ "$2" -eq 1 && "$1" == *"✋ ConstraintError: $3"* ]]' _ "$out" "$rc" "$2"
}
VSTUB=noexport v_case "the profile exports no access key" "the profile exported NO access key"
VSTUB=fail     v_case "the profile cannot export"         "the ambient profile could not export credentials"
VSTUB=noregion v_case "no region resolves bare"           "with NO profile named, NO region resolves"
VZSH=ambient   v_case "a fresh zsh exports AWS_PROFILE"   "a fresh non-interactive zsh exports AWS_PROFILE='ambient'"
# the caller's shell exports AWS_PROFILE and the rc files do not: the probe must strip
#   the inherited env (`env -u AWS_PROFILE`), or it blames 2.5.zsh for the human's shell
out="$(VPARENT=ambient run_5_6_aws_verify "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
check "5.6.aws verify · an AWS_PROFILE the caller exports is not read as zsh's (rc 0)" \
  bash -c '[[ "$2" -eq 0 && "$1" != *"a fresh non-interactive zsh exports"* ]]' _ "$out" "$rc"
rm -f "$H/.aws/credentials"
v_case "the credentials file is absent" "~/.aws/credentials is ABSENT"

# the roads that refuse or decline before any claim
H="$fixture/h11c"
seed_config "$H"
awk '!/ec2_metadata_service_endpoint/' "$H/.aws/config" > "$H/x" && mv "$H/x" "$H/.aws/config"
out="$(run_5_6_aws_verify "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "5.6.aws verify · hetzner, serve not wired (rc $rc)" "${out//$H/<home>}"
check "5.6.aws verify · serve-unwired is a ✋ (rc 1)" test "$rc" -eq 1
check "5.6.aws verify · serve-unwired names infra's fix" bash -c "[[ \"\$1\" == *'fix (infra)'* ]]" _ "$out"

H="$fixture/h11d"
seed_config "$H" 'http://203.0.113.9:9911'
out="$(run_5_6_aws_verify "$H" cloud@hetzner.hetzbot 2>&1)"; rc=$?
record "5.6.aws verify · hetzner, a non-loopback endpoint (rc $rc)" "${out//$H/<home>}"
check "5.6.aws verify · bad-endpoint is a ✋ (rc 1)" test "$rc" -eq 1
check "5.6.aws verify · bad-endpoint names the value" bash -c "[[ \"\$1\" == *\"non-loopback ec2_metadata_service_endpoint ('http://203.0.113.9:9911')\"* ]]" _ "$out"

H="$fixture/h11e"
seed_config "$H"
out="$(run_5_6_aws_verify "$H" cloud@other.platform 2>&1)"; rc=$?
record "5.6.aws verify · camp grove on an unmapped platform (rc $rc)" "$out"
check "5.6.aws verify · unmapped is a ✋ (rc 1)" test "$rc" -eq 1
check "5.6.aws verify · unmapped names the function to teach" bash -c "[[ \"\$1\" == *grove_aws_identity_endpoint* ]]" _ "$out"

out="$(run_5_6_aws_verify "$H" local@unix 2>&1)"; rc=$?
record "5.6.aws verify · laptop (rc $rc)" "$out"
check "5.6.aws verify · a laptop is not applicable (rc 0)" test "$rc" -eq 0
check "5.6.aws verify · a laptop says so" bash -c "[[ \"\$1\" == *'not applicable'* ]]" _ "$out"

####################################################################
# arm 12 — aws.reach.set, every identity road
####################################################################
H="$fixture/h12a"
seed_config "$H"
awk '!/ec2_metadata_service_endpoint/' "$H/.aws/config" > "$H/x" && mv "$H/x" "$H/.aws/config"
cp "$H/.aws/config" "$fixture/h12a.before"
out="$(run_reach "$H" cloud@hetzner.hetzbot aws.reach.set --org acme --env test --assume grove-hop --account 123456789012 --mode apply 2>&1)"; rc=$?
record "aws.reach.set · hetzner, serve not wired (rc $rc)" "${out//$H/<home>}"
check "aws.reach.set · serve-unwired is refused (rc 2)" test "$rc" -eq 2
check "aws.reach.set · serve-unwired writes no byte" cmp -s "$H/.aws/config" "$fixture/h12a.before"

H="$fixture/h12b"
seed_config "$H" 'http://203.0.113.9:9911'
cp "$H/.aws/config" "$fixture/h12b.before"
out="$(run_reach "$H" cloud@hetzner.hetzbot aws.reach.set --org acme --env test --assume grove-hop --account 123456789012 --mode apply 2>&1)"; rc=$?
record "aws.reach.set · hetzner, a non-loopback endpoint (rc $rc)" "${out//$H/<home>}"
check "aws.reach.set · bad-endpoint is refused (rc 2)" test "$rc" -eq 2
check "aws.reach.set · bad-endpoint writes no byte" cmp -s "$H/.aws/config" "$fixture/h12b.before"

H="$fixture/h12c"
seed_config "$H"
cp "$H/.aws/config" "$fixture/h12c.before"
out="$(run_reach "$H" cloud@other.platform aws.reach.set --org acme --env test --assume grove-hop --account 123456789012 --mode apply 2>&1)"; rc=$?
record "aws.reach.set · camp grove on an unmapped platform (rc $rc)" "$out"
check "aws.reach.set · unmapped is refused, never read as a laptop (rc 2)" test "$rc" -eq 2
check "aws.reach.set · unmapped names the function to teach" bash -c "[[ \"\$1\" == *grove_aws_identity_endpoint* ]]" _ "$out"
check "aws.reach.set · unmapped writes no byte" cmp -s "$H/.aws/config" "$fixture/h12c.before"

H="$fixture/h12d"
seed_config "$H"
out="$(run_reach "$H" local@unix aws.reach.set --org acme --env test --assume grove-hop --account 123456789012 --mode plan 2>&1)"; rc=$?
record "aws.reach.set · laptop plan (rc $rc)" "$out"
check "aws.reach.set · a laptop reads as the laptop box kind" bash -c "[[ \"\$1\" == *'box:     laptop (local@unix — no platform identity)'* ]]" _ "$out"

####################################################################
# 5.6.aws provision — each verdict the identity's TOOLS can render: the
#   verify per cli state, and the upsert's fetch faults. the state reader,
#   root, and the wire are stubbed; no byte is fetched, no install runs
####################################################################
provision_text=""
run_provision() {
  # $1 = cli state the reader answers, $2 = 'plugin' to put the ssm plugin on PATH,
  # $3 = phase (provision_verify | provision_upsert), $4 = the fault ('' = none):
  #   a url suffix → that fetch fails · unzip → the extract fails · install → the
  #   installer fails · shadow → the re-read after install still sees v1 · apt → apt
  #   refuses the plugin package
  # captured as locals: the stubs below are functions, and their own $1..$4 shadow these
  local cli_said="$1" fault="${4:-}"
  local pbin="$fixture/pbin.$1.${2:-bare}.$3.${fault//[^a-z]/}"
  mkdir -p "$pbin" "$fixture/ptmp"
  [[ "$2" == plugin ]] && { printf '#!/usr/bin/env bash\nexit 0\n' > "$pbin/session-manager-plugin"; chmod +x "$pbin/session-manager-plugin"; }
  local reread=whole
  [[ "$fault" == shadow ]] && reread=v1
  (
    export PATH="$pbin:/usr/bin:/bin" GROVE_SRC="$HERE/src"   # the signer key paths read it
    # shellcheck source=/dev/null
    source "$HERE/src/bundle.upgrade.sh"   # bundle.run, bundle.said — as the entrypoint loads them
    # shellcheck source=/dev/null
    source "$HERE/src/grove.provision/5.devtools/5.6.aws/_.sh"
    # shellcheck source=/dev/null
    source "$HERE/src/grove.provision/5.devtools/5.6.aws/${3/_/.}.sh"
    # the first read answers $cli_said; the re-read after the install answers $reread
    grove_provision_5_6_aws_cli_state() {
      if [[ -f "$pbin/.read" ]]; then echo "$reread"; return 0; fi
      : > "$pbin/.read"; echo "$cli_said"
    }
    pkg_assert_apt() { return 0; }
    bundle.root.owns() { return 0; }
    web_tempdir() { printf '%s' "$fixture/ptmp"; }
    # the url that ends in $fault fails; every other fetch lands an empty file
    web_fetch() {
      [[ -n "$fault" && "$1" == *"$fault" ]] && return 1
      [[ "${2:-}" == --into ]] && : > "$3"
      return 0
    }
    web_verify_gpg_signature() { return 0; }
    unzip() { [[ "$fault" == unzip ]] && { echo "unzip: cannot find or open the zip" >&2; return 9; }; return 0; }
    sudo() { [[ "$fault" == install ]] && { echo "install: permission denied" >&2; return 1; }; return 0; }
    pkg_apt() { [[ "$fault" == apt ]] && { echo "E: the package is broken" >&2; return 100; }; return 0; }
    "grove_provision_5_6_aws_$3" 2>&1
    echo "rc=$?"
  )
}
for state in absent adrift v1; do
  out="$(run_provision "$state" plugin provision_verify)"
  provision_text+="## provision.verify · cli ${state} · plugin present"$'\n'"$out"$'\n\n'
  check "5.6.aws provision.verify · cli ${state} → a qualified ✋ with the fix, rc 1" \
    bash -c '[[ "$1" == *"✋ ConstraintError: "* && "$1" == *"fix: rhx grove.provision --what 5.6.aws --mode apply"* && "$1" == *"rc=1" ]]' _ "$out"
done
out="$(run_provision whole '' provision_verify)"
provision_text+="## provision.verify · cli whole · plugin absent"$'\n'"$out"$'\n\n'
check "5.6.aws provision.verify · plugin absent → a qualified ✋, rc 1" \
  bash -c '[[ "$1" == *"✋ ConstraintError: the ssm session-manager plugin is absent"* && "$1" == *"rc=1" ]]' _ "$out"
out="$(run_provision whole plugin provision_verify)"
provision_text+="## provision.verify · cli whole · plugin present"$'\n'"$out"$'\n\n'
check "5.6.aws provision.verify · whole + plugin → ✔, rc 0" bash -c '[[ "$1" == *"rc=0" && "$1" != *"✋"* ]]' _ "$out"
for fault in ".zip" ".zip.sig" "session-manager-plugin.deb" "session-manager-plugin.deb.sig"; do
  state=absent
  [[ "$fault" == session-* ]] && state=whole
  out="$(run_provision "$state" '' provision_upsert "$fault")"
  out="${out//$fixture/<fixture>}"
  provision_text+="## provision.upsert · the fetch of *${fault} fails"$'\n'"$out"$'\n\n'
  check "5.6.aws provision.upsert · *${fault} fetch fails → a qualified 💥, rc 1" \
    bash -c '[[ "$1" == *"💥 MalfunctionError: "* && "$1" == *"rc=1" ]]' _ "$out"
done
# the faults past the fetches: extract, install, a shadow on PATH, and apt's refusal
pv_case() {   # $1 = cli state, $2 = fault, $3 = header, $4 = the halt it must name
  local out
  out="$(run_provision "$1" '' provision_upsert "$2")"
  out="${out//$fixture/<fixture>}"
  provision_text+="## provision.upsert · $3"$'\n'"$out"$'\n\n'
  check "5.6.aws provision.upsert · $3 → a qualified 💥, rc 1" \
    bash -c '[[ "$1" == *"💥 MalfunctionError: $2"* && "$1" == *"rc=1" ]]' _ "$out" "$4"
}
pv_case absent unzip   "the extract fails"                    "could not extract the aws cli installer"
pv_case absent install "the installer fails"                  "the aws cli installer failed"
pv_case absent shadow  "the install lands, a v1 shadows it"   "the installer ran, and the aws on PATH is still 'v1'"
pv_case whole  apt     "apt refuses the plugin package"       "the ssm plugin package would not install"
####################################################################
# the files a reviewer reads — every byte snapped
####################################################################
# shellcheck source=/dev/null
source "$HERE/.play/permanent/play.snap.operations.sh"
snapdir="$HERE/.play/permanent/prove.hetzner-default-profile-survives.snap"
play_snap_verify dir="$snapdir" name=hetzner.config-after-apply actual="$hetzner_config" || failed=1
play_snap_verify dir="$snapdir" name=ec2.config-after-apply actual="$ec2_config" || failed=1
play_snap_verify dir="$snapdir" name=hetzner.serve-not-wired actual="$decline_text" || failed=1
play_snap_verify dir="$snapdir" name=transcript actual="$transcript" || failed=1
play_snap_verify dir="$snapdir" name=provision-verdicts actual="${provision_text%$'\n\n'}" || failed=1
# the words every writer's 💥 composes for a refused swap — one per rc
swap_why_text="$(
  export HOME="$fixture/swapwhy"
  # shellcheck source=/dev/null
  source "$HERE/src/grove.aws.sh"
  for code in 3 4 1; do printf '## rc %s\n%s\n\n' "$code" "$(grove_aws_config_swap_why "$code")"; done
)"
swap_why_text="${swap_why_text//$fixture/<fixture>}"
check "swap why · rc 3 names the other writer and the re-run" bash -c '[[ "$1" == *"re-run to rebuild from the new bytes"* ]]' _ "$swap_why_text"
check "swap why · rc 4 names a defect here, not on the box" bash -c '[[ "$1" == *"a defect here, not on the box"* ]]' _ "$swap_why_text"
check "swap why · io names the file to check" bash -c '[[ "$1" == *"<fixture>/swapwhy/.aws/config is writable"* ]]' _ "$swap_why_text"
play_snap_verify dir="$snapdir" name=swap-why actual="$swap_why_text" || failed=1

[[ "$failed" -ne 0 ]] && exit 1
echo "🌲 all claims held ✔"
exit 0
