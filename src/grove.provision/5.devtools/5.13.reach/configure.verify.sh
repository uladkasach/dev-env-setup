#!/usr/bin/env bash
######################################################################
# .what = prove that, for each declared env, the rack NAMES a profile and that
#         profile ANSWERS in the account the tree declares
# .why
#   - ⚠️ it re-asks what the upsert proved — a plan is the one read a human trusts
#   - ⚠️ it checks the ACCOUNT, since a wrong-account profile assumes cleanly
#   - 🛑 the account is COMPARED, never printed (`rule.forbid.dox-in-public-repo`)
# .refs = gotcha.5-13-reach.demo=per-org-rows-and-the-reap, m10
#
# guarantee:
#   - read-only: one sts call and one rack read per env, and no write
#   - it declines where the reach cannot apply, and FAILS where it should hold
######################################################################

grove_provision_5_13_reach_configure_verify() {
  local owner
  owner="$(grove_provision_5_13_reach_owner)"

  if ! aws configure export-credentials --profile ambient >/dev/null 2>&1; then
    echo "   • declined — no ambient identity here, so no reach to prove"
    return 0
  fi

  if ! command -v rhx >/dev/null 2>&1; then
    echo "   • declined — rhx is absent, so the rack cannot be read (5.3.brains)"
    return 0
  fi

  ####################################################################
  # ⚠️ a NAMED org's rack read is CWD-SENSITIVE, so it runs where the write did
  #   - 📜 `5.12.rack` measured one box one second apart: `ambient` from the
  #     scratch root, EMPTY from this checkout
  #   - a named org reads against a `keyrack.yml` IN SCOPE
  #   - ⇒ an empty answer here would mean the wrong cwd, never an absent entry
  #   - (`gotcha.a-check-that-cries-wolf-gets-silenced`)
  ####################################################################
  local gitroot srcname
  gitroot="$(grove_provision_5_12_rack_gitroot)"
  srcname="$(grove_provision_5_13_reach_srcorg)/$(grove_provision_5_13_reach_srcname)"

  # ⚠️ parse the row the SAME way the upsert does — one table, two readers, free
  #    to drift. a `${pair##*:}` here reads the ROLE key as the account key, so
  #    every env falls to the weaker 🌙 "no clone declares the account"
  local failed=0 pair rest org env reader akey rkey account named seen declsrc
  for pair in $(grove_provision_5_13_reach_envs); do
    org="${pair%%:*}"
    rest="${pair#*:}"
    env="${rest%%:*}"
    rest="${rest#*:}"
    reader="${rest%%:*}"
    rest="${rest#*:}"
    akey="${rest%%:*}"
    rkey="${rest##*:}"
    declsrc="$(grove_provision_5_13_reach_declsrc "$reader")" || declsrc="(unknown reader '${reader}')"

    # 🛑 declare THIS ROW's org before its reads — `5.12.rack` runs first and its
    #    loop leaves the LAST org it wired declared in that scratch yml. a named-org
    #    read resolves against the yml in scope, so without this a row reads empty
    #    and reports a false ✋ on an entry that is present.
    #    ⚠️ per ROW, since the rows no longer share an org
    grove_provision_5_12_rack_declare_org "$gitroot" "$org" || { failed=1; continue; }

    # 1. does the rack NAME a profile for this env?
    named="$(env -C "$gitroot" rhx keyrack get --owner "$owner" --key AWS_PROFILE \
               --org "$org" --env "$env" --unlock --value 2>/dev/null | tail -1)"

    if [[ -z "$named" ]]; then
      # 🛑 an UNWIRED row whose DECLARATION is unreadable is UNPROVEN, never
      #    broken — it declines on the upsert's SAME two reads, in order, since a
      #    ✋ would name a re-apply that declines forever (m10)
      if [[ -z "$(grove_provision_5_13_reach_role "$reader" "$rkey")" ]]; then
        echo "   • ${org}.${env} declined — the role key '${rkey}' is not readable here"
        echo "     ⇒ the upsert declined for the same reason, so no hop is owed yet"
        echo "     ⇒ it is DECLARED in ${srcname}, by the '${reader}' reader:"
        echo "       ${declsrc}"
        continue
      fi

      # ⚠️ a DISAGREEMENT also reads empty, and `_account` has already printed
      #   its own ✋ that names the files — so this decline hides none of it
      if [[ -z "$(grove_provision_5_13_reach_account "$reader" "$akey")" ]]; then
        echo "   • ${org}.${env} declined — the account key '${akey}' is not readable here"
        echo "     ⇒ the upsert declined for the same reason, so no hop is owed yet"
        echo "     ⇒ it is DECLARED in ${srcname}, by the '${reader}' reader:"
        echo "       ${declsrc}"
        continue
      fi

      echo "   ✋ the rack names no profile for ${org}.${env}.AWS_PROFILE" >&2
      echo "      ⇒ every suite that targets ${env} dies at 'AWS_PROFILE not set.'" >&2
      echo "        with live credentials one metadata call away" >&2
      echo "      fix: rhx grove.provision --what 5.13.reach --mode apply" >&2
      failed=1
      continue
    fi

    # 2. does that profile ANSWER, and from the account the tree declares?
    # ⚠️ the refusal is CAPTURED, never discarded — aws's sentence sorts the causes (m10)
    said="$(aws sts get-caller-identity --profile "$named" \
              --query Account --output text 2>&1)" || true
    seen="$(printf '%s\n' "$said" | grep -oE '^[0-9]{12}$' | head -1)"

    if [[ -z "$seen" ]]; then
      # 🛑 THREE causes read identically here, and want OPPOSITE fixes. the two
      #    AssumeRole denials are sorted only by the ORG, which this code cannot
      #    ask — so the fix-text puts "should this org reach here AT ALL?" FIRST,
      #    before any infra ask. no id is printed for either cause
      #    (`rule.require.a-grove-reaches-its-own-org-only`, m10)
      if [[ "$said" == *AccessDenied* && "$said" == *AssumeRole* ]]; then
        echo "   ✋ ${org}.${env} — the hop is declared, and this box is REFUSED it" >&2
        echo "      ⇒ a re-apply of this bundle refuses identically. TWO causes wear" >&2
        echo "        this one message, and they want OPPOSITE repairs:" >&2
        echo "      1. does a '${org}' row belong on a grove of THIS org at all?" >&2
        echo "         no  ⇒ 🔴 OURS. delete the row; no grant is owed, and none may" >&2
        echo "               be sought (rule.require.a-grove-reaches-its-own-org-only)" >&2
        echo "      2. only if yes — the role EXISTS and this box sits outside its" >&2
        echo "         trust policy ⇒ an infra ask. the grant owed: trust this box's" >&2
        echo "         CAMP role as a principal on" >&2
        echo "         '$(grove_provision_5_13_reach_role "$reader" "$rkey")', beside the camp role already there" >&2
        echo "      ⇒ ask 1 FIRST. its answer is the ORG's, and the refusal says no" >&2
        echo "        word about it — an ask filed on a no buys a standing hop into" >&2
        echo "        another org's accounts, to silence a check that was right" >&2
        echo "      ⇒ read the refusal in full, on the box (it names the ids):" >&2
        echo "        aws sts get-caller-identity --profile ${named}" >&2
        failed=1
        continue
      fi

      echo "   ✋ the rack names '${named}' for ${org}.${env}, and it does not answer" >&2
      echo "      ⇒ a named profile with no live body is a profile aws cannot find" >&2
      echo "        — the half-applied pair aws.reach.set exists to prevent" >&2
      echo "      ⇒ read the refusal in full:" >&2
      echo "        aws sts get-caller-identity --profile ${named}" >&2
      echo "      fix: rhx grove.provision --what 5.13.reach --mode apply" >&2
      failed=1
      continue
    fi

    account="$(grove_provision_5_13_reach_account "$reader" "$akey")"
    if [[ -z "$account" ]]; then
      echo "   🌙 ${org}.${env} answers as '${named}', and no clone declares the"
      echo "      account to compare it against — so the ACCOUNT half is unproven"
      echo "      ⇒ this is a weaker ✔ on purpose: the call answers, and whether"
      echo "        it lands in the right account cannot be judged with no tree"
      continue
    fi

    if [[ "$seen" != "$account" ]]; then
      echo "   ✋ '${named}' answers from an account the tree does not declare" >&2
      echo "      ⇒ neither id is printed: this repo is public and a duct keeps" >&2
      echo "        scrollback (rule.forbid.dox-in-public-repo)" >&2
      echo "      ⇒ this is the SILENT failure the derivation exists to stop — the" >&2
      echo "        profile assumed cleanly, and into somewhere else. every suite" >&2
      echo "        on it will fail on permissions, far from this cause" >&2
      echo "      ⇒ compare them by hand:" >&2
      echo "        aws sts get-caller-identity --profile ${named} --query Account" >&2
      # ⚠️ the SOURCE org, never the row's target org — a row may reach into an
      #   account that no clone of its own org declares, which is why the two
      #   axes parted in the first place (`5.13.reach/_.sh`, `_srcorg`)
      # ⚠️ and the FILE is the row's own reader's, never one fixed path — an
      #   `arnconst` row's id is nowhere in a declapract.use.yml
      echo "        under ~/git/$(grove_provision_5_13_reach_srcorg)/, read:" >&2
      echo "        ${declsrc}" >&2
      failed=1
      continue
    fi

    echo "   ✔ ${org}.${env} answers as '${named}', in the declared account"
  done

  # every reach this box carries that no row declares — asked HERE too, since a
  # plan runs no upsert. a ✋, never a 🌙: it is live reach nobody granted (m10)
  local declared carried seen

  # 🛑 an UNKNOWN org proves no drift — see the same block in the upsert
  #   with no org this run read no table, so every carried fence would read as
  #   undeclared and this check would ✋ on a box that may be perfectly correct
  if [[ -z "${GROVE_ORG:-}" ]]; then
    echo "   🌙 this run names no org, so no reach is declared — drift is unproven"
    grove_org_absent_say
    return $failed
  fi

  declared="$(grove_provision_5_13_reach_declared_profiles)"

  # ⚠️ an unreadable fence list is a 🌙, never a ✔ — see the same block in the
  #   upsert. a checkout pushed as `src/` alone carries no grammar to read
  if ! carried="$(grove_provision_5_13_reach_carried)"; then
    echo "   🌙 the reach fences could not be listed, so drift is unproven here"
    echo "      ⇒ this checkout carries no .agent/, so an undeclared profile"
    echo "        would be invisible to this check rather than absent"
    return $failed
  fi

  while IFS= read -r seen; do
    [[ -n "$seen" ]] || continue

    # ⚠️ a whole-line match in pure bash — see the same block in the upsert for
    #   why it is neither a partial match nor a `grep -q` in a pipe
    case $'\n'"$declared"$'\n' in
      *$'\n'"$seen"$'\n'*) continue ;;
    esac

    echo "   ✋ this box carries reach '${seen}', and no row declares it" >&2
    echo "      ⇒ it is a live profile: a real role in a real account, under a" >&2
    echo "        name this repo no longer owns. a suite or a human can select" >&2
    echo "        it, and no declaration says what it is for" >&2
    echo "      fix: rhx grove.provision --what 5.13.reach --mode apply" >&2
    echo "        (its upsert reaps every fence this table does not declare)" >&2
    failed=1
  done < <(printf '%s\n' "$carried")

  return $failed
}
