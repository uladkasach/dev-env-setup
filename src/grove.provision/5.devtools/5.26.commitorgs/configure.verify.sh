#!/usr/bin/env bash
######################################################################
# .what = prove the commit gate allows, on this seat, each org the grove's token can
#         push to; and name each crew here whose org the token cannot push to
#
# .it reads the meter the gate's way (`grove_provision_5_26_commitorgs_state_of`
#   mirrors `check_org_blocker`), so a verdict here is the verdict a crew meets
#
# exit:
#   0 = every token org is allowed (or blocked by the human, which is honored),
#       and every crew here belongs to a token org
#   1 = an org is unset, the meter is damaged, the token is unread or reaches no
#       org, or a crew's org is out of the token's reach; the fix is named
######################################################################

grove_provision_5_26_commitorgs_configure_verify() {
  grove_provision_5_26_commitorgs_declines && return 0
  grove_provision_5_26_commitorgs_refuses_without_jq && return 1

  local seat orgs presence bytes='' states org state unset_orgs damaged_orgs failed=false
  seat="$(whoami)@$(hostname)"

  if ! orgs="$(grove_provision_5_26_commitorgs_token_orgs)"; then
    echo "   ✋ ConstraintError: the github token on $seat could not be read, so the orgs it may push to are unknown" >&2
    echo "      ├─ asked: gh api user/repos (bounded at ${GROVE_COMMITORGS_GH_SECONDS}s)" >&2
    echo "      └─ fix: rhx grove.provision --what 5.4.gh --mode apply   # it wires gh to the token" >&2
    return 1
  fi
  if [[ -z "$orgs" ]]; then
    echo "   ✋ ConstraintError: the github token on $seat can push to no org, so no crew here can ship" >&2
    echo "      ├─ why: the token's push scope is the grant; it is set where the token is minted" >&2
    echo "      └─ fix: widen the token's scope where it is minted, then place it again from your laptop — rhx git.grove.auth.github.set <grove>" >&2
    return 1
  fi
  echo "   • the token on $seat can push to $(grove_provision_5_26_commitorgs_orgs_phrase_of "$orgs")"

  presence="$(grove_provision_5_26_commitorgs_meter_presence)"
  grove_provision_5_26_commitorgs_refuses_unreadable "$presence" "$seat" && return 1
  if [[ "$presence" == "present" ]] && ! bytes="$(grove_provision_5_26_commitorgs_meter_bytes)"; then
    echo "   💥 MalfunctionError: the org commit meter on $seat is present, and could not be read" >&2
    echo "      ├─ file: $(grove_provision_5_26_commitorgs_meter_path)" >&2
    echo "      ├─ read why: ls -l $(grove_provision_5_26_commitorgs_meter_path)   # a mode or owner fault fails every re-run" >&2
    echo "      └─ fix: once it reads, re-run — rhx grove.provision --what 5.26.commitorgs --mode plan" >&2
    return 1
  fi

  states="$(grove_provision_5_26_commitorgs_states_of orgs="$orgs" presence="$presence" bytes="$bytes")"
  while IFS='=' read -r org state; do
    case "$state" in
      allowed|allowed@all)
        echo "   • the commit gate allows org '$org' on $seat ✔$(grove_provision_5_26_commitorgs_scope_of "$state")" ;;
      blocked|blocked@all)
        echo "   🌙 org '$org' is blocked on $seat by the human's own word$(grove_provision_5_26_commitorgs_scope_of "$state") — left as is; its crews are refused here until the human lifts it" ;;
    esac
  done <<< "$states"

  # the crews' read prints its bullets here, so every bullet sits above the refusals
  grove_provision_5_26_commitorgs_verify_crew_orgs orgs="$orgs" seat="$seat" || failed=true

  damaged_orgs="$(grove_provision_5_26_commitorgs_orgs_in states="$states" in=corrupt)"
  if [[ -n "$damaged_orgs" ]]; then
    echo "   ✋ ConstraintError: the org commit meter on $seat is damaged, so the commit gate refuses $(grove_provision_5_26_commitorgs_orgs_phrase_of "$damaged_orgs")" >&2
    grove_provision_5_26_commitorgs_damaged_fix "$seat"
    failed=true
  fi

  unset_orgs="$(grove_provision_5_26_commitorgs_orgs_in states="$states" in=unset)"
  if [[ -n "$unset_orgs" ]]; then
    echo "   ✋ ConstraintError: the commit gate finds no grant for $(grove_provision_5_26_commitorgs_orgs_phrase_of "$unset_orgs") on $seat" >&2
    echo "      ├─ why: a crew of an org with no grant is refused at its done gate, with 'no org config'" >&2
    echo "      └─ fix: rhx grove.provision --what 5.26.commitorgs --mode apply   # it allows each token org" >&2
    failed=true
  fi

  [[ "$failed" == true ]] && return 1
  return 0
}

# .what = name each crew org on this seat the token cannot push to
# .why  = a crew of such an org cannot ship here whatever the meter holds
grove_provision_5_26_commitorgs_verify_crew_orgs() {
  local orgs='' seat='' outside orgless crew_org arg
  for arg in "$@"; do
    case "$arg" in
      orgs=*) orgs="${arg#orgs=}" ;;
      seat=*) seat="${arg#seat=}" ;;
    esac
  done

  if [[ -z "$(grove_provision_5_26_commitorgs_crew_orgs)" ]]; then
    echo "   • no crew tree lives on $seat yet — none to grade"
    return 0
  fi

  # a tree whose keyrack names no org fails on that keyrack before this gate reads a meter
  orgless="$(grove_provision_5_26_commitorgs_crew_trees_of '<none>')"
  [[ -n "$orgless" ]] && echo "   🌙 crew trees on $seat whose keyrack names no org, so no meter grant helps them: $orgless"

  # a ✔ counts only trees with an org: where every tree is orgless, none was graded
  if [[ -z "$(grove_provision_5_26_commitorgs_crew_orgs | grep -v '^<none> ')" ]]; then
    echo "   • no crew tree on $seat names an org — none to grade"
    return 0
  fi

  outside="$(grove_provision_5_26_commitorgs_crew_orgs_outside "$orgs")"
  if [[ -z "$outside" ]]; then
    echo "   • every crew tree with an org on $seat belongs to an org the token can push to ✔"
    return 0
  fi

  echo "   ✋ ConstraintError: crews of $(grove_provision_5_26_commitorgs_orgs_phrase_of "$outside") live on $seat, and the token cannot push to them" >&2
  for crew_org in $outside; do
    echo "      ├─ $crew_org: $(grove_provision_5_26_commitorgs_crew_trees_of "$crew_org")" >&2
  done
  echo "      ├─ fix: widen the token's scope where it is minted, then place it again from your laptop — rhx git.grove.auth.github.set <grove>" >&2
  echo "      └─ or:  sprout those crews on a grove whose token reaches them" >&2
  return 1
}
