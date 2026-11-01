#!/usr/bin/env bash
######################################################################
# .what = show what firefox caches for one extension in
#         `addonStartup.json.lz4` — its startup data, which is where a
#         dynamic theme (`browser.theme.update`) is kept as `lastTheme`
#
# .why  = an extension theme like firefox-color's is re-applied at start
#         from THIS cache, not from the extension's own storage. so when
#         the colors vanish on a restart, the question is whether the
#         cache still holds `lastTheme`. the file is mozlz4 (lz4 block +
#         a magic header), which no tool on the box reads, so python does
#
# usage:
#   firefox.addon.startup.get.sh --id FirefoxColor@mozilla.com
#
# guarantee:
#   - read-only: never writes the profile
#   - exit 0 = answered, 1 = malfunction, 2 = bad input or no profile
######################################################################

set -uo pipefail

# parse --id; rhx injects its own flags, so scan every arg
addon_id=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) addon_id="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ -z "$addon_id" ]]; then
  echo "✋ ConstraintError: --id is required (e.g. --id FirefoxColor@mozilla.com)" >&2
  echo "   see every id: rhx firefox.addons.get" >&2
  exit 2
fi

# find the default-release profile; its dir name is generated
ff_root="$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"
profile_dir="$(grep -oP 'Path=\K.*default-release' "$ff_root/profiles.ini" 2>/dev/null)"
if [[ -z "$profile_dir" ]]; then
  echo "✋ ConstraintError: no default-release profile in $ff_root/profiles.ini" >&2
  exit 2
fi
cache="$ff_root/$profile_dir/addonStartup.json.lz4"
if [[ ! -f "$cache" ]]; then
  echo "✋ ConstraintError: no addonStartup.json.lz4 in $profile_dir" >&2
  exit 2
fi

echo "🦊 firefox.addon.startup.get --id $addon_id"
echo "   ├─ cache: $profile_dir/addonStartup.json.lz4  ($(date -r "$cache" '+%F %T'))"

# decode mozlz4 and print this addon's entry; python stdlib only
CACHE="$cache" ADDON_ID="$addon_id" python3 - <<'PY'
import os, json

def lz4_block(src, size):
    # raw lz4 block decoder
    out = bytearray(); i = 0
    while i < len(src):
        tok = src[i]; i += 1
        ln = tok >> 4
        if ln == 15:
            while True:
                b = src[i]; i += 1; ln += b
                if b != 255: break
        out += src[i:i+ln]; i += ln
        if i >= len(src): break
        off = src[i] | (src[i+1] << 8); i += 2
        ml = tok & 15
        if ml == 15:
            while True:
                b = src[i]; i += 1; ml += b
                if b != 255: break
        ml += 4
        for _ in range(ml): out.append(out[-off])
    return bytes(out[:size])

raw = open(os.environ["CACHE"], "rb").read()
if raw[:8] != b"mozLz40\0":
    raise SystemExit("not a mozlz4 file")
doc = json.loads(lz4_block(raw[12:], int.from_bytes(raw[8:12], "little")))

addon = os.environ["ADDON_ID"]
entry = None
for loc, body in doc.items():
    if addon in (body.get("addons") or {}):
        entry = (loc, body["addons"][addon]); break
if not entry:
    print("   └─ (this addon is absent from the startup cache)")
    raise SystemExit(0)

loc, a = entry
sd = a.get("startupData") or {}
print(f"   ├─ location: {loc}")
print(f"   ├─ enabled: {a.get('enabled')}  version: {a.get('version')}")
print(f"   └─ startupData keys: {sorted(sd.keys()) or '(none)'}")
if "lastTheme" in sd:
    print(f"      └─ lastTheme: {json.dumps(sd['lastTheme'])[:600]}")
else:
    print("      └─ lastTheme: ABSENT — firefox has no theme to restore at start")
PY
if [[ $? -ne 0 ]]; then
  echo "💥 MalfunctionError: could not decode $cache" >&2
  exit 1
fi
