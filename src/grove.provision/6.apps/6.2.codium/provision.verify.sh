#!/usr/bin/env bash
######################################################################
# .what = prove codium is on PATH, and that its repo is declared ONCE
#
# ⚠️ .why the duplicate-repo claim earns its own line
#         the old installer appended its repo line on every run. a box that was
#         set up twice carries the entry twice, and apt then prints a
#         "Target Packages is configured multiple times" complaint on EVERY
#         `apt update` from then on — noise that trains a human to skim apt's
#         output, which is where real key and signature errors also appear.
#
#         codium works fine in that state, so a presence-only check reports the
#         box healthy while it degrades every future package operation.
#
# guarantee:
#   - READ-ONLY. it observes; it mutates no state
######################################################################

grove_provision_6_2_codium_provision_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no screen on $GROVE_ENV_SERVER, so no GUI editor"
    echo "      is expected here"
    return 0
  fi

  local failed=0

  ####################################################################
  # 1. the binary
  ####################################################################
  if command -v codium >/dev/null 2>&1; then
    echo "   • codium is on PATH ✔ ($(codium --version 2>/dev/null | head -1))"
  else
    echo "   ✋ codium is absent from PATH" >&2
    echo "      ⇒ this box has no GUI editor, and the sync-settings config this" >&2
    echo "        repo declares has no client to load it" >&2
    echo "      fix: rhx grove.provision --what 6.2.codium --mode apply \\" >&2
    echo "             --include codium" >&2
    return 1
  fi

  ####################################################################
  # 2. the repo is declared exactly once
  #
  # .why no -q: under the driver's `pipefail` it would exit on match and SIGPIPE
  #      grep's own producer (gotcha.pipefail-grep-q)
  ####################################################################
  local hits
  hits="$(grep -rl 'paulcarroty.gitlab.io/vscodium-deb-rpm-repo' \
    /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | sort -u | wc -l)"

  local lines
  lines="$(grep -rh 'paulcarroty.gitlab.io/vscodium-deb-rpm-repo' \
    /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | grep -c . || true)"

  if [[ "${lines:-0}" -eq 1 ]]; then
    echo "   • the vscodium apt repo is declared once ✔"
  elif [[ "${lines:-0}" -eq 0 ]]; then
    echo "   🌙 codium is installed, but its apt repo is no longer declared"
    echo "      it will not receive updates. re-apply to restore the repo"
  else
    echo "   ✋ the vscodium apt repo is declared $lines times across $hits files" >&2
    echo "      ⇒ apt complains 'configured multiple times' on EVERY update from" >&2
    echo "        now on, which trains a reader to skim the output where real key" >&2
    echo "        and signature errors also appear" >&2
    echo "      read them: grep -r vscodium /etc/apt/sources.list.d/" >&2
    echo "      fix: leave ONE line, then re-run this verify" >&2
    failed=1
  fi

  ####################################################################
  # 3. the key is SCOPED — no copy left in the blanket-trust directory
  #
  # ⚠️ .why this claim was absent, and what its absence cost
  #      the upsert moved this key from `/etc/apt/trusted.gpg.d/` (trusted for
  #      EVERY repo) to `/etc/apt/keyrings/` + `signed-by=`. that is the whole
  #      security purpose of the bundle — and until now the verify asked only
  #      about the repo LINE, never the key's location.
  #
  #      so a box provisioned by the old installer kept the blanket-trust copy
  #      and this phase printed ✔ at it, on every run, forever. a verify that
  #      cannot disprove the bundle's central claim is not a weak check; it is
  #      the claim made without evidence (rule.require.upgrade-entries-verify-
  #      themselves — driven is not proven).
  ####################################################################
  local keyfile_legacy="/etc/apt/trusted.gpg.d/vscodium.gpg"
  if [[ -f "$keyfile_legacy" ]]; then
    echo "   ✋ the vscodium key still sits in /etc/apt/trusted.gpg.d/" >&2
    echo "      ⇒ a key there is trusted for EVERY apt repo, so this publisher's" >&2
    echo "        signature can vouch for a package that names ANY origin —" >&2
    echo "        debian, ubuntu, docker, github" >&2
    echo "      ⇒ this is the exact flaw the scoped keyfile exists to close, and" >&2
    echo "        the scoped copy does NOT undo it — the old file must go" >&2
    echo "      fix: rhx grove.provision --what 6.2.codium --mode apply \\" >&2
    echo "             --include codium" >&2
    failed=1
  elif [[ -f /etc/apt/keyrings/vscodium.gpg ]]; then
    echo "   • the vscodium key is scoped to its own repo ✔"
  else
    echo "   🌙 no vscodium key in either location, so its scope cannot be judged"
  fi

  return $failed
}
