# demo: 6.3.dropbox — why an apt repo replaced a fetched .deb

## .what

`6.3.dropbox` once fetched a dated `.deb` unverified and ran its root preinst/postinst
(`rule.require.verify-binary-downloads`). four measurements, `diagnose.dropbox-verifiability`
and `diagnose.apt-key-wire-read`, 2026-08-13, justified the switch to a gpg-signed apt repo.

## m1 — no hash is expressible for the .deb; a signed apt repo IS

- `.sha256`, `.sha256sum`, `.asc`, `.sig` beside the `.deb` all 404 — no hash pin is
  expressible for it at all
- `linux.dropbox.com/ubuntu/dists/disco/Release` and `Release.gpg` both return 200 — a
  gpg-signed apt repo exists
- ⇒ the fix is a new ROUTE (the apt repo), not a new CHECK bolted onto the old one; a
  KEY pin re-verifies every package that source will ever serve

## m2 — the key lives at a `/fedora/` url, and it is not a mistake

- every ubuntu-shaped key url 404s; it is ONE key shared across both distros
- verified against `Release.gpg`: gpg reports a good signature made by dropbox's own
  automatic release key, fingerprint `1C61 A265 6FB5 7B7E 4DE0  F4C1 FC91 8B33 5044 912E`
- a `Release.gpg` that merely exists says a signature was made, never by WHICH key
  (`rule.require.seam-claims-have-an-owner`)

## m3 — the repo's 2020.03.04 dated `.deb` is not a downgrade

- that `.deb` is a LAUNCHER at 69,360 bytes, not the client itself
- its payload: `/usr/bin/dropbox`, a nautilus extension, icons, a `.desktop` file
- the sync daemon is fetched on first launch and updates itself thereafter
  (`gotcha.my-own-note-became-my-evidence`)

## m4 — the fingerprint's tier, and how to raise it

- `diagnose.apt-key-wire-read` read all five anchors in one pass — evidence about the
  PATH the bytes took, silent about dropbox's own origin. this stays a WIRE READ,
  the weakest pin tier (`term=pin`)
- unlike the other wire-read pins, this one carries a second witness: it verified
  `Release.gpg` too
- ⇒ to raise the tier, re-run that diagnose from a different network

## .see also

- `6.3.dropbox/provision.upsert.sh` — the header these measurements back
- `rule.require.verify-binary-downloads`
- `gotcha.my-own-note-became-my-evidence`
