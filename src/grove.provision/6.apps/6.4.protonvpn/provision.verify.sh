#!/usr/bin/env bash
######################################################################
# .what = prove the protonvpn client is on this box
#
# .it claims presence, never a live tunnel
#   - whether a vpn is CONNECTED is a human's choice, made per session
#   - to fail on a disconnected client would report a defect on every box
#
# 🛑 .the binary is `protonvpn-app`, and NOT `protonvpn`
#
# 📜 measured off proton's own index:
#
#      proton-vpn-gtk-app       → /usr/bin/protonvpn-app   ← what we install
#      proton-vpn-cli           → /usr/bin/protonvpn       ← a different package
#      proton-vpn-gnome-desktop → none; it is a metapackage
#
#   - ⚠️ so a test of `protonvpn` yields a false ✋
#   - the install succeeds, the app runs, and the verify reports it absent
#   - a check that reddens against software that works gets silenced
#   - (gotcha.a-check-that-cries-wolf-gets-silenced)
#   - ⇒ a PACKAGE name and a BINARY name are two facts, so both were read
#   - (rule.require.trust-but-verify)
#
# guarantee
#   - READ-ONLY: it observes and mutates no state
######################################################################

grove_provision_6_4_protonvpn_provision_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no screen on $GROVE_ENV_SERVER, so the desktop vpn"
    echo "      client is not expected here"
    return 0
  fi

  if command -v protonvpn-app >/dev/null 2>&1; then
    echo "   • protonvpn-app is on PATH ✔"
    return 0
  fi

  echo "   ✋ protonvpn-app is absent from PATH" >&2
  echo "      ⇒ any host that is reachable ONLY over the vpn reads as down" >&2
  echo "      ⚠️ this asks for 'protonvpn-app', which proton-vpn-gtk-app ships." >&2
  echo "        a 'protonvpn' on PATH is proton-vpn-cli, a DIFFERENT package —" >&2
  echo "        so its presence would not satisfy this bundle" >&2
  echo "      fix: rhx grove.provision --what 6.4.protonvpn --mode apply \\" >&2
  echo "             --include protonvpn" >&2
  return 1
}
