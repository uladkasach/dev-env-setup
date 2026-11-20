#!/usr/bin/env bash
######################################################################
# .what = prove `pkg_install` names every absent package BEFORE a seat with no
#         root refuses, and names none when all are present
#
# .why  = 📜 2026-11-19: a camper seat refused 5.21.playwright with the no-root ✋.
#         every row it printed read ✔, since a present package prints and an
#         absent one did not — so the refusal named no package, and the cause (a
#         stale checkout on ground that never installed one) took a pane hunt
#
# .the rows
#   1. one absent, no root  — the absent name prints, then the refusal
#   2. all present          — no "absent" line, and no root is asked for
#   3. the bite             — with the line cut, row 1 names no package
#
# .what it does to the box
#   - none: every pkg_* probe is stubbed in a subshell; no apt, no sudo
#
# usage:
#   rhx play.run --play prove.pkg-install-names-what-it-wants
#
# exit:
#   0 = every claim held · 1 = a claim failed · 2 = the subject is unreadable
######################################################################

set -uo pipefail

echo "🔎 prove.pkg-install-names-what-it-wants"
echo "   └─ subject: pkg_install (src/grove.pkg.sh)"
echo ""

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[[ -n "$ROOT" ]] || { echo "   └─ ✋ ConstraintError: not inside a git checkout" >&2; exit 2; }
SUBJECT="$ROOT/src/grove.pkg.sh"
[[ -f "$SUBJECT" ]] || { echo "   └─ ✋ ConstraintError: the subject is absent: $SUBJECT" >&2; exit 2; }
LINE='echo "   • absent, to install: ${wanted[*]}"'
grep -qF -- "$LINE" "$SUBJECT" || { echo "   └─ ✋ ConstraintError: the absent-name line is not in $SUBJECT" >&2; exit 2; }

failed=0; passed=0
claim() {
  local label="$1"; shift
  if "$@"; then echo "   ✔ $label"; passed=$((passed + 1)); return 0; fi
  echo "   💥 MalfunctionError: $label" >&2; failed=$((failed + 1))
}
has() { [[ "$1" == *"$2"* ]]; }
lacks() { [[ "$1" != *"$2"* ]]; }

FIX="$(mktemp -d)" || { echo "   └─ 💥 MalfunctionError: could not build a fixture dir" >&2; exit 1; }
trap 'rm -rf "$FIX"' EXIT

# .what = source a copy of the subject, stub every probe, run pkg_install
#   - present names are read from PRESENT; pkg_assert_sudo refuses and logs that it was asked
run_with() {
  local subject="$1"; shift
  ( # shellcheck disable=SC1090
    source "$subject" >/dev/null 2>&1
    pkg_assert_apt() { return 0; }
    pkg_present() { [[ " $PRESENT " == *" $1 "* ]]; }
    pkg_assert_sudo() { echo "SUDO-ASKED"; echo "✋ no root" >&2; return 1; }
    pkg_install "$@"
  ) 2>&1
}

######################################################################
# row 1 — one absent, no root
######################################################################
PRESENT="liba libb"
out="$(run_with "$SUBJECT" liba libb libc)"; rc=$?
claim "1a. the run refuses (non-zero)" [ "$rc" -ne 0 ]
claim "1b. the absent package is named" has "$out" "absent, to install: libc"
claim "1c. the name prints before the refusal" bash -c '[[ "${1%%SUDO-ASKED*}" == *"absent, to install"* ]]' _ "$out"

######################################################################
# row 2 — all present
######################################################################
PRESENT="liba libb libc"
out="$(run_with "$SUBJECT" liba libb libc)"; rc=$?
claim "2a. a converged box passes (exit 0)" [ "$rc" -eq 0 ]
claim "2b. no absent line prints" lacks "$out" "absent, to install"
claim "2c. no root is asked for" lacks "$out" "SUDO-ASKED"

######################################################################
# row 3 — the bite: cut the line, and row 1 names no package
######################################################################
body="$(cat "$SUBJECT")"
printf '%s\n' "${body//"$LINE"/:}" > "$FIX/grove.pkg.cut.sh"
claim "3a. the cut copy lacks the line (the fixture took)" bash -c '! grep -qF -- "$1" "$2"' _ "$LINE" "$FIX/grove.pkg.cut.sh"
PRESENT="liba libb"
out="$(run_with "$FIX/grove.pkg.cut.sh" liba libb libc)"
claim "3b. without the line, the refusal names no package" lacks "$out" "libc"

echo ""
echo "🌊 $passed held · $failed failed"
[[ "$failed" -eq 0 ]] || exit 1
exit 0
