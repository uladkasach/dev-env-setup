#!/usr/bin/env bash
######################################################################
# .what = read an installed firefox extension's own source: list the
#         files inside its .xpi, or print one of them
#
# .why  = "what does this extension do at startup?" is answered by its
#         manifest and background page, which sit zipped inside the
#         profile's `extensions/<id>.xpi`. no unzip is on the box, so
#         python's zipfile reads it
#
# usage:
#   firefox.addon.source.get.sh --id FirefoxColor@mozilla.com
#   firefox.addon.source.get.sh --id FirefoxColor@mozilla.com --path manifest.json
#   firefox.addon.source.get.sh --id FirefoxColor@mozilla.com --path background.js --grep 'theme'
#
# guarantee:
#   - read-only: never writes the profile
#   - exit 0 = answered, 1 = malfunction, 2 = bad input or no such addon
######################################################################

set -uo pipefail

# parse flags; rhx injects its own flags, so scan every arg
addon_id=""; path=""; grep_re=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) addon_id="${2:-}"; shift 2 ;;
    --path) path="${2:-}"; shift 2 ;;
    --grep) grep_re="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ -z "$addon_id" ]]; then
  echo "✋ ConstraintError: --id is required (e.g. --id FirefoxColor@mozilla.com)" >&2
  exit 2
fi

# find the default-release profile; its dir name is generated
ff_root="$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"
profile_dir="$(grep -oP 'Path=\K.*default-release' "$ff_root/profiles.ini" 2>/dev/null)"
xpi="$ff_root/$profile_dir/extensions/$addon_id.xpi"
if [[ -z "$profile_dir" || ! -f "$xpi" ]]; then
  echo "✋ ConstraintError: no xpi for $addon_id in the default-release profile" >&2
  echo "   see every id: rhx firefox.addons.get" >&2
  exit 2
fi

echo "🦊 firefox.addon.source.get --id $addon_id${path:+ --path $path}${grep_re:+ --grep $grep_re}"

XPI="$xpi" FILE="$path" GREP="$grep_re" python3 - <<'PY'
import os, re, zipfile
z = zipfile.ZipFile(os.environ["XPI"])
path, pat = os.environ["FILE"], os.environ["GREP"]
if not path:
    for n in z.namelist(): print(f"   ├─ {n}")
    raise SystemExit(0)
if path not in z.namelist():
    raise SystemExit(f"no file '{path}' in the xpi")
text = z.read(path).decode("utf-8", "replace")
if not pat:
    print(text); raise SystemExit(0)
# grep mode: print each match with ~200 chars of context (bundles are one long line)
for m in re.finditer(pat, text):
    s, e = max(0, m.start() - 200), min(len(text), m.end() + 200)
    print(f"   ├─ @{m.start()}: …{text[s:e]}…")
PY
[[ $? -eq 0 ]] || { echo "💥 MalfunctionError: could not read $xpi" >&2; exit 1; }
