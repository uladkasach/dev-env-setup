#!/usr/bin/env bash
######################################################################
# .what = install yubikey-agent + ykman, and enable the two user services
#
# .pcscd.socket as well as the agent
#   - yubikey-agent talks to the key through pcsc-lite
#   - with the socket disabled it starts healthy and answers ssh with "no keys"
#   - ⇒ that failure reads as an empty YubiKey
#
# .`systemctl --user`, never system-wide
#   - the agent holds ONE human's key and must die with their session
#   - ⇒ a system unit would keep it alive for every user on the box
#
# guarantee:
#   - idempotent: both installs short-circuit and `enable --now` converges
#   - it writes into NO file of this repo (see `_.sh` on the append it replaced)
######################################################################

grove_provision_5_9_yubikey_provision_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — a YubiKey is tapped by a hand, and no hand reaches"
    echo "      a headless box"
    return 0
  fi

  pkg_install yubikey-agent || return 1
  pkg_install yubikey-manager || return 1

  ####################################################################
  # .the two user services
  #   - a box with no systemd user session is a container or a chroot
  #   - ⇒ it reports rather than fails, since the packages did install
  ####################################################################
  if ! systemctl --user daemon-reload 2>/dev/null; then
    echo "   🌙 no systemd user session here, so the agent services cannot be"
    echo "      enabled. the packages are installed; the agent is not running"
    return 0
  fi

  systemctl --user enable --now pcscd.socket || {
    echo "   ✋ could not enable pcscd.socket" >&2
    echo "      ⇒ the agent would start, report healthy, and answer every ssh" >&2
    echo "        request with 'no keys' — which reads as an empty YubiKey" >&2
    return 1
  }

  systemctl --user enable --now yubikey-agent.service || {
    echo "   ✋ could not enable yubikey-agent.service" >&2
    return 1
  }

  echo "   • yubikey-agent installed and enabled ✔"
}
