#!/usr/bin/env bash
######################################################################
# .what = prove git holds BOTH halves of an identity on this box
#
# .it is ASSERTED, never merely reported
#   - git refuses to commit with either half absent
#   - ⇒ the failure arrives at commit time, far from here
#
# 🛑 there is NO 🌙 branch
#   - a decline on an unauthed gh is correct only where `5.4.gh` runs LATER
#   - `5.4.gh` runs BEFORE this bundle
#   - ⇒ an unauthed gh is a real defect, never a fact about order
#   - ⇒ its fix names `5.4.gh` (`rule.require.errors-name-the-fix`)
#
# guarantee:
#   - READ-ONLY. it reads git's config and repairs no state
#
# exit:
#   0 = both halves present
#   1 = the identity is absent or half-written, and the cause is named
######################################################################

grove_provision_5_15_identity_configure_verify() {
  local email name
  email="$(git config --global user.email 2>/dev/null || true)"
  name="$(git config --global user.name 2>/dev/null || true)"

  if [[ -n "$email" && -n "$name" ]]; then
    echo "   • git identity set ($name <$email>) ✔"
    return 0
  fi

  echo "   ✋ git identity is INCOMPLETE (email='$email' name='$name')" >&2
  echo "      ⇒ git refuses to commit with either half absent, so this box" >&2
  echo "        cannot commit — and the error arrives at commit time, not here" >&2

  ####################################################################
  # ⚠️ the CAUSE decides which fix is named
  #   - a headless box derives its identity from gh's credential
  #   - ⇒ an unauthed gh is the usual cause there
  ####################################################################
  if ! gh auth status >/dev/null 2>&1; then
    echo "      ⇒ gh holds no login, and a headless box DERIVES its identity from" >&2
    echo "        exactly that credential — so this is gh's gap, not an absent" >&2
    echo "        human. 5.4.gh runs BEFORE this bundle, so it is not order either" >&2
    echo "      read why: gh auth status" >&2
    echo "      fix: rhx grove.provision --what 5.4.gh --mode apply" >&2
    return 1
  fi

  echo "      ⇒ gh IS authed, so the credential is there and the derivation did" >&2
  echo "        not land — the upsert is what to re-read" >&2
  echo "      read why: gh api user --jq .login    # should name an account" >&2
  echo "      fix: rhx grove.provision --what 5.15.identity --mode apply" >&2
  return 1
}
