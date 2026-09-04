#!/usr/bin/env bash
######################################################################
# .what = point codium at microsoft's extension marketplace, and declare its
#         sync-settings config
#
# .the marketplace override
#   - vscodium ships with the open-vsx registry
#   - that registry carries a subset of what vscode's marketplace does
#   - an absent extension then reads as "extension broken", not "wrong registry"
#
# ⚠️ .the sync config is copied from $GROVE_SRC
#   - a hardcoded `~/git/more/dev-env-setup/...` installs MAIN's config
#   - ⇒ one run could leave a box configured from two different commits
#   - (howto.install-configs-from-a-worktree)
#
# 🛑 .a phase may NEVER launch the editor, not even to prompt
#   - a bare `codium` opens a window and holds the run until a human closes it
#   - the extension download it would prompt for is a click INSIDE the editor
#   - ⇒ that is a runbook step, so it reads out as one below
#   - (rule.require.one-command-provision)
#
# guarantee
#   - idempotent: both files are DECLARED, so a re-run rewrites identical bytes
#   - BOUNDED: it opens no window and blocks on no human
######################################################################

grove_provision_6_2_codium_configure_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no codium on $GROVE_ENV_SERVER to configure"
    return 0
  fi

  if ! command -v codium >/dev/null 2>&1; then
    echo "   🌙 codium is absent, so there is no client to configure."
    echo "      provision.verify names that defect and its fix"
    return 0
  fi

  ####################################################################
  # 1. the marketplace override — declared, so a re-run is a no-op
  ####################################################################
  local product="$HOME/.config/VSCodium/product.json"
  mkdir -p "$(dirname "$product")" || return 1
  cat > "$product" <<'PRODUCT'
{
  "extensionsGallery": {
    "serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery",
    "cacheUrl": "https://vscode.blob.core.windows.net/gallery/index",
    "itemUrl": "https://marketplace.visualstudio.com/items",
    "controlUrl": "",
    "recommendationsUrl": ""
  }
}
PRODUCT
  echo "   • marketplace override declared → $product"

  ####################################################################
  # 2. the sync-settings extension, then its config
  #
  # .the extension goes FIRST
  #   - it owns the globalStorage directory the config lands in
  #   - so an earlier copy writes into a path the extension then replaces
  #
  # 🛑 .this THIRD-PARTY install carries NO version pin
  #   - `--install-extension x@1.2.3` is valid syntax, so a pin LOOKS available
  #   - `extensions.autoUpdate` defaults to TRUE and no file in `codium/` sets it
  #   - so a version named at install time is overwritten by the next launch
  #   - ⇒ an unenforceable pin reads as coverage and holds no state
  #
  # ⚠️ the control that WOULD hold is two parts, and both must land together
  #      1. `"extensions.autoUpdate": false` in this repo's codium settings
  #      2. the pin here, plus a verify that asks the LIVE extension list
  #   - part 1 changes a human's editor behaviour, and is the human's call
  #   - `6.apps` declines on a grove, so it cannot be proven the usual way
  #   - (rule.require.prove-changes-on-a-grove)
  #
  # .the exposure this leaves, stated plainly
  #   - a marketplace publish reaches this laptop on the next editor launch
  #   - it does NOT reach a grove (define.6-apps-is-laptop-only)
  ####################################################################
  if ! codium --install-extension zokugun.sync-settings --force >/dev/null 2>&1; then
    echo "   ✋ could not install the zokugun.sync-settings extension" >&2
    echo "      ⇒ absent it, the settings this repo declares never reach the" >&2
    echo "        editor, so a fresh box looks configured and behaves default" >&2
    return 1
  fi

  local src="$GROVE_SRC/../codium/sync.settings.yml"
  local dst="$HOME/.config/VSCodium/User/globalStorage/zokugun.sync-settings/settings.yml"

  if [[ ! -f "$src" ]]; then
    echo "   ✋ no sync.settings.yml at $src" >&2
    echo "      ⇒ this run's own checkout is incomplete, so the copy would" >&2
    echo "        silently install whatever was there before" >&2
    return 1
  fi

  mkdir -p "$(dirname "$dst")" || return 1
  cp "$src" "$dst" || return 1
  echo "   • sync-settings config installed → $dst"
  echo "     to pull the settings down, run this INSIDE codium:"
  echo "       Sync Settings: Download (repository -> user)"
}
