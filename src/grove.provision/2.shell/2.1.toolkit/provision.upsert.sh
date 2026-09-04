#!/usr/bin/env bash
# .what = make the shell toolkit EXIST on this machine
# .why the list splits ESSENTIAL vs COMFORT — an absent essential breaks a
#   later bundle and must fail loud; an absent comfort costs a nicety, and a
#   box that lacks one is still converged
# .why `unzip` is essential, though no bundle names it in a body — three
#   later steps unpack a zip and nobody declared the dependency
#   .refs = gotcha.2-1-toolkit.demo=unzip-cascade-and-per-machine-gates, m1
# .why `curl` is essential — fourteen later bundles fetch over https, and
#   with no base-tool bundle the fetch rests on one unrelated side effect
#   (rule.require.bundle-as-sole-declaration)
# .why `gnupg` is not guarded at its three call sites instead — a guard at
#   each is three writers on one fact (rule.forbid.two-writers-on-one-artifact)
# .why `pv` is essential — `git backup` hard fail-fasts with no `pv`, so an
#   absent `pv` blocks a disaster-recovery tool, never a mere nicety
#   .refs = uladkasach/dev-env-setup#121
# .why `xclip` installs on a HEADLESS box — a per-machine list is a second
#   list to keep, and every prior "has a screen" gate confused EFFECT with HOLD
#   .refs = gotcha.2-1-toolkit.demo=unzip-cascade-and-per-machine-gates, m2
# guarantee:
#   - idempotent: apt reports a present package and returns 0

grove_provision_2_1_toolkit_provision_upsert() {
  # 1. the essentials: jq/tree/ripgrep (json, dir view, search), unzip (fnm,
  #   nerd fonts, aws cli v2), curl (14 later fetches), gnupg (3 dearmor sites),
  #   pv (git backup's progress/archive pipe)
  if ! pkg_install jq tree unzip ripgrep curl gnupg pv; then
    echo "   ✋ an essential toolkit package did not install" >&2
    echo "      ⇒ these are not niceties: unzip alone gates fnm, the nerd fonts," >&2
    echo "        and the aws cli; pv gates git backup — and each absence reads" >&2
    echo "        as an unrelated failure rather than as an absent 200kb tool" >&2
    echo "      read why: sudo apt-get install jq tree unzip ripgrep curl gnupg pv" >&2
    return 1
  fi

  # 2. the comforts — xclip, fzf. tolerates its own failure: a box that
  #   lacks either is still converged (rule.forbid.failhide, other side)
  if pkg_install xclip fzf; then
    echo "   • toolkit installed — jq, tree, unzip, ripgrep, curl, gnupg, pv, xclip, fzf"
  else
    echo "   • toolkit installed — jq, tree, unzip, ripgrep, curl, gnupg, pv"
    echo "   🌙 xclip and/or fzf are absent from this box's repos (see above)"
    echo "      these are comforts, so the run continues; capability is unaffected"
  fi
}
