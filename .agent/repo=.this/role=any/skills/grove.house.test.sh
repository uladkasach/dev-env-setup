#!/usr/bin/env bash
######################################################################
# .what = the hermetic clamps for a house grove's box-free half: each forbidden
#         row whose subject is a pure reader, asked over fixtures
#
# .why  a house seat's badge, its renewal, its tier, and its aws.params gate are
#       each judged by a pure function — a path or a tag in, one word out. so
#       each can be clamped with no grove, no root, no aws account, and no human:
#       on a laptop, and on every ci push. the facts that need a real seat
#       (cross-uid reads, the loopback sshd) are `prove.house-grove-box-half`'s
#
# .the rows it clamps (vision `1.vision.experience.case=_.md`)
#   24  a widened key or dir is refused
#   27  a `serve` endpoint (an imds override, or Ec2InstanceMetadata) is refused
#   28  a static key or an sso token, alone or beside the badge, is refused
#   29  `house@*` fails the aws.params gate closed
#   37  a cert under a day left is refused; the renewal owes a run, and names the
#       CA it lacks rather than guess one
#   11  a user-owned election never makes a seat a house seat (the probe's trust half)
#
# 🛑 hermetic by construction
#   - every fixture sits in one `mktemp -d`, removed on exit
#   - the readers are passed fixture PATHS, never `$HOME`
#   - the renewal runs as a child with `HOME` set to the fixture, and the run
#     halts if any fixture path escapes the temp dir
#   - no network: the renewal arms here all stop before an aws call
#
# usage:
#   rhx grove.house.test
#
# exit:
#   0 = every case passed · 1 = a case failed, named · 2 = a tool this needs is absent
######################################################################

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
AWS_DIR="$ROOT/src/grove.provision/5.devtools/5.6.aws"

for tool in openssl awk stat mktemp; do
  command -v "$tool" >/dev/null 2>&1 || { echo "✋ ConstraintError: this suite needs $tool" >&2; exit 2; }
done
[[ -f "$AWS_DIR/_.sh" ]] || { echo "✋ ConstraintError: no 5.6.aws bundle under ${ROOT:-<no checkout>}" >&2; exit 2; }

# shellcheck source=/dev/null
source "$AWS_DIR/_.sh"
# shellcheck source=/dev/null
source "$AWS_DIR/configure.verify.sh"
# shellcheck source=/dev/null
source "$ROOT/src/grove.provision/5.devtools/5.12.rack/_.sh"
# shellcheck source=/dev/null
source "$ROOT/src/grove.env.sh"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

pass=0
fail=0
# .what = record one case: its name, and whether it held
check() {
  local name="$1" ok="$2"
  if [[ "$ok" == yes ]]; then
    pass=$(( pass + 1 )); echo "   ✔ $name"
  else
    fail=$(( fail + 1 )); echo "   ✋ $name" >&2
  fi
}
# .what = yes when two words match, so a case reads as one line
is() { [[ "$1" == "$2" ]] && echo yes || echo no; }

echo "🏠 grove.house.test"

######################################################################
# fixtures — a badge dir at 0700, an ec key, and certs of chosen lifetimes
######################################################################
mkcert() {   # mkcert <dir> <days>
  mkdir -p "$1" && chmod 700 "$1"
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -subj '/CN=house-test' -days "$2" \
    -keyout "$1/badge.key" -out "$1/badge.crt" 2>/dev/null || return 1
  chmod 600 "$1/badge.key" "$1/badge.crt"
}
mkcert "$T/week/.aws/house" 7 || { echo "✋ openssl could not mint a fixture cert" >&2; exit 2; }
mkcert "$T/day/.aws/house"  1 || exit 2

cfg_good="$T/config.good"
printf '%s\n' \
  '# grove: the house badge' \
  '[profile ambient]' \
  'credential_process = /usr/local/bin/aws_signing_helper credential-process --certificate ~/.aws/house/badge.crt --private-key ~/.aws/house/badge.key --trust-anchor-arn <ta> --profile-arn <p> --role-arn <r>' \
  'region = us-east-1' \
  '' \
  '[default]' \
  'credential_process = aws_signing_helper credential-process --certificate ~/.aws/house/badge.crt' \
  'region = us-east-1' \
  > "$cfg_good"

# .what = a config with ONE ambient body, for one shape case
cfg_one() {   # cfg_one <name> <line>...
  local f="$T/config.$1"; shift
  { printf '[profile ambient]\n'; printf '%s\n' "$@"; } > "$f"
  printf '%s' "$f"
}

######################################################################
# the shape reader — rows 27, 28
######################################################################
echo "   ├─ badge shape"
check "credential_process via the helper reads as process"            "$(is "$(grove_provision_5_6_aws_badge_shape "$cfg_good" 'profile ambient')" process)"
check "[default] reads as process too"                                "$(is "$(grove_provision_5_6_aws_badge_shape "$cfg_good" default)" process)"
check "row 27: an imds endpoint override reads as serve"              "$(is "$(grove_provision_5_6_aws_badge_shape "$(cfg_one serve 'ec2_metadata_service_endpoint = http://127.0.0.1:9911/')" 'profile ambient')" serve)"
check "row 27: Ec2InstanceMetadata reads as instance_role"            "$(is "$(grove_provision_5_6_aws_badge_shape "$(cfg_one imds 'credential_source = Ec2InstanceMetadata')" 'profile ambient')" instance_role)"
check "row 27: a credential_process that runs serve is foreign"      "$(is "$(grove_provision_5_6_aws_badge_shape "$(cfg_one srvproc 'credential_process = aws_signing_helper serve --port 9911')" 'profile ambient')" process_foreign)"
check "row 28: a static key reads as static_key"                      "$(is "$(grove_provision_5_6_aws_badge_shape "$(cfg_one key 'aws_access_key_id = AKIAFIXTUREFIXTURE00')" 'profile ambient')" static_key)"
check "row 28: an sso session reads as sso"                           "$(is "$(grove_provision_5_6_aws_badge_shape "$(cfg_one sso 'sso_session = fixture')" 'profile ambient')" sso)"
check "row 28: the badge with a static key beside it reads as mixed"  "$(is "$(grove_provision_5_6_aws_badge_shape "$(cfg_one mix 'credential_process = aws_signing_helper credential-process' 'aws_access_key_id = AKIAFIXTUREFIXTURE00')" 'profile ambient')" mixed)"
check "a commented-out source is not a source"                        "$(is "$(grove_provision_5_6_aws_badge_shape "$(cfg_one cmt '# aws_access_key_id = AKIAFIXTUREFIXTURE00' 'credential_process = aws_signing_helper credential-process')" 'profile ambient')" process)"
check "an absent profile reads as absent"                             "$(is "$(grove_provision_5_6_aws_badge_shape "$cfg_good" 'profile other')" absent)"
check "an absent file reads as absent"                                "$(is "$(grove_provision_5_6_aws_badge_shape "$T/no.such.config" 'profile ambient')" absent)"

######################################################################
# the file modes — row 24
######################################################################
echo "   ├─ badge files"
check "a 0600 key in a 0700 dir reads as tight"                       "$(is "$(grove_provision_5_6_aws_badge_file_state "$T/week/.aws/house/badge.key")" tight)"
cp -a "$T/week" "$T/widekey"; chmod 644 "$T/widekey/.aws/house/badge.key"
check "row 24: a 0644 key reads as wide"                              "$(is "$(grove_provision_5_6_aws_badge_file_state "$T/widekey/.aws/house/badge.key")" wide)"
cp -a "$T/week" "$T/widedir"; chmod 755 "$T/widedir/.aws/house"
check "row 24: a 0600 key in a 0755 dir reads as wide"                "$(is "$(grove_provision_5_6_aws_badge_file_state "$T/widedir/.aws/house/badge.key")" wide)"
check "an absent key reads as absent"                                 "$(is "$(grove_provision_5_6_aws_badge_file_state "$T/week/.aws/house/no.key")" absent)"

######################################################################
# the hours left — row 37
######################################################################
echo "   ├─ cert hours"
h="$(grove_provision_5_6_aws_cert_hours_left "$T/week/.aws/house/badge.crt")"
check "a 7-day cert reads 166–168 hours left (got $h)"               "$( [[ "$h" =~ ^[0-9]+$ ]] && (( h >= 166 && h <= 168 )) && echo yes || echo no)"
h="$(grove_provision_5_6_aws_cert_hours_left "$T/week/.aws/house/badge.crt" "$(( $(date -u +%s) + 8 * 86400 ))")"
check "the same cert, read 8 days on, is past its end (got $h)"      "$( [[ "$h" =~ ^-[0-9]+$ ]] && echo yes || echo no)"
check "a file that is no cert reads as ?"                             "$(is "$(grove_provision_5_6_aws_cert_hours_left "$cfg_good")" '?')"

######################################################################
# the whole judge, as the verify asks it
######################################################################
echo "   ├─ badge verdicts"
v() { grove_provision_5_6_aws_house_badge_verdicts "$@" >/dev/null 2>&1 && echo pass || echo refuse; }
d="$T/week/.aws/house"
check "a 7-day cert, tight files, the helper profile: pass"          "$(is "$(v "$cfg_good" "$d/badge.crt" "$d/badge.key")" pass)"
check "row 24: a widened key: refuse"                                 "$(is "$(v "$cfg_good" "$T/widekey/.aws/house/badge.crt" "$T/widekey/.aws/house/badge.key")" refuse)"
check "row 27: a serve profile: refuse"                               "$(is "$(v "$(cfg_one serve2 'ec2_metadata_service_endpoint = http://127.0.0.1:9911/')" "$d/badge.crt" "$d/badge.key")" refuse)"
check "row 28: a static key beside the badge: refuse"                 "$(is "$(v "$T/config.mix" "$d/badge.crt" "$d/badge.key")" refuse)"
check "row 37: a cert under a day left: refuse"                       "$(is "$(v "$cfg_good" "$T/day/.aws/house/badge.crt" "$T/day/.aws/house/badge.key")" refuse)"
check "row 37: a cert read past its end: refuse"                      "$(is "$(v "$cfg_good" "$d/badge.crt" "$d/badge.key" "$(( $(date -u +%s) + 8 * 86400 ))")" refuse)"
check "row 30: no cert at all: refuse, never pass"                    "$(is "$(v "$cfg_good" "$T/none/badge.crt" "$T/none/badge.key")" refuse)"

######################################################################
# the renewal — it never writes above the threshold, and never guesses a CA
######################################################################
echo "   ├─ renewal"
renew() { HOME="$1" bash "$AWS_DIR/house.badge.renew.sh" >"$T/renew.out" 2>&1; echo $?; }
before="$(stat -c '%Y %s' "$T/week/.aws/house/badge.crt")"
check "a 7-day cert: no change, exit 0"                               "$(is "$(renew "$T/week")" 0)"
check "  … and the cert is untouched"                                 "$(is "$(stat -c '%Y %s' "$T/week/.aws/house/badge.crt")" "$before")"
rc="$(renew "$T/day")"
check "a cert under a day, no CA named: exit 2"                       "$(is "$rc" 2)"
check "  … and the refusal names infra#36, the CA's owner"            "$(grep 'infrastructure#36' "$T/renew.out" >/dev/null && echo yes || echo no)"
check "  … and no work dir is left behind"                            "$(compgen -G "$T/day/.aws/house/.renew.*" >/dev/null && echo no || echo yes)"
mkdir -p "$T/empty"
check "no cert at all: exit 2"                                        "$(is "$(renew "$T/empty")" 2)"

######################################################################
# the unit — rendered from this checkout, no placeholder left
######################################################################
echo "   ├─ renewal unit"
svc="$(GROVE_SRC="$ROOT/src" grove_provision_5_6_aws_house_service_text)"
check "the service names this checkout's renewal"                     "$(printf '%s' "$svc" | grep -F "$ROOT/src/grove.provision/5.devtools/5.6.aws/house.badge.renew.sh" >/dev/null && echo yes || echo no)"
check "  … and no @RENEW_EXEC@ placeholder remains"                   "$(printf '%s' "$svc" | grep '@RENEW_EXEC@' >/dev/null && echo no || echo yes)"
check "the timer is a calendar spec, so Persistent= binds it"         "$(grep '^OnCalendar=' "$AWS_DIR/house.badge.renew.timer" >/dev/null && echo yes || echo no)"

######################################################################
# the aws.params gate — row 29
######################################################################
echo "   ├─ aws.params gate"
gate() { GROVE_ENV_SERVER="$1" grove_provision_5_12_rack_platform_is_ec2 && echo open || echo closed; }
check "row 29: house@unix: closed"                                    "$(is "$(gate house@unix)" closed)"
check "local@unix: closed"                                            "$(is "$(gate local@unix)" closed)"
check "cloud@aws.ec2: open"                                           "$(is "$(gate cloud@aws.ec2)" open)"

######################################################################
# the probe's trust half — a seat may never elect itself
######################################################################
echo "   └─ house election trust"
mkdir -p "$T/house.d"; chmod 755 "$T/house.d"
printf 'camper %s\nground %s\n' "$(id -un)" "$(id -un)" > "$T/house.d/house-test"; chmod 644 "$T/house.d/house-test"
probe() { GROVE_HOUSE_ELECTION_DIR="$1" grove_env_probe_house && echo house || echo not; }
if [[ "$(id -u)" -eq 0 ]]; then
  check "(as root, a self-owned fixture IS root-owned — this arm needs a non-root run)" yes
else
  check "row 11: an election this uid owns, which names it: not a house seat" "$(is "$(probe "$T/house.d")" not)"
fi
check "a root-owned dir with no election that names this uid: not"   "$(is "$(probe /etc)" not)"
check "an absent dir: not"                                            "$(is "$(probe "$T/no.such.dir")" not)"

######################################################################
# the escape check — every fixture stayed inside the temp dir
######################################################################
[[ -e "$T/week/.aws/house/badge.crt" && "$T" == "${TMPDIR:-/tmp}"/* ]] || { echo "✋ a fixture path left the temp dir" >&2; fail=$(( fail + 1 )); }

echo ""
echo "   $pass passed, $fail failed"
[[ "$fail" -eq 0 ]] || exit 1
echo "🌲 every house box-free clamp holds ✔"