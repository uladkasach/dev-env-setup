#!/usr/bin/env bash
######################################################################
# .what = prove the `gh` binary is present
#
# .the AUTH is not checked here
#   - a credential is the configure phase's claim
#   - its own verify makes that claim
#   - this phase asserts only the capability
#   - that is the split the bundle exists to hold (see the ⚠️ in `_.sh`)
#
# guarantee:
#   - READ-ONLY
#
# exit:
#   0 = gh is present
#   1 = it is not
######################################################################

grove_provision_5_4_gh_provision_verify() {
  if command -v gh >/dev/null 2>&1; then
    echo "   • gh present ($(gh --version 2>/dev/null | head -1 | awk '{print $3}')) ✔"
    return 0
  fi

  echo "   ✋ gh is not on PATH" >&2
  echo "      ⇒ ubuntu's archive has no gh, so an absent binary usually means" >&2
  echo "        github's apt source was never added rather than that apt failed" >&2
  echo "      ⇒ the configure phase below cannot give a credential to a binary" >&2
  echo "        that does not exist, so it will report owed work too" >&2
  echo "      fix: rhx grove.provision --what 5.4.gh --mode apply" >&2
  return 1
}
