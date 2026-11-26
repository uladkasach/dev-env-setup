#!/usr/bin/env bash
######################################################################
# .what = read the extensions firefox holds — id, version, package path —
#         and, on demand, search inside one extension's package
#
# .why  = "can a policy configure this extension?" is a question about the
#         extension's OWN code: firefox hands `3rdparty` policy values only
#         to an extension that reads `storage.managed`. the package (.xpi) is
#         a zip in the profile, so the answer is a grep away, and this keeps
#         that grep a repeatable read rather than an ad-hoc unzip
#
# usage:
#   rhx firefox.addon.get                                   # list every addon
#   rhx firefox.addon.get --name 1password                  # one addon's row
#   rhx firefox.addon.get --name 1password --grep 'storage\.managed'
#
# guarantee:
#   - read-only: never writes the profile
#   - reads the flatpak profile (the build this repo installs)
#   - exit 0 = answered, 1 = malfunction, 2 = constraint (no profile, no match)
######################################################################

set -uo pipefail

NAME=""
GREP=""
FF_ROOT="$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="${2:-}"; shift 2 ;;
    --grep) GREP="${2:-}"; shift 2 ;;
    --help|-h)
      echo "firefox.addon.get — list firefox addons; search inside one with --grep"
      echo "  usage: rhx firefox.addon.get [--name <part of its name>] [--grep <regex>]"
      exit 0 ;;
    --repo|--role|--skill) shift 2 ;;
    *) echo "✋ ConstraintError: unknown arg: $1" >&2; exit 2 ;;
  esac
done

for tool in jq unzip; do
  command -v "$tool" >/dev/null 2>&1 || { echo "✋ ConstraintError: $tool is not on PATH" >&2; exit 2; }
done

# the profile firefox LAUNCHES is the [Install…] Default=; a profile's Path need
# not end in "default-release" (a "Profile 1" dir is common), so never match on it
ini="$FF_ROOT/profiles.ini"
profile_dir="$(awk -F= '/^\[Install/ { on = 1; next } /^\[/ { on = 0 } on && $1 == "Default" { print $2; exit }' "$ini" 2>/dev/null)"
[[ -n "$profile_dir" ]] || profile_dir="$(awk -F= '/^\[/ { p = "" } $1 == "Path" { p = $2 } $1 == "Default" && $2 == "1" { print p; exit }' "$ini" 2>/dev/null)"
if [[ -z "$profile_dir" ]]; then
  echo "✋ ConstraintError: no firefox profile at $FF_ROOT" >&2
  echo "   ⇒ firefox has never been started on this box" >&2
  exit 2
fi
profile="$FF_ROOT/$profile_dir"
addons="$profile/extensions.json"
[[ -r "$addons" ]] || { echo "✋ ConstraintError: no extensions.json in $profile" >&2; exit 2; }

# one row per non-builtin addon: name | id | version | path | location
rows="$(jq -r --arg n "${NAME,,}" '
  .addons[]
  | select((.location | startswith("app-builtin")) | not)
  | select(.location != "app-system-defaults")
  | select(($n == "") or ((.defaultLocale.name // "") | ascii_downcase | contains($n)))
  | [(.defaultLocale.name // "?"), .id, .version, (.path // "?"), .location]
  | join("|")' "$addons")" || { echo "💥 MalfunctionError: could not parse $addons" >&2; exit 1; }

if [[ -z "$rows" ]]; then
  echo "✋ ConstraintError: no addon matches '${NAME}'" >&2
  exit 2
fi

echo "🦊 firefox.addon.get${NAME:+ --name $NAME}${GREP:+ --grep '$GREP'}"
echo "   └─ profile: $profile"
while IFS='|' read -r n id ver path loc; do
  echo ""
  echo "   $n"
  echo "   ├─ id:       $id"
  echo "   ├─ version:  $ver"
  echo "   ├─ location: $loc"
  echo "   └─ package:  $path"
done <<<"$rows"

[[ -n "$GREP" ]] || exit 0

# the search needs exactly one package
if [[ "$(wc -l <<<"$rows")" -ne 1 ]]; then
  echo "" >&2
  echo "✋ ConstraintError: --grep needs one addon; narrow --name" >&2
  exit 2
fi
xpi="$(cut -d'|' -f4 <<<"$rows")"
[[ -r "$xpi" ]] || { echo "✋ ConstraintError: package unreadable: $xpi" >&2; exit 2; }

echo ""
echo "   🔭 '$GREP' inside the package"
hits=0
while IFS= read -r member; do
  [[ "$member" == */ ]] && continue
  found="$(timeout 30 unzip -p "$xpi" "$member" 2>/dev/null | grep -oE ".{0,80}${GREP}.{0,80}" | head -5)"
  [[ -n "$found" ]] || continue
  hits=$(( hits + 1 ))
  echo "      ├─ $member"
  while IFS= read -r line; do echo "      │    $line"; done <<<"$found"
done < <(timeout 30 unzip -Z1 "$xpi")

if [[ "$hits" -eq 0 ]]; then
  echo "      └─ no member of the package matches"
else
  echo "      └─ $hits member(s) match"
fi
exit 0
