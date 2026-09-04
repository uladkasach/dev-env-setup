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
  echo "  --profiles  also list every profile in ~/.aws/config"
  exit 0
fi

ENV=""
SHOW_PROFILES="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    --env) ENV="$2"; shift 2 ;;
    --profiles) SHOW_PROFILES="true"; shift ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# source credentials for a named env from keyrack (skip when the shell already carries them)
PROFILE_USED=""
if [[ -n "$ENV" && -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
  # ⚠️ the rack's stderr is NOT redirected — see git.grove.wake.sh for the
  #    measurement. this site is the sharpest instance of the defect: its
  #    old fix-text read "if it reads 'absent'…" while the line above had
  #    just sent that very word to /dev/null. it told a human to read a
  #    stream it had destroyed one line earlier (`term=swallow`).
  PROFILE_USED=$(rhx keyrack get --owner ehmpath --env "$ENV" --key AWS_PROFILE --value) || PROFILE_USED=""
  if [[ -z "$PROFILE_USED" ]]; then
    echo "✋ the rack did not hand over AWS_PROFILE for env=$ENV" >&2
    echo "" >&2
    echo "  fix: the rack named it above — read that line, not this one." >&2
    echo "       locked 🔒 wants an unlock; absent 🫧 wants a set, and a" >&2
    echo "       set overwrites a live value, so read it before you type." >&2
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
  echo "  fix: point the shell at an env —" >&2
  echo "    rhx aws.whoami --env <test|prep|prod|root|camp>" >&2
  echo "  or, in your own shell —" >&2
  echo "    use.ahbode.<env>" >&2
  exit 1
fi

ACCOUNT=$(echo "$IDENTITY" | jq -r '.Account')
ARN=$(echo "$IDENTITY" | jq -r '.Arn')

echo "🐢 righteous"
echo ""
echo "🔭 aws.whoami${ENV:+ --env $ENV}"
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
