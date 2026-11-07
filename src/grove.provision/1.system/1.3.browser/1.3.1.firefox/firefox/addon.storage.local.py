# .what = read, or set, boolean flags inside ONE json-string key of a firefox
#         extension's storage.local — the store an extension keeps its config in
#
# .why  = an extension's options page writes to storage.local, and firefox
#         offers no file, pref, or policy that sets those options (1password's
#         managed schema accepts one key, CredentialIntelligence). so a declared
#         option must be written into the store itself
#
# the store, decoded:
#   - storage.local is an indexeddb: <profile>/storage/default/
#     moz-extension+++<uuid>^userContextId=4294967295/idb/*.sqlite
#   - db 'webExtensions-storage-local', object store 'storage-local-data'
#   - each row's `data` is a snappy block over a spidermonkey structured clone
#   - this handles ONE shape: a top-level string that holds a json object.
#     any other shape is refused with its tag, never guessed at
#
# 🛑 .why a write needs firefox QUIT
#   - a live firefox holds the db open and the extension holds its config in
#     memory; a write under it is lost at the extension's next save, or races
#   - ⇒ apply refuses (exit 4) while any firefox process lives
#
# 🛑 .why no value is printed
#   - a password manager keeps account secrets in the same profile storage
#   - ⇒ only the NAMED flags are printed, never the json around them
#
# usage:
#   python3 addon.storage.local.py --profile <dir> --addon-id <id> --key config \
#     --set inlineShowAutomatically=false --set inlineSaveEnabled=false --mode plan
#
# exit:
#   0 = every flag holds its declared value (after the write, in apply)
#   1 = malfunction — an unreadable shape, a failed write
#   3 = plan: drift — at least one flag differs
#   4 = apply: drift, and firefox is live, so no write was made
#   5 = absent — no uuid, no storage.local db, or no such key (extension never ran)

import os, sys, glob, json, struct, sqlite3, argparse

SCTAG_HEADER = 0xFFF10000
SCTAG_STRING = 0xFFFF0004
LATIN1 = 1 << 31


def snappy_decode(buf):
    i = 0
    while buf[i] & 0x80:
        i += 1
    i += 1
    out = bytearray()
    while i < len(buf):
        tag = buf[i]; i += 1; kind = tag & 3
        if kind == 0:
            ln = tag >> 2
            if ln >= 60:
                nb = ln - 59; ln = int.from_bytes(buf[i:i + nb], "little"); i += nb
            ln += 1; out += buf[i:i + ln]; i += ln; continue
        if kind == 1:
            ln = ((tag >> 2) & 7) + 4; off = ((tag >> 5) << 8) | buf[i]; i += 1
        elif kind == 2:
            ln = (tag >> 2) + 1; off = int.from_bytes(buf[i:i + 2], "little"); i += 2
        else:
            ln = (tag >> 2) + 1; off = int.from_bytes(buf[i:i + 4], "little"); i += 4
        for _ in range(ln):
            out.append(out[-off])
    return bytes(out)


def snappy_encode(raw):
    # literal-only snappy: valid for any decoder, no compression needed
    out = bytearray()
    n = len(raw)
    while True:
        b = n & 0x7F; n >>= 7
        out.append(b | (0x80 if n else 0))
        if not n:
            break
    for at in range(0, len(raw), 65536):
        chunk = raw[at:at + 65536]
        out.append(61 << 2)
        out += (len(chunk) - 1).to_bytes(2, "little")
        out += chunk
    return bytes(out)


def clone_to_text(clone):
    # header word, then one string word, then the chars padded to 8
    if len(clone) < 16:
        raise ValueError(f"clone too short ({len(clone)} bytes)")
    _, htag = struct.unpack("<II", clone[0:8])
    if htag != SCTAG_HEADER:
        raise ValueError(f"no clone header (tag 0x{htag:08x})")
    sdata, stag = struct.unpack("<II", clone[8:16])
    if stag != SCTAG_STRING:
        raise ValueError(f"top-level value is not a string (tag 0x{stag:08x})")
    latin1 = bool(sdata & LATIN1)
    length = sdata & ~LATIN1
    width = 1 if latin1 else 2
    body = clone[16:16 + length * width]
    rest = clone[16 + ((length * width + 7) // 8) * 8:]
    if rest:
        raise ValueError(f"{len(rest)} trailer bytes after the string")
    text = body.decode("latin-1") if latin1 else body.decode("utf-16-le")
    return clone[0:8], text


def text_to_clone(header, text):
    try:
        body = text.encode("latin-1"); flag = LATIN1
    except UnicodeEncodeError:
        body = text.encode("utf-16-le"); flag = 0
    length = len(text) if flag else len(body) // 2
    pad = (-len(body)) % 8
    return header + struct.pack("<II", length | flag, SCTAG_STRING) + body + b"\0" * pad


def key_bytes(name):
    # firefox idb key encode for a string: 0x30, each char + 1, no terminator
    return bytes([0x30]) + bytes(ord(c) + 1 for c in name)


def firefox_live():
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                argv0 = f.read().split(b"\0")[0]
        except OSError:
            continue
        if argv0.endswith(b"/firefox") or argv0.endswith(b"/firefox-bin"):
            return True
    return False


def find_uuid(profile, addon_id):
    with open(os.path.join(profile, "prefs.js")) as f:
        for line in f:
            if "extensions.webextensions.uuids" in line:
                raw = line.split(",", 1)[1].rsplit(")", 1)[0].strip()
                return json.loads(json.loads(raw)).get(addon_id)
    return None


def find_db(profile, uuid):
    pattern = os.path.join(profile, "storage/default",
                           f"moz-extension+++{uuid}^userContextId=4294967295", "idb", "*.sqlite")
    for db in glob.glob(pattern):
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        try:
            name = (con.execute("select name from database").fetchone() or [""])[0]
        finally:
            con.close()
        if name == "webExtensions-storage-local":
            return db
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", required=True)
    ap.add_argument("--addon-id", required=True)
    ap.add_argument("--key", required=True)
    ap.add_argument("--set", action="append", default=[])
    ap.add_argument("--mode", choices=["plan", "apply"], default="plan")
    args = ap.parse_args()

    want = {}
    for pair in args.set:
        name, _, val = pair.partition("=")
        if val not in ("true", "false"):
            print(f"✋ --set {pair}: only true|false is supported", file=sys.stderr)
            return 1
        want[name] = val == "true"

    uuid = find_uuid(args.profile, args.addon_id)
    db = find_db(args.profile, uuid) if uuid else None
    if not db:
        print(f"absent: no storage.local db for {args.addon_id} (has it ever run?)")
        return 5

    try:
        return patch(db, args, want)
    except sqlite3.OperationalError as error:
        # a live firefox may hold the db locked; that is the quit-owed case, not a malfunction
        if "locked" in str(error) and firefox_live():
            print("live: firefox is up and holds the db locked, so no read or write was made")
            return 4
        raise


def patch(db, args, want):
    con = sqlite3.connect(db, timeout=0)
    try:
        sid = con.execute("select id from object_store where name = 'storage-local-data'").fetchone()
        row = sid and con.execute("select data from object_data where object_store_id = ? and key = ?",
                                  (sid[0], key_bytes(args.key))).fetchone()
        if not row:
            print(f"absent: no '{args.key}' key in storage.local of {args.addon_id}")
            return 5

        header, text = clone_to_text(snappy_decode(row[0]))
        obj = json.loads(text)
        if not isinstance(obj, dict):
            raise ValueError("the json in the key is not an object")

        drift = {k: v for k, v in want.items() if obj.get(k) is not v}
        for k, v in want.items():
            mark = "✔" if k not in drift else "≠"
            print(f"{mark} {k}: {json.dumps(obj.get(k, 'absent'))} (declared {json.dumps(v)})")

        if not drift:
            return 0
        if args.mode == "plan":
            return 3
        if firefox_live():
            print("live: firefox is up, so no write was made")
            return 4

        obj.update(drift)
        # compact separators: the extension wrote it compact, so keep its shape
        text_new = json.dumps(obj, separators=(",", ":"), ensure_ascii=False)
        blob = snappy_encode(text_to_clone(header, text_new))
        con.execute("update object_data set data = ? where object_store_id = ? and key = ?",
                    (blob, sid[0], key_bytes(args.key)))
        con.commit()

        # read it back through the decoder, so a bad encode fails here, not in firefox
        back = con.execute("select data from object_data where object_store_id = ? and key = ?",
                           (sid[0], key_bytes(args.key))).fetchone()[0]
        check = json.loads(clone_to_text(snappy_decode(back))[1])
        if any(check.get(k) is not v for k, v in want.items()):
            raise ValueError("read-back differs from the write")
        print(f"wrote: {', '.join(f'{k}={json.dumps(v)}' for k, v in drift.items())}")
        return 0
    finally:
        con.close()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"💥 {type(e).__name__}: {e}", file=sys.stderr)
        sys.exit(1)
