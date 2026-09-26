#!/usr/bin/env bash
######################################################################
# .what = 1password — the desktop vault a human unlocks, and the auto-lock
#         timer COSMIC cannot supply
#
# .why this bundle exists
#   - no prior run ever declared 1password, so it was a hand-install only
#   - .refs = gotcha.6-5-onepassword.demo=never-installed-by-any-run.md
#
# 🛑 .the `op` CLI LEFT this bundle — it lives at `5.19.op` now, which also
#   OWNS the 1password apt key and repo. this bundle writes NEITHER
#   (`rule.forbid.two-writers-on-one-artifact`), and READS the anchor instead
#   - .refs = gotcha.5-19-op.demo=keyrack-vault-backend.md
#
# .why local only
#   - the vault is a GUI app a human unlocks by hand, and a grove has no
#     screen to draw it on. a grove is handed scoped credentials instead
#     (`plan.grove-credentials.md`)
#
# .why the bundle is `6.5.onepassword`, not `6.5.1password`
#   - `bundle.num.of` reads every dot-segment before the first non-digit
#     one, so `6.5.1password` computes `6.5` correctly, but a human reads
#     it as slug `6.5.1` plus a stray word — the digit is spelled out
#     (`rule.require.bundle-names-name-their-subject`)
#
# .why it is opt-in
#   - `GROVE_OPTIN_APPS` (`src/bundle.upgrade.sh`) means a run installs the
#     app only when asked
#   - a GUI vault on a laptop nobody asked for is a preference imposed; one
#     `--include onepassword` at the moment of use is the cheaper trade
#   - ⚠️ that argument held for `op` too, and was wrong for it — a PROGRAM
#     cannot pass `--include` on a human's behalf
#
# usage:
#   rhx grove.provision --include onepassword --mode apply
######################################################################

GROVE_OPTIN_APPS+=(onepassword)

grove_provision_6_5_onepassword() {
  grove_optin onepassword || { grove_optin_decline onepassword; return 0; }

  bundle.upgrade 6.5.onepassword.provision.upsert
  bundle.upgrade 6.5.onepassword.provision.verify
  bundle.upgrade 6.5.onepassword.configure.upsert
  bundle.upgrade 6.5.onepassword.configure.verify
}
