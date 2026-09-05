#!/usr/bin/env bash
######################################################################
# .what = the dropbox desktop sync client
#
# .why  it is its own bundle and not part of 6.1.flatpaks
#         dropbox ships an apt repo of its own, signed by a key this bundle
#         pins — so its install story is a trust anchor plus a source line, not
#         a flathub ref, and its failures are apt's rather than flatpak's.
#
# .why  it holds no `configure` phase, though it declares a repo and a key
#         those are what it takes to GET the package onto the box, so they are
#         provision — the same split `6.2.codium` and `5.8.docker` use.
#
#         what a configure phase would own is dropbox's own settings, and there
#         are none to own: dropbox keeps its account and its folder map inside
#         its daemon state, behind a sign-in this repo holds no credential for.
#         so there is no file to declare, and no config to verify.
#
# ⚠️ .OPT-IN — a run installs dropbox only when asked
#         see `GROVE_OPTIN_APPS` in `src/bundle.upgrade.sh`
#
# usage:
#   rhx grove.provision --include dropbox --mode apply
######################################################################

GROVE_OPTIN_APPS+=(dropbox)

grove_provision_6_3_dropbox() {
  grove_optin dropbox || { grove_optin_decline dropbox; return 0; }

  bundle.upgrade 6.3.dropbox.provision.upsert
  bundle.upgrade 6.3.dropbox.provision.verify
}
