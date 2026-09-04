#!/usr/bin/env bash
######################################################################
# .what = prove `git` resolves on PATH
#
# guarantee:
#   - READ-ONLY
#
# exit:
#   0 = git resolves
#   1 = it does not
######################################################################

grove_provision_2_2_git_provision_verify() {
  if command -v git >/dev/null 2>&1; then
    echo "   • git resolves ($(git --version 2>/dev/null | awk '{print $3}')) ✔"
    return 0
  fi

  echo "   ✋ git does not resolve on PATH" >&2
  echo "      ⇒ the configure phase below writes 'git config --global', so it" >&2
  echo "        cannot run at all — and every later git clone fails too" >&2
  echo "      fix: rhx grove.provision --what 2.2.git --mode apply" >&2
  return 1
}
