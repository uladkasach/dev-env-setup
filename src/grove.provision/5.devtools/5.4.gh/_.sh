#!/usr/bin/env bash
######################################################################
# .what = the `gh` binary, and a credential for it to hold
#
# ⚠️ the BINARY and the AUTH are separate phases
#   - only the AUTH needs a human, so a `local` gate on both is half true
#   - 📜 one function conflated the two, so a grove got NEITHER — and the org
#     clone, built on gh, had no gh to call at all
#   - ⇒ provision lands the binary on every machine
#   - ⇒ configure gives it a credential by whichever means the machine has
#   - `2.2.git` and `2.3.ssh` fixed the same conflation for identity and key
#   - (`rule.require.identical-bundle-composition`)
#
# .this bundle applies to a HEADLESS box
#   - a grove clones the org's repos, reads issues, and opens PRs through gh
#   - ⇒ gh is how the grove does its work
#
# guarantee:
#   - identical on every machine
#   - (`rule.require.identical-bundle-composition`)
######################################################################

grove_provision_5_4_gh() {
  bundle.upgrade 5.4.gh.provision.upsert
  bundle.upgrade 5.4.gh.provision.verify
  bundle.upgrade 5.4.gh.configure.upsert
  bundle.upgrade 5.4.gh.configure.verify
}
