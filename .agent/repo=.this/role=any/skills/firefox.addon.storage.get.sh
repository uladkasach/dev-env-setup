#!/usr/bin/env bash
######################################################################
# .what = dump what one firefox extension has saved in its storage:
#         storage.local (indexeddb) and storage.sync (storage-sync-v2)
#
# .why  = an extension like firefox-color keeps its state (the applied
#         theme) in storage no file exposes as text. to ask "did the
#         saved state survive?" the two stores must be decoded, and no
#         sqlite3 cli is on the box, so python's stdlib does it
#
# usage:
#   firefox.addon.storage.get.sh --id FirefoxColor@mozilla.com
#
# guarantee:
#   - read-only: opens each sqlite in immutable mode, never writes
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

echo "🦊 firefox.addon.storage.get --id $addon_id"
echo "   ├─ profile: $profile_dir"

# decode both stores; python stdlib only (sqlite3 + a raw snappy decoder)
PROFILE="$ff_root/$profile_dir" ADDON_ID="$addon_id" python3 - <<'PY'
import os, re, json, glob, sqlite3, datetime

profile = os.environ["PROFILE"]
addon = os.environ["ADDON_ID"]

def ro(path):
    # immutable=1: read without a lock or a write, safe while firefox runs
    return sqlite3.connect(f"file:{path}?immutable=1", uri=True)

def snappy(buf):
    # raw snappy block decoder (firefox compresses idb values with it)
    i, n, shift = 0, 0, 0
    while True:
        b = buf[i]; i += 1
        n |= (b & 0x7f) << shift; shift += 7
        if b < 0x80: break
    out = bytearray()
    while i < len(buf):
        tag = buf[i]; i += 1; kind = tag & 3
        if kind == 0:
            ln = tag >> 2
            if ln >= 60:
                nb = ln - 59; ln = int.from_bytes(buf[i:i+nb], "little"); i += nb
            ln += 1; out += buf[i:i+ln]; i += ln; continue
        if kind == 1:
            ln = ((tag >> 2) & 7) + 4; off = ((tag >> 5) << 8) | buf[i]; i += 1
        elif kind == 2:
            ln = (tag >> 2) + 1; off = int.from_bytes(buf[i:i+2], "little"); i += 2
        else:
            ln = (tag >> 2) + 1; off = int.from_bytes(buf[i:i+4], "little"); i += 4
        for _ in range(ln): out.append(out[-off])
    return bytes(out)

def readable(raw):
    # pull the printable runs out of a structured-clone blob
    txt = raw.decode("latin-1")
    runs = re.findall(r"[\x20-\x7e]{3,}", txt)
    return " | ".join(runs)

# map the addon id to its moz-extension uuid
uuids = {}
with ro(os.path.join(profile, "prefs.js")) if False else open(os.path.join(profile, "prefs.js")) as f:
    for line in f:
        if "extensions.webextensions.uuids" in line:
            raw = line.split(",", 1)[1].rsplit(")", 1)[0].strip()
            uuids = json.loads(json.loads(raw))
uuid = uuids.get(addon)
print(f"   ├─ uuid: {uuid or '(none — addon never started)'}")

# storage.local — indexeddb under storage/default/moz-extension+++<uuid>^userContextId=...
print("   ├─ storage.local (indexeddb)")
found = False
if uuid:
    for db in sorted(glob.glob(os.path.join(profile, "storage/default", f"moz-extension+++{uuid}*", "idb", "*.sqlite"))):
        found = True
        mtime = datetime.datetime.fromtimestamp(os.path.getmtime(db)).isoformat(" ", "seconds")
        print(f"   │  ├─ {os.path.relpath(db, profile)}  (written {mtime})")
        con = ro(db)
        rows = con.execute("select key, data, file_ids from object_data").fetchall()
        print(f"   │  │  └─ {len(rows)} row(s)")
        for key, data, file_ids in rows:
            try:
                val = snappy(data)
            except Exception:
                val = data
            text = readable(val)
            print(f"   │  │     ├─ key={readable(key) or key.hex()}  bytes={len(val)}{'  (external file)' if file_ids else ''}")
            print(f"   │  │     │  {text[:600]}")
if not found:
    print("   │  └─ (no indexeddb for this addon)")

# storage.sync — storage-sync-v2.sqlite, plain json keyed by ext_id
print("   └─ storage.sync (storage-sync-v2.sqlite)")
sync = os.path.join(profile, "storage-sync-v2.sqlite")
if os.path.exists(sync):
    con = ro(sync)
    for table in ("storage_sync_data", "storage_sync_mirror"):
        try:
            rows = con.execute(f"select data from {table} where ext_id = ?", (addon,)).fetchall()
        except sqlite3.Error as e:
            print(f"      ├─ {table}: unreadable ({e})"); continue
        print(f"      ├─ {table}: {len(rows)} row(s)")
        for (data,) in rows:
            print(f"      │  {(data or '')[:600]}")
else:
    print("      └─ (no storage-sync-v2.sqlite)")
PY
status=$?
if [[ $status -ne 0 ]]; then
  echo "💥 MalfunctionError: could not decode the storage for $addon_id" >&2
  exit 1
fi
