#!/usr/bin/env bash
######################################################################
# .what = make `git` EXIST on this machine
#
# .why a one-line phase earns its own file
#   - folded into configure, one phase would claim two kinds of fact
#   - "the binary exists" and "the binary is shaped" fail for different reasons
#   - they are repaired by different acts
#   - ⇒ they get separate verdicts (term=provision, term=configure)
#
# guarantee:
#   - idempotent: apt reports a present package and returns 0
######################################################################

grove_provision_2_2_git_provision_upsert() {
  if ! pkg_install git; then
    echo "   ✋ git did not install" >&2
    echo "      ⇒ nearly every later bundle assumes it: tpm is a git clone," >&2
    echo "        the nvim plugin managers are git clones, and this repo's own" >&2
    echo "        pull is one. so the failures land far from here" >&2
    echo "      read why: sudo apt-get install git" >&2
    return 1
  fi
}
