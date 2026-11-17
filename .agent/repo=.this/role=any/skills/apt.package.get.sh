#!/usr/bin/env bash
######################################################################
# .what = read what apt knows of one or more packages: installed version,
#         candidate version and its source, the candidate's declared Depends,
#         and whether an install would succeed — a simulated install, no root
#
# .why  = "apt has it and the install still failed" has several causes — a
#         held lock, a stale index, an unmet dependency — and they want
#         different repairs. the simulation names which one holds, read-only
#
# usage:
#   rhx apt.package.get --name dropbox
#   rhx apt.package.get --name libpango1.0-0 --name libpango-1.0-0
#
# guarantee:
#   - READ-ONLY: apt-cache reads and an `apt-get --simulate`; no sudo, no lock
######################################################################

set -uo pipefail

main() {
  local names=() files=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) names+=("${2:-}"); shift 2 ;;
      --files) files=1; shift ;;
      --help|-h)
        echo "📦 apt.package.get — installed, candidate, depends, and a simulated install verdict"
        echo ""
        echo "usage:"
        echo "  rhx apt.package.get --name <pkg> [--name <pkg> …]"
        return 0 ;;
      --repo|--role|--skill) shift 2 ;;
      *) echo "✋ ConstraintError: unknown arg: $1" >&2; echo "   fix: rhx apt.package.get --help" >&2; return 2 ;;
    esac
  done
  if [[ ${#names[@]} -eq 0 ]]; then
    echo "✋ ConstraintError: name at least one package with --name" >&2; return 2
  fi
  if ! command -v apt-cache >/dev/null 2>&1; then
    echo "✋ ConstraintError: apt-cache is absent — this box is not apt-based" >&2; return 2
  fi

  echo "📦 apt.package.get"
  local name policy installed candidate source depends sim verdict
  for name in "${names[@]}"; do
    policy="$(apt-cache policy "$name" 2>&1)"
    installed="$(awk -F': ' '/Installed:/{print $2; exit}' <<<"$policy")"
    candidate="$(awk -F': ' '/Candidate:/{print $2; exit}' <<<"$policy")"
    # the first source row under the version table
    source="$(awk '/Version table:/{t=1; next} t && /^ +[0-9]+ /{print $2, $3; exit}' <<<"$policy")"
    echo ""
    echo "   • $name"
    echo "       installed: ${installed:-unknown to apt}"
    echo "       candidate: ${candidate:-unknown to apt}${source:+  ($source)}"
    if [[ -z "$candidate" || "$candidate" == "(none)" ]]; then
      echo "       ⇒ no candidate — absent from every repo this box reads"
      continue
    fi

    depends="$(apt-cache show "$name=$candidate" 2>/dev/null | awk -F': ' '/^Depends:/{print $2; exit}')"
    echo "       depends:   ${depends:-none}"

    # the simulation is apt's own solver, so its verdict is the one a real install meets
    sim="$(apt-get --simulate install "$name" 2>&1)"
    if grep -q '^Inst ' <<<"$sim" || grep -q 'is already the newest version' <<<"$sim"; then
      verdict="installable ✔"
    else
      verdict="NOT installable ✋"
    fi
    echo "       install:   $verdict"
    grep -E 'Depends:|but it is not|^E: ' <<<"$sim" | sed 's/^ */         /'

    [[ "$files" -eq 1 ]] && __pkg_files "$name" "$candidate"
  done

  # a read answered is a success, whatever it found — the last grep's no-match is not a failure
  return 0
}

# .what = fetch the candidate .deb into a private temp dir, unpacked and NEVER
#         installed, and print its files and the maintainer hooks that would run
#         as root — so "what does this put on the box" is read, not assumed
__pkg_files() {
  local name="$1" version="$2" tmp deb hook root
  # into the repo's gitignored .temp/, so the unpacked files can be read with the
  # repo's own tools; outside a repo, a private temp dir
  root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [[ -n "$root" ]]; then
    tmp="$root/.temp/apt.package.get/$name=$version"
    rm -rf -- "$tmp" && mkdir -p "$tmp"
  else
    tmp="$(mktemp -d)"
  fi
  [[ -d "$tmp" ]] || { echo "       💥 MalfunctionError: no dir to unpack into" >&2; return 1; }
  # apt-get download writes into the cwd; a subshell keeps the cwd change local
  if ! ( cd "$tmp" && apt-get download "$name=$version" >/dev/null 2>&1 ); then
    echo "       💥 MalfunctionError: apt-get download $name=$version failed — the files stay unread" >&2
    rm -rf "$tmp"; return 1
  fi
  deb="$(printf '%s\n' "$tmp"/*.deb | head -n 1)"
  echo "       package:   $(basename "$deb") · $(du -h "$deb" | cut -f1) · sha256 $(sha256sum "$deb" | cut -c1-16)…"
  echo "       unpacked:  $tmp/root  (left for a read; delete when done)"
  dpkg-deb -x "$deb" "$tmp/root" && dpkg-deb -e "$deb" "$tmp/root/DEBIAN"
  echo "       files:"
  dpkg-deb -c "$deb" | awk '$6 !~ /\/$/ {printf "         %8s  %s\n", $3, $6}'
  echo "       maintainer hooks (run as ROOT at install):"
  local any=0
  for hook in preinst postinst prerm postrm config triggers; do
    [[ -f "$tmp/root/DEBIAN/$hook" ]] || continue
    any=1
    echo "         • $hook ($(wc -l <"$tmp/root/DEBIAN/$hook") lines) — $tmp/root/DEBIAN/$hook"
  done
  [[ "$any" -eq 1 ]] || echo "         none ✔"
}

main "$@"
