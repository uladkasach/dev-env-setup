#!/usr/bin/env bash
######################################################################
# .what = put the capture chain's three packages on the box
#
# .why each
#   - pipewire-bin     = `pw-record`, the recorder
#   - pulseaudio-utils = `pactl`, the only reader of the default source's mute
#   - libnotify-bin    = `notify-send`, the mid-take alert sink
#
# ⚠️ `pulseaudio-utils` on a pipewire box is CORRECT — pipewire answers `pactl`
#    via pipewire-pulse, `pw-record` cannot read a mute, `wpctl` wants wireplumber
######################################################################

grove_provision_1_9_audio_provision_upsert() {
  if [[ "$GROVE_ENV_SERVER" != "local@unix" ]]; then
    echo "   🌙 declined — no microphone on $GROVE_ENV_SERVER, so no capture"
    echo "      chain is expected here"
    return 0
  fi

  pkg_install pipewire-bin pulseaudio-utils libnotify-bin || return 1
}
