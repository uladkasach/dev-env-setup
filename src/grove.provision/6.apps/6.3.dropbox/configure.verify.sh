#!/usr/bin/env bash
######################################################################
# .what = prove each dropbox tray icon in the newest dist has a current copy in
#         the user's hicolor theme
#
# guarantee:
#   - READ-ONLY
######################################################################

grove_provision_6_3_dropbox_configure_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no screen on $GROVE_ENV_SERVER, so no tray icon"
    return 0
  fi

  local src dst rel stale=() total=0
  src="$(grove_provision_6_3_dropbox_icons_src)"
  dst="$(grove_provision_6_3_dropbox_icons_dst)"
  if [[ -z "$src" ]]; then
    echo "   🌙 no dropbox dist yet — signed out, or never started; no icon to place"
    return 0
  fi

  while IFS= read -r rel; do
    total=$(( total + 1 ))
    cmp -s "$src/$rel" "$dst/$rel" || stale+=("$rel")
  done < <(grove_provision_6_3_dropbox_icons_list "$src")

  if [[ "$total" -eq 0 ]]; then
    echo "   ✋ ConstraintError: $src holds no dropboxstatus-*.png — dropbox moved its icons" >&2
    echo "      ⇒ the panel draws a broken dropbox icon until this bundle reads the new place" >&2
    return 1
  fi
  if [[ ${#stale[@]} -gt 0 ]]; then
    echo "   ✋ ConstraintError: ${#stale[@]} of $total dropbox tray icons are absent or stale in $dst" >&2
    echo "      ⇒ the panel cannot find them by name, so it draws a broken icon" >&2
    echo "      fix: rhx grove.provision --what 6.3.dropbox --include dropbox --mode apply" >&2
    return 1
  fi
  echo "   • dropbox tray icons ($total) current in the hicolor theme ✔"
}
