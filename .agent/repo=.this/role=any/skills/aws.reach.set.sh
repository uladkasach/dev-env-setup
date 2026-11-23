#!/usr/bin/env bash
######################################################################
# aws.reach.set — give this box one org+env's aws identity, both halves
#
# .what = declare `[profile <org>.<env>.<owner>]` in `~/.aws/config` AND point
#         the rack's `<org>.<env>.AWS_PROFILE` at that same name, so any
#         consumer that reads the rack lands in the right account.
#
# .why  = a test suite does not name an account. it reads `AWS_PROFILE` and
#         trusts the box. that pointer has TWO halves, and each is useless
#         without the other:
#
#           the NAME   — `ahbode.test.AWS_PROFILE` = "ahbode.test.ehmpath"
#                        stored on the rack; identical on every box
#           the BODY   — `[profile ahbode.test.ehmpath]` in ~/.aws/config
#                        DIFFERENT per box: an sso login on a laptop, an
#                        instance-role chain on a grove
#
#         a rack entry with no profile body names a profile aws cannot find;
#         a profile body with no rack entry is a profile nobody names. two
#         halves, one skill, so neither can be half-done.
#
# ⚠️ .why the name is `<org>.<env>.<owner>` and NOT `<org>.<env>`
#      this convention is EXTANT, not invented here. read off this laptop
#      2026-08-08 — `~/.aws/config` carries `ahbode.test.ehmpath`,
#      `ahbode.prep.ehmpath`, `ahbode.prod.ehmpath`, `ahbode.camp.ehmpath`,
#      and the rack's `ahbode.camp.AWS_PROFILE` answers exactly
#      `ahbode.camp.ehmpath`. the `<owner>` tail is what separates one
#      human's everyday-power seat from `.admin` / `.daily` / `.reader`
#      seats on the SAME account. drop it and two seats collide on one name.
#
# ⚠️ .why this is per ORG+ENV and not per REPO
#      a keyrack slug is natively `<org>.<env>.<KEY>`, so org+env is already
#      the axis the rack indexes on. ten ahbode repos that all test against
#      <prep-acct> share one entry; a repo in a different org gets its own
#      by virtue of its org. a per-repo pass would write the same value ten
#      times and give a robot ten places to disagree with itself.
#
#      what IS per-repo is the ACCOUNT NUMBER, and that is why `--account`
#      may be read from a repo's `declapract.use.yml` (see below) rather
#      than typed from memory.
#
# ⚠️ .why `--account` prefers declapract over a typed flag
#      every declapract repo declares its accounts already:
#
#        # ahbode/svc-chat/declapract.use.yml
#        variables:
#          organizationName: 'ahbode'
#          awsAccountId:
#            dev:  <prep-acct>
#            prep: <prep-acct>
#            prod: <prod-acct>
#
#      a typed `--account` is a number a human recalls, and a recalled account
#      number is the one input here that fails SILENTLY: a plausible id for the
#      wrong account yields a profile that assumes cleanly into somewhere else.
#      a declaration cannot be misremembered. `--account` stays accepted for a
#      box with no repo in reach.
#
#      ⚠️ declapract says `dev`, the rack says `test`. one account
#         (both <prep-acct>) under two vocabularies, so `--env test` reads
#         declapract's `dev` key. this states that mapping rather than infer
#         it: a silent fallthrough to `prep` is a plausible answer drawn from
#         the wrong row.
#
# ⚠️ .why `--role` is never guessed
#      a session on 2026-08-06 guessed three role names — `ahbode-test-role`,
#      `ahbode-prep-role`, `OrganizationAccountAccessRole` — took three
#      refusals, and nearly reported "the grove has no prep access" about a
#      grove that had it. the real name, `<prep-oidc-role>`, assumed on the
#      first try. a guessed role name draws a refusal that reads exactly like
#      an absent grant (`rule.forbid.failhide`). so: name it, and this skill
#      PROVES it with sts before it reports ✔.
#
# ⚠️ .why this file writes to `~/.aws/config`, which `5.6.aws` also owns
#      `rule.forbid.two-writers-on-one-artifact` bites when two writers can
#      touch the same BYTES. they cannot here: `5.6.aws` owns exactly its
#      `# grove: the ambient …`…`# grove: end` fence (ambient, plus [default]
#      on ec2), and this skill owns one `# grove: reach <profile>` fence per
#      profile. each rewrites only its own fence and copies every other line
#      through. aws offers no second file for profiles, so the fence is the
#      boundary.
#
# 🛑 .and [default] is a THIRD writer's on a hetzner grove
#      infra's identity skill rewrites [default] there on its own schedule.
#      every write this skill makes re-reads [default] at the last moment and
#      refuses to land if it moved, or if the new body would change it
#      (`src/grove.aws.sh`). the box kind comes from the platform, and the
#      body names the endpoint [default] names
#
# usage:
#   rhx aws.reach.set --org ahbode --env test --assume <prep-oidc-role>
#   rhx aws.reach.set --org ahbode --env test --assume <prep-oidc-role> --mode apply
#   rhx aws.reach.set --org ahbode --env prod --assume <prod-oidc-role> \
#                     --account <prod-acct> --mode apply
#   rhx aws.reach.set --org ahbode --env camp --mode apply     # no role: camp IS the box
#   rhx aws.reach.set help
#
# options:
#   --org       the org the account belongs to           (required)
#   --env       test | prep | prod | camp                (required)
#   --assume    role to assume in that account           (required, except --env camp)
#               (NOT `--role` — rhachet injects that one into every skill)
#   --account   12-digit account id                      (read from declapract if absent)
#   --from      path to a repo holding declapract.use.yml (default: cwd)
#   --owner     rack owner + profile-name tail           (default: ehmpath)
#   --region    aws region for the profile               (default: us-east-1)
#   --gitroot   the git root every keyrack call runs from (default: cwd if a repo,
#               else 5.12.rack's scratch root) — a caller that DECLARED the org there
#               names it, so the write reads the declaration the caller laid
#   --mode      plan (default) or apply
#
# guarantee:
#   - idempotent: a re-run rewrites its own fence and changes no other line
#   - READ-ONLY in plan mode; it prints the exact block apply would write
#   - never reports ✔ on an unproven profile — apply ends with a live
#     `sts get-caller-identity` through the profile it just wrote
#   - exit 0 = the profile answers, and names the expected account
#   - exit 1 = malfunction (aws refused, keyrack broke)
#   - exit 2 = constraint (bad args, undeclarable account, laptop with no sso,
#     a camp grove with no identity road, a wrong account, a shadowed rack)
######################################################################
set -uo pipefail

# ⚠️ read the whole ARG VECTOR, never `$1` — rhachet injects `--skill <slug>` ahead
#    of the caller's args, so a `$1` test never fires (measured 2026-08-30; ten
#    skills in this dir carried it, and each read `help` as its SUBJECT instead)
if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "aws.reach.set — give this box one org+env's aws identity, both halves"
  echo ""
  echo "usage:"
  echo "  rhx aws.reach.set --org <org> --env <env> [--assume <role>] [--mode apply]"
  echo ""
  echo "options:"
  echo "  --org       the org the account belongs to            (required)"
  echo "  --env       test | prep | prod | camp                 (required)"
  echo "  --assume    role to assume there                      (required, except --env camp)"
  echo "              (NOT --role: rhachet injects that into every skill)"
  echo "  --account   12-digit account id     (read from declapract.use.yml if absent)"
  echo "  --from      repo path holding declapract.use.yml      (default: cwd)"
  echo "  --owner     rack owner + profile-name tail            (default: ehmpath)"
  echo "  --region    aws region                                (default: us-east-1)"
  echo "  --gitroot   git root for keyrack calls  (default: cwd if a repo, else the rack's)"
  echo "  --mode      plan (default) or apply"
  echo ""
  echo "it writes BOTH halves of the pointer:"
  echo "  1. [profile <org>.<env>.<owner>]  in ~/.aws/config   (the body, per box)"
  echo "  2. <org>.<env>.AWS_PROFILE        on the rack        (the name, everywhere)"
  echo ""
  echo "examples:"
  echo "  rhx aws.reach.set --org ahbode --env test --assume <prep-oidc-role> --mode apply"
  echo "  rhx aws.reach.set --org ahbode --env camp --mode apply"
  exit 0
fi

# shellcheck source=./aws.reach.operations.sh
source "$(dirname "${BASH_SOURCE[0]}")/aws.reach.operations.sh"

ORG=""
ENV=""
ROLE=""
ACCOUNT=""
FROM="$PWD"
OWNER="ehmpath"
REGION="us-east-1"
MODE="plan"
GITROOT_GIVEN=""

while [[ $# -gt 0 ]]; do
  # a value flag with no value refuses: `shift 2` past the last arg shifts naught,
  # so the loop would read the same flag forever
  [[ "$1" =~ ^--(gitroot|org|env|assume|account|from|owner|region|mode|skill|repo|role)$ && $# -lt 2 ]] && {
    echo "✋ ConstraintError: $1 needs a value" >&2; echo "   see: rhx aws.reach.set help" >&2; exit 2; }
  case "$1" in
    --gitroot) GITROOT_GIVEN="$2"; shift 2 ;;
    --org)     ORG="$2";     shift 2 ;;
    --env)     ENV="$2";     shift 2 ;;
    --assume)  ROLE="$2";    shift 2 ;;
    --account) ACCOUNT="$2"; shift 2 ;;
    --from)    FROM="$2";    shift 2 ;;
    --owner)   OWNER="$2";   shift 2 ;;
    --region)  REGION="$2";  shift 2 ;;
    --mode)    MODE="$2";    shift 2 ;;
    ###################################################################
    # 🛑 `--role` is RHACHET's flag, and this skill's is `--assume`
    #
    # 📜 measured 2026-08-31. rhachet injects `--role <slug>` into every skill
    #    it runs, and this loop took that flag as the IAM ROLE NAME. two costs,
    #    and the second is fatal:
    #      · a `--env test|prep|prod` run built `arn:…:role/any` — a role that
    #        does not exist, so the assume failed and named the wrong cause
    #      · a `--env camp` run could not run AT ALL: line ~349 refuses any
    #        `--role` for camp, so the injected value tripped a guard on every
    #        single invocation, against a caller who typed no role
    #
    # ⇒ `--role` is dropped with rhachet's other two, and the IAM role has a
    #   name rhachet does not use. its ABSENCE is loud below — the required
    #   check and the camp refusal each name `--assume`, so a human who types
    #   `--role` is told which one to use rather than left with a default
    ###################################################################
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "✋ ConstraintError: unknown argument '$1'" >&2; echo "   see: rhx aws.reach.set help" >&2; exit 2 ;;
  esac
done

# a given rack root must be a repo, refused before any step reads or writes on its behalf
[[ -z "$GITROOT_GIVEN" ]] || git -C "$GITROOT_GIVEN" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "✋ ConstraintError: --gitroot '$GITROOT_GIVEN' is not a git repo" >&2
  echo "   fix: rhx grove.provision --what 5.12.rack --mode apply   (it owns the rack root)" >&2
  exit 2
}
[[ -n "$ORG" ]] || { echo "✋ ConstraintError: --org is required (e.g. --org ahbode)" >&2; exit 2; }
[[ -n "$ENV" ]] || { echo "✋ ConstraintError: --env is required (test|prep|prod|camp)" >&2; exit 2; }
####################################################################
# 🛑 this list MIRRORS keyrack's `KEYRACK_VALID_ENVS` — it never extends it
#   this skill writes BOTH halves, and the rack half is a `keyrack set`. so an
#   env this list accepts and keyrack refuses writes the profile body and then
#   fails — the half-applied pair, with a decline that names the callee.
#
#   📜 measured 2026-09-18: a `demo` value was added here to let an
#   `ehmpathy:demo` reach row through. it got one step further and died on
#   `invalid --env 'demo': must be one of sudo, prod, prep, test, all, camp`,
#   with `[profile ehmpathy.demo.ehmpath]` already on disk. ⇒ the enum was the
#   SIGNAL, never the defect: `demo` names an ACCOUNT, and an env names a TIER.
#   the row was rewired to `ehmpathy:test` + `ehmpathy:prep`, both into that one
#   account, which is what `ehmpathy/sdk-aws-lambda` already selects by.
#
#   ⇒ so a new env here is owed a keyrack release FIRST, never the reverse
####################################################################
case "$ENV" in
  test|prep|prod|camp) ;;
  *) echo "✋ ConstraintError: invalid --env '$ENV' (test|prep|prod|camp)" >&2; exit 2 ;;
esac
[[ "$MODE" == "plan" || "$MODE" == "apply" ]] || { echo "✋ ConstraintError: invalid --mode '$MODE' (plan|apply)" >&2; exit 2 ;}

####################################################################
# 🛑 every value that reaches ~/.aws/config is GRAMMAR-CLAMPED first
#
# .why  ~/.aws/config is not a passive record — it is an execution surface.
#       one line in a profile block, `credential_process = <cmd>`, makes the
#       aws cli run that command to fetch credentials. so ANY value composed
#       into this file that can carry a NEWLINE can add that line, and the
#       next `aws` call on this box runs it.
#
#       the values below reach that file: `$ORG` and `$OWNER` through
#       `$PROFILE` (the section header), `$ACCOUNT` and `$ROLE` through
#       `role_arn`, `$REGION` through `region`. not one was checked before
#       2026-08-31 — a `--role $'x\ncredential_process = curl …|sh'` wrote a
#       live backdoor into a file the human never re-reads.
#
# .why  a CLAMP and not an escape: each of these has a KNOWN, narrow, publicly
#       documented grammar. so the honest guard states what is ALLOWED and
#       refuses the rest (`rule.require.solve-at-cause`) — an escape would have
#       to anticipate every way an ini parser accepts a line break, and one
#       missed form is a silent backdoor rather than a visible error.
#
# ⚠️ `$ACCOUNT` is NOT clamped here. it has a second source — section 3 reads
#    it from a `declapract.use.yml` — so its one point of finalization is the
#    END of that section, and that is where its clamp sits. to check it twice
#    would be two holders of one rule (m.9), and the one that drifts is the one
#    a reader does not expect to exist.
####################################################################
reach_clamp() {
  local flag="$1" value="$2" allowed="$3" shape="$4"
  if [[ -z "$value" ]]; then return 0; fi
  if [[ "$value" == *[!$allowed]* ]]; then
    echo "✋ $flag holds a byte outside its grammar" >&2
    echo "" >&2
    echo "  given:   '$value'" >&2
    echo "  allowed: $shape" >&2
    echo "  ⇒ this value is composed into ~/.aws/config, where a line of" >&2
    echo "    'credential_process = <cmd>' is CODE the aws cli runs. a value" >&2
    echo "    that can hold a newline can write that line." >&2
    exit 2
  fi
}
reach_clamp --org "$ORG" 'A-Za-z0-9._-' '[A-Za-z0-9._-] (a github org name)'
reach_clamp --owner "$OWNER" 'A-Za-z0-9._-' '[A-Za-z0-9._-]'
reach_clamp --assume "$ROLE" 'A-Za-z0-9+=,.@_/-' '[A-Za-z0-9+=,.@_/-] (an iam role name, path allowed)'
reach_clamp --region "$REGION" 'a-z0-9-' '[a-z0-9-] (e.g. us-east-1)'

# ⚠️ the profile NAME and the config PATH are sourced too — `aws.reach.del`
#   must name the very same string to reap the very same fence
PROFILE="$(aws_reach_profile "$ORG" "$ENV" "$OWNER")"
CFG="$(aws_reach_config)"
DECL_ENV="$ENV"; [[ "$ENV" == "test" ]] && DECL_ENV="dev"

echo "🐢 heres the wave..."
echo ""
echo "🔭 aws.reach.set --org $ORG --env $ENV --mode $MODE"
echo "   ├─ profile: $PROFILE"

####################################################################
# 1. which BODY does this box need?
#
# ⚠️ .why the box is derived and not told by a flag
#      a `--for cloud` flag would let a human declare a grove body on a
#      laptop, which produces a profile that cannot work and reads fine in
#      the file. the PLATFORM is the fact, derived once by `src/grove.env.sh`
#      — the same answer `5.6.aws` reads for its own gate
#
# 🛑 .why not a probe of 169.254.169.254, as this section once ran
#      a hetzner grove has no route there, so that probe called it a laptop
#      and the skill asked for an sso login on a headless box. the platform
#      names both grove kinds, and `grove_aws_identity_endpoint` names the one
#      fact their bodies differ by
####################################################################
aws_reach_runtime_load || exit 2
grove_env_derive || exit 2

ENDPOINT="$(grove_aws_identity_endpoint)"; ROAD="$(grove_aws_identity_road "$?")"
case "$ROAD" in
  known)       HOSTKIND="grove";  HOSTWHY="$GROVE_ENV_SERVER" ;;
  no-identity) HOSTKIND="laptop"; HOSTWHY="$GROVE_ENV_SERVER — no platform identity" ;;
  unmapped)
    # a camp grove read as a laptop would get an sso body on a box with no browser
    echo "   └─ ✋ ConstraintError: $GROVE_ENV_SERVER is a camp grove, and this repo knows no road to its aws identity" >&2
    echo "" >&2
    echo "  why: a grove body names the endpoint that serves the box's identity, and this" >&2
    echo "       platform has none mapped; a laptop's sso body would not work here" >&2
    echo "  fix: teach grove_aws_identity_endpoint (src/grove.aws.sh) this platform's road" >&2
    exit 2 ;;
  serve-unwired)
    echo "   └─ ✋ ConstraintError: a hetzner grove, and [default] in $CFG names no ec2_metadata_service_endpoint" >&2
    echo "" >&2
    echo "  why: every grove body here names the endpoint that serves the box's identity," >&2
    echo "       and on hetzner that line is infra's to write. this skill mirrors it, and" >&2
    echo "       will not invent a port" >&2
    echo "  fix: run infra's grove identity skill with serve wired, then re-run this" >&2
    exit 2 ;;
  bad-endpoint)
    echo "   └─ ✋ ConstraintError: [default] in $CFG names a non-loopback ec2_metadata_service_endpoint ('$ENDPOINT')" >&2
    echo "" >&2
    echo "  why: that line would be copied into this profile, and the sdk would send" >&2
    echo "       its identity requests to another host" >&2
    echo "  fix: re-run infra's grove identity skill, then re-run this" >&2
    exit 2 ;;
esac
# the rack's vault, decided ONCE so the plan names the vault the apply writes: a laptop
#   unlocks by sso (aws.config); a grove has no sso, so a plain reference store is the
#   honest vault. see the ⚠️ block in the header
VAULT="os.direct"; [[ "$HOSTKIND" == "laptop" ]] && VAULT="aws.config"
echo "   ├─ box:     $HOSTKIND ($HOSTWHY)"
[[ -n "$ENDPOINT" ]] && echo "   ├─ identity: $ENDPOINT (mirrored from [default])"

####################################################################
# 2. a laptop's body is an SSO login this skill must NOT author
#
# ⚠️ .why it declines rather than writes
#      an sso body needs an `sso_start_url` — an identity-center url this
#      skill has no truthful source for. to synthesize one would be to
#      guess a credential endpoint, which is the `--role` hazard wearing a
#      different hat. a laptop's profiles are declared by `aws configure sso`
#      and already sit in this file; the skill's job here is to CONFIRM.
####################################################################
if [[ "$HOSTKIND" == "laptop" ]]; then
  if grep -q "^\[profile ${PROFILE}\]" "$CFG" 2>/dev/null; then
    echo "   └─ ✔ a laptop, and '$PROFILE' is already declared — no work"
    echo "      ├─ a laptop's body is an sso login, owned by 'aws configure sso'; this skill authors grove bodies"
    echo "      └─ prove it: aws sts get-caller-identity --profile $PROFILE"
    exit 0
  fi
  echo "   └─ ✋ ConstraintError: a laptop, and '$PROFILE' is NOT declared" >&2
  echo "      ├─ why: on a laptop this profile is an sso login, whose sso_start_url this skill has no truthful source for" >&2
  echo "      └─ fix: declare it with aws's own tool, then rerun this to set the rack half: aws configure sso --profile $PROFILE" >&2
  exit 2
fi

####################################################################
# 3. the account — declared, or typed
####################################################################
if [[ -z "$ACCOUNT" && "$ENV" != "camp" ]]; then
  DECL="$FROM/declapract.use.yml"
  if [[ -r "$DECL" ]]; then
    ACCOUNT="$(awk -v want="$DECL_ENV" '
      /^[[:space:]]*awsAccountId:/ { inblock=1; next }
      inblock && /^[[:space:]]*[a-zA-Z]+:[[:space:]]*[0-9]+[[:space:]]*$/ {
        split($0, kv, ":"); gsub(/[[:space:]]/, "", kv[1]); gsub(/[[:space:]]/, "", kv[2])
        if (kv[1] == want) { print kv[2]; exit }
        next
      }
      inblock && /^[[:space:]]*[a-zA-Z]+:/ { exit }
    ' "$DECL")"
    [[ -n "$ACCOUNT" ]] && echo "   ├─ account: $ACCOUNT (declared: declapract.use.yml → awsAccountId.$DECL_ENV)"
  fi
fi

if [[ -z "$ACCOUNT" && "$ENV" != "camp" ]]; then
  echo "   └─ ✋ ConstraintError: no account for org=$ORG env=$ENV" >&2
  echo "" >&2
  echo "  why: no --account was passed, and no declapract.use.yml under" >&2
  echo "       '$FROM' declares awsAccountId.$DECL_ENV" >&2
  echo "  fix: point at a repo that declares it —" >&2
  echo "    rhx aws.reach.set --org $ORG --env $ENV --assume <role> --from ~/git/$ORG/<repo>" >&2
  echo "  or name it outright, from the org's account list (never from memory):" >&2
  echo "    rhx aws.reach.set --org $ORG --env $ENV --assume <role> --account <id>" >&2
  exit 2
fi

# 🛑 the account's clamp — HERE, because here is where its value is final
#
# .why  an aws account id is EXACTLY twelve decimal digits. that is not a
#       convention, it is the format, so the allow-list is total and any other
#       shape is a defect however it arrived.
#
# ⚠️ .why this matters more than the other four
#       `$ACCOUNT` has TWO sources: a `--account` flag a human typed, and a
#       `declapract.use.yml` an awk block reads out of some repo on this disk.
#       the second is not the human's word — `5.13.reach` picks that file by a
#       GLOB across every clone under `~/git/<org>/`, so whoever can write any
#       one of those clones names the account this box assumes a role into.
#
#       ⇒ and note what section 8 does with it downstream: it proves the live
#         sts answer against `$ACCOUNT`. that check is only worth its ✔ if
#         `$ACCOUNT` is itself a well-formed id from a source the box trusts —
#         otherwise it compares one attacker-chosen value to another and
#         reports agreement. the clamp is what makes that later ✔ mean a thing.
if [[ -n "$ACCOUNT" && ! "$ACCOUNT" =~ ^[0-9]{12}$ ]]; then
  echo "   └─ ✋ '$ACCOUNT' is not an aws account id" >&2
  echo "" >&2
  echo "  an account id is exactly 12 decimal digits." >&2
  echo "  ⇒ if this came from a declapract.use.yml, that file's awsAccountId" >&2
  echo "    block is malformed — read it before you trust the repo it sits in:" >&2
  echo "      $FROM/declapract.use.yml" >&2
  echo "  ⇒ this value becomes a role_arn in ~/.aws/config, and it is what" >&2
  echo "    section 8 proves the live sts answer against." >&2
  exit 2
fi

####################################################################
# 4. the body
#
# ⚠️ .why `--env camp` takes NO role
#      camp is the account the grove itself lives in, so its instance role
#      IS the identity — there is no hop to make. a role_arn here would ask
#      the badge to assume into its own account, which is a real refusal
#      dressed as a config error
####################################################################
if [[ "$ENV" == "camp" ]]; then
  [[ -z "$ROLE" ]] || { echo "   └─ ✋ ConstraintError: --env camp takes no --assume: camp is the grove's own account" >&2; exit 2; }
  BODY=$'credential_source = Ec2InstanceMetadata\nregion = '"$REGION"
  echo "   ├─ reach:   the grove's own badge (camp — no hop)"
else
  [[ -n "$ROLE" ]] || {
    echo "   └─ ✋ ConstraintError: --assume is required for --env $ENV" >&2
    echo "" >&2
    echo "  why: a grove reaches another account by ASSUMING a role there," >&2
    echo "       and a guessed role name refuses in a way that reads exactly" >&2
    echo "       like an absent grant. so it is named, never inferred." >&2
    echo "  ⚠️ if you typed '--role', that flag is RHACHET's — it injects one" >&2
    echo "     into every skill, so this one is '--assume'" >&2
    echo "  fix: read the name from the org's infra repo, then pass it —" >&2
    echo "    rhx git.repo.get lines --in $ORG/infrastructure --words 'ROLE_NAME'" >&2
    exit 2
  }
  ROLE_ARN="arn:aws:iam::${ACCOUNT}:role/${ROLE}"
  BODY=$'role_arn = '"$ROLE_ARN"$'\ncredential_source = Ec2InstanceMetadata\nregion = '"$REGION"
  echo "   ├─ reach:   the grove's badge ⇒ $ROLE_ARN"
fi

####################################################################
# ⚠️ on hetzner, the body names WHERE the badge is served
#   - `credential_source = Ec2InstanceMetadata` asks the sdk default,
#     169.254.169.254, which a hetzner grove has no route to
#   - the one line below points that same source at infra's signer, so the
#     body stays ec2's shape plus one line (route F5)
#   - 📌 a `source_profile = default` hop was the first shape asked for; from
#     recall of botocore, a source profile resolves only through the PROFILE
#     providers, which exclude instance metadata. the live sts call in
#     section 8 is what proves this body
####################################################################
[[ -n "$ENDPOINT" ]] && BODY+=$'\nec2_metadata_service_endpoint = '"$ENDPOINT"

# ⚠️ the fence grammar is SOURCED, never spelled here
#   - `aws.reach.del` reaps by this exact pair of lines, and `aws.reach.get`
#     lists by it. three holders of one string is an m.9 drift that has not
#     fired yet, and the em dash is a byte nobody re-types correctly
#   - ⇒ `aws.reach.operations.sh` holds it once, and its LIST reader derives
#     its own affixes from `_fence_open` so it cannot drift either
FENCE_OPEN="$(aws_reach_fence_open "$PROFILE")"
FENCE_SHUT="$(aws_reach_fence_shut "$PROFILE")"

####################################################################
# 🛑 a [profile] of this NAME outside this skill's fence is refused, never adopted
#
# .why
#   - a second `[profile <name>]` in one file is legal ini, and the sdk lets
#     the LAST one win — so the file reads as two bodies and acts as one, in
#     silence, and which one depends on order
#   - a hand-laid block is a human's (or infra's) decision: to delete it is to
#     overrule them, and to append beside it is the silent shadow above
#   - ⇒ the honest move is to stop and name both, before either half is written
#     (route F4)
####################################################################
TWINS="$(aws_reach_twin_count "$PROFILE")"
if [[ "${TWINS:-0}" != "0" ]]; then
  echo "   └─ ✋ ConstraintError: $CFG already declares [profile $PROFILE] OUTSIDE this skill's fence" >&2
  echo "" >&2
  echo "  where: $CFG, lines $(aws_reach_unfenced_ranges_csv "$PROFILE")" >&2
  echo "  why: a second block of one name is silent — the sdk reads the last one," >&2
  echo "       so this skill would either shadow that block or be shadowed by it" >&2
  echo "  ⇒ the block was laid by hand (or by another writer), so it is not this" >&2
  echo "    skill's to delete" >&2
  echo "  fix: remove that unfenced [profile $PROFILE] block from $CFG, then re-run this" >&2
  exit 2
fi

####################################################################
# 5. plan
####################################################################
if [[ "$MODE" == "plan" ]]; then
  echo "   └─ plan — apply would write these two halves:"
  echo ""
  echo "      1. into ~/.aws/config"
  echo "         $FENCE_OPEN"
  echo "         [profile $PROFILE]"
  printf '%s\n' "$BODY" | sed 's/^/         /'
  echo "         $FENCE_SHUT"
  echo ""
  echo "      2. onto the rack"
  echo "         rhx keyrack set --owner $OWNER --key AWS_PROFILE \\"
  echo "                         --org $ORG --env $ENV --vault $VAULT"
  echo ""
  echo "      then it PROVES the pair with a live call:"
  echo "         aws sts get-caller-identity --profile $PROFILE"
  echo ""
  echo "      re-run with --mode apply."
  exit 0
fi

####################################################################
# 6. apply — half one: the profile body
#
# ⚠️ every line outside THIS fence is copied through byte for byte, so a
#    re-run is an upsert of one block and not a rewrite of the file
####################################################################
#
# 🛑 [default] is never this skill's, on any platform
#   - ec2: `5.6.aws` writes it; hetzner: infra's identity skill writes it
#   - ⇒ the swap refuses a body that would change it, and refuses to land if
#     another writer moved it after this run read the file (`src/grove.aws.sh`)
####################################################################
echo "   └─ apply"
mkdir -p "$HOME/.aws"
touch "$CFG"

DEFAULT_BEFORE="$(grove_aws_config_section cfg="$CFG" name=default)"
TMP="$(grove_aws_config_tmp)" || { echo "      └─ 💥 MalfunctionError: no tmp file beside $CFG" >&2; exit 1; }
# 🛑 set IN PLACE, never drop-then-append: an append moved `5.6.aws`'s block and
#   stranded a blank line mid-file, so each run rewrote the file the other
#   bundle left (`grove_aws_config_fence_set`, `src/grove.aws.sh`)
aws_reach_fence_set "$PROFILE" "$(
  printf '%s\n' "$FENCE_OPEN"
  printf '[profile %s]\n' "$PROFILE"
  printf '%s\n' "$BODY"
  printf '%s' "$FENCE_SHUT"
)" > "$TMP"

if cmp -s "$TMP" "$CFG"; then
  echo "      ├─ ~/.aws/config already current for [profile $PROFILE]"
  rm -f "$TMP"
else
  grove_aws_config_swap cfg="$CFG" new="$TMP" default_before="$DEFAULT_BEFORE" default=keep; SWAP_RC=$?
  if (( SWAP_RC != 0 )); then
    echo "      └─ 💥 MalfunctionError: ~/.aws/config was NOT written: $(grove_aws_config_swap_why "$SWAP_RC")" >&2
    grove_aws_config_swap_said "         " >&2
    exit 1
  fi
  echo "      ├─ ~/.aws/config now declares [profile $PROFILE] ✔"
fi

####################################################################
# 7. apply — half two: the rack entry
#
# ⚠️ .why the vault differs by box, and neither choice is a secret store
#      no secret is ever typed here: an AWS_PROFILE value is a profile NAME,
#      and the name is already written above.
#
#        laptop → `aws.config`  — rhachet: "stores only profile names
#                                 (references)"; its UNLOCK is a browser sso
#                                 auth, which a laptop has and a grove does not
#        grove  → `os.direct`   — rhachet: "plaintext file storage, no unlock".
#                                 correct for a grove, whose credentials come
#                                 from IMDS and never from an sso token
#
#      ⚠️ measured 2026-08-08: `keyrack set --vault aws.config` on grove-1
#         prompted `which sso domain? / sso start url`, and hung on a duct
#         with no tty. that is not a keyrack defect — aws.config's unlock IS
#         sso, and a grove has none. the vault must match the box
#
# ⚠️ .the shadow that outranks BOTH — `os.envvar` is checked FIRST
#      rhachet's `KeyrackHostVault` says it plainly: *"os.envvar is always
#      checked first in grant flow (ci passthrough)"*. so an exported
#      `AWS_PROFILE` in the shell wins over every rack entry, for every org
#      and every env, and a perfect rack is never consulted.
#
#      that is exactly grove-1's state: `~/.zshenv` exports
#      `AWS_PROFILE=ambient` (owned by `2.5.zsh`), so
#      `keyrack get --org ahbode --env test --key AWS_PROFILE` answers
#      `ambient` on a box whose rack holds no such entry at all. see
#      `howdoes.a-box-reach-an-aws-account.md`, failure 4
#
# ⚠️ .why the extant value is COMPARED and not merely detected — 📜 2026-08-08
#      `if keyrack get succeeds → already answers` is a failhide. grove-1's
#      rack answered `ahbode.test.AWS_PROFILE = "ambient"` — a leftover from a
#      bootstrap that ran before any org profile existed. the get SUCCEEDS, so
#      such a skill skips the set, prints ✔, and svc-chat's suite still runs as
#      camp:
#
#        rack ahbode.test.AWS_PROFILE = ambient
#        profile ahbode.test.ehmpath  = …<prep-acct>:…/<prep-oidc-role>  ✔
#        all 44 refusals              = …<camp-acct>:…/<camp-grove-role>
#
#      the hop worked and no one named it. a probe that cannot tell the
#      RIGHT value from ANY value must not report a verdict
#      (`rule.forbid.failhide`, `term=probe`)
####################################################################
######################################################################
# .what = the cwd every keyrack call below runs from
#
# .why  = rhachet's cli calls `getGitRepoRoot` before a keyrack WRITE, and it
#         reads a `keyrack.yml` in scope to decide whether a NAMED org's key is
#         declared. both halves of that requirement are about the CWD — and on a
#         grove the cwd is often not a repo at all. `grove.bootstrap.sh` names
#         PUSHED as a legitimate provenance for `src`, and a pushed tree has no
#         `.git` by design.
#
#   ⚠️ the requirement is PER-SUBCOMMAND, never "before ANY keyrack subcommand".
#      at rhachet@1.45.1, measured by a read of `invokeKeyrack.js`:
#
#        get (:330)  source (:451)  unlock (:860)  →  getGitRepoRootOrNull
#        list (:1102)                              →  no root call at all
#        set (:563)  del (:726)     fill (:1152)   →  getGitRepoRoot, HARD
#
#      so THIS skill still needs the root — it ends in a `keyrack set` — and a
#      neighbour that only READS does not. do not copy this block to a reader
#      (`rule.require.trust-but-verify`; a universal claim measured 2026-08-10
#      and the tool moved past it with no signal to us)
#
#         measured on this box 2026-08-10: `--mode apply` wrote the profile BODY
#         into ~/.aws/config successfully, then died on the rack half with
#         `Not inside a Git repository`. a half-applied pair is precisely what
#         this skill's header says must never happen — "a profile body with no
#         rack entry is a profile nobody names".
#
#   ⇒ `5.12.rack` already owns the answer: a scratch `git init` root at
#     `$HOME/.local/state/keyrack.gitroot`, with a `keyrack.yml` that declares
#     AWS_PROFILE for camp, test, and prep. this READS it and never writes it
#     (`rule.forbid.two-writers-on-one-artifact`).
#
#   ⇒ the cwd wins wherever it IS a repo, so a laptop run from a real checkout
#     behaves exactly as it did before this fallback existed
#
# .note = a workaround for an upstream over-requirement. the operation needs no
#         repo; the cli demands one. the durable fix belongs in rhachet
#         (`rule.require.solve-at-cause`) — until it lands, this is the seam
######################################################################
# 🛑 a GIVEN root wins: the cwd's own keyrack.yml declares only its repo's org, so a
#   run from a real checkout refused every cross-org row the caller had declared in
#   the rack root (📜 2026-11-20, an ec2 grove: both `ehmpathy` rows read
#   "not on this manifest's org allowlist", while a pushed checkout — no `.git`, so
#   the fallback — passed the same rows)
GITROOT="$PWD"
# a given root is a repo, by the check right after the parse
[[ -n "$GITROOT_GIVEN" ]] && GITROOT="$GITROOT_GIVEN"
if [[ -z "$GITROOT_GIVEN" ]] && ! git -C "$PWD" rev-parse --git-dir >/dev/null 2>&1; then
  GITROOT="$HOME/.local/state/keyrack.gitroot"
  if [[ ! -d "$GITROOT/.git" ]]; then
    echo "      └─ 💥 MalfunctionError: the cwd is not a git repo, and the box has no rack root" >&2
    echo "" >&2
    echo "  why: rhachet's cli refuses every keyrack subcommand outside a git root" >&2
    echo "  fix: rhx grove.provision --what 5.12.rack --mode apply" >&2
    echo "       (it owns $GITROOT, and declares AWS_PROFILE there)" >&2
    exit 1
  fi
  echo "      ├─ gitroot: $GITROOT (the cwd is not a repo)"
fi

RACK_SEEN="$(env -C "$GITROOT" rhx keyrack get --owner "$OWNER" --org "$ORG" --env "$ENV" --key AWS_PROFILE \
  --value --unlock 2>/dev/null | tail -1)"

if [[ "$RACK_SEEN" == "$PROFILE" ]]; then
  echo "      ├─ rack already answers ${ORG}.${ENV}.AWS_PROFILE = $PROFILE"
else
  [[ -n "$RACK_SEEN" ]] \
    && echo "      ├─ ⚠️ rack answers '$RACK_SEEN', expected '$PROFILE' — it will be re-set" \
    || echo "      ├─ rack does not answer ${ORG}.${ENV}.AWS_PROFILE yet"

  echo "      │  vault: $VAULT  (a $HOSTKIND)"

  # ⚠️ .why the value is FED on stdin, when a pat never may be
  #      `keyrack set` prompts `enter secret for AWS_PROFILE:`, and on a
  #      grove that prompt has no tty — a duct-borne run hangs there forever.
  #      `git.grove.auth.github.set` answers the same prompt over an `ssh -t`,
  #      because a github pat must never travel as data this process can see.
  #
  #      an AWS_PROFILE value is NOT a secret. it is `<org>.<env>.<owner>`,
  #      computed above from the flags, printed in this skill's own output,
  #      and already written into ~/.aws/config one step earlier. so the
  #      hazard that forbids a pipe for a pat does not exist here.
  #
  #      what DOES carry over is the failure mode: fed a pipe, keyrack may
  #      read the tty anyway, skip the value, store an EMPTY string, and
  #      print `✔ set` regardless (measured with a pat, 2026-08-02). that is
  #      why the re-read below is not optional — it is the one rung that
  #      separates this from a claim
  # keyrack's own words are KEPT, then shown inside this tree: raw, they land at
  #   column 0 between two branches. its `✔ set` is dropped on success, since a
  #   set's claim is no proof — the re-read below is
  SET_RC=0
  SET_SAID="$(printf '%s\n' "$PROFILE" | env -C "$GITROOT" rhx keyrack set --owner "$OWNER" --key AWS_PROFILE \
        --org "$ORG" --env "$ENV" --vault "$VAULT" 2>&1)" || SET_RC=$?
  if (( SET_RC != 0 )); then
    echo "      └─ 💥 MalfunctionError: keyrack refused the set" >&2
    while IFS= read -r line; do
      [[ -n "${line//[[:space:]]/}" ]] && echo "         ⇒ it said: $line" >&2
    done <<< "$SET_SAID"
    echo "" >&2
    echo "  why: AWS_PROFILE may not be DECLARED for env=$ENV in this repo's" >&2
    echo "       .agent/keyrack.yml — an undeclared key stores and then reads" >&2
    echo "       'absent 🫧' forever (domain.terms/term=entry)" >&2
    echo "  fix: declare it, then re-run —" >&2
    echo "    env.$ENV:" >&2
    echo "      - AWS_PROFILE" >&2
    exit 1
  fi

  # ⚠️ a `✔ set` is a claim about the STORE and says none of the READ.
  #    ask again — this is the rung `term=entry` exists because of
  RACK_SEEN="$(env -C "$GITROOT" rhx keyrack get --owner "$OWNER" --org "$ORG" --env "$ENV" --key AWS_PROFILE \
    --value --unlock 2>/dev/null | tail -1)"
  if [[ "$RACK_SEEN" != "$PROFILE" ]]; then
    echo "      └─ ✋ ConstraintError: the set reported success and the rack still answers '$RACK_SEEN'" >&2
    echo "" >&2
    echo "  expected: $PROFILE" >&2
    echo "  ⇒ every consumer reads the rack, so each will act as '$RACK_SEEN'" >&2
    echo "    no matter how correct the profile body is" >&2
    echo "  ⇒ if it still answers an EXPORTED value, the rack is shadowed:" >&2
    echo "    'os.envvar' is checked FIRST in keyrack's grant flow, so an" >&2
    echo "    AWS_PROFILE in the shell outranks every rack entry there is." >&2
    echo "    ~/.zshenv exports one (owned by 2.5.zsh) — that is the cause." >&2
    echo "  fix: set it by hand, and answer '$PROFILE' at the value prompt —" >&2
    echo "    rhx keyrack set --owner $OWNER --key AWS_PROFILE \\" >&2
    echo "                    --org $ORG --env $ENV --vault $VAULT" >&2
    exit 2
  fi
  echo "      ├─ rack now answers ${ORG}.${ENV}.AWS_PROFILE = $PROFILE ✔"
fi

####################################################################
# 8. PROVE it — a written profile is not a working one
#
# ⚠️ this is the rung that separates this skill from a file writer. a
#    role_arn that does not exist, a trust policy that omits this grove, a
#    typo'd account — all three produce a file that reads perfectly and a
#    call that refuses. so the ✔ below is earned by a live sts call, never
#    by the write succeeding (rule.require.upgrade-entries-verify-themselves)
####################################################################
echo "      ├─ prove: aws sts get-caller-identity --profile $PROFILE"
if ! WHOAMI="$(timeout -k 10 30 aws sts get-caller-identity --profile "$PROFILE" --output json 2>&1)"; then
  echo "      └─ 💥 MalfunctionError: the profile is declared and does NOT answer" >&2
  echo "" >&2
  echo "  aws said:" >&2
  printf '%s\n' "$WHOAMI" | head -4 | sed 's/^/    /' >&2
  echo "" >&2
  # name WHO asked: on hetzner the badge is a roles-anywhere session, and a
  # trust policy written for ec2 alone refuses it while it reads like a typo
  ASKER="$(timeout -k 5 20 aws sts get-caller-identity --profile ambient --query Arn --output text 2>/dev/null)"
  # a roles-anywhere session's source identity or tags refused: name every action owed
  # at once (`grove_aws_trust_refused`, `grove_aws_trust_actions_owed`)
  if refused="$(grove_aws_trust_refused "$WHOAMI")"; then
    echo "  ⇒ the role TRUSTS this box, and refuses what its session carries ($refused)" >&2
    echo "    the principal that asked: ${ASKER:-<unknown — the ambient profile did not answer>}" >&2
    echo "    ⇒ an IAM Roles Anywhere session carries a source identity and session tags," >&2
    echo "      and a chained AssumeRole passes both on. the role's trust statement for" >&2
    echo "      that principal must allow all three actions — an ask of $ORG/infrastructure:" >&2
    echo "        $(grove_aws_trust_actions_owed)" >&2
    exit 1
  fi
  # 🛑 only a refusal BY THE ROLE is an ask of infra. a hop whose SOURCE does not
  #   answer (a dead signer, a lapsed session, no credentials, a timeout) fails here
  #   too — and to blame the role's trust policy for that sends the human to infra
  #   over a fault on this box
  if [[ "$WHOAMI" != *AccessDenied* ]]; then
    echo "  ⇒ the hop's SOURCE did not answer: this is no refusal by the role" >&2
    echo "    the ambient identity it chains from: ${ASKER:-<it did not answer either>}" >&2
    echo "    ⇒ a stopped signer, a lapsed session, or absent credentials reads exactly so" >&2
    echo "    fix: rhx grove.provision --what 5.6.aws --mode plan" >&2
    exit 1
  fi
  echo "  ⇒ AccessDenied on sts:AssumeRole means the ROLE exists and this box" >&2
  echo "    is not in its trust policy — an ask of $ORG/infrastructure, not a box defect" >&2
  echo "    the principal that asked: ${ASKER:-<unknown — the ambient profile did not answer>}" >&2
  echo "    ⇒ the role's trust policy must name that principal" >&2
  echo "  ⇒ a role arn that does not exist refuses the same way. confirm the" >&2
  echo "    name first:" >&2
  echo "      rhx git.repo.get lines --in $ORG/infrastructure --words 'ROLE_NAME'" >&2
  exit 1
fi

SEEN_ACCT="$(printf '%s' "$WHOAMI" | jq -r '.Account')"
SEEN_ARN="$(printf '%s' "$WHOAMI" | jq -r '.Arn')"

if [[ "$ENV" != "camp" && "$SEEN_ACCT" != "$ACCOUNT" ]]; then
  echo "      └─ ✋ ConstraintError: the profile answers as the WRONG account" >&2
  echo "" >&2
  echo "  expected: $ACCOUNT" >&2
  echo "  detected: $SEEN_ACCT  ($SEEN_ARN)" >&2
  echo "  ⇒ this is the silent failure --account exists to prevent: a valid" >&2
  echo "    identity in somewhere else. re-check the account for env=$ENV" >&2
  exit 2
fi

echo "      └─ ✔ answers, in account $SEEN_ACCT"
echo ""
echo "🌊 cowabunga! '$ORG' env=$ENV is reachable from this box"
echo "   ├─ name:   ${ORG}.${ENV}.AWS_PROFILE  =  $PROFILE"
echo "   ├─ body:   [profile $PROFILE] in ~/.aws/config"
echo "   ├─ whoami: $SEEN_ARN"
echo "   └─ next:   run the suite the same way a laptop does —"
echo "      rhx git.repo.test --what integration"
