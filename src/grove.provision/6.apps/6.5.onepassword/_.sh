#!/usr/bin/env bash
######################################################################
# .what = 1password — the desktop vault, its `op` cli, and the auto-lock timer
#         COSMIC cannot supply
#
# .why this bundle exists, and why `op` is a hard dependency here
#   - no prior run ever declared 1password, so `op` was a hand-install only
#   - `src/backup_env.sh` and `src/util.yubikey.ssh.sh` both name `op` in
#     their own instructions
#   - .refs = gotcha.6-5-onepassword.demo=never-installed-by-any-run.md
#
# .why local only
#   - the vault is a GUI app a human unlocks by hand; the `op` cli is
#     useless without it, and a grove holds no unlockable vault — it is
#     handed scoped credentials instead (`plan.grove-credentials.md`)
#
# .why the bundle is `6.5.onepassword`, not `6.5.1password`
#   - `bundle.num.of` reads every dot-segment before the first non-digit
#     one, so `6.5.1password` computes `6.5` correctly, but a human reads
#     it as slug `6.5.1` plus a stray word — the digit is spelled out
#     (`rule.require.bundle-names-name-their-subject`)
#
# .why the opt-in has a real cost, and why it is still opt-in
#   - `GROVE_OPTIN_APPS` (`src/bundle.upgrade.sh`) means a run installs
#     neither the app nor `op` unless asked
#   - the two utilities above are human-run, off the provision path, so an
#     absent `op` costs one `--include onepassword` at the moment of use —
#     cheaper than an unasked GUI vault on every laptop
#   - each utility must SAY `op` is absent, never fail on a bare
#     `command not found` (`rule.require.errors-name-the-fix`)
#   - ONE opt-in name covers both packages: a human who wants the vault
#     wants its cli, so two names would let a box ask for half a bundle
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
