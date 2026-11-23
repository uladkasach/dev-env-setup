#!/usr/bin/env bash
######################################################################
# .what = take ONE org+env's reach off this box — both halves, the inverse of
#         `aws.reach.set`
#
# .why
#   - a family that can SET and cannot DEL converges in one direction only, so
#     a box's profiles become a function of every row this repo ever declared
#     rather than of the rows it declares now
#   - ⇒ that broke `rule.require.one-command-provision`'s determinism clause:
#     two boxes with identical trees held different reach, by history
#   - 📜 measured 2026-09-18 on grove-ahbode-v20260901: an `ehmpathy:demo` row
#     was wired, wrote its profile body, died at keyrack's env enum, and was
#     rewired to `ehmpathy:test` + `ehmpathy:prep`. the row left the table and
#     `[profile ehmpathy.demo.ehmpath]` stayed — live, and it named a real role
#     in a real account, under a profile no declaration owned
#
# 🛑 a reap is NOT a repair play, and this skill is never the fix a human runs
#   - `5.13.reach` drives it for each fence its row table no longer declares,
#     so the box converges to the DECLARATION by the one command
#   - ⇒ a human who finds a stale profile re-applies that bundle
#     (`rule.forbid.repair-plays`, `rule.require.install-via-procedures`)
#
# ⚠️ `--env` is DELIBERATELY not clamped to keyrack's enum, and `aws.reach.set`'s
#    is. a fence can exist under an env keyrack refuses — that is exactly how
#    the measured orphan above was made — so a reaper bound by that enum could
#    never remove the one class of fence most likely to be stale. the RACK half
#    still obeys the enum, and says so rather than attempt a refused call.
#
# usage:
#   rhx aws.reach.del --org ehmpathy --env demo                 # plan
#   rhx aws.reach.del --org ehmpathy --env demo --mode apply
#   rhx aws.reach.del help
#
# options:
#   --org       the org whose reach to remove            (required)
#   --env       the env whose reach to remove            (required)
#   --owner     rack owner + profile-name tail           (default: ehmpath)
#   --gitroot   the git root the keyrack del runs from   (default: cwd if a repo,
#               else 5.12.rack's scratch root)
#   --mode      plan (default) or apply
#
# guarantee:
#   - idempotent: a reach already absent is a ✔, never a failure
#   - READ-ONLY in plan mode; it names both halves apply would remove
#   - every line outside the profile's own fence is copied through byte for byte
#   - exit 0 = this box no longer carries that reach
#   - exit 1 = malfunction (the config or the rack refused)
#   - exit 2 = constraint (bad args)
######################################################################
set -uo pipefail

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "aws.reach.del — take one org+env's reach off this box, both halves"
  echo ""
  echo "usage:"
  echo "  rhx aws.reach.del --org <org> --env <env> [--mode apply]"
  echo ""
  echo "options:"
  echo "  --org       the org whose reach to remove            (required)"
  echo "  --env       the env whose reach to remove            (required)"
  echo "  --owner     rack owner + profile-name tail           (default: ehmpath)"
  echo "  --gitroot   git root for the keyrack del  (default: cwd if a repo, else the rack's)"
  echo "  --mode      plan (default) or apply"
  echo ""
  echo "it removes BOTH halves of the pointer:"
  echo "  1. [profile <org>.<env>.<owner>]  from ~/.aws/config  (the body)"
  echo "  2. <org>.<env>.AWS_PROFILE        from the rack       (the name)"
  echo ""
  echo "🛑 a stale profile is a DECLARATION drift — reap it by the one command:"
  echo "  rhx grove.provision --what 5.13.reach --mode apply"
  exit 0
fi

# shellcheck source=./aws.reach.operations.sh
source "$(dirname "${BASH_SOURCE[0]}")/aws.reach.operations.sh"
aws_reach_runtime_load || exit 2

ORG=""
ENV=""
OWNER="ehmpath"
MODE="plan"
GITROOT_GIVEN=""

while [[ $# -gt 0 ]]; do
  # a value flag with no value refuses: `shift 2` past the last arg shifts naught,
  # so the loop would read the same flag forever
  [[ "$1" =~ ^--(gitroot|org|env|owner|mode|skill|repo|role)$ && $# -lt 2 ]] && {
    echo "✋ ConstraintError: $1 needs a value" >&2; echo "   see: rhx aws.reach.del help" >&2; exit 2; }
  case "$1" in
    --gitroot) GITROOT_GIVEN="$2"; shift 2 ;;
    --org)   ORG="$2";   shift 2 ;;
    --env)   ENV="$2";   shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --mode)  MODE="$2";  shift 2 ;;
    # ⚠️ rhachet injects these three into every skill it runs — see the block
    #   on `--role` in `aws.reach.set`, which this family learned the hard way
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "✋ ConstraintError: unknown argument '$1'" >&2; echo "   see: rhx aws.reach.del help" >&2; exit 2 ;;
  esac
done

# a given rack root must be a repo, refused before any step reads or writes on its behalf
[[ -z "$GITROOT_GIVEN" ]] || git -C "$GITROOT_GIVEN" rev-parse --git-dir >/dev/null 2>&1 || {
  echo "✋ ConstraintError: --gitroot '$GITROOT_GIVEN' is not a git repo" >&2
  echo "   fix: rhx grove.provision --what 5.12.rack --mode apply   (it owns the rack root)" >&2
  exit 2
}
[[ -n "$ORG" ]] || { echo "✋ ConstraintError: --org is required (e.g. --org ehmpathy)" >&2; exit 2; }
[[ -n "$ENV" ]] || { echo "✋ ConstraintError: --env is required (e.g. --env demo)" >&2; exit 2; }
[[ "$MODE" == "plan" || "$MODE" == "apply" ]] \
  || { echo "✋ ConstraintError: invalid --mode '$MODE' (plan|apply)" >&2; exit 2; }

####################################################################
# 🛑 the three values below compose a profile NAME that is handed to `awk -v`
#   and used as a fence literal. a newline in any of them splits that literal,
#   so the fence this reaps would differ from the fence it names
#   - the grammar is the same one `aws.reach.set` clamps on the way IN, which
#     is why a value outside it cannot name a fence that exists
####################################################################
reach_clamp() {
  local flag="$1" value="$2"
  if [[ "$value" == *[!A-Za-z0-9._-]* ]]; then
    echo "✋ ConstraintError: $flag holds a byte outside its grammar" >&2
    echo "   given:   '$value'" >&2
    echo "   allowed: [A-Za-z0-9._-]" >&2
    echo "   ⇒ these compose a profile NAME, and a name that can hold a newline" >&2
    echo "     can name a fence other than the one it appears to" >&2
    exit 2
  fi
}
reach_clamp --org "$ORG"
reach_clamp --env "$ENV"
reach_clamp --owner "$OWNER"

PROFILE="$(aws_reach_profile "$ORG" "$ENV" "$OWNER")"
CFG="$(aws_reach_config)"

echo "🐢 heres the wave..."
echo ""
echo "🔭 aws.reach.del --org $ORG --env $ENV --mode $MODE"
echo "   ├─ profile: $PROFILE"

####################################################################
# 1. which halves does this box actually hold?
#
# ⚠️ both are READ before either is written, so plan and apply report the same
#   two facts and a plan is a truthful preview of the apply
####################################################################
HAS_BODY=0
while IFS= read -r seen; do
  [[ "$seen" == "$PROFILE" ]] && HAS_BODY=1
done < <(aws_reach_fence_list)

####################################################################
# 🛑 the RACK half obeys keyrack's enum; the CONFIG half does not
#   - `KEYRACK_VALID_ENVS` is a hardcoded list in rhachet, so an env outside it
#     could never have been written to the rack — there is no entry to remove,
#     and a `keyrack del` would refuse with a message about the caller's flags
#   - ⇒ this MIRRORS that list rather than extends it, exactly as
#     `aws.reach.set` does, and for the same reason
####################################################################
RACK_REACHABLE=0
case "$ENV" in
  sudo|prod|prep|test|all|camp) RACK_REACHABLE=1 ;;
esac

if [[ "$HAS_BODY" -eq 0 ]]; then
  echo "   ├─ ~/.aws/config holds no fence for this profile"
else
  echo "   ├─ ~/.aws/config holds its fenced [profile] body"
fi

if [[ "$RACK_REACHABLE" -eq 0 ]]; then
  echo "   ├─ the rack cannot hold '$ENV' — keyrack's env enum has no such value,"
  echo "   │  so no rack half was ever written and none is removed"
fi

if [[ "$HAS_BODY" -eq 0 && "$RACK_REACHABLE" -eq 0 ]]; then
  echo "   └─ this box carries no such reach ✔ (already converged)"
  exit 0
fi

####################################################################
# 2. plan
####################################################################
if [[ "$MODE" == "plan" ]]; then
  echo "   └─ plan — apply would remove:"
  [[ "$HAS_BODY" -eq 1 ]] \
    && echo "      1. the fenced [profile $PROFILE] block in ~/.aws/config" \
    || echo "      1. (no config half to remove)"
  [[ "$RACK_REACHABLE" -eq 1 ]] \
    && echo "      2. ${ORG}.${ENV}.AWS_PROFILE from this seat's rack" \
    || echo "      2. (no rack half is possible for env '$ENV')"
  echo ""
  echo "      re-run with --mode apply."
  exit 0
fi

echo "   └─ apply"

####################################################################
# 3. apply — half one: the profile body
####################################################################
#
# 🛑 [default] is never this skill's — the swap re-reads it at the last moment,
#   so a rewrite by infra's identity skill mid-run is never put back
#   (`src/grove.aws.sh`)
if [[ "$HAS_BODY" -eq 1 ]]; then
  DEFAULT_BEFORE="$(grove_aws_config_section cfg="$CFG" name=default)"
  TMP="$(grove_aws_config_tmp)" || { echo "      └─ 💥 MalfunctionError: no tmp file beside $CFG" >&2; exit 1; }
  aws_reach_fence_drop "$PROFILE" > "$TMP"

  # ⚠️ a reap that empties the file removed more than one fence — the drop
  #   copies every other line through, so an empty result means the awk saw a
  #   fence it should not have. refuse rather than truncate a live config
  if [[ ! -s "$TMP" && -s "$CFG" ]]; then
    rm -f "$TMP"
    echo "      └─ 💥 the reap would empty ~/.aws/config — refused" >&2
    echo "         ⇒ every line outside one fence must copy through, so an" >&2
    echo "           empty result is a defect in the fence grammar, never a" >&2
    echo "           config that held only this profile" >&2
    exit 1
  fi

  grove_aws_config_swap cfg="$CFG" new="$TMP" default_before="$DEFAULT_BEFORE" default=keep; SWAP_RC=$?
  if (( SWAP_RC != 0 )); then
    echo "      └─ 💥 MalfunctionError: ~/.aws/config was NOT written: $(grove_aws_config_swap_why "$SWAP_RC")" >&2
    grove_aws_config_swap_said "         " >&2
    exit 1
  fi
  echo "      ├─ ~/.aws/config no longer declares [profile $PROFILE] ✔"
else
  echo "      ├─ ~/.aws/config already declares no [profile $PROFILE]"
fi

####################################################################
# 4. apply — half two: the rack entry
#
# ⚠️ `keyrack del` is one of the subcommands that calls `getGitRepoRoot` HARD
#   (measured in `aws.reach.set`'s own gitroot block), so it needs a root the
#   same way a `set` does — and on a grove the cwd is often not a repo at all
####################################################################
if [[ "$RACK_REACHABLE" -eq 1 ]]; then
  if ! command -v rhx >/dev/null 2>&1; then
    echo "      └─ ✋ ConstraintError: rhx is absent, so the rack half cannot be removed" >&2
    echo "         ⇒ the config half is gone and the rack may still NAME this" >&2
    echo "           profile — a name with no body, which is the half-applied" >&2
    echo "           pair inverted" >&2
    echo "         fix: rhx grove.provision --what 5.3.brains --mode apply" >&2
    exit 1
  fi

  # 🛑 a GIVEN root wins, as in `aws.reach.set`: the cwd's keyrack.yml allows its
  #   own repo's org only, so a cross-org del run from a real checkout refuses
  GITROOT="$PWD"
  # a given root is a repo, by the check right after the parse
  [[ -n "$GITROOT_GIVEN" ]] && GITROOT="$GITROOT_GIVEN"
  if [[ -z "$GITROOT_GIVEN" ]] && ! git -C "$PWD" rev-parse --git-dir >/dev/null 2>&1; then
    GITROOT="$HOME/.local/state/keyrack.gitroot"
    if [[ ! -d "$GITROOT/.git" ]]; then
      echo "      └─ 💥 MalfunctionError: the cwd is not a git repo, and the box has no rack root" >&2
      echo "         fix: rhx grove.provision --what 5.12.rack --mode apply" >&2
      exit 1
    fi
  fi

  # ⚠️ an ABSENT entry and a REFUSED del are told apart by a re-read, never by
  #   the del's own exit code — `keyrack del` on a key this host does not carry
  #   is a no-op in some versions and a refusal in others, and this skill must
  #   be idempotent across both (`rule.require.idempotent-install-procedures`)
  env -C "$GITROOT" rhx keyrack del --owner "$OWNER" --key AWS_PROFILE \
    --org "$ORG" --env "$ENV" >/dev/null 2>&1 || true

  RACK_SEEN="$(env -C "$GITROOT" rhx keyrack get --owner "$OWNER" --org "$ORG" \
    --env "$ENV" --key AWS_PROFILE --value --unlock 2>/dev/null | tail -1)"

  ##################################################################
  # 🛑 an `os.envvar` shadow answers for EVERY org and env, so a non-empty
  #   read here is not proof the entry survived
  #   - rhachet: "os.envvar is always checked first in grant flow"
  #   - `2.5.zsh` exports `AWS_PROFILE=ambient` on every grove, so a seat with
  #     no entry at all still answers `ambient`
  #   - ⇒ only an answer equal to THIS PROFILE proves the entry is still there
  ##################################################################
  if [[ "$RACK_SEEN" == "$PROFILE" ]]; then
    echo "      └─ ✋ ConstraintError: the rack still names ${ORG}.${ENV}.AWS_PROFILE = $PROFILE" >&2
    echo "         ⇒ the body is gone, so that name now points at no profile" >&2
    echo "         read the refusal in full:" >&2
    echo "           env -C $GITROOT rhx keyrack del --owner $OWNER \\" >&2
    echo "             --key AWS_PROFILE --org $ORG --env $ENV" >&2
    exit 1
  fi

  [[ -n "$RACK_SEEN" ]] \
    && echo "      ├─ the rack no longer names this profile (it answers '$RACK_SEEN' — a shadow or a peer entry)" \
    || echo "      ├─ the rack no longer names ${ORG}.${ENV}.AWS_PROFILE ✔"
fi

echo "      └─ this box no longer carries ${ORG}.${ENV} reach ✔"
exit 0
