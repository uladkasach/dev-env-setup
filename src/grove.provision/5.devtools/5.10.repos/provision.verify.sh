#!/usr/bin/env bash
######################################################################
# .what = report how many of each org's repos are on disk, and refute the one
#         state the upsert can never repair on its own: a HALF-CLONED repo
#
# ⚠️ an absent repo REPORTS rather than refutes
#   - `gh repo list` returns whatever the token can see, and that set moves daily
#   - ⇒ a repo made an hour ago would fail a strict check on a healthy box
#
# ⚠️ a HALF-CLONED repo is the opposite — a hard ✋
#   - a verify whose only `return 1`s belong to `gh` makes no claim of its own
#   - a clone cut partway leaves the dir and `.git/` and never lands `.git/HEAD`
#   - ⇒ no git command opens that, and a bundle with no such branch reports ✔
#   - (`rule.forbid.failhide`)
#
# 🛑 BOTH halves cut that set with ONE reader
#   - two inline tests over one set disagree on exactly this input
#   - ⇒ the upsert would count the corpse DONE forever, and the only fix this
#     file could name is a HAND STEP, `rm -rf <dir>`
#   - ⇒ both ask the state reader declared once in this bundle's `_.sh`
#   - (`rule.require.one-command-provision`,
#      `gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
#
# guarantee:
#   - READ-ONLY: it observes and mutates no state
#
# exit:
#   0 = gh is usable, and every repo dir on disk is a readable checkout
#   1 = gh is absent or unauthed, or a repo dir is half-cloned
######################################################################

####################################################################
# ⚠️ every `gh` call below is BOUNDED
#   - each leaves the machine, and this file runs on every `--mode plan`
#   - on a captive portal `gh auth status` sits on a TCP connect for minutes,
#     and `gh repo list` then does it once PER ORG, in silence
#   - a timeout is always a 🌙, since the answer was not observed
#   - ⇒ to fail on a dead network sends a human to a login that fixes none of it
#   - (`rule.require.bounded-probes-in-verifies`)
####################################################################
GROVE_REPOS_GH_PROBE_SECONDS=15
GROVE_REPOS_GH_LIST_SECONDS=60

grove_provision_5_10_repos_provision_verify() {
  local orgs="${GROVE_GIT_ORGS:-ehmpathy ahbode whodisio}"

  if ! command -v gh >/dev/null 2>&1; then
    echo "   ✋ gh is absent, so no org's repos can be listed or cloned" >&2
    echo "      ⇒ this box cannot reach any repo it does not already hold" >&2
    echo "      fix: rhx grove.provision --what 2.shell --mode apply" >&2
    return 1
  fi

  local rc
  timeout -k 5 "$GROVE_REPOS_GH_PROBE_SECONDS" gh auth status >/dev/null 2>&1 && rc=0 || rc=$?

  if [[ "$rc" -eq 124 ]]; then
    echo "   🌙 github did not answer within ${GROVE_REPOS_GH_PROBE_SECONDS}s, so no org can be listed"
    echo "      ⇒ this judges no credential; the network is what was not reached"
    echo "      read it by hand, unbounded: gh auth status"
    return 0
  fi

  if [[ "$rc" -ne 0 ]]; then
    echo "   ✋ gh is present but unauthed" >&2
    echo "      ⇒ every org list returns an opaque error, so no clone can run" >&2
    echo "      ⇒ the credential belongs to 5.4.gh, which reads it from the rack" >&2
    echo "      fix: rhx grove.provision --what 5.4.gh --mode apply" >&2
    echo "           its ✋ names the exact 'rhx keyrack set' a human owes" >&2
    return 1
  fi

  local organization present absent broken repo
  local halves=()
  for organization in $orgs; do
    present=0
    absent=0
    broken=0
    while read -r repo _; do
      [[ -z "$repo" ]] && continue
      ################################################################
      # ⚠️ the SHARED reader, from this bundle's `_.sh`
      #   - it names the STATE rather than answers a boolean
      #   - ⇒ an inline test would be a second cut of the set the upsert cuts
      #   - ⇒ THIS half needs three answers, and a predicate gives two
      ################################################################
      case "$(grove_provision_5_10_repos_state "$HOME/git/$repo")" in
        whole)  present=$(( present + 1 )) ;;
        absent) absent=$(( absent + 1 )) ;;
        half)   broken=$(( broken + 1 )); halves+=("$HOME/git/$repo") ;;
      esac
    done < <(timeout -k 5 "$GROVE_REPOS_GH_LIST_SECONDS" gh repo list "$organization" --limit 1000 2>/dev/null)

    if (( absent == 0 && broken == 0 && present > 0 )); then
      echo "   • $organization — all $present repos on disk ✔"
    elif (( present == 0 && absent == 0 && broken == 0 )); then
      echo "   🌙 $organization — the token can see no repos here"
    else
      ################################################################
      # ⚠️ the fix-text SPLITS ON MODE, and that split is load-bear
      #   - under `plan` the upsert was short-circuited, so an apply is owed
      #   - under `apply` the upsert ran and `return 1`s on any clone failure,
      #     which breaks the phase chain and SKIPS this verify
      #   - ⇒ under apply, every clone it attempted succeeded
      #   - ⇒ the gap can only be a repo that appeared between the two lists
      #   - ⇒ "apply again" there is a decline cured by a second run, a blocker
      #   - the race is real, so the FACT earns a 🌙 and the INSTRUCTION does not
      #   - (`term=decline`, `rule.require.one-command-provision`)
      ################################################################
      echo "   🌙 $organization — $present on disk, $absent not on disk"
      if [[ "${GROVE_MODE:-apply}" == "apply" ]]; then
        echo "      the upsert ran in this run and every clone it tried succeeded,"
        echo "      so these appeared on github after it listed. no step is owed —"
        echo "      the next scheduled run takes them"
      else
        echo "      (a repo made since the last run is expected here)"
        echo "      to fetch them: rhx grove.provision --what 5.10.repos --mode apply"
      fi
    fi
  done

  ####################################################################
  # THE claim — no repo dir is half-cloned
  #   - see the header for why this is fatal rather than owed
  ####################################################################
  if [[ ${#halves[@]} -eq 0 ]]; then
    echo "   • every repo dir on disk opens as a git checkout ✔"
    return 0
  fi

  echo "   ✋ ${#halves[@]} repo dir(s) hold a .git with no readable HEAD" >&2
  local half
  for half in "${halves[@]}"; do
    echo "      • $half" >&2
  done
  ####################################################################
  # 🛑 the fix names an APPLY, never a hand step
  #   - a `rm -rf <dir>` instruction is a HAND STEP on a box with no hand
  #   - ⇒ the upsert asks the SAME reader, so it moves a half-clone aside
  #   - (`rule.require.one-command-provision`, `rule.require.solve-at-cause`)
  #
  # ⚠️ this ✋ carries a NARROW claim
  #   - under `apply` the upsert returns 1 on any repair it could not make,
  #     which skips this verify
  #   - ⇒ a half-clone that reaches here under apply is a defect in the repair
  ####################################################################
  echo "      ⇒ a clone was cut partway: the dir and its .git are here, and" >&2
  echo "        .git/HEAD never landed, so no git command opens it" >&2
  echo "      fix: rhx grove.provision --what 5.10.repos --mode apply" >&2
  echo "           its upsert moves a half-clone aside and re-clones it" >&2
  return 1
}
