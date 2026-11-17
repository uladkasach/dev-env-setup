#!/usr/bin/env bash
######################################################################
# .what = copy dropbox's tray icons into the user's hicolor theme, so a panel
#         that looks icons up by name finds them
#
# .why  cosmic's tray ignores the `IconThemePath` dropbox sends, so the icon it
#         names (`dropboxstatus-idle`) resolved to naught and drew broken
#
# .why  a copy, and not a symlink
#         the dist dir carries its version in its name and is replaced on each
#         dropbox update; a link into it dangles the day dropbox updates. a copy
#         holds, and the next apply refreshes it from the newest dist
#
# guarantee:
#   - idempotent: a file lands only where it differs
#   - no root: every write lands in $HOME
######################################################################

grove_provision_6_3_dropbox_configure_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no screen on $GROVE_ENV_SERVER, so no tray icon"
    return 0
  fi

  local src dst rel copied=0 total=0
  src="$(grove_provision_6_3_dropbox_icons_src)"
  dst="$(grove_provision_6_3_dropbox_icons_dst)"
  if [[ -z "$src" ]]; then
    echo "   🌙 no dropbox dist yet — the daemon downloads it at first sign-in; apply again after"
    return 0
  fi

  while IFS= read -r rel; do
    total=$(( total + 1 ))
    cmp -s "$src/$rel" "$dst/$rel" && continue
    if ! install -D -m 0644 "$src/$rel" "$dst/$rel"; then
      echo "   💥 MalfunctionError: could not write $dst/$rel" >&2
      return 1
    fi
    copied=$(( copied + 1 ))
  done < <(grove_provision_6_3_dropbox_icons_list "$src")

  if [[ "$total" -eq 0 ]]; then
    echo "   💥 MalfunctionError: $src holds no dropboxstatus-*.png — dropbox moved its icons" >&2
    return 1
  fi
  if [[ "$copied" -eq 0 ]]; then
    echo "   • tray icons current ($total) ✔"
  else
    echo "   • tray icons declared: $copied of $total into $dst"
    echo "     ⇒ dropbox re-reads its icon at its next state change; a quit + restart of dropbox shows it at once"
  fi
}
