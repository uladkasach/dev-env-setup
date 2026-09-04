#!/usr/bin/env bash
######################################################################
# .what = prove the LIVE system monospace font is the one this repo declares
#
# .it reads the value back, rather than trust the write
#   - `gsettings set` succeeds against a schema another process may overwrite
#   - a theme, a desktop reset, or a settings app can do that a second later
#   - so the write's exit code proves the write happened
#   - it never proves the value still holds
#   - only a read back answers "what font opens tomorrow"
#
# guarantee
#   - READ-ONLY: it observes and mutates no state
######################################################################

grove_provision_4_1_fonts_configure_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 not applicable — no desktop on $GROVE_ENV_SERVER"
    return 0
  fi

  if ! command -v gsettings >/dev/null 2>&1 \
    || ! gsettings writable org.gnome.desktop.interface monospace-font-name >/dev/null 2>&1; then
    echo "   🌙 no gnome desktop schema here, so the system monospace font"
    echo "      cannot be observed. kitty is unaffected (it names its own font)"
    return 0
  fi

  local want='Hack Nerd Font Mono 12'
  local live
  live="$(gsettings get org.gnome.desktop.interface monospace-font-name 2>/dev/null)"
  live="${live#\'}"
  live="${live%\'}"

  if [[ "$live" == "$want" ]]; then
    echo "   • system monospace font is live as '$want' ✔"
    return 0
  fi

  echo "   ✋ the system monospace font is '$live', not '$want'" >&2
  echo "      ⇒ every gtk app opens that font instead, and a font with no icon" >&2
  echo "        range draws an icon as tofu (▯). kitty names its own font, so" >&2
  echo "        this key does not reach it" >&2
  echo "      fix: rhx grove.provision --what 4.1.fonts --mode apply" >&2
  return 1
}
