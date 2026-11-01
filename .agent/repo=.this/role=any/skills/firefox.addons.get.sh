#!/usr/bin/env bash
######################################################################
# .what = list the addons (extensions + themes) in the flatpak firefox
#         default-release profile, with whether each is active
#
# .why  = the desert palette lives inside the firefox-color extension,
#         so "my firefox lost its colors" is first a question of which
#         addon or theme is active now. `extensions.json` answers it, and
#         the profile dir is generated, so it is read out of profiles.ini
#
# usage:
#   firefox.addons.get.sh
#
# guarantee:
#   - read-only: never writes the profile
#   - exit 0 = answered, 1 = malfunction, 2 = no profile to read
######################################################################

set -uo pipefail

ff_root="$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"

# find the default-release profile; its dir name is generated
profile_dir="$(grep -oP 'Path=\K.*default-release' "$ff_root/profiles.ini" 2>/dev/null)"
if [[ -z "$profile_dir" ]]; then
  echo "✋ ConstraintError: no default-release profile in $ff_root/profiles.ini" >&2
  echo "   fix: start firefox once, so it creates a profile" >&2
  exit 2
fi
addons="$ff_root/$profile_dir/extensions.json"
if [[ ! -f "$addons" ]]; then
  echo "✋ ConstraintError: no extensions.json in $ff_root/$profile_dir" >&2
  exit 2
fi

echo "🦊 firefox.addons.get"
echo "   ├─ profile: $profile_dir"
echo "   └─ addons (extension + theme)"

# one row per addon: active?, type, name, id, last update, disable flags
if ! jq -r '
  .addons[]
  | select(.type == "extension" or .type == "theme")
  | [ (if .active then "✔ active" else "· off   " end),
      .type,
      (.defaultLocale.name // .id),
      .id,
      ((.updateDate // 0) / 1000 | floor | strftime("%Y-%m-%d")),
      (if .userDisabled then "userDisabled" else "" end),
      (if .appDisabled then "appDisabled" else "" end) ]
  | "      ├─ " + (map(select(. != "")) | join("  "))
' "$addons"; then
  echo "💥 MalfunctionError: could not parse $addons" >&2
  exit 1
fi
