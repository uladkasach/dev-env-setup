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
  local owner
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

  local gitroot
  gitroot="$(grove_provision_5_12_rack_gitroot)"

  # 1. one row at a time. ⚠️ the role AND the org are read INSIDE the loop — the
  #    rows share neither, so a hoisted read writes one value into every profile
  local failed=0 pair rest org env reader akey rkey role account
  for pair in $(grove_provision_5_13_reach_envs); do
    org="${pair%%:*}"
    rest="${pair#*:}"
    env="${rest%%:*}"
    rest="${rest#*:}"
    reader="${rest%%:*}"
    rest="${rest#*:}"
    akey="${rest%%:*}"
    rkey="${rest##*:}"

    # ⚠️ halt a short row here: `${rest##*:}` would hand back some EARLIER
    #    field, whose empty role read looks like "infrastructure is not cloned"
    if [[ "$pair" != *:*:*:*:* ]]; then
      echo "   ✋ the row '${pair}' is malformed" >&2
      echo "      ⇒ a row is '<org>:<env>:<reader>:<accountKey>:<roleKey>' — see 5.13.reach/_.sh" >&2
      failed=1
      continue
    fi

    ##################################################################
    # 🛑 declare THIS ROW's org before its `aws.reach.set` runs
    #   - that skill's own `keyrack set` resolves a NAMED org against the
    #     `keyrack.yml` in scope, and the scratch root is `5.12.rack`'s
    #   - `5.12.rack` runs FIRST and its loop leaves the LAST org it wired
    #     declared there, so this phase must never inherit that leftover
    #   - 📜 measured: with `ehmpathy` left declared, all three rows died on
    #     `org "ahbode" does not match keyrack.yml org "ehmpathy"`, AFTER each
    #     had already written its `~/.aws/config` body — a half-applied pair
    #   - ⇒ one fact, two consumers: `5.12.rack` OWNS the scratch declaration,
    #     and every borrower re-states the org it needs
    #   - (`rule.forbid.two-writers-on-one-artifact`,
    #      `gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
    #
    # 🛑 .why PER ROW and no longer once, above the loop
    #   - the rows no longer share an org, so one declaration ahead of them
    #     leaves every row but the first resolved against the wrong yml
    #   - that file declares ONE org by contract (`5.12.rack`'s own comment),
    #     so the rewrite per row is its intended use, never a workaround
    ##################################################################
    grove_provision_5_12_rack_declare_org "$gitroot" "$org" || { failed=1; continue; }

    ##################################################################
    # the ROLE — read from infrastructure's own declaration, never recalled
    #
    # 🛑 the decline names the row's OWN reader's file, never one fixed path
    #   - a row that reads `resources.reach-arns.ts` and declines with the
    #     `GROVE_ROLE_NAME` sentence sends a human to repair a file whose
    #     contract FORBIDS that key — a fix nobody can perform, forever
    #   - ⇒ `_declsrc` holds that sentence once, for both halves (m.9)
    ##################################################################
    local declsrc; declsrc="$(grove_provision_5_13_reach_declsrc "$reader")" || declsrc="(unknown reader '${reader}')"

    role="$(grove_provision_5_13_reach_role "$reader" "$rkey")"

    if [[ -z "$role" ]]; then
      echo "   • ${org}.${env} declined — the role key '${rkey}' is not readable here"
      echo "     ⇒ it is DECLARED in ahbode/infrastructure, by the '${reader}' reader:"
      echo "       ${declsrc}"
      ################################################################
      # 🛑 name BOTH repairs — this reader cannot tell them apart
      #   - an ABSENT clone and a clone PRESENT AND BEHIND read identically:
      #     the key is unreadable here. the repairs are opposite
      #   - ⇒ a decline that names only the clone-absent fix sends a human to
      #     re-run `5.10.repos` on a box whose clone is already there. it
      #     changes naught, and the decline repeats on every apply forever
      #   - 📜 measured 2026-09-14 on grove-ahbode-v20260901: infra WAS cloned,
      #     and the demo pair sits on a branch that has not merged
      #   - (`rule.require.one-command-provision`, its unrepairable-fix-text
      #      clause; `gotcha.a-check-that-cries-wolf-gets-silenced`)
      ################################################################
      echo "     fix — whichever holds. the two read the SAME way from here:"
      echo "       • the clone is absent:  rhx grove.provision --what 5.10.repos --mode apply"
      echo "       • the clone is behind:  the declaration has not merged to that"
      echo "         repo's main yet, so no command on THIS box can close it"
      echo "     🛑 it is NOT guessed. a role name that does not exist refuses with"
      echo "        the same AccessDenied as a role that excludes this box, so a"
      echo "        guess turns a readable gap into a false 'no access' report"
      continue
    fi
    echo "   • ${env} role (read from infrastructure's declaration): $role"

    # ⚠️ the account is read and PASSED, never printed, since it is dox
    #   - (`rule.forbid.dox-in-public-repo`)
    account="$(grove_provision_5_13_reach_account "$reader" "$akey")"
    if [[ -z "$account" ]]; then
      echo "   • ${org}.${env} declined — the account key '${akey}' is not readable here"
      echo "     ⇒ it is DECLARED in ahbode/infrastructure, by the '${reader}' reader:"
      echo "       ${declsrc}"
      echo "     ⇒ those are clones, so this declines until 5.10.repos has run"
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
