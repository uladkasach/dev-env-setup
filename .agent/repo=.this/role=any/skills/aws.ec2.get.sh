#!/usr/bin/env bash
######################################################################
# aws.ec2.get — report ec2 instances and their live state
#
# .what = look up ec2 instances by tag (or by id) and report each one's
#         state, type, private ip, and launch time as a tree.
#
# .why  = "is the box actually up?" is the first question any tunnel or ssh
#         failure raises, and the local symptoms cannot answer it — a bound
#         port proves a tunnel process lives, never that the box behind it
#         is awake. this reads the authority (the aws api) instead of a
#         guess, and wraps it so no raw `aws ec2` is hand-rolled.
#
# usage:
#   rhx aws.ec2.get --tag exid=grove-1
#   rhx aws.ec2.get --tag exid=grove-1 --env camp
#   rhx aws.ec2.get --id i-0123456789abcdef0
#   rhx aws.ec2.get --tag grove=grove-1 --state all
#   rhx aws.ec2.get help
#
# options:
#   --tag    a key=value tag filter; repeatable (all must match)
#   --id     an instance id; skips the tag lookup
#   --env    aws env whose credentials to source via keyrack; default camp
#   --state  filter by instance state, or `all`; default all
#   --ssm    also report each instance's ssm agent status (ping, version,
#            last seen) — a private box is reachable only through ssm, so
#            ec2 state alone cannot answer whether a tunnel can relay
#
# guarantee:
#   - reports the ACTIVE aws account first, so a result is never read
#     against the wrong account by mistake
#   - read-only; never starts, stops, or mutates an instance
#   - exit 0 = the query ran, 1 = malfunction, 2 = constraint
#   - exit 0 with an empty tree = no instance matched (not an error)
######################################################################
set -uo pipefail

######################################################################
# 🛑 an EC2 TAG is remote-chosen text, and this skill prints it to a terminal
#
# .why  = a tag value is free-form utf-8 that ANY principal with
#         `ec2:CreateTags` may write — and the boxes this skill reports on are
#         GROVES, which are assumed compromised. so `\(.Key)=\(.Value)` is a
#         grove-authored string on its way to a terminal that OBEYS bytes, and
#         `src/tmux.conf` sets `set-clipboard on`: one OSC 52 in a tag writes
#         this human's clipboard, and the next paste is a command they vouch for.
#
#         ⚠️ `.AgentVersion` is the same shape one layer out — it is reported BY
#            THE AGENT ON THE BOX, so a compromised grove chooses it too.
#
# .why the WHOLE render is piped, not the tag field alone
#         a per-field strip is a list, and a list goes stale the day a column is
#         added (`gotcha.a-check-that-cries-wolf`, m.12: a reader that matches a
#         SUBSET reports the subset as the whole). the boundary is "text this
#         skill did not author", and that is every byte of the aws answer.
#
# ⚠️ .whether the grove's own role may write tags is NOT knowable from here
#         the iam policy lives in `ahbode/infrastructure`, so a claim either way
#         would be my own note used as its own evidence
#         (`gotcha.my-own-note-became-my-evidence`). the sink costs one pipe and
#         holds whatever that policy says, today or after the next edit.
#
# ⚠️ the CHECKOUT's copy, never `~/.bash_aliases.ductwork.sh` — a skill in this
#    tree is judged against this tree, and an installed copy may be older
######################################################################
if ! command -v __duct_strip_escapes >/dev/null 2>&1; then
  _aws_ec2_ductwork="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)/src/ductwork.sh"
  if [[ -r "$_aws_ec2_ductwork" ]]; then
    # shellcheck disable=SC1090
    source "$_aws_ec2_ductwork"
  else
    echo "✋ ductwork is absent from this checkout, so aws-chosen bytes cannot be stripped" >&2
    echo "   looked at: $_aws_ec2_ductwork" >&2
    echo "   ⇒ it owns __duct_strip_escapes, the one sink between a tag value" >&2
    echo "     and a terminal that OBEYS what it is sent" >&2
    exit 1
  fi
fi

# ⚠️ read the whole ARG VECTOR, never `$1` — rhachet injects `--skill <slug>` ahead
#    of the caller's args, so a `$1` test never fires (measured 2026-08-30; ten
#    skills in this dir carried it, and each read `help` as its SUBJECT instead)
if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "aws.ec2.get"
  echo ""
  echo "usage:"
  echo "  rhx aws.ec2.get --tag <key=value> [--tag ...] [--env <env>] [--state <state|all>]"
  echo "  rhx aws.ec2.get --id <instance-id> [--env <env>]"
  echo ""
  echo "options:"
  echo "  --tag    key=value tag filter; repeatable (all must match)"
  echo "  --id     instance id; skips the tag lookup"
  echo "  --env    aws env for credentials via keyrack; default camp"
  echo "  --state  instance state filter, or 'all'; default all"
  exit 0
fi

ENV="camp"
STATE="all"
ID=""
SSM="false"
TAGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)   TAGS+=("$2"); shift 2 ;;
    --id)    ID="$2"; shift 2 ;;
    --env)   ENV="$2"; shift 2 ;;
    --state) STATE="$2"; shift 2 ;;
    --ssm)   SSM="true"; shift ;;
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$ID" && ${#TAGS[@]} -eq 0 ]]; then
  echo "✋ absent required arg: --tag <key=value> or --id <instance-id>" >&2
  exit 2
fi
for TAG in "${TAGS[@]}"; do
  if [[ "$TAG" != *"="* ]]; then
    echo "✋ invalid --tag: $TAG (must be key=value)" >&2
    exit 2
  fi
done

# source credentials for the env from keyrack (skip when the shell already carries them)
if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
  # ⚠️ the rack's stderr is NOT redirected — see git.grove.wake.sh for the
  #    measurement. locked 🔒 and absent 🫧 share exit code 2 and differ only
  #    in that stream, and they want opposite repairs.
  AWS_PROFILE=$(rhx keyrack get --owner ehmpath --env "$ENV" --key AWS_PROFILE --value) || AWS_PROFILE=""
  if [[ -z "$AWS_PROFILE" ]]; then
    echo "✋ the rack did not hand over AWS_PROFILE for env=$ENV" >&2
    echo "" >&2
    echo "  fix: the rack named it above — read that line, not this one." >&2
    echo "       locked 🔒 wants an unlock; absent 🫧 wants a set, and a" >&2
    echo "       set overwrites a live value, so read it before you type." >&2
    exit 1
  fi
  if ! eval "$(aws configure export-credentials --profile "$AWS_PROFILE" --format env 2>/dev/null)"; then
    echo "🐢 bummer dude — no credentials from profile $AWS_PROFILE" >&2
    echo "" >&2
    echo "  fix: log the sso session back in —" >&2
    echo "    aws sso login --profile $AWS_PROFILE" >&2
    exit 1
  fi
  unset AWS_PROFILE AWS_DEFAULT_PROFILE
fi

ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
if [[ -z "$ACCOUNT" ]]; then
  echo "🐢 bummer dude — cannot read the active aws account" >&2
  echo "" >&2
  echo "  fix: unlock the env's credentials —" >&2
  echo "    rhx keyrack unlock --owner ehmpath --env $ENV" >&2
  exit 1
fi

# build the query args
QUERY_ARGS=()
if [[ -n "$ID" ]]; then
  QUERY_ARGS+=(--instance-ids "$ID")
else
  FILTERS=()
  for TAG in "${TAGS[@]}"; do
    FILTERS+=("Name=tag:${TAG%%=*},Values=${TAG#*=}")
  done
  if [[ "$STATE" != "all" ]]; then
    FILTERS+=("Name=instance-state-name,Values=$STATE")
  fi
  QUERY_ARGS+=(--filters "${FILTERS[@]}")
fi

RESULT=$(aws ec2 describe-instances "${QUERY_ARGS[@]}" --output json 2>/dev/null || echo "")
if [[ -z "$RESULT" ]]; then
  echo "🐢 bummer dude — the ec2 describe call failed" >&2
  echo "" >&2
  echo "  why: the credentials may lack ec2:DescribeInstances, or the region is wrong" >&2
  echo "  fix: confirm the account and region —" >&2
  echo "    rhx aws.whoami --env $ENV" >&2
  exit 1
fi

echo "🐢 righteous"
echo ""
echo "🔭 aws.ec2.get${ID:+ --id $ID}$(for T in "${TAGS[@]}"; do printf ' --tag %s' "$T"; done)"
echo "   ├─ account: $ACCOUNT"
echo "   ├─ state:   $STATE"

COUNT=$(echo "$RESULT" | jq '[.Reservations[].Instances[]] | length')
if [[ "$COUNT" == "0" ]]; then
  echo "   └─ 🫧 no instance matched"
  exit 0
fi

echo "   └─ found: $COUNT"
# 🛑 `| __duct_strip_escapes` — the tag half of this render is remote-chosen
#    text, and its reason lives in full at the top of this file
echo "$RESULT" | jq -r '
  [.Reservations[].Instances[]] | .[] |
  "      ├─ \(.InstanceId)\n" +
  "      │  ├─ state:   \(.State.Name)\n" +
  "      │  ├─ type:    \(.InstanceType)\n" +
  "      │  ├─ private: \(.PrivateIpAddress // "none")\n" +
  "      │  ├─ since:   \(.LaunchTime)\n" +
  "      │  └─ tags:    \([.Tags[]? | "\(.Key)=\(.Value)"] | join(", "))"
' | __duct_strip_escapes

# a private grove is reached ONLY through ssm, so ec2 state alone cannot answer
# "can i reach it" — an instance can read as up while its ssm agent is absent,
# which is exactly the case a bound-but-mute tunnel presents. report both.
if [[ "$SSM" == "true" ]]; then
  echo "   └─ ssm"
  for IID in $(echo "$RESULT" | jq -r '[.Reservations[].Instances[]] | .[].InstanceId'); do
    SSM_INFO=$(aws ssm describe-instance-information \
      --filters "Key=InstanceIds,Values=$IID" --output json 2>/dev/null || echo "")
    SSM_COUNT=$(echo "$SSM_INFO" | jq '.InstanceInformationList | length' 2>/dev/null || echo "0")
    if [[ "$SSM_COUNT" == "0" ]]; then
      echo "      ├─ $IID"
      echo "      │  └─ 🫧 absent from ssm — no agent registered, so no tunnel can relay"
    else
      # 🛑 `.AgentVersion` is reported BY THE AGENT ON THE BOX, so a compromised
      #    grove chooses it — same sink, same reason as the tag render above
      echo "$SSM_INFO" | jq -r --arg iid "$IID" '
        .InstanceInformationList[] |
        "      ├─ \($iid)\n" +
        "      │  ├─ ping:    \(.PingStatus)\n" +
        "      │  ├─ agent:   \(.AgentVersion)\n" +
        "      │  └─ lastSeen: \(.LastPingDateTime)"
      ' | __duct_strip_escapes
    fi
  done
fi
