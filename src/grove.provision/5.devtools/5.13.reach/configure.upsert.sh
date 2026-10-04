#!/usr/bin/env bash
######################################################################
# .what = wire this seat's reach into each declared env, by DRIVE of the skill
#         that already does it correctly
# .why
#   - it drives `rhx aws.reach.set` rather than reimplement it — the skill writes
#     BOTH halves and proves the pair; the bundle adds only the two inputs
#   - CONFIGURE, never PROVISION — both halves live in `$HOME`, so each seat drives its own
#   - 🛑 it REAPS every fence no row declares, since a bundle that only adds
#     never converges
# .refs = gotcha.5-13-reach.demo=per-org-rows-and-the-reap, m11 — every block below
#
# guarantee:
#   - the skill re-reads the rack and re-proves the hop each run
#   - an already-correct pair costs one sts call and writes no new state
#   - it DECLINES wherever an input cannot be read, and guesses none
######################################################################

grove_provision_5_13_reach_configure_upsert() {
  local owner
  owner="$(grove_provision_5_13_reach_owner)"

  # 0. an ambient identity to chain OFF — every profile assumes from the box's
  #    badge, and a laptop has none. `5.12.rack` and `5.6.aws` agree on this
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

  # 0.5 make the DECLARATION CLONE current before any row reads it — a presence
  #     guard is not convergence (`_sync` in `_.sh`)
  # 🛑 the clone is NAMED from `_srcorg`, never a literal — an org with NO source
  #    is a different fact from an absent clone
  local srcorg srcname srcstate
  srcorg="$(grove_provision_5_13_reach_srcorg)"
  srcname="${srcorg:+$srcorg/$(grove_provision_5_13_reach_srcname)}"
  srcstate="$(grove_provision_5_13_reach_sync)"

  # 🛑 it REPORTS and falls through, never returns — the reap below must still run
  if [[ -z "$srcorg" ]]; then
    echo "   🌙 org '${GROVE_ORG:-<unset>}' declares no source repo, so no row is read"
    echo "      ⇒ an org with no declared table gets ZERO rows, never another"
    echo "        org's (rule.require.a-grove-reaches-its-own-org-only)"
    echo "      ⇒ this is NOT an absent clone — there is no repo to clone"
    echo "      fix: if this grove's work needs aws reach, add its arms:"
    echo "        src/grove.provision/5.devtools/5.13.reach/_.sh → _srcorg + _envs"
  else

  case "$srcstate" in
    current) echo "   • $srcname is current — its declarations are fresh" ;;
    absent)  echo "   🌙 $srcname is not cloned — every row below declines"
             echo "      fix: rhx grove.provision --what 5.10.repos --mode apply" ;;
    dirty)   echo "   🌙 $srcname has edits in flight — left as it stands"
             echo "      ⇒ the rows read THAT tree, which may differ from its main" ;;
    ahead)   echo "   🌙 $srcname has diverged from its upstream — left alone"
             echo "      ⇒ a fast-forward would drop work, so the rows read what it holds" ;;
    detached) echo "   🌙 $srcname is on no branch with an upstream — left alone" ;;
    *)       echo "   🌙 $srcname could not be fetched — the rows read what it holds"
             echo "      ⇒ a declaration merged since the last fetch is invisible here" ;;
  esac

  fi

  local gitroot
  gitroot="$(grove_provision_5_12_rack_gitroot)"

  # every `rhx` below runs from the CHECKOUT ROOT, where rhachet links this
  # repo's role. 🛑 hoisted ABOVE the loop — `set -u` killed the reap when every
  # row declined before a loop-local line could set it
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

    # 🛑 declare THIS ROW's org first — `5.12.rack` leaves its last org in the
    #    scratch yml, and a mismatch dies AFTER the config body is written
    grove_provision_5_12_rack_declare_org "$gitroot" "$org" || { failed=1; continue; }

    # the ROLE, read from infrastructure's declaration, never recalled. a decline
    # names the row's OWN reader's file (`_declsrc`) and the clone's STATE
    local declsrc; declsrc="$(grove_provision_5_13_reach_declsrc "$reader")" || declsrc="(unknown reader '${reader}')"

    role="$(grove_provision_5_13_reach_role "$reader" "$rkey")"

    if [[ -z "$role" ]]; then
      echo "   • ${org}.${env} declined — the role key '${rkey}' is not readable here"
      echo "     ⇒ it is DECLARED in ${srcname}, by the '${reader}' reader:"
      echo "       ${declsrc}"
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
    echo "   • ${env} role (read from ${srcname}'s declaration): $role"

    # ⚠️ the account is read and PASSED, never printed (`rule.forbid.dox-in-public-repo`)
    account="$(grove_provision_5_13_reach_account "$reader" "$akey")"
    if [[ -z "$account" ]]; then
      echo "   • ${org}.${env} declined — the account key '${akey}' is not readable here"
      echo "     ⇒ it is DECLARED in ${srcname}, by the '${reader}' reader:"
      echo "       ${declsrc}"
      echo "     ⇒ those are clones, so this declines until 5.10.repos has run"
      continue
    fi

    # ⚠️ CAPTURED and replayed on failure — the skill's output IS the diagnosis
    # 🛑 `--assume`, NEVER `--role` — rhachet injects `--role` itself, so the
    #    skill drops a caller's in silence. only a FROM-SCRATCH box shows it
    local reachlog rc
    reachlog="$(env -C "$checkout" rhx aws.reach.set \
                  --org "$org" --env "$env" --owner "$owner" \
                  --assume "$role" --account "$account" --mode apply 2>&1)"
    rc=$?

    if [[ $rc -ne 0 ]]; then
      # ⚠️ the CAUSE is read from the log, never assumed. no `-q` on either read:
      #    a matched `grep -q` under pipefail takes the ELSE branch
      echo "   ✋ could not give this seat reach into ${org}.${env}" >&2
      echo "      ⇒ every suite that targets ${env} resources acts as the CAMP" >&2
      echo "        role instead, and is refused on each call it makes" >&2

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

  # 2. reap every reach this table no longer declares — by DECLARATION, never a
  #    hand list of dead names, and bounded to this family's `# grove: reach` fences
  local declared carried seen

  # 🛑 an UNKNOWN org may NEVER drive a reap — it read no table, so every fence
  #    would look undeclared and the reap would strip the box's whole reach
  if [[ -z "${GROVE_ORG:-}" ]]; then
    echo "   🌙 this run names no org, so no reach is declared — and none was reaped"
    grove_org_absent_say
    return $failed
  fi

  declared="$(grove_provision_5_13_reach_declared_profiles)"

  # ⚠️ a checkout with no `.agent/` cannot list its fences — a SKIPPED reap,
  #    never a converged box (`rule.forbid.failhide`)
  if ! carried="$(grove_provision_5_13_reach_carried)"; then
    echo "   🌙 the reach fences could not be listed, so none were reaped"
    echo "      ⇒ this checkout carries no .agent/, so the fence grammar has"
    echo "        no holder here — an undeclared profile would stay live"
    echo "      fix: push the whole checkout, not src/ alone"
    return $failed
  fi

  while IFS= read -r seen; do
    [[ -n "$seen" ]] || continue

    # ⚠️ a WHOLE-LINE match in pure bash — a partial match spares a live fence
    case $'\n'"$declared"$'\n' in
      *$'\n'"$seen"$'\n'*) continue ;;
    esac

    echo "   • ${seen} is carried by this box and declared by no row — reaped"

    # the org+env, cut from the RIGHT of `<org>.<env>.<owner>` — an org may hold a dot
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
