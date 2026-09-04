#!/usr/bin/env bash
######################################################################
# .what = prove `gh` holds a credential github will accept
#
# .`gh auth status`, never a test for the TOKEN variable
#   - an expired or under-scoped token passes a `[[ -n ]]` test
#   - ⇒ it then fails at the first api call, inside whichever skill made it
#   - `gh auth status` asks github, so it answers the claim
#
# .a REFUSED credential is only ever a ✋, never a 🌙
#   - gh is how every machine here reaches github, headless or not
#
# ⚠️ the ask is BOUNDED, and a timeout is the one 🌙 here
#   - this runs on every `--mode plan`, which a human expects to be quick
#   - behind a captive portal it sits on a TCP connect for minutes
#   - ⇒ `grove.provision` would read as hung
#   - a timeout says the credential was NOT OBSERVED, never that github refused
#   - ⇒ a ✋ there would blame a token for a router
#   - (`rule.require.bounded-probes-in-verifies`)
#
# guarantee:
#   - READ-ONLY: it asks github about the credential and writes no state
#
# exit:
#   0 = gh holds a credential github accepts — or the ask could not be completed
#   1 = github was reached and refused the credential
######################################################################

GROVE_GH_AUTH_PROBE_SECONDS=15

grove_provision_5_4_gh_configure_verify() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "   ✋ gh is absent, so it can hold no credential" >&2
    echo "      ⇒ the provision phase above owns that claim; repair it first" >&2
    return 1
  fi

  local rc
  timeout -k 5 "$GROVE_GH_AUTH_PROBE_SECONDS" gh auth status >/dev/null 2>&1 && rc=0 || rc=$?

  if [[ "$rc" -eq 124 ]]; then
    echo "   🌙 github did not answer within ${GROVE_GH_AUTH_PROBE_SECONDS}s, so the credential is unproven"
    echo "      ⇒ this judges no token — a captive portal or a blackholed firewall"
    echo "        looks exactly like this from here"
    echo "      read it by hand, unbounded: gh auth status"
    return 0
  fi

  if [[ "$rc" -eq 0 ]]; then
    # .name WHICH credential, since the two are repaired differently
    if [[ -n "${GH_TOKEN:-}" ]]; then
      echo "   • gh authed via GH_TOKEN, and github accepts it ✔"
    else
      echo "   • gh authed via a stored login, and github accepts it ✔"
    fi
    return 0
  fi

  echo "   ✋ gh holds no credential github will accept" >&2
  echo "      ⇒ a SET GH_TOKEN is not enough: an expired or under-scoped token" >&2
  echo "        passes a presence test and fails at the first api call, inside" >&2
  echo "        whichever skill made it — never here" >&2
  echo "      ⇒ so this asks github, and github said no" >&2
  if [[ "$GROVE_ENV_SERVER" == "local@unix" ]]; then
    echo "      fix: gh auth login" >&2
  else
    echo "      fix (this box confirms no human, so a login cannot be answered):" >&2
    echo "        1. cd ~/git/more/dev-env-setup && rhx keyrack set \\" >&2
    echo "             --owner ehmpath --key GITHUB_TOKEN \\" >&2
    echo "             --org @all --env camp --vault aws.params" >&2
    echo "           answer its two prompts: mechanism 1, then paste the pat" >&2
    echo "      ⚠️ the pat needs BOTH scopes: 'repo' to clone, 'read:org' so gh" >&2
    echo "         can enumerate. one with only 'repo' clones every repo you" >&2
    echo "         name and cannot tell you what there is to name" >&2
    echo "        2. rhx grove.provision --what 5.4.gh --mode apply" >&2
    echo "      ⚠️ step 2 is NOT optional after a scope change on the same pat." >&2
    echo "         git asks the rack on every fetch, so it picks a rescope up at" >&2
    echo "         once. gh holds a STORED LOGIN taken here, so its copy stays" >&2
    echo "         stale until this bundle re-reads the rack. measured 2026-08-05:" >&2
    echo "         git went green on a rescoped pat while gh stayed refused" >&2
    echo "      the value is typed on a tty and stored age-encrypted — never pass" >&2
    echo "      it as an argument, and never export it into a duct pane" >&2
    echo "      ⚠️ one set, no fill: set stores the value itself, and fill re-drives" >&2
    echo "         its prompts, so a chained fill takes the pat as a mechanism answer" >&2
    echo "      see grove.auth.github.roadmap.md" >&2
  fi
  echo "      read why: gh auth status" >&2
  return 1
}
