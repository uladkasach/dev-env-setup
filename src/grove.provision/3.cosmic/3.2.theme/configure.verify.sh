#!/usr/bin/env bash
######################################################################
# .what
#   - prove the desert palette reached GTK apps
#   - through the stylesheet COSMIC generates, and the GTK3 link that carries it
#
# ⚠️ .it checks a COLOR, never a file's bytes
#   - `~/.config/gtk-4.0/cosmic/dark.css` belongs to COSMIC, which regenerates it
#   - 📜 a diff against the repo copy fails on every healthy box: 106 lines vs 60
#   - a verify whose failure a re-apply cannot cure is worse than no verify
#   - ⇒ the claim asks whether the generated stylesheet is the DESERT one
#
# .#333333 is the sentinel
#   - it is the desert window background, declared in `src/cosmic.theme.ron`
#   - COSMIC writes it as `rgba(51, 51, 51, ...)`, so both forms are accepted
#
# guarantee
#   - READ-ONLY: it observes and mutates no state
######################################################################

grove_provision_3_2_theme_configure_verify() {
  if [[ "$GROVE_ENV_SERVER" != local@* ]]; then
    echo "   🌙 declined — no compositor and no GTK apps on $GROVE_ENV_SERVER"
    return 0
  fi

  local failed=0
  local gtk4="$HOME/.config/gtk-4.0/cosmic/dark.css"
  local gtk3="$HOME/.config/gtk-3.0/gtk.css"

  ####################################################################
  # 1. COSMIC generated a stylesheet, and it carries the desert background
  #
  #   - no `-q` on the grep, because under `pipefail` it would exit on match
  #   - it would then SIGPIPE its producer (gotcha.pipefail-grep-q)
  ####################################################################
  if [[ ! -r "$gtk4" ]]; then
    echo "   ✋ COSMIC has generated no GTK stylesheet at $gtk4" >&2
    echo "      ⇒ firefox and every other GTK app draws in the default light" >&2
    echo "        theme, wrapped by a themed COSMIC shell" >&2
    echo "      fix: rhx grove.provision --what 3.2.theme --mode apply" >&2
    failed=1
  elif grep -E '#333333|rgba\(51, *51, *51' "$gtk4" >/dev/null; then
    echo "   • the generated GTK stylesheet carries the desert palette ✔"
  else
    echo "   ✋ $gtk4 exists but does NOT declare the desert background" >&2
    echo "      ⇒ a stylesheet is present, so a file check would pass while GTK" >&2
    echo "        apps draw in some other theme entirely" >&2
    echo "      read it: grep window_bg_color $gtk4" >&2
    echo "      fix: rhx grove.provision --what 3.2.theme --mode apply" >&2
    failed=1
  fi

  ####################################################################
  # 2. GTK3 resolves to that same file
  ####################################################################
  if [[ -L "$gtk3" ]] && [[ "$(readlink -f "$gtk3")" == "$(readlink -f "$gtk4")" ]]; then
    echo "   • GTK3 reads the same stylesheet as GTK4 ✔"
  elif [[ -e "$gtk3" ]]; then
    echo "   ✋ $gtk3 does not point at $gtk4" >&2
    echo "      ⇒ GTK3 and GTK4 apps then drift apart, so half the windows" >&2
    echo "        re-theme on the next apply and half do not" >&2
    echo "      fix: rhx grove.provision --what 3.2.theme --mode apply" >&2
    failed=1
  else
    echo "   ✋ no GTK3 stylesheet at $gtk3" >&2
    echo "      ⇒ GTK3 apps read no theme at all, while GTK4 apps read desert" >&2
    echo "      fix: rhx grove.provision --what 3.2.theme --mode apply" >&2
    failed=1
  fi

  return $failed
}
