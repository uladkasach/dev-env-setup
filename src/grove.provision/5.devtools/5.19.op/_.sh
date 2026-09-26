#!/usr/bin/env bash
######################################################################
# .what = `op`, the 1password cli — on EVERY box, as a fact not a preference
#
# .why no decline and no opt-in
#   - `op` backs keyrack's `1password` vault, reached by BARE NAME
#   - its absence FAILHIDES as a locked vault (`rule.forbid.failhide`)
#   - every caller is a PROGRAM, and a program cannot pass `--include`
#   - it also owns the 1password apt anchor `6.5.onepassword` reads, so that
#     anchor has ONE writer (`rule.forbid.two-writers-on-one-artifact`)
#
# .refs = gotcha.5-19-op.demo=keyrack-vault-backend.md — every measurement
# usage:
#   rhx grove.provision --what 5.19.op --mode apply
######################################################################

# the apt anchor — ONE declaration, read by both phases. ⚠️ its fingerprint is a WIRE READ (.refs)
GROVE_OP_KEY_URL="https://downloads.1password.com/linux/keys/1password.asc"
GROVE_OP_KEY_FPR="3FEF9748469ADBE15DA7CA80AC2D62742012EA22"
GROVE_OP_KEYFILE="/usr/share/keyrings/1password-archive-keyring.gpg"

# .what = the repo line apt must hold, for THIS box's architecture
# .why  = ONE renderer — upsert WRITES and verify READS one text, and two
#         copies drift (`gotcha.a-check-that-cries-wolf`, m.9)
grove_provision_5_19_op_repo_line() {
  local arch
  arch="$(dpkg --print-architecture)" || return 1
  echo "deb [arch=$arch signed-by=$GROVE_OP_KEYFILE] https://downloads.1password.com/linux/debian/$arch stable main"
}

grove_provision_5_19_op() {
  bundle.upgrade 5.19.op.provision.upsert
  bundle.upgrade 5.19.op.provision.verify
}
