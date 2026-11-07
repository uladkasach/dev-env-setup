#!/usr/bin/env bash
######################################################################
# .what = map what one firefox extension has saved in its storage:
#         storage.local and every indexeddb the extension owns, plus
#         storage.sync (storage-sync-v2)
#
# .why  = an extension keeps its state (a theme, its settings) in storage
#         no file exposes as text. to ask "where is X persisted?" the
#         stores must be decoded, and no sqlite3 cli is on the box, so
#         python's stdlib does it
#
# 🛑 .why values are NOT printed by default
#   - a password manager keeps account secrets in the SAME storage as its
#     settings (measured 2026-11-03: 1password's idb held the account's
#     secret key in plain structured-clone text)
#   - a dump of every value puts those secrets into a terminal, a log, and
#     any tool that captures stdout
#   - ⇒ the default is a MAP: db → object store → key → size, no values
#   - ⇒ one value is shown only on request (--key), and secret-shaped text
#     inside it is redacted even then
#
# usage:
#   firefox.addon.storage.get.sh --id FirefoxColor@mozilla.com                  # the map
#   firefox.addon.storage.get.sh --id FirefoxColor@mozilla.com --key theme      # one value
#   firefox.addon.storage.get.sh --id <id> --store <name> --key <key>           # scoped
#
# guarantee:
#   - read-only: opens each sqlite in immutable mode, never writes
#   - never prints a value unless --key names it; redacts secret-shaped text
#   - exit 0 = answered, 1 = malfunction, 2 = bad input or no profile
######################################################################

set -uo pipefail

# parse flags; rhx injects its own flags, so scan every arg
addon_id=""; want_key=""; want_store=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) addon_id="${2:-}"; shift 2 ;;
    --key) want_key="${2:-}"; shift 2 ;;
    --store) want_store="${2:-}"; shift 2 ;;
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

echo "🦊 firefox.addon.storage.get --id $addon_id${want_store:+ --store $want_store}${want_key:+ --key $want_key}"
echo "   ├─ profile: $profile_dir"

PROFILE="$ff_root/$profile_dir" ADDON_ID="$addon_id" WANT_KEY="$want_key" WANT_STORE="$want_store" python3 - <<'PY'
import os, re, json, glob, struct, sqlite3, datetime

profile = os.environ["PROFILE"]
addon = os.environ["ADDON_ID"]
want_key = os.environ["WANT_KEY"]
want_store = os.environ["WANT_STORE"]

def ro(path):
    # immutable=1: read without a lock or a write, safe while firefox runs
    return sqlite3.connect(f"file:{path}?immutable=1", uri=True)

def snappy(buf):
    # raw snappy block decoder (firefox compresses idb values with it)
    i, shift = 0, 0
    while True:
        b = buf[i]; i += 1; shift += 7
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

def idb_key(raw):
    # decode firefox's idb key encoder: 0x10 number, 0x20 date, 0x30 string, 0x50 array
    if not raw: return "∅"
    t = raw[0]
    if t in (0x10, 0x20):
        b = bytearray(raw[1:9].ljust(8, b"\0"))
        bits = int.from_bytes(b, "big")
        bits = bits ^ (1 << 63) if bits & (1 << 63) else ~bits & ((1 << 64) - 1)
        n = struct.unpack(">d", bits.to_bytes(8, "big"))[0]
        return str(int(n)) if n == int(n) else str(n)
    if t == 0x30:
        out, i = [], 1
        while i < len(raw) and raw[i] != 0:
            c = raw[i]
            if c < 0x80: out.append(chr(c - 1)); i += 1
            else: out.append("?"); i += 2
        return "".join(out)
    return "0x" + raw.hex()

SECRET = re.compile(
    r"A3-[A-Z0-9]{5,}(?:-[A-Z0-9]{4,})+"     # 1password secret key
    r"|[A-Za-z0-9_\-+/=]{40,}"                # long tokens, keys, ciphertext
    r"|[\w.+-]+@[\w-]+\.[\w.]+"               # emails
)
def redact(text):
    return SECRET.sub("‹redacted›", text)

def readable(raw):
    runs = re.findall(r"[\x20-\x7e]{3,}", raw.decode("latin-1"))
    return redact(" | ".join(runs))

def value_of(data):
    try: return snappy(data)
    except Exception: return data

# map the addon id to its moz-extension uuid
uuids = {}
with open(os.path.join(profile, "prefs.js")) as f:
    for line in f:
        if "extensions.webextensions.uuids" in line:
            uuids = json.loads(json.loads(line.split(",", 1)[1].rsplit(")", 1)[0].strip()))
uuid = uuids.get(addon)
print(f"   ├─ uuid: {uuid or '(none — addon never started)'}")

# every indexeddb under storage/default/moz-extension+++<uuid>*: storage.local
# lives in the ^userContextId=4294967295 origin; the extension's OWN dbs in the bare one
print("   ├─ indexeddb")
dbs = sorted(glob.glob(os.path.join(profile, "storage/default", f"moz-extension+++{uuid}*", "idb", "*.sqlite"))) if uuid else []
if not dbs:
    print("   │  └─ (none)")
for db in dbs:
    mtime = datetime.datetime.fromtimestamp(os.path.getmtime(db)).isoformat(" ", "seconds")
    con = ro(db)
    dbname = (con.execute("select name from database").fetchone() or ["?"])[0]
    origin = os.path.basename(os.path.dirname(os.path.dirname(db)))
    kind = "storage.local" if "userContextId=4294967295" in origin else "the extension's own idb"
    print(f"   │  ├─ db '{dbname}' ({kind}, written {mtime})")
    stores = con.execute("select id, name from object_store order by name").fetchall()
    for sid, sname in stores:
        if want_store and sname != want_store: continue
        rows = con.execute("select key, length(data) from object_data where object_store_id = ?", (sid,)).fetchall()
        keys = [idb_key(k) for k, _ in rows]
        # a store of opaque/numeric keys is a record table; show count + a few keys only
        sample = ", ".join(keys[:12]) + (f", … (+{len(keys)-12})" if len(keys) > 12 else "")
        print(f"   │  │  ├─ store '{sname}': {len(rows)} row(s)")
        print(f"   │  │  │  └─ keys: {sample or '(empty)'}")
        if want_key:
            for k, data in con.execute("select key, data from object_data where object_store_id = ?", (sid,)):
                if idb_key(k) != want_key: continue
                print(f"   │  │  │     └─ {want_key} = {readable(value_of(data))[:1200]}")

# storage.sync — plain json keyed by ext_id
print("   └─ storage.sync (storage-sync-v2.sqlite)")
sync = os.path.join(profile, "storage-sync-v2.sqlite")
if os.path.exists(sync):
    con = ro(sync)
    for (data,) in con.execute("select data from storage_sync_data where ext_id = ?", (addon,)):
        obj = json.loads(data or "{}")
        print(f"      ├─ keys: {', '.join(sorted(obj)) or '(empty)'}")
        if want_key in obj:
            print(f"      │  └─ {want_key} = {redact(json.dumps(obj[want_key]))[:1200]}")
    print("      └─ (end)")
else:
    print("      └─ (no storage-sync-v2.sqlite)")
PY
if [[ $? -ne 0 ]]; then
  echo "💥 MalfunctionError: could not decode the storage for $addon_id" >&2
  exit 1
fi
