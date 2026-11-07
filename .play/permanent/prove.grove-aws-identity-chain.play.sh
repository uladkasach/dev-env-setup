#!/usr/bin/env bash
######################################################################
# .what = ask a grove the questions an AWS CONSUMER asks, in the order it asks
#         them, on any grove kind: a cloud grove's camper or a house grove's
#
# .why  = a box's identity chain has three links, and each breaks alone:
#
#           1. the bare call    — a program that names no profile must still find
#                                 a region and the box's OWN badge (`[default]`)
#           2. the badge        — `[profile ambient]` must be the badge this KIND
#                                 of grove carries, and no fallback beside it
#           3. the reach        — the rack names a profile per env, and sts through
#                                 it lands in the account the tree declares
#
#         📜 the name was cited by two briefs since 2026-08-08 while no play of
#         that name was ever committed (F9). this is that play, written from the
#         questions those briefs say it asked.
#
# .the claims
#   0. `~/.zshenv` exports no `AWS_PROFILE` — an export there shadows the rack
#      for every env at once (`howdoes.a-box-reach-an-aws-account`)
#   1. with no profile named, a region resolves
#   2. with no profile named, sts answers — and with the SAME arn as `ambient`,
#      so the bare call carries the box's own badge and no other
#   3. `ambient` is this grove kind's badge:
#        house@* → `credential_process`, and NO `credential_source`, static key,
#                  or sso beside it (vision case=4: never a fallback)
#        cloud@* → `credential_source = Ec2InstanceMetadata`
#   4. the reach: `5.13.reach`'s own verify, run in plan mode. that verify holds
#      the rack→profile→account check, and this play does not re-parse it
#      (one fact, one holder)
#
# 🛑 .it never echoes a credential
#   - no call here prints a key, a secret, or a session token. sts is asked for
#     `Arn` alone, and the arn is shown with its account replaced by `<acct>`
#   - `aws configure get` is asked only for NON-secret fields, and a static key
#     field is tested for presence, never printed
#
# guarantee:
#   - READ-ONLY. two sts calls and a plan; no write, in AWS or on the box
#   - exit 0 = every link holds · 1 = a link is broken, named · 2 = this box
#     cannot be asked (no aws cli, no checkout, no derivable server)
######################################################################

set -u

_self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || _self=""
if   [[ -n "$_self" && -f "$_self/src/grove.env.sh" ]];            then _root="$_self"
elif [[ -f "$PWD/src/grove.env.sh" ]];                             then _root="$PWD"
elif [[ -f "$HOME/git/more/dev-env-setup.wip/src/grove.env.sh" ]]; then _root="$HOME/git/more/dev-env-setup.wip"
else                                                                   _root="$HOME/git/more/dev-env-setup"
fi

echo "🌲 prove.grove-aws-identity-chain"

# shellcheck source=/dev/null
source "$_root/src/grove.env.sh" 2>/dev/null
if ! declare -F grove_env_derive >/dev/null || ! grove_env_derive >/dev/null 2>&1; then
  echo "   ✋ ConstraintError: the server cannot be derived from $_root" >&2
  echo "      fix: rhx git.grove.push <grove> --from . --into git/more/dev-env-setup.wip --mode apply" >&2
  exit 2
fi
if ! command -v aws >/dev/null 2>&1; then
  echo "   ✋ ConstraintError: no aws cli on this box — no link can be asked" >&2
  echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
  exit 2
fi
echo "   • server: $GROVE_ENV_SERVER · checkout: $_root"

failed=0

# .what = an arn reduced to its SHAPE: account, role, and session replaced
# .why  = a pasted log lands in briefs, and this repo is public. the role name
#         and the session (an instance id on ec2) are dox as much as the account
#         (`rule.forbid.dox-in-public-repo`); the shape — `assumed-role` — is the
#         part a reader needs. 📜 first run printed both, 2026-11-06
grove_aws_chain_redact() {
  sed -E -e 's/[0-9]{12}/<acct>/g' \
         -e 's#(assumed-role)/[^/[:space:]]+/[^[:space:]]+#\1/<role>/<session>#g' \
         -e 's#:(role|user)/[^[:space:]]+#:\1/<name>#g' \
         -e 's/i-[0-9a-f]{8,}/<instance-id>/g'
}

# claim 0 — no shell-wide AWS_PROFILE
if [[ -f "$HOME/.zshenv" ]] && grep -qE '^[[:space:]]*export[[:space:]]+AWS_PROFILE=' "$HOME/.zshenv"; then
  echo "   ✋ claim 0: ~/.zshenv exports AWS_PROFILE" >&2
  echo "      ⇒ os.envvar wins, so one export shadows the rack for every env" >&2
  echo "      fix: rhx grove.provision --what 2.5.zsh --mode apply" >&2
  failed=1
else
  echo "   • claim 0: ~/.zshenv exports no AWS_PROFILE ✔"
fi

# claims 1 and 2 run with no profile in the env, as a consumer that names none
region="$(env -u AWS_PROFILE -u AWS_DEFAULT_PROFILE aws configure get region 2>/dev/null)"
if [[ -n "$region" ]]; then
  echo "   • claim 1: no profile named → region $region ✔"
else
  echo "   ✋ claim 1: no profile named → no region" >&2
  echo "      ⇒ the [default] block is absent, so a bare call has no region" >&2
  echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
  failed=1
fi

# ⚠️ a refusal is KEPT, never blanked: its sentence is what names the cause
bare="$(env -u AWS_PROFILE -u AWS_DEFAULT_PROFILE aws sts get-caller-identity --query Arn --output text 2>&1)" || true
ambi="$(env -u AWS_PROFILE -u AWS_DEFAULT_PROFILE aws sts get-caller-identity --profile ambient --query Arn --output text 2>&1)" || true
if [[ "$bare" == arn:* && "$bare" == "$ambi" ]]; then
  echo "   • claim 2: no profile named → $(printf '%s' "$bare" | grove_aws_chain_redact), the ambient badge ✔"
elif [[ "$bare" != arn:* ]]; then
  echo "   ✋ claim 2: no profile named → sts did not answer" >&2
  echo "      ⇒ $(printf '%s' "$bare" | grep -m1 . | grove_aws_chain_redact)" >&2
  echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
  failed=1
else
  echo "   ✋ claim 2: the bare call answers as a DIFFERENT identity than ambient" >&2
  echo "      ⇒ bare:    $(printf '%s' "$bare" | grove_aws_chain_redact)" >&2
  echo "      ⇒ ambient: $(printf '%s' "$ambi" | grep -m1 . | grove_aws_chain_redact)" >&2
  echo "      ⇒ [default] and [profile ambient] must be the one badge" >&2
  failed=1
fi

# claim 3 — the badge this grove kind carries, and no other source beside it
cproc="$(aws configure get credential_process --profile ambient 2>/dev/null)"
csrc="$(aws configure get credential_source --profile ambient 2>/dev/null)"
akey="$(aws configure get aws_access_key_id --profile ambient 2>/dev/null)"
sso="$(aws configure get sso_start_url --profile ambient 2>/dev/null)$(aws configure get sso_session --profile ambient 2>/dev/null)"
case "$GROVE_ENV_SERVER" in
  house@*)
    if [[ -n "$cproc" && -z "$csrc" && -z "$akey" && -z "$sso" ]]; then
      echo "   • claim 3: ambient is credential_process, and no other source ✔"
    else
      echo "   ✋ claim 3: a house seat's ambient is not credential_process alone" >&2
      echo "      ⇒ credential_process: ${cproc:+set}${cproc:-absent} · credential_source: ${csrc:-absent}" >&2
      echo "        · static key: ${akey:+PRESENT}${akey:-absent} · sso: ${sso:+PRESENT}${sso:-absent}" >&2
      echo "      ⇒ a house grove has no IMDS, and any fallback is a second identity" >&2
      echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
      failed=1
    fi
    ;;
  cloud@*)
    if [[ "$csrc" == "Ec2InstanceMetadata" && -z "$akey" ]]; then
      echo "   • claim 3: ambient is the instance role, and no static key ✔"
    else
      echo "   ✋ claim 3: a cloud grove's ambient is not the instance role alone" >&2
      echo "      ⇒ credential_source: ${csrc:-absent} · static key: ${akey:+PRESENT}${akey:-absent}" >&2
      echo "      fix: rhx grove.provision --what 5.6.aws --mode apply" >&2
      failed=1
    fi
    ;;
  *)
    echo "   ✋ ConstraintError: claim 3 has no badge contract for $GROVE_ENV_SERVER" >&2
    echo "      ⇒ this play asks a GROVE; a laptop's identity is its human's login" >&2
    exit 2
    ;;
esac

# claim 4 — the reach, asked of the bundle that owns it
reach="$(bash "$_root/src/grove.provision._.sh" --what 5.13.reach --mode plan 2>&1)" && rrc=0 || rrc=$?
if [[ "$rrc" -eq 0 ]]; then
  echo "   • claim 4: 5.13.reach verify holds — each rack profile lands in its declared account ✔"
else
  echo "   ✋ claim 4: 5.13.reach verify failed (rc=$rrc); its own rows, verbatim:" >&2
  printf '%s\n' "$reach" | grep -E '✋|⇒|fix:' | grove_aws_chain_redact | sed 's/^/      /' >&2
  failed=1
fi

[[ "$failed" -eq 0 ]] && echo "🌲 every link in the chain holds ✔"
exit "$failed"
