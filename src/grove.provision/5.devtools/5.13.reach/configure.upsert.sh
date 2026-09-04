#!/usr/bin/env bash
######################################################################
# .what = wire this seat's reach into each declared env, by DRIVE of the skill
#         that already does it correctly
#
# .it drives `rhx aws.reach.set` rather than reimplement it
#   - that skill writes BOTH halves and proves the pair with a live sts call
#   - ⇒ an inlined body would fork one logic into two disagreeable places
#   - the BUNDLE adds only the two inputs the skill cannot derive
#   - (`rule.require.bundle-as-sole-declaration`, one level down)
#
# .it is CONFIGURE, never PROVISION
#   - it touches `~/.aws/config` and this seat's keyrack manifest, both in `$HOME`
#   - ⇒ each seat drives its own, as `5.12.rack` and `5.8.docker` do
#
# guarantee:
#   - the skill re-reads the rack and re-proves the hop each run
#   - an already-correct pair costs one sts call and writes no new state
#   - it DECLINES wherever an input cannot be read, and guesses none
######################################################################

grove_provision_5_13_reach_configure_upsert() {
  local org owner
  org="$(grove_provision_5_13_reach_org)"
  owner="$(grove_provision_5_13_reach_owner)"

  ####################################################################
  # 0. is there an ambient identity to chain OFF of?
  #
  # ⚠️ every profile this writes sets `credential_source = Ec2InstanceMetadata`
  #   - ⇒ the box's own badge does the assume, and a laptop has no badge
  #   - `5.12.rack` and `5.6.aws.configure.upsert` decline on this same fact
  #   - ⇒ all three must agree, or one names a profile that cannot answer
  ####################################################################
  if ! aws configure export-credentials --profile ambient >/dev/null 2>&1; then
    echo "   • declined — no ambient identity here, so no badge to assume from"
    echo "     ⇒ on a laptop this is correct: its route to the same profile name"
    echo "       is an sso login, which is a human's to perform"
    return 0
  fi

  if ! command -v rhx >/dev/null 2>&1; then
    echo "   • declined — rhx is absent, so the reach skill cannot run (5.3.brains)"
    return 0
  fi

  ####################################################################
  # 1. the ROLE — read from infrastructure's own declaration, never recalled
  ####################################################################
  local role
  role="$(grove_provision_5_13_reach_role)"

  if [[ -z "$role" ]]; then
    echo "   • declined — the grove role name is not readable on this box"
    echo "     ⇒ it is DECLARED in ahbode/infrastructure:"
    echo "       provision/aws.auth/resources.role-names.ts → GROVE_ROLE_NAME"
    echo "     ⇒ that repo is a clone, so this declines until 5.10.repos has run:"
    echo "       rhx grove.provision --what 5.10.repos --mode apply"
    echo "     🛑 it is NOT guessed. a role name that does not exist refuses with"
    echo "        the same AccessDenied as a role that excludes this box, so a"
    echo "        guess turns a readable gap into a false 'no access' report"
    return 0
  fi
  echo "   • role (read from infrastructure's declaration): $role"

  ####################################################################
  # 2. one env at a time
  ####################################################################
  local failed=0 pair env dkey account
  for pair in $(grove_provision_5_13_reach_envs); do
    env="${pair%%:*}"
    dkey="${pair##*:}"

    # ⚠️ the account is read and PASSED, never printed, since it is dox
    #   - (`rule.forbid.dox-in-public-repo`)
    account="$(grove_provision_5_13_reach_account "$dkey")"
    if [[ -z "$account" ]]; then
      echo "   • ${org}.${env} declined — no declapract.use.yml declares awsAccountId.${dkey}"
      echo "     ⇒ every repo of one org declares the same accounts, so any clone"
      echo "       answers. until 5.10.repos has run, none is present"
      continue
    fi

    ##################################################################
    # ⚠️ CAPTURED and replayed on failure, never muted
    #   - the skill's output IS the diagnosis: a profile, an arn, an account
    #   - ⇒ a muted run says "did not complete" and drops its own reason
    #   - (`rule.forbid.failhide`)
    #
    # ⚠️ run it from the CHECKOUT ROOT, never from the inherited cwd
    #   - rhachet links a `repo=.this` role relative to the GIT ROOT it runs from
    #   - a phase inherits its caller's cwd, and a grove apply starts at `$HOME`
    #   - 📜 2026-08-12, one box, one minute apart:
    #
    #       cwd = $HOME               ✋ no skill "aws.reach.set" found in any
    #                                   linked role
    #       cwd = the checkout root   ✔ the skill itself answered
    ##################################################################
    local checkout; checkout="$(dirname "$GROVE_SRC")"

    ##################################################################
    # 🛑 `--assume`, NEVER `--role`, and the wrong one is DROPPED in silence
    #   - 📜 2026-09-01, on a grove built from scratch, `--role "$role"` gave:
    #
    #       ✋ could not give this seat reach into ahbode.test
    #            └─ ✋ --assume is required for --env test
    #
    #   - the flag is `--assume` because RHACHET injects `--role <slug>` itself
    #   - ⚠️ the skill cannot tell an injected `--role` from a caller's iam role
    #   - ⇒ the silence is CORRECT at the callee, and each caller owes the sweep
    #   - ⇒ one fact, the flag's name, sits in two files and is free to drift
    #   - (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
    #
    # 🛑 only a FROM-SCRATCH box could show it
    #   - a converged grove already holds an `~/.aws/config` that answers
    #   - ⇒ this phase re-proves the pair and reports ✔ whatever flag it passed
    #   - (`rule.require.one-command-provision`)
    ##################################################################
    local reachlog rc
    reachlog="$(env -C "$checkout" rhx aws.reach.set \
                  --org "$org" --env "$env" --owner "$owner" \
                  --assume "$role" --account "$account" --mode apply 2>&1)"
    rc=$?

    if [[ $rc -ne 0 ]]; then
      ################################################################
      # ⚠️ the CAUSE is read from the log, never assumed
      #   - 📜 2026-08-12: an unconditional AccessDenied claim printed directly
      #     above `no skill "aws.reach.set" found in any linked role`
      #   - ⇒ no AssumeRole was attempted, so there was no AccessDenied to read
      #   - ⇒ a reader who trusts that verdict files infra an ask for a box gap
      #   - (`gotcha.a-check-that-cries-wolf-gets-silenced`)
      ################################################################
      echo "   ✋ could not give this seat reach into ${org}.${env}" >&2
      echo "      ⇒ every suite that targets ${env} resources acts as the CAMP" >&2
      echo "        role instead, and is refused on each call it makes" >&2

      # ⚠️ `-q` is deliberately absent on both reads below
      #   - under `set -uo pipefail` a matched `grep -q` SIGPIPEs `printf` → 141
      #   - ⇒ the `if` takes its ELSE branch on a MATCH
      #   - ⇒ the most precise cause this block can name is the one it skips
      #   - (`gotcha.pipefail-grep-q`, its size-dependence case)
      if printf '%s\n' "$reachlog" | grep 'found in any linked role' >/dev/null; then
        echo "      ⇒ the SKILL never ran, so this box's reach is UNTESTED — this" >&2
        echo "        is not an infra gap. rhachet linked no role that declares" >&2
        echo "        it, which means the checkout carries no .agent/, or the" >&2
        echo "        call was made outside the checkout root" >&2
        echo "      read which: rhx git.grove.send <grove> --bare \\" >&2
        echo "        --why 'a verify needs the remote verdict' \\" >&2
        echo "        --play diagnose.grove-reaches-this-repos-skills" >&2
      elif printf '%s\n' "$reachlog" | grep -i 'AccessDenied' >/dev/null; then
        echo "      ⇒ an AccessDenied on sts:AssumeRole means the role exists and" >&2
        echo "        this box is outside its trust policy — an infra ask, not a" >&2
        echo "        box defect (handoff.infra.grove-account-reach.md)" >&2
      else
        echo "      ⇒ the skill ran and refused for a reason that is neither an" >&2
        echo "        absent linkage nor an AccessDenied — read its own words" >&2
      fi

      echo "      ⇒ what it said:" >&2
      printf '%s\n' "$reachlog" | sed 's/^/        /' >&2
      failed=1
      continue
    fi

    echo "   • ${org}.${env} reaches its account, proven with a live sts call ✔"
  done

  return $failed
}
