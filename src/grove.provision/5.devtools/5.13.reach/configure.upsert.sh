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

  ####################################################################
  # 0.5 make the DECLARATION CLONE current, before any row reads it
  #
  # 🛑 a presence guard is not convergence — see `_sync` in this bundle's `_.sh`
  #   `5.10.repos` skips a clone that opens, so a declaration merged upstream
  #   reaches no box that already holds the repo. every row below reads a file
  #   in that clone, so a stale tree makes every one of them decline — with a
  #   reason that names an upstream gap that does not exist
  ####################################################################
  local srcstate; srcstate="$(grove_provision_5_13_reach_sync)"
  case "$srcstate" in
    current) echo "   • ahbode/infrastructure is current — its declarations are fresh" ;;
    absent)  echo "   🌙 ahbode/infrastructure is not cloned — every row below declines"
             echo "      fix: rhx grove.provision --what 5.10.repos --mode apply" ;;
    dirty)   echo "   🌙 ahbode/infrastructure has edits in flight — left as it stands"
             echo "      ⇒ the rows read THAT tree, which may differ from its main" ;;
    ahead)   echo "   🌙 ahbode/infrastructure has diverged from its upstream — left alone"
             echo "      ⇒ a fast-forward would drop work, so the rows read what it holds" ;;
    detached) echo "   🌙 ahbode/infrastructure is on no branch with an upstream — left alone" ;;
    *)       echo "   🌙 ahbode/infrastructure could not be fetched — the rows read what it holds"
             echo "      ⇒ a declaration merged since the last fetch is invisible here" ;;
  esac

  local gitroot
  gitroot="$(grove_provision_5_12_rack_gitroot)"

  ####################################################################
  # the cwd every `rhx` call below runs from
  #
  # ⚠️ run each from the CHECKOUT ROOT, never from the inherited cwd
  #   - rhachet links a `repo=.this` role relative to the GIT ROOT it runs from
  #   - a phase inherits its caller's cwd, and a grove apply starts at `$HOME`
  #   - 📜 2026-08-12, one box, one minute apart:
  #
  #       cwd = $HOME               ✋ no skill "aws.reach.set" found in any
  #                                   linked role
  #       cwd = the checkout root   ✔ the skill itself answered
  #
  # 🛑 hoisted ABOVE the loop, and it used to sit inside it
  #   - a `local` inside a loop is still function-scoped, so it read fine —
  #     right up until a box where EVERY row declined before reaching that
  #     line. then the reap below ran with it unset, and `set -u` killed the
  #     phase on the one box class that most needed the reap to run
  ####################################################################
  local checkout; checkout="$(dirname "$GROVE_SRC")"

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
      # 🛑 the clone's STATE is measured above, so the decline names it
      #   - an ABSENT clone and a clone PRESENT AND BEHIND read identically to
      #     THIS reader: the key is unreadable. the repairs are opposite
      #   - ⇒ phase 0.5 settles which, so the fix-text below is a fact rather
      #     than a menu a human must sort for themselves
      #   - 📜 the menu cost a real apply. its "the clone is behind" arm read
      #     "the declaration has not merged … so no command on THIS box can
      #     close it" — and on 2026-09-18 the declaration HAD merged, the clone
      #     was simply stale, and a fetch closed it. a correct verdict with the
      #     wrong reason (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4)
      ################################################################
      echo "     ⇒ that clone reads '${srcstate}' this run"
      case "$srcstate" in
        absent)  echo "     fix: rhx grove.provision --what 5.10.repos --mode apply" ;;
        current) echo "     ⇒ it is at its upstream's tip, so the key is genuinely"
                 echo "       undeclared — no command on THIS box can close it" ;;
        *)       echo "     ⇒ so the tree read was not its upstream's tip. settle it"
                 echo "       there, then re-apply this bundle" ;;
      esac
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
    # ⚠️ `$checkout` is the cwd — hoisted above this loop, and the block there
    #   carries why (a `local` inside a loop outlives it, until the run where
    #   no iteration reaches the line that sets it)
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

  ####################################################################
  # 2. reap every reach this table no longer declares
  #
  # 🛑 .why a bundle that only ADDS is not a bundle that CONVERGES
  #   - the loop above wires each declared row and touches no other fence, so
  #     a row that LEAVES the table leaves both its halves on every box that
  #     ever applied it
  #   - ⇒ reach became a function of every row this repo EVER held, so two
  #     boxes with identical trees carried different reach, by apply order
  #   - (`rule.require.one-command-provision`, its deterministic clause)
  #
  # ⚠️ it reaps by DECLARATION, never by a hand-written list of dead names
  #   - a list of what to remove goes stale the moment a row is renamed, and
  #     its staleness is silent — no run says a name was omitted
  #   - ⇒ the question asked is "what does this box carry that the table does
  #     not declare", which needs no second list and cannot rot
  #
  # ⚠️ a reap is bounded to the fences THIS FAMILY wrote
  #   - `aws.reach.get --names` lists only `# grove: reach` fences, so the
  #     `ambient` profile `5.6.aws` owns and a human's own `[profile …]` are
  #     invisible here and cannot be reaped
  #   - (`rule.forbid.two-writers-on-one-artifact`)
  ####################################################################
  local declared carried seen
  declared="$(grove_provision_5_13_reach_declared_profiles)"

  # ⚠️ a checkout with no `.agent/` cannot be read, and that is NOT "no reach"
  #   - a `git.grove.push --from src` carries `src/` and leaves the skills dir
  #     behind, so the fence grammar has no holder to source
  #   - ⇒ say the reap was SKIPPED rather than report a converged box
  #   - (`rule.forbid.failhide` — an unread subject is never a clean one)
  if ! carried="$(grove_provision_5_13_reach_carried)"; then
    echo "   🌙 the reach fences could not be listed, so none were reaped"
    echo "      ⇒ this checkout carries no .agent/, so the fence grammar has"
    echo "        no holder here — an undeclared profile would stay live"
    echo "      fix: push the whole checkout, not src/ alone"
    return $failed
  fi

  while IFS= read -r seen; do
    [[ -n "$seen" ]] || continue

    ##################################################################
    # ⚠️ a WHOLE-LINE match, in pure bash, and no `grep -q` in a pipe
    #   - an exact line, because `ehmpathy.test.ehmpath` matches part of
    #     `ehmpathy.test.ehmpath2` and a partial match would spare a fence
    #     that is genuinely undeclared
    #   - and no `grep -q`: under `set -uo pipefail` a MATCHED `grep -q`
    #     SIGPIPEs its producer, so the `if` takes its else branch on a hit
    #     (`gotcha.pipefail-grep-q`)
    ##################################################################
    case $'\n'"$declared"$'\n' in
      *$'\n'"$seen"$'\n'*) continue ;;
    esac

    echo "   • ${seen} is carried by this box and declared by no row — reaped"

    ##################################################################
    # ⚠️ the org+env are split back OUT of the profile name, since that is
    #   what `aws.reach.del` takes. the name is `<org>.<env>.<owner>` and an
    #   org may hold a dot, so each tail is cut from the RIGHT
    ##################################################################
    local dead_env dead_org
    dead_org="${seen%.*}"        # drop .<owner>
    dead_env="${dead_org##*.}"   # the env is now the tail
    dead_org="${dead_org%.*}"    # and the org is what remains

    local deadlog drc
    deadlog="$(env -C "$checkout" rhx aws.reach.del \
                 --org "$dead_org" --env "$dead_env" --owner "$owner" \
                 --mode apply 2>&1)"
    drc=$?

    if [[ $drc -ne 0 ]]; then
      echo "   ✋ could not reap the undeclared reach '${seen}'" >&2
      echo "      ⇒ it stays live on this box: a profile that names a real role" >&2
      echo "        in a real account, under a name this repo no longer declares" >&2
      echo "      ⇒ what it said:" >&2
      printf '%s\n' "$deadlog" | sed 's/^/        /' >&2
      failed=1
    fi
  done < <(printf '%s\n' "$carried")

  return $failed
}
