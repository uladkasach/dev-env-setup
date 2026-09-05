#!/usr/bin/env bash
######################################################################
# .what = vscodium — the GUI editor, and the only app here with a config this
#         repo owns
#
# .it is the one app in this section with a `configure` phase
#   - spotify, slack, dropbox and protonvpn keep their settings behind a sign-in
#   - `codium/sync.settings.yml` IS tracked here
#   - the marketplace override is a json file this repo writes
#   - ⇒ codium has a declared state to converge to, and the other four do not
#
# ⚠️ .the copilot setup is NOT a phase here
#   - it ran `sudo vim` and then waited on a human, which is a runbook
#   - it lives at `guides/codium.copilot.md`
#
# ⚠️ .OPT-IN — a run installs codium only when asked
#   - see `GROVE_OPTIN_APPS` in `src/bundle.upgrade.sh`
#
# usage:
#   rhx grove.provision --include codium --mode apply
######################################################################

GROVE_OPTIN_APPS+=(codium)

######################################################################
# ⚠️ the gate sits at the BUNDLE, not in each of the four phases
#   - all four serve one app, so one question answers for all
#   - four copies of one predicate would drift the day a fifth phase lands
#   - (rule.require.identical-bundle-composition)
######################################################################
grove_provision_6_2_codium() {
  grove_optin codium || { grove_optin_decline codium; return 0; }

  bundle.upgrade 6.2.codium.provision.upsert
  bundle.upgrade 6.2.codium.provision.verify
  bundle.upgrade 6.2.codium.configure.upsert
  bundle.upgrade 6.2.codium.configure.verify
}
