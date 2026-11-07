#!/usr/bin/env bash
######################################################################
# .what = read, or set, boolean flags inside one json-string key of a
#         firefox extension's storage.local (e.g. 1password's `config`)
#
# .why  = an extension's options live in storage.local, which no pref,
#         file, or policy reaches. this drives the SAME decoder the
#         1.3.1.firefox bundle uses, so a human can plan a flip by hand
#         and the bundle remains the one declaration
#
# usage:
#   firefox.addon.storage.set.sh --id <addon-id> --key config \
#     --set inlineShowAutomatically=false                      # plan (default)
#   firefox.addon.storage.set.sh ... --mode apply              # write (firefox must be quit)
#
# guarantee:
#   - prints only the named flags, never the json around them
#   - apply refuses while firefox lives (exit 4), so no write races the extension
#   - exit 0 = converged, 1 = malfunction, 2 = bad input, 3 = drift (plan),
#     4 = firefox live, 5 = absent
######################################################################

set -uo pipefail

# parse flags; rhx injects its own flags, so scan every arg
addon_id=""; key=""; mode="plan"; sets=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) addon_id="${2:-}"; shift 2 ;;
    --key) key="${2:-}"; shift 2 ;;
    --set) sets+=(--set "${2:-}"); shift 2 ;;
    --mode) mode="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ -z "$addon_id" || -z "$key" || ${#sets[@]} -eq 0 ]]; then
  echo "✋ ConstraintError: --id, --key, and at least one --set name=true|false are required" >&2
  echo "   e.g. --id '{d634138d-c276-4fc8-924b-40a0ea21d284}' --key config --set inlineSaveEnabled=false" >&2
  exit 2
fi

ff_root="$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"
profile_dir="$(grep -oP 'Path=\K.*default-release' "$ff_root/profiles.ini" 2>/dev/null)"
if [[ -z "$profile_dir" ]]; then
  echo "✋ ConstraintError: no default-release profile in $ff_root/profiles.ini" >&2
  exit 2
fi

repo_root="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
patcher="$repo_root/src/grove.provision/1.system/1.3.browser/1.3.1.firefox/firefox/addon.storage.local.py"

echo "🦊 firefox.addon.storage.set --id $addon_id --key $key --mode $mode"
python3 "$patcher" --profile "$ff_root/$profile_dir" --addon-id "$addon_id" --key "$key" \
  "${sets[@]}" --mode "$mode" | sed 's/^/   ├─ /'
code="${PIPESTATUS[0]}"
echo "   └─ exit $code"
exit "$code"
