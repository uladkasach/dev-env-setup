#!/usr/bin/env bash
######################################################################
# .what = prove each essential toolkit command RESOLVES, and report on the comforts
#
# .why the check is `command -v` and not `dpkg -s`
#   - a package can be installed while its binary is unreachable
#   - a broken PATH, a half-configured dpkg, or a name that installs another binary
#   - every caller in this repo reaches these tools by NAME
#   - ⇒ the claim worth an assertion is "the name resolves"
#
# .why an absent COMFORT is a 🌙 and an absent ESSENTIAL is a ✋
#   - it mirrors the upsert exactly
#   - a comfort that failed to install there did not fail the run
#   - ⇒ a verify stricter than its upsert reports owed work no upsert will ever do
#   - that is a red line on every run forever
#
# guarantee:
#   - READ-ONLY. it resolves names and repairs no state
#
# exit:
#   0 = every essential resolves
#   1 = an essential is unreachable, and which is named
######################################################################

grove_provision_2_1_toolkit_provision_verify() {
  local failed=0

  ####################################################################
  # 1. the essentials — each absence is named with what it costs
  ####################################################################
  local tool
  local absent=()
  # ⚠️ this list must mirror the upsert's
  #   - 📜 `gnupg` was added there and not here for one apply
  #   - ⇒ the box declared a fact no phase would ever re-check
  #   - (rule.require.upgrade-entries-verify-themselves)
  for tool in jq tree unzip rg curl gpg pv; do
    command -v "$tool" >/dev/null 2>&1 || absent+=("$tool")
  done

  if [[ "${#absent[@]}" -eq 0 ]]; then
    echo "   • toolkit essentials resolve — jq, tree, unzip, rg, curl, gpg, pv ✔"
  else
    echo "   ✋ an essential toolkit command does NOT resolve: ${absent[*]}" >&2
    echo "      ⇒ each of these is depended on by NAME, so the failure surfaces" >&2
    echo "        wherever the caller lives — never here. an absent unzip reads" >&2
    echo "        as 'pnpm is broken'; an absent rg reads as 'nvim search is dead';" >&2
    echo "        an absent pv breaks git backup" >&2
    echo "      note: two names differ from their package — ripgrep ships 'rg'," >&2
    echo "        and gnupg ships 'gpg'" >&2
    echo "      fix: rhx grove.provision --what 2.1.toolkit --mode apply" >&2
    failed=$(( failed + 1 ))
  fi

  ####################################################################
  # 2. the comforts — reported, never asserted
  ####################################################################
  local comfort_absent=()
  for tool in xclip fzf; do
    command -v "$tool" >/dev/null 2>&1 || comfort_absent+=("$tool")
  done

  if [[ "${#comfort_absent[@]}" -eq 0 ]]; then
    echo "   • toolkit comforts resolve — xclip, fzf ✔"
  else
    echo "   🌙 a toolkit comfort does not resolve: ${comfort_absent[*]}"
    echo "      capability is unaffected; only convenience is"
  fi

  [[ "$failed" -eq 0 ]] || return 1
}
