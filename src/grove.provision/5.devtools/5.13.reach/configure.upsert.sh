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

# .what = replay a skill's own words under this bundle's `what it said:` line
# .why  = a verbatim replay strands its tree glyphs, so each line sits at one depth
grove_provision_5_13_reach_said() {
  printf '%s\n' "$1" | sed -E 's/^[[:space:]]*((│|├─|└─)[[:space:]]*)*//; /^$/d; s/^/        /'
}

grove_provision_5_13_reach_configure_upsert() {
  grove_env_seat_is_admin && { grove_env_seat_admin_declines "account reach"; return 0; }
  local owner
  owner="$(grove_provision_5_13_reach_owner)"

  # 0. an ambient identity to chain OFF — every profile assumes from the box's
  #    badge, and a laptop has none. on a camp seat the same silence is a fault
  if ! aws configure export-credentials --profile ambient >/dev/null 2>&1; then
    grove_env_ambient_absent_says "account reach"
    return
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
    carried) echo "   🌙 $srcname is a carried tree (no .git) — the rows read what it holds"
             echo "      ⇒ it has no upstream, so a declaration merged since the carry"
             echo "        is invisible here. re-carry it to refresh:"
             echo "        rhx git.grove.push <grove> --from <its checkout> --into git/$(grove_org_clonedir "$srcorg")/$(grove_provision_5_13_reach_srcname) --mode apply" ;;
    *)       echo "   🌙 $srcname could not be fetched — the rows read what it holds"
             echo "      ⇒ a declaration merged since the last fetch is invisible here" ;;
  esac

  fi

  local gitroot
  gitroot="$(grove_provision_5_12_rack_gitroot)"

  # every `rhx` below runs from the CHECKOUT ROOT, where rhachet links this repo's
  # role. 🛑 hoisted ABOVE the loop — `set -u` killed the reap when every row declined
  local checkout; checkout="$(dirname "$GROVE_SRC")"

  # 1. one row at a time. ⚠️ the role AND the org are read INSIDE the loop — the
  #    rows share neither, so a hoisted read writes one value into every profile
  local failed=0 pair org env reader akey rkey role account
  for pair in $(grove_provision_5_13_reach_envs); do
    IFS='|' read -r org env reader akey rkey <<< "$(grove_provision_5_13_reach_row_fields "$pair")"

    # ⚠️ halt a short row here: its empty role read looks like an absent clone
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
    # the DECLARATION source and the role's OWNER can differ (a cross-org opt-in), so
    #   the line names both — the trust ask below goes to the owner, never the source
    echo "   • ${org}.${env} role: $role (declared in ${srcname}$([[ "$org" != "${srcorg%%-*}" ]] && printf '; a role %s owns' "$org"))"

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
    local reachlog rc refused
    # 🛑 `--gitroot`: the keyrack write must read the org this row just DECLARED there.
    #    from a real checkout, the cwd's own keyrack.yml wins, and it allows its repo's org only
    reachlog="$(env -C "$checkout" rhx aws.reach.set --gitroot "$gitroot" \
                  --org "$org" --env "$env" --owner "$owner" \
                  --assume "$role" --account "$account" --mode apply 2>&1)"
    rc=$?

    if [[ $rc -ne 0 ]]; then
      # ⚠️ the CAUSE is read from the log. no `-q`: under pipefail it takes the ELSE branch
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
      elif printf '%s\n' "$reachlog" | grep "OUTSIDE this skill's fence" >/dev/null; then
        # a hand-laid twin of the hop's profile: the sdk reads the LAST of two blocks
        #   of one name, so the skill refuses to write beside it (catalog c11)
        echo "      ⇒ ~/.aws/config already holds this hop's profile OUTSIDE the fence —" >&2
        echo "        laid by hand or by another writer, so it is not this bundle's to delete." >&2
        echo "        remove that block (the skill names its lines below), then re-apply" >&2
      elif refused="$(grove_aws_trust_refused "$reachlog")"; then
        # 🛑 read FIRST: a session-tag refusal's text holds "AssumeRole" too, and its
        #   repair is the opposite one — the role trusts this box already
        #   (the same shared reader the verify sorts by, `src/grove.aws.sh`)
        echo "      ⇒ the role TRUSTS this box, and refuses what its session carries ($refused)" >&2
        echo "        an infra ask: the role's trust policy must allow all three of" >&2
        echo "        $(grove_aws_trust_actions_owed), in ${org}/infrastructure" >&2
      elif printf '%s\n' "$reachlog" | grep -i 'AccessDenied' >/dev/null; then
        grove_provision_5_13_reach_denied_causes_say "$org" "$role"
      else
        echo "      ⇒ the skill ran and refused for a reason that is neither an" >&2
        echo "        absent linkage nor an AccessDenied — read its own words" >&2
      fi

      echo "      ⇒ what it said:" >&2
      grove_provision_5_13_reach_said "$reachlog" >&2
      failed=1
      continue
    fi

    echo "   • ${org}.${env} reaches its account, proven with a live sts call ✔"
  done

  # 2. reap every reach no row declares — bounded to this family's `# grove: reach` fences
  local declared carried seen

  # 🛑 an UNKNOWN org may NEVER drive a reap — it read no table, so every fence
  #    would look undeclared and the reap would strip the box's whole reach
  if [[ -z "${GROVE_ORG:-}" ]]; then
    echo "   🌙 this run names no org, so no reach is declared — and none was reaped"
    grove_org_absent_say
    return $failed
  fi

  declared="$(grove_provision_5_13_reach_declared_profiles)"

  # ⚠️ no `.agent/` → no fence list → a SKIPPED reap, never a converged box
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
      grove_provision_5_13_reach_said "$deadlog" >&2
      failed=1
    fi
  done < <(printf '%s\n' "$carried")

  return $failed
}
