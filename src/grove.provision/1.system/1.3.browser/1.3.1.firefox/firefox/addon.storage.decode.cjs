// .what = print one firefox IndexedDB sqlite file's rows as json, key → value
// .why  = an extension's `storage.local` is where its own options live (the
//         1password autofill menu, the firefox color theme). firefox stores each
//         value as a snappy-compressed structured clone, so no text read of the
//         file can answer "was this option set?" — this decode can
//
// usage: node addon.storage.decode.cjs <path to a COPY of the .sqlite>
// .why .cjs = a `"type": "module"` package.json above it would make a `.js`
//             an ES module, where `require` is undefined
//
// guarantee:
//   - read-only: opens the file readOnly; the caller passes a copy, so a live
//     firefox's lock and wal are never touched
//   - a value it cannot decode is printed as "<undecoded: why>", never dropped
//   - needs node >= 22.5 (built-in `node:sqlite`)
const { DatabaseSync } = require('node:sqlite');

// firefox IDB key: 0x30 then each utf-16 unit, c<=0x7e → c+1; else 2 or 3 bytes
const asKey = (b) => {
  if (b[0] !== 0x30) return `<key type ${b[0]}>`;
  let s = '', i = 1;
  while (i < b.length && b[i] !== 0) {
    const c = b[i];
    if (!(c & 0x80)) { s += String.fromCharCode(c - 1); i += 1; continue; }
    if (!(c & 0x40)) { s += String.fromCharCode((((c & 0x3f) << 8) | b[i + 1]) + 0x7f); i += 2; continue; }
    s += String.fromCharCode((((c << 10) | (b[i + 1] << 2) | (b[i + 2] >> 6)) & 0xffff)); i += 3;
  }
  return s;
};

// snappy raw format: varint length, then literal + copy elements
const asUnsnapped = (src) => {
  let p = 0, len = 0, shift = 0;
  for (;;) { const c = src[p++]; len |= (c & 0x7f) << shift; if (!(c & 0x80)) break; shift += 7; }
  const out = Buffer.alloc(len); let o = 0;
  while (p < src.length) {
    const t = src[p++], kind = t & 3;
    if (kind === 0) {
      let n = t >> 2;
      if (n >= 60) { const w = n - 59; n = 0; for (let k = 0; k < w; k++) n |= src[p++] << (8 * k); }
      n += 1; src.copy(out, o, p, p + n); p += n; o += n; continue;
    }
    let n, off;
    if (kind === 1) { n = ((t >> 2) & 7) + 4; off = ((t >> 5) << 8) | src[p++]; }
    if (kind === 2) { n = (t >> 2) + 1; off = src.readUInt16LE(p); p += 2; }
    if (kind === 3) { n = (t >> 2) + 1; off = src.readUInt32LE(p); p += 4; }
    for (let k = 0; k < n; k++, o++) out[o] = out[o - off];
  }
  return out;
};

// structured clone: 8-byte words, (data u32, tag u32) little endian
const asUncloned = (buf) => {
  let p = 0;
  const word = () => { const d = buf.readUInt32LE(p), t = buf.readUInt32LE(p + 4); p += 8; return [t, d]; };
  const str = (d) => {
    const n = d & 0x7fffffff, latin1 = d & 0x80000000;
    const bytes = latin1 ? n : n * 2;
    const s = latin1 ? buf.toString('latin1', p, p + n) : buf.toString('utf16le', p, p + bytes);
    p += Math.ceil(bytes / 8) * 8; return s;
  };
  const refs = [];
  const read = () => {
    const [t, d] = word();
    if (t < 0xfff00000) { p -= 8; const v = buf.readDoubleLE(p); p += 8; return v; }
    switch (t) {
      case 0xfff10000: return read();                       // header
      case 0xffff0000: return null;
      case 0xffff0001: return undefined;
      case 0xffff0002: return d !== 0;
      case 0xffff0003: return d | 0;
      case 0xffff0004: return str(d);
      case 0xffff0005: { const v = buf.readDoubleLE(p); p += 8; return new Date(v).toJSON(); }
      case 0xffff000d: return refs[d];                      // back reference
      case 0xffff0007: case 0xffff0008: {                   // array, object
        const v = t === 0xffff0007 ? [] : {}; refs.push(v);
        for (;;) {
          if (buf.readUInt32LE(p + 4) === 0xffff0013) { p += 8; return v; } // end of keys
          const k = read(); v[k] = read();
        }
      }
      default: throw new Error(`tag 0x${t.toString(16)}`);
    }
  };
  return read();
};

module.exports = { asKey, asUnsnapped, asUncloned };

// run as a command: print every row of the db at argv[2]
if (require.main === module) {
  const db = new DatabaseSync(process.argv[2], { readOnly: true });
  const out = {};
  for (const row of db.prepare('SELECT key, data, file_ids FROM object_data').all()) {
    const k = asKey(Buffer.from(row.key));
    if (row.file_ids) { out[k] = '<undecoded: value stored in a side file>'; continue; }
    try { out[k] = asUncloned(asUnsnapped(Buffer.from(row.data))); }
    catch (e) { out[k] = `<undecoded: ${e.message}>`; }
  }
  process.stdout.write(JSON.stringify(out));
}
