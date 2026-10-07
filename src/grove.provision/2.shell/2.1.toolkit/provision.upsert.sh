#!/usr/bin/env bash
# .what = make the shell toolkit EXIST on this machine
# .why the list splits ESSENTIAL vs COMFORT — an absent essential costs a
#   CAPABILITY and must fail loud; an absent comfort costs a nicety, and a
#   box that lacks one is still converged
# .why `unzip`, `curl`, `gnupg`, `pv` are essential — each gates a later bundle
#   (fnm, 14 fetches, 3 dearmors, `git backup`) whose failure reads as unrelated
# .why `age` is essential though it gates no bundle — its caller is a HUMAN.
#   ⚠️ it is NOT keyrack's: the rack uses the `age-encryption` npm library
#   (`5.3.brains`). apt serves it on both box classes (jammy 1.0.0, 2026-09-24)
# .why 🛑 `yq` is NOT here: apt serves it on noble and not on jammy, so it is
#   its own bundle (`5.17.yq`) with one pinned binary
# .why `xclip` installs on a HEADLESS box — a per-machine list is a second list
# .refs = gotcha.2-1-toolkit.demo=unzip-cascade-and-per-machine-gates, m1-m3
# guarantee:
#   - idempotent: apt reports a present package and returns 0

grove_provision_2_1_toolkit_provision_upsert() {
  # 1. the essentials: jq/tree/ripgrep (json, dir view, search), unzip
  #   (fnm, nerd fonts, aws cli v2), curl (14 later fetches), gnupg (3 dearmor
  #   sites), pv (git backup's progress/archive pipe), age (a human's file
  #   encryption). ⚠️ EVERY box class must carry each
  if ! pkg_install jq tree unzip ripgrep curl gnupg pv age; then
    echo "   ✋ an essential toolkit package did not install" >&2
    echo "      ⇒ these are not niceties: unzip alone gates fnm, the nerd fonts," >&2
    echo "        and the aws cli; pv gates git backup — and each absence reads" >&2
    echo "        as an unrelated failure rather than as an absent 200kb tool" >&2
    echo "      read why: sudo apt-get install jq tree unzip ripgrep curl gnupg pv age" >&2
    return 1
  fi

  # 2. the comforts — xclip, fzf, iw. tolerates its own failure: a box that
  #   lacks one is still converged (rule.forbid.failhide, other side)
  #   - iw reads the radio's live power-save state for `network.wifi.probe`;
  #     without it the probe reports that rung unread, and no capability is lost
  if pkg_install xclip fzf iw; then
    echo "   • toolkit installed — jq, tree, unzip, ripgrep, curl, gnupg, pv, age, xclip, fzf, iw"
  else
    echo "   • toolkit installed — jq, tree, unzip, ripgrep, curl, gnupg, pv, age"
    echo "   🌙 xclip, fzf, and/or iw are absent from this box's repos (see above)"
    echo "      these are comforts, so the run continues; capability is unaffected"
  fi
}
