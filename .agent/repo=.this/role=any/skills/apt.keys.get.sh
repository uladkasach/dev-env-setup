#!/usr/bin/env bash
######################################################################
# .what = list every key apt trusts, split by SCOPE: the blanket keyrings that
#         vouch for EVERY repo, and the scoped keyrings that a `signed-by=`
#         line ties to one repo
#
# .why  = a key in /etc/apt/trusted.gpg or /etc/apt/trusted.gpg.d/ may sign a
#         package that names ANY origin — debian, ubuntu, docker. vendor install
#         hooks still put keys there with `apt-key add`, silently. this names
#         each blanket key, so a stray one is seen before it is trusted
#
# usage:
#   rhx apt.keys.get
#
# guarantee:
#   - READ-ONLY: gpg reads into a private, throwaway home; the keyrings are
#     opened read-only and never written
######################################################################

set -uo pipefail

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        echo "🔑 apt.keys.get — every key apt trusts, blanket vs scoped, and which repo names each scoped one"
        echo ""
        echo "usage:"
        echo "  rhx apt.keys.get"
        return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      *) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   fix: rhx apt.keys.get --help" >&2; return 2 ;;
    esac
  done
  if ! command -v gpg >/dev/null 2>&1; then
    echo "✋ ConstraintError: gpg is absent — no keyring can be read" >&2; return 2
  fi

  # a private gpg home, so no read here touches the human's own keyring
  local home
  home="$(mktemp -d)" || { echo "💥 MalfunctionError: no temp dir" >&2; return 1; }
  trap 'rm -rf -- "$home"' RETURN

  echo "🔑 apt.keys.get"

  echo ""
  echo "── blanket — trusted for EVERY repo"
  local ring any=0
  for ring in /etc/apt/trusted.gpg /etc/apt/trusted.gpg.d/*.gpg /etc/apt/trusted.gpg.d/*.asc; do
    [[ -f "$ring" ]] || continue
    any=1
    echo "   • $ring"
    __keys_in "$home" "$ring"
  done
  [[ "$any" -eq 1 ]] || echo "   none ✔"

  echo ""
  echo "── scoped — trusted only where a source line names it with signed-by="
  any=0
  for ring in /etc/apt/keyrings/* /usr/share/keyrings/*; do
    [[ -f "$ring" ]] || continue
    # which source files name this keyring — a scoped key no repo names is dead weight
    local users
    users="$(grep -rlF "$ring" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | xargs -r -n1 basename | paste -sd' ')"
    [[ -n "$users" ]] || continue
    any=1
    echo "   • $ring  ← $users"
    __keys_in "$home" "$ring"
  done
  [[ "$any" -eq 1 ]] || echo "   none named by a source line"

  echo ""
  echo "🌲 done — a vendor key in the blanket section vouches for every repo; scope it or remove it"
}

# .what = each key in one keyring: fingerprint and the identity it claims
__keys_in() {
  local home="$1" ring="$2" out
  # --show-keys reads a file directly, armored or binary, and imports naught
  out="$(gpg --homedir "$home" --with-colons --show-keys "$ring" 2>/dev/null \
    | awk -F: '/^fpr:/ && !f {fpr=$10; f=1} /^uid:/ && f {print "       " fpr "  " $10; f=0}')"
  if [[ -z "$out" ]]; then
    # an armored .asc or an unreadable ring answers empty — say so, never "no keys"
    echo "       (could not list — armored, empty, or unreadable)"
    return 0
  fi
  printf '%s\n' "$out"
}

main "$@"
