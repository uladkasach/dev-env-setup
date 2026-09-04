# demo: 6.4.protonvpn — two end-to-end defects a wire play found, neither visible to a
# tree run on either box class

## .what

`6.4.protonvpn` installs a release `.deb` that declares proton's own apt repo, then pulls
the real client from apt. four measurements, 2026-08-13 to 2026-08-14, back its pin and
its package names.

## m1 — the sha256 pin reaches TIER 1, read 2026-08-13

- proton publishes the sha256 for the exact release `.deb` in its setup docs, a page
  SEPARATE from the download itself:
  `https://protonvpn.com/support/official-linux-vpn-ubuntu/`
- an attacker must compromise both surfaces to pass (`term=pin`)
- at an earlier version the only pin expressible was one computed FROM the download
  itself — the fix was a new ROUTE: a release proton documents and CAN be checked
  (`rule.require.verify-binary-downloads`)

## m2 — the download url 404s on every box, at every version — found 2026-08-13

- `prove.sha256-pins-bite`'s FIRST run here found the fetch aimed at
  `protonvpn.com/download`, which 404s; the real host is `repo.protonvpn.com`
- this bundle declines off `local@unix` and skips on an installed client. only a
  FRESH LAPTOP ever ran this line — and there had been none since it broke
- ⇒ a bundle whose install path runs on ONE box class has no ambient evidence
  (`define.provision-defect-shapes`, `.the DARKEST corner`)

## m3 — the binary on PATH belongs to a DIFFERENT package, measured 2026-08-14

off proton's own index:

| package | the binary it puts on PATH |
|---|---|
| `proton-vpn-gtk-app` | `/usr/bin/protonvpn-app` |
| `proton-vpn-cli` | `/usr/bin/protonvpn` |
| `proton-vpn-gnome-desktop` | none — a metapackage |

a test for `protonvpn` asks whether the CLI is installed. this bundle installs the
DESKTOP client. that test would never short-circuit; the verify would ✋ on a box
where the app is installed and works.

## m4 — `protonvpn` is not a name proton's apt repo serves at all, found 2026-08-14

- `prove.apt-sources-serve`'s first read of proton's INDEX found this bundle asked apt
  for a package named `protonvpn`. proton's stable suite has no such name
- so the install could not have succeeded on any box, at any version — the second
  end-to-end defect a wire play found here, neither visible to a run of the tree
  (`define.provision-defect-shapes`, `.the DARKEST corner`)
- the names proton's `stable main` actually serves: `proton-vpn-gnome-desktop` (the
  desktop client, and what proton's own ubuntu setup page names), `proton-vpn-gtk-app`
  (the gtk app the desktop package depends on), `proton-vpn-cli` (a terminal client, no
  gui), `protonvpn-gui` (a transitional alias upstream keeps only until it does not)
- the client is arch-independent, so it sits in `binary-all`, not `binary-amd64` — a
  reader that asks one index alone cannot see it

## .see also

- `6.4.protonvpn/provision.upsert.sh` — the header these measurements back
- `define.provision-defect-shapes`
- `rule.require.verify-binary-downloads`
