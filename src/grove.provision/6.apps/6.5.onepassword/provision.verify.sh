#!/usr/bin/env bash
######################################################################
# .what = prove the desktop vault landed
#
# 🛑 .`op` and the apt anchor are NOT asserted here — `5.19.op` owns both
#   - a claim asserted in two places is two readers on one fact, free to
#     disagree, and the one that disagrees is the one nobody edits
#     (`gotcha.a-check-that-cries-wolf`, m.9)
#   - ⚠️ and the split is not merely tidy: `op` is asserted on EVERY box,
#     where this bundle declines on any box with no screen. to keep the `op`
#     claim here would make it unreachable on exactly the boxes — the
#     headless ones — where keyrack's `1password` vault most needs it
#
# ⚠️ .this verify is the LESS important half, and that is the split's point
#   - the desktop app is visible, so an absent icon is noticed the same day
#   - `op` is invisible until keyrack, `backup_env.sh`, or
#     `util.yubikey.ssh.sh` reaches for it — which is the day a human needs a
#     secret, and no sooner
#   - 📜 that asymmetry hid this tool's absence through a whole migration
#
# guarantee
#   - READ-ONLY: it observes and mutates no state
######################################################################

grove_provision_6_5_onepassword_provision_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no screen on $GROVE_ENV_SERVER, so no vault is expected"
    return 0
  fi

  local failed=0

  ####################################################################
  # 1. the desktop vault
  ####################################################################
  if command -v 1password >/dev/null 2>&1; then
    echo "   • the 1password app is on PATH ✔"
  else
    echo "   ✋ the 1password app is absent from PATH" >&2
    echo "      ⇒ no vault to unlock, so op has no session to borrow even where" >&2
    echo "        op itself is installed" >&2
    echo "      fix: rhx grove.provision --what 6.5.onepassword --mode apply \\" >&2
    echo "             --include onepassword" >&2
    failed=1
  fi

  return $failed
}
