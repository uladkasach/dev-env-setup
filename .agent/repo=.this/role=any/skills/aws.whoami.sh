#!/usr/bin/env bash
######################################################################
# aws.whoami — report the aws identity this shell can reach
#
# .what = read the active aws session (account, arn, profile source) and
#         report it as a tree; optionally source a named env's credentials
#         from keyrack first, the same way the infra skills do.
#
# .why  = every aws question starts with "which account am i in?" — and a
#         raw `aws sts get-caller-identity` is a bare command with no
#         hint when it fails. this wraps that one read behind a skill so
#         no aws command is ever hand-rolled at the prompt, and a failure
#         names the fix (unlock the keyrack, or run use.ahbode.<env>).
#
# usage:
#   rhx aws.whoami                    # report the ambient session
#   rhx aws.whoami --env camp         # source camp creds from keyrack, then report
#   rhx aws.whoami --profiles         # also list the configured profiles
#   rhx aws.whoami help
#
# options:
#   --env       env to source credentials for via keyrack (test|prep|prod|root|camp)
#   --profiles  also list every profile in ~/.aws/config
#
# guarantee:
#   - exit 0 = an identity was read
#   - exit 1 = malfunction (no credentials, expired sso token)
#   - exit 2 = constraint (bad arg)
######################################################################
set -euo pipefail

# ⚠️ read the whole ARG VECTOR, never `$1` — rhachet injects `--skill <slug>` ahead
#    of the caller's args, so a `$1` test never fires. measured 2026-08-30: this
#    very line let `rhx aws.whoami help` answer `unknown argument: help`
if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "aws.whoami"
  echo ""
  echo "usage:"
  echo "  rhx aws.whoami [--env <env>] [--profiles]"
  echo ""
  echo "options:"
  echo "  --env       env to source credentials for via keyrack (test|prep|prod|root|camp)"
  echo "  --org       keyrack org whose credential to read; default the manifest's org: line."
  echo "              ⚠️ a box in ANOTHER org needs this, or the read lands in the"
  echo "              account this checkout names"
  echo "  --profiles  list every profile NAME in ~/.aws/config (works with no session)"
  echo ""
  echo "⚠️ there is deliberately no --profile flag. a camp AWS_PROFILE is a credential"
  echo "   keyrack DECLARES, so a raw --profile read is a blocker under"
  echo "   rule.require.reach-credentials-through-keyrack. reach it with --env."
  exit 0
fi

# 🛑 the rack read for a FOREIGN org needs a scratch gitroot, and that holder is
#    where it lives (`term=keyrack.gitroot`)
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/git.grove.rack.operations.sh"

ENV=""
ORG=""
SHOW_PROFILES="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    --env) ENV="$2"; shift 2 ;;
    --org) ORG="$2"; shift 2 ;;
    --profiles) SHOW_PROFILES="true"; shift ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# source credentials for a named env from keyrack (skip when the shell already carries them)
PROFILE_USED=""

# 🛑 do NOT add a `--profile <name>` axis here. it was built 2026-09-23 to reach a
#    camp profile in an org the manifest cannot name, and it is a BLOCKER under
#    `rule.require.reach-credentials-through-keyrack`: a raw aws call used to
#    obtain a credential keyrack DECLARES (`.agent/keyrack.yml` → env.camp:
#    AWS_PROFILE). it also reads ~/.aws/sso/cache — a store keyrack does not
#    fill — so its answer does not decide the claim it appears to settle.
#
#    the wall it tried to climb is real: `@this` resolves to the manifest's ONE
#    `org:` line, so a slug in any other org reads `absent 🫧`. the cure belongs
#    in the manifest's org axis, never in a door beside the rack.
#
# ✔ .and that cure LANDED 2026-09-28 — `--org`, read through `_rack_profile`
#    it is the axis this block prescribed, never the door it refused: `--org`
#    names a KEYRACK coordinate, so the read still goes through the rack and
#    `rule.require.reach-credentials-through-keyrack` holds in full. what the
#    rejected `--profile` did was reach past the rack into `~/.aws/sso/cache`
#
#    ⚠️ a foreign org is read from a scratch gitroot with a one-org manifest,
#      because keyrack scopes a named-org read to the CHECKOUT — so the axis
#      alone was not enough, and the holder is what makes it reach
if [[ -n "$ENV" && -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
  # ⚠️ the rack's stderr is NOT redirected — see git.grove.wake.sh for the
  #    measurement. this site is the sharpest instance of the defect: its
  #    old fix-text read "if it reads 'absent'…" while the line above had
  #    just sent that very word to /dev/null. it told a human to read a
  #    stream it had destroyed one line earlier (`term=swallow`).
  PROFILE_USED="$(_rack_profile "$ENV" "$ORG")" || PROFILE_USED=""
  if [[ -z "$PROFILE_USED" ]]; then
    echo "✋ the rack did not hand over AWS_PROFILE for env=$ENV${ORG:+ org=$ORG}" >&2
    echo "" >&2
    _rack_profile_fix "$ENV" "$ORG"
    exit 1
  fi
  if ! eval "$(aws configure export-credentials --profile "$PROFILE_USED" --format env 2>/dev/null)"; then
    echo "🐢 bummer dude — no credentials from profile $PROFILE_USED" >&2
    echo "" >&2
    echo "  fix: log the sso session back in —" >&2
    echo "    aws sso login --profile $PROFILE_USED" >&2
    exit 1
  fi
  unset AWS_PROFILE AWS_DEFAULT_PROFILE
fi

IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null || echo "")
if [[ -z "$IDENTITY" ]]; then
  echo "🐢 bummer dude — cannot read the active aws identity" >&2
  echo "" >&2
  echo "  why: no credentials in this shell, or the sso token expired" >&2
  # ⚠️ the profile roster is printed HERE, on the failure path, on purpose.
  #    measured 2026-09-23: --profiles sat BELOW this exit, so the one read
  #    that needs no credentials at all (`aws configure list-profiles` parses
  #    ~/.aws/config) was reachable only once credentials already worked.
  #    a human with no session — the exact human who needs to know which
  #    profiles exist — got `exit 1` and no roster.
  if [[ "$SHOW_PROFILES" == "true" ]]; then
    echo "  profile NAMES in ~/.aws/config — ⚠️ NOT a keyrack fact. a name here" >&2
    echo "  says only that the file lists it; the rack may declare none of them:" >&2
    aws configure list-profiles 2>/dev/null | while read -r P; do
      echo "    ├─ $P" >&2
    done
    echo "  what the RACK holds: rhx keyrack list --owner ehmpath" >&2
  else
    echo "  names this box has configured: rhx aws.whoami --profiles" >&2
  fi
  echo "  fix: point the shell at an env —" >&2
  echo "    rhx aws.whoami --env <test|prep|prod|root|camp>" >&2
  echo "  or, in your own shell —" >&2
  echo "    use.<org>.<env>" >&2
  exit 1
fi

ACCOUNT=$(echo "$IDENTITY" | jq -r '.Account')
ARN=$(echo "$IDENTITY" | jq -r '.Arn')

echo "🐢 righteous"
echo ""
# ⚠️ the header echoes `--org` too, and this is the ONE skill where that costs
#    most to omit: the axis SELECTS THE ACCOUNT, and the account is the whole
#    answer. a header that reads `--env camp` beside a foreign account invites
#    the reader to think camp resolved it
#    (`howto.write.skills-stdout` — a header shows the resolved inputs)
echo "🔭 aws.whoami${ENV:+ --env $ENV}${ORG:+ --org $ORG}"
echo "   ├─ account: $ACCOUNT"
echo "   ├─ arn:     $ARN"
if [[ -n "$PROFILE_USED" ]]; then
  echo "   ├─ profile: $PROFILE_USED (via keyrack env=$ENV)"
else
  echo "   ├─ profile: ${AWS_PROFILE:-<ambient session>}"
fi

if [[ "$SHOW_PROFILES" == "true" ]]; then
  echo "   └─ profiles"
  aws configure list-profiles | while read -r P; do
    echo "      ├─ $P"
  done
else
  echo "   └─ tip: --profiles to list every configured profile"
fi
