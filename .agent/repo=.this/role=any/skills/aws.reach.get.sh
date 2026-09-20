#!/usr/bin/env bash
######################################################################
# .what = report the reach this box actually carries — one row per profile
#         `aws.reach.set` has written, and whether each still answers
#
# .why
#   - the family could SET a reach and never ASK for one. so the question a
#     human and a bundle both have — "can this box reach <org>.<env>?" — had
#     no verb, and was answered by an ad-hoc `aws sts assume-role` over a duct
#     (`rule.forbid.adhoc-shell`: an absent skill is the defect to fix)
#   - 🛑 and a set nobody can READ is a set nobody can CONVERGE. `5.13.reach`
#     drives this to find the fences its row table no longer declares, which
#     is the only way a row that LEAVES that table can reach the box
#
# 🛑 no account id is ever printed
#   - this repo is public, and a duct keeps scrollback
#   - ⇒ a row names the profile and the ROLE, and reports the account only as
#     an agreement with what was asked for (`rule.forbid.dox-in-public-repo`)
#
# 🛑 `--names` is NOT pipe-safe through `rhx`, and the transport is the cause
#   - rhachet writes a banner to STDOUT ahead of every skill. measured 2026-09-18:
#
#       $ rhx aws.reach.get --names | cat -A
#       $
#       🪨 run solid skill repo=.this/role=any/skill=aws.reach.get$
#       $
#
#   - ⇒ a caller that diffs those lines against a declared set reads the banner
#     as a profile name, finds it undeclared, and acts on it
#   - ⇒ so a caller either FILTERS to the profile grammar ([A-Za-z0-9._-], which
#     the banner's space and slash both fail), or skips the transport and sources
#     `aws.reach.operations.sh` for `aws_reach_fence_list` directly
#   - `5.13.reach` takes the second road, and its `_carried` carries the reason
#   - (`project_rhx-not-pipe-safe`)
#
# ⚠️ it reports the CONFIG half, and names the rack half it cannot see
#   - a reach is a pair: the body here, the name on the rack. this verb reads
#     one file and makes one sts call per row, so it is cheap and needs no
#     keyrack unlock — and it says so rather than imply it read both
#   - ⇒ `5.13.reach.configure.verify` is what proves the PAIR, per declared row
#
# usage:
#   rhx aws.reach.get                      # every reach, with a live probe
#   rhx aws.reach.get --names              # just the profile names, one per line
#   rhx aws.reach.get --org ehmpathy       # only that org's rows
#   rhx aws.reach.get --probe skip         # read the file, make no sts call
#   rhx aws.reach.get help
#
# options:
#   --names     print profile names only, one per line   (for a caller to diff)
#   --org       report only rows whose profile is that org's
#   --owner     the profile-name tail to match           (default: ehmpath)
#   --probe     live | skip — make an sts call per row   (default: live)
#
# guarantee:
#   - READ-ONLY, always. it writes no file and changes no state
#   - exit 0 = the read completed, whatever it found — an empty box is a fact,
#     never a failure (a caller that diffs a set needs the empty set too)
#   - exit 1 = malfunction (the config could not be read)
#   - exit 2 = constraint (bad args)
######################################################################
set -uo pipefail

if [[ " $* " == *" help "* || " $* " == *" --help "* || " $* " == *" -h "* ]]; then
  echo "aws.reach.get — report the reach this box carries, one row per profile"
  echo ""
  echo "usage:"
  echo "  rhx aws.reach.get [--names] [--org <org>] [--probe live|skip]"
  echo ""
  echo "options:"
  echo "  --names     profile names only, one per line   (for a caller to diff)"
  echo "  --org       report only that org's rows"
  echo "  --owner     the profile-name tail to match     (default: ehmpath)"
  echo "  --probe     live | skip — one sts call per row (default: live)"
  echo ""
  echo "it reads the CONFIG half — the [profile] bodies aws.reach.set wrote."
  echo "the rack half (the NAME) is proven per declared row by:"
  echo "  rhx grove.provision --what 5.13.reach --mode plan"
  echo ""
  echo "examples:"
  echo "  rhx aws.reach.get"
  echo "  rhx aws.reach.get --names"
  echo "  rhx aws.reach.get --org ehmpathy --probe skip"
  exit 0
fi

# shellcheck source=./aws.reach.operations.sh
source "$(dirname "${BASH_SOURCE[0]}")/aws.reach.operations.sh"

NAMES=0
ORG=""
OWNER="ehmpath"
PROBE="live"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --names) NAMES=1; shift ;;
    --org)   ORG="$2";   shift 2 ;;
    --owner) OWNER="$2"; shift 2 ;;
    --probe) PROBE="$2"; shift 2 ;;
    # ⚠️ rhachet injects these three into every skill it runs, so each is
    #   dropped here — see `aws.reach.set`'s own block on `--role`
    --skill|--repo|--role) shift 2 ;;
    --) shift ;;
    *) echo "✋ unknown argument '$1'" >&2; echo "   see: rhx aws.reach.get help" >&2; exit 2 ;;
  esac
done

[[ "$PROBE" == "live" || "$PROBE" == "skip" ]] \
  || { echo "✋ invalid --probe '$PROBE' (live|skip)" >&2; exit 2; }

CFG="$(aws_reach_config)"

####################################################################
# --names — the machine face. one name per line, and no banner
#
# 🛑 a caller DIFFS this against a declared set, so every byte on stdout is
#    read as a name. the human face below writes its rows here too, which is
#    why the two faces exit on separate paths rather than share a printer
####################################################################
if [[ "$NAMES" -eq 1 ]]; then
  while IFS= read -r profile; do
    [[ -n "$profile" ]] || continue
    [[ -z "$ORG" || "$profile" == "$ORG".* ]] || continue
    printf '%s\n' "$profile"
  done < <(aws_reach_fence_list)
  exit 0
fi

echo "🐢 heres the wave..."
echo ""
echo "🔭 aws.reach.get --probe $PROBE"

if [[ ! -f "$CFG" ]]; then
  echo "   └─ this box holds no ~/.aws/config, so it carries no reach"
  exit 0
fi

FOUND=0
while IFS= read -r profile; do
  [[ -n "$profile" ]] || continue
  [[ -z "$ORG" || "$profile" == "$ORG".* ]] || continue
  FOUND=$(( FOUND + 1 ))

  # ⚠️ the ROLE is named and the ACCOUNT is not — the arn carries both, so it
  #   is split rather than printed (`rule.forbid.dox-in-public-repo`)
  role="$(aws configure get role_arn --profile "$profile" 2>/dev/null)"
  role="${role##*/}"
  [[ -n "$role" ]] || role="the box's own badge (no hop)"

  echo "   ├─ $profile"
  echo "   │  ├─ assumes: $role"

  if [[ "$PROBE" == "skip" ]]; then
    echo "   │  └─ answers: unasked (--probe skip)"
    continue
  fi

  ##################################################################
  # ⚠️ the probe is BOUNDED — an sts call on a box whose badge is gone can
  #   hang on a metadata retry, and this verb is driven by a bundle
  #   (`rule.require.bounded-probes-in-verifies`)
  ##################################################################
  if timeout 20 aws sts get-caller-identity --profile "$profile" \
       --query Account --output text >/dev/null 2>&1; then
    echo "   │  └─ answers: ✔"
  else
    echo "   │  └─ answers: ✋ — the body is written and the hop was refused"
  fi
done < <(aws_reach_fence_list)

if [[ "$FOUND" -eq 0 ]]; then
  echo "   └─ this box carries no reach${ORG:+ for '$ORG'}"
  exit 0
fi

echo "   └─ $FOUND reach profile(s)"
echo ""
echo "   ⚠️ this is the CONFIG half. the rack half — the NAME each suite reads"
echo "      — is proven per declared row by:"
echo "        rhx grove.provision --what 5.13.reach --mode plan"
exit 0
