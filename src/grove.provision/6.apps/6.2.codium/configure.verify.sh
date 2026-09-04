#!/usr/bin/env bash
######################################################################
# .what
#   - prove codium reads microsoft's marketplace
#   - prove it holds the sync-settings extension
#   - prove it carries THIS checkout's sync config
#
# .the config is compared by CONTENT, never by presence
#   - a settings.yml from an older commit is a file that exists
#   - so a presence check passes on a box that syncs the wrong profile
#   - `4.5.nvim.configure.verify` makes the same claim about init.lua
#   - (rule.require.judge-declared-state-not-live-state)
#
# guarantee
#   - READ-ONLY: it observes and mutates no state
######################################################################

grove_provision_6_2_codium_configure_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no codium on $GROVE_ENV_SERVER to configure"
    return 0
  fi

  if ! command -v codium >/dev/null 2>&1; then
    echo "   🌙 codium is absent, so its config cannot be observed."
    echo "      provision.verify names that defect and its fix"
    return 0
  fi

  local failed=0

  ####################################################################
  # 1. the marketplace override
  ####################################################################
  local product="$HOME/.config/VSCodium/product.json"
  if [[ -r "$product" ]] && grep -F 'marketplace.visualstudio.com' "$product" >/dev/null; then
    echo "   • codium points at the microsoft marketplace ✔"
  else
    echo "   ✋ the marketplace override is ABSENT from $product" >&2
    echo "      ⇒ codium falls back to open-vsx, where several extensions this" >&2
    echo "        repo expects simply do not exist — which reads as a broken" >&2
    echo "        extension rather than as a wrong registry" >&2
    echo "      fix: rhx grove.provision --what 6.2.codium --mode apply \\" >&2
    echo "             --include codium" >&2
    failed=1
  fi

  ####################################################################
  # 2. the sync-settings extension is installed
  #
  #   - no `-q`, because under the driver's `pipefail` it would SIGPIPE codium
  #   - (gotcha.pipefail-grep-q)
  ####################################################################
  if timeout -k 10 30 codium --list-extensions </dev/null 2>/dev/null \
    | grep -Fix 'zokugun.sync-settings' >/dev/null; then
    echo "   • the sync-settings extension is installed ✔"
  else
    echo "   ✋ zokugun.sync-settings is NOT installed (or the probe timed out)" >&2
    echo "      ⇒ the settings this repo declares have no client to load them" >&2
    echo "      fix: rhx grove.provision --what 6.2.codium --mode apply \\" >&2
    echo "             --include codium" >&2
    failed=1
  fi

  ####################################################################
  # 3. the installed sync config matches THIS checkout
  ####################################################################
  local src="$GROVE_SRC/../codium/sync.settings.yml"
  local dst="$HOME/.config/VSCodium/User/globalStorage/zokugun.sync-settings/settings.yml"

  if [[ ! -f "$dst" ]]; then
    echo "   ✋ no sync-settings config at $dst" >&2
    echo "      fix: rhx grove.provision --what 6.2.codium --mode apply \\" >&2
    echo "             --include codium" >&2
    failed=1
  elif [[ ! -f "$src" ]]; then
    echo "   🌙 a config is installed, but this checkout holds no $src to"
    echo "      compare it against"
  elif diff -q "$src" "$dst" >/dev/null 2>&1; then
    echo "   • the installed sync config matches this checkout ✔"
  else
    echo "   ✋ the installed sync config DIFFERS from this checkout" >&2
    echo "      ⇒ the file exists, so a presence check would pass while codium" >&2
    echo "        syncs an older profile than this commit declares" >&2
    echo "      read the drift: diff $src $dst" >&2
    echo "      fix: rhx grove.provision --what 6.2.codium --mode apply \\" >&2
    echo "             --include codium" >&2
    failed=1
  fi

  return $failed
}
