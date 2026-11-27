#!/usr/bin/env bash
######################################################################
# .what = report which policy files imagemagick consults, and whether it
#         hands a postscript file to ghostscript, under each config path
#
# .why  = a policy.xml on disk proves naught: imagemagick 6 reads only the
#         paths it was built to read. this asks the live tool, both bare and
#         with MAGICK_CONFIGURE_PATH, so a fix is chosen from a measurement
#
# usage:
#   imagemagick.policy.get.sh                 # bare, and with ~/.config/ImageMagick
#   imagemagick.policy.get.sh --dir <dir>     # with MAGICK_CONFIGURE_PATH=<dir>
#
# guarantee:
#   - read-only, besides one temp dir it removes on exit
#   - the ghostscript probe is bounded (timeout 20s)
#   - exit 0 = answered, 1 = malfunction, 2 = bad input
######################################################################
set -uo pipefail

dir="${XDG_CONFIG_HOME:-$HOME/.config}/ImageMagick"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill|--repo|--role) shift 2 ;;
    --dir) dir="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "✋ ConstraintError: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

im=""
for c in magick convert; do command -v "$c" >/dev/null 2>&1 && { im="$c"; break; }; done
[[ -n "$im" ]] || { echo "✋ ConstraintError: no imagemagick on PATH" >&2; exit 2; }
ident=(identify); [[ "$im" == magick ]] && ident=(magick identify)

work="$(mktemp -d "${TMPDIR:-/tmp}/imagemagick.policy.get.XXXXXX")" || { echo "💥 MalfunctionError: no temp dir" >&2; exit 1; }
trap 'rm -rf "$work"' EXIT
printf '%%!PS-Adobe-3.0 EPSF-3.0\n%%%%BoundingBox: 0 0 8 8\n0 0 moveto 8 8 lineto stroke\n' > "$work/probe.eps"

probe() {
  local label="$1"; shift
  echo "   ├─ $label"
  echo "   │  ├─ policy paths consulted"
  env "$@" "$im" -list policy 2>&1 | grep '^Path:' | sed 's/^Path: */   │  │  ├─ /'
  echo "   │  ├─ rules in force"
  env "$@" "$im" -list policy 2>&1 | grep -E '^ +(Policy|rights|pattern|name|value):' \
    | paste -sd' ' | sed 's/ *Policy: /\n/g' | sed '/^$/d; s/  */ /g; s/^/   │  │  ├─ /'
  local out; out="$(env "$@" timeout -k 5 20 "${ident[@]}" "$work/probe.eps" 2>&1 | head -1)"
  if printf '%s' "$out" | grep -qi 'not authorized\|security policy'; then
    echo "   │  └─ eps probe: refused ✔"
  else
    echo "   │  └─ eps probe: READ — ${out:-<no output>}"
  fi
}

echo "🔭 imagemagick.policy.get"
echo "   ├─ binary: $(command -v "$im") ($("$im" -version 2>/dev/null | head -1))"
probe "bare" PATH="$PATH"
probe "MAGICK_CONFIGURE_PATH=$dir" MAGICK_CONFIGURE_PATH="$dir"
echo "   └─ done"
