# rule.forbid.unchecked-dependency-vulns

## .what

**a bundle may not install third-party code until somebody has checked it for known
holes, and the check is written down in the bundle, dated.**

`rule.require.verify-binary-downloads` proves the bytes came from who they claim. it says
naught about whether those bytes are SAFE. a correctly signed package with a published
exploit passes every signature check there is.

## .what owes a check

| source | owes a check? | why |
|---|---|---|
| the distro's own repos (`noble`, `noble-security`, `noble-updates`) | no | the distro's security team patches them, and unattended-upgrades applies the patch |
| a third-party apt repo (docker, github, tailscale, dropbox, …) | **yes** | none but the vendor watches it |
| a pinned release binary, tarball, or installer | **yes** | a pin freezes the version, holes and all |
| an npm / pnpm / cargo / flatpak package a bundle names | **yes** | same — the bundle chose the version |

## .what a check is — three questions, answered in the bundle header

1. **what runs, and as whom?** list the package's files and its maintainer hooks
   (`preinst`, `postinst`, …) — those run as ROOT at install
   (`rhx apt.package.get --name <pkg> --files`)
2. **how old is it?** the source's newest release date. a source older than a year is
   a smell: the vendor may have stopped there, and holes found since stay unpatched
3. **is there a known hole?** search the vendor's advisories and a CVE database for the
   package and its version; name where you searched and what you found, even when the
   answer is "no advisory found"

record it beside the install, so the next reader sees it was asked:

```sh
# .security (checked 2026-11-16)
#   runs:   /usr/bin/dropbox (python launcher, as the user); no maintainer hooks
#   age:    2020.03.04 — the repo's only release
#   holes:  no advisory found — searched: <where>
```

## .why

- **a signature is a claim about ORIGIN, never about SAFETY.** the two are
  orthogonal, and a check that proves one reads as if it proved both
- **a stale source looks identical to a stable one.** an install that works says
  naught about the years of fixes the vendor never shipped
- **root runs first.** a maintainer hook runs as root before anyone opens the app,
  so "it is only a launcher" must be shown, not assumed

## .measured — 2026-11-16, `6.3.dropbox`

dropbox's signed apt repo serves one package, dated 2020. the bundle verified its key
with care (`gotcha.6-3-dropbox.demo=apt-repo-not-deb`), and no step anywhere asked
whether a launcher that old was safe to run. the human asked, in one line.

## .enforcement

- a bundle that installs from a source in the "yes" rows with no `.security` block =
  **blocker**
- a `.security` block with no date, or no named place searched = **blocker** — a check
  that names no source cannot be repeated
- an install from a source with a known unpatched advisory = **blocker**, unless the
  block names why that hole cannot reach this box
- a `.security` block older than a year = **nitpick** — re-check on contact

## .see also

- `rule.require.verify-binary-downloads` — the origin half; this is the safety half
- `howto.review-public-repo-hazards` — pins published in a public repo tell a reader
  which advisories apply to you
- `rule.require.security-paramount`
