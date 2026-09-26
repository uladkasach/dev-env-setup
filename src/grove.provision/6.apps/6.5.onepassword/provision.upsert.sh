#!/usr/bin/env bash
######################################################################
# .what = install the 1password desktop app, from the apt repo `5.19.op`
#         declared
# .ref  = https://support.1password.com/install-linux/
#
# 🛑 .this phase writes NO key and NO repo line, and installs NO `op` —
#   `5.19.op` owns all three, and is dispatched a whole section earlier with
#   no opt-in, so the anchor is down before this runs
#   (`rule.forbid.two-writers-on-one-artifact`)
#   - .refs = gotcha.5-19-op.demo=keyrack-vault-backend.md
#
# guarantee
#   - idempotent: an installed app short-circuits the apt call
#   - it DECLINES on a box with no screen
######################################################################

grove_provision_6_5_onepassword_provision_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo '   🌙 declined — the vault is a GUI app a human unlocks by hand, and'
    echo "      $GROVE_ENV_SERVER has no screen. op without that app is inert, so"
    echo '      neither half is owed here. a grove is handed scoped credentials'
    echo '      instead (plan.grove-credentials.md)'
    return 0
  fi

  ####################################################################
  # 1. already here? then no write is owed, and no root is reached for
  ####################################################################
  if command -v 1password >/dev/null 2>&1; then
    echo "   • the 1password app ✔ (already installed)"
    return 0
  fi

  ####################################################################
  # 2. the apt anchor `5.19.op` placed — READ, never written
  #
  # 🛑 a SEAM, asked rather than assumed: a `--what 6.5.onepassword` run drives
  #    THIS bundle alone, so the anchor may be absent. apt would then fail with
  #    "the repository is not signed" — a line that names no owner
  ####################################################################
  if [[ ! -f /usr/share/keyrings/1password-archive-keyring.gpg ]]; then
    echo "   ✋ the 1password apt key is absent, so this app cannot install" >&2
    echo "      ⇒ the key and repo are owned by 5.19.op, not by this bundle —" >&2
    echo "        one apt trust anchor, one writer" >&2
    echo "      ⇒ a full run places it a whole section earlier; a --what run" >&2
    echo "        against this bundle alone does not" >&2
    echo "      fix: rhx grove.provision --what 5.19.op --mode apply" >&2
    return 1
  fi

  ####################################################################
  # 3. the app
  #
  # ⚠️ every write below is root's, and `sudo` reads a password from a TERMINAL
  #   - on a duct, which is tmux, the prompt sits on the pane
  #   - it then eats the next command sent as its answer
  #   - `pkg_install` asserts this, so a bundle that reaches root must too
  ####################################################################
  pkg_assert_sudo || return 1

  # the anchor may have landed in this same run, so the index must be re-read
  # before apt can see the repo behind it
  pkg_refresh || true

  pkg_install 1password || return 1

  echo "   • installed: 1password"
}
