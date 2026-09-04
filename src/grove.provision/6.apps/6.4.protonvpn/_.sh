#!/usr/bin/env bash
######################################################################
# .what = the protonvpn desktop client
#
# .why  it is its own bundle
#         proton ships a .deb that declares its apt repo, then the client through
#         apt, then two tray-indicator packages. that three-step is a story of its
#         own, and the version pin on the first step has its own expiry.
#
# .why  it holds no `configure` phase
#         the vpn's credentials and server choice live behind a sign-in inside the
#         client. this repo declares no file it reads.
#
# ⚠️ .OPT-IN — a run installs protonvpn only when asked
#         see `GROVE_OPTIN_APPS` in `src/bundle.upgrade.sh`
#
#         🛑 this bundle is the reason opt-in earns its keep. it has now been
#         found broken end to end THREE times, each by a play pointed at a
#         different link, and each defect had run on every box for months:
#
#           2026-08-13  the download url answered 404      → prove.sha256-pins-bite
#           2026-08-14  `pkg_install protonvpn` names no
#                       package proton serves               → prove.apt-sources-serve
#           2026-08-14  the verify tested the CLI's binary  → the fix for the above
#
#         a grove DECLINED the install and a laptop SKIPPED it on a binary that
#         was already there, so both printed a clean result about a path that
#         could not work. an app a human never asked for is an app whose failure
#         nobody reads (`define.provision-defect-shapes`, `.the DARKEST
#         corner`).
#
#         ✔ and the gap it left is CLOSED as of 2026-08-14: this bundle's apt
#         index — the one carried by the `.deb` fetched below — is now reached by
#         `prove.apt-sources-serve`, which opens the package and reads the source
#         out of it. its deferral audit prints `· none`
#
# usage:
#   rhx grove.provision --include protonvpn --mode apply
######################################################################

GROVE_OPTIN_APPS+=(protonvpn)

grove_provision_6_4_protonvpn() {
  grove_optin protonvpn || { grove_optin_decline protonvpn; return 0; }

  bundle.upgrade 6.4.protonvpn.provision.upsert
  bundle.upgrade 6.4.protonvpn.provision.verify
}
