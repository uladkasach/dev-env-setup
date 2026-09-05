#!/usr/bin/env bash
######################################################################
# .what = declare Hack Nerd Font Mono as the SYSTEM monospace font
#
# .a system-wide key, though kitty already names its own font
#   - kitty reads `font_family` out of its own kitty.conf, so this is not for it
#   - it is what every OTHER gtk app obeys, since none has a font key of its own
#
# ⚠️ .the FONT is this phase's subject, and no one terminal is
#   - 📜 2026-08-13: this header once justified the key by ptyxis alone
#   - so when ptyxis was deleted the phase read as orphaned with it
#   - ⇒ a phase justified by ONE consumer looks disposable when that consumer goes
#   - (rule.require.bundle-names-name-their-subject)
#
# .size 12 is part of the value, not a separate key
#   - gsettings stores family and size as ONE string, and rejects a bare family
#
# guarantee
#   - idempotent: a gsettings set over an identical value is a no-op
#   - it DECLINES where no desktop schema exists, rather than fail on a grove
######################################################################

grove_provision_4_1_fonts_configure_upsert() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no desktop on $GROVE_ENV_SERVER, so no gtk app here"
    echo "      reads this key"
    return 0
  fi

  ####################################################################
  # gsettings is absent on a minimal box, and its schema is absent without gnome
  #   - both are the same class: a desktop key with no desktop
  #   - so both report, and neither halts the run
  ####################################################################
  if ! command -v gsettings >/dev/null 2>&1; then
    echo "   🌙 gsettings is absent, so the system monospace font cannot be"
    echo "      declared. kitty is unaffected (it names its own font)"
    return 0
  fi

  if ! gsettings writable org.gnome.desktop.interface monospace-font-name >/dev/null 2>&1; then
    echo "   🌙 the gnome desktop schema is absent, so there is no key to declare."
    echo "      kitty is unaffected (it names its own font)"
    return 0
  fi

  local want='Hack Nerd Font Mono 12'
  if ! gsettings set org.gnome.desktop.interface monospace-font-name "$want"; then
    echo "   ✋ could not declare the system monospace font" >&2
    echo "      ⇒ every gtk app keeps the desktop default, which has no icon" >&2
    echo "        range, so their glyphs draw as tofu (▯). kitty is unaffected" >&2
    return 1
  fi

  echo "   • system monospace font declared → $want"
}
