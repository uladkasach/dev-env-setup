#!/usr/bin/env bash
######################################################################
# .what = prove `dox.diff.verify` flags a grove name of any segment count
#
# .why  = 📜 2026-11-19: the machine class matched `grove-<org>-v<date>` only, so a
#         name with a platform segment between the org and the date passed the
#         scan clean. a public pr then carried 35 real box names past a green
#         verdict. one segment was the whole fault
#
# .the rows
#   1. a one-segment name   — flagged (the shape the class always read)
#   2. a two-segment name   — flagged (the shape it missed)
#   3. a clean diff         — exit 0, no hit
#   4. the bite             — the same scan with the segment group cut misses row 2
#   5. a forge's ssh user   — passes; a personal address on the same line still fails
#
# .what it does to the box
#   - every write lands under one `mktemp -d`, removed on exit. no network
#
# usage:
#   rhx play.run --play prove.dox-diff-reads-every-grove-name
#
# exit:
#   0 = every claim held · 1 = a claim failed · 2 = the subject is unreadable
######################################################################

set -uo pipefail

echo "🔎 prove.dox-diff-reads-every-grove-name"
echo "   └─ subject: dox.diff.verify (machine class)"
echo ""

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[[ -n "$ROOT" ]] || { echo "   └─ ✋ ConstraintError: not inside a git checkout" >&2; exit 2; }
SKILL="$ROOT/.agent/repo=.this/role=any/skills/dox.diff.verify.sh"
[[ -f "$SKILL" ]] || { echo "   └─ ✋ ConstraintError: the subject is absent: $SKILL" >&2; exit 2; }
SEGMENTS='(-[a-z0-9]+)*'
grep -qF -- "$SEGMENTS" "$SKILL" || { echo "   └─ ✋ ConstraintError: the segment group is absent from $SKILL" >&2; exit 2; }

# the fixture names, built at run time: a literal here would trip the very scan this
#   play proves, on every diff that touches it. fake org, a date no box will hold
DAY="v20991231"
ONE="grove-acme-$DAY"
TWO="grove-acme-hetzner-$DAY"

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

# .what = a fresh repo with one staged file of the given text
repo_with() {
  rm -rf "$FIX/repo"; mkdir -p "$FIX/repo"
  git -C "$FIX/repo" init -q
  git -C "$FIX/repo" -c user.name=fixture -c user.email=fixture@example.com commit -q --allow-empty -m root
  printf '%s\n' "$1" > "$FIX/repo/note.md"
  git -C "$FIX/repo" add note.md
}

# .what = run a scanner copy inside the fixture repo; stdout+stderr, then rc
scan_with() { ( cd "$FIX/repo" && bash "$1" ) 2>&1; }

######################################################################
# row 1 — a one-segment name
######################################################################
repo_with "# measured on $ONE, camper seat"
out="$(scan_with "$SKILL")"; rc=$?
claim "1a. a one-segment grove name fails the scan (exit 1)" [ "$rc" -eq 1 ]
claim "1b. it is named as a machine hit" has "$out" "machine  $ONE"

######################################################################
# row 2 — a two-segment name
######################################################################
repo_with "# measured on $TWO, camper seat"
out="$(scan_with "$SKILL")"; rc=$?
claim "2a. a two-segment grove name fails the scan (exit 1)" [ "$rc" -eq 1 ]
claim "2b. it is named whole, platform segment and all" has "$out" "machine  $TWO"

######################################################################
# row 3 — a clean diff
######################################################################
repo_with '# measured on a hetzner grove, camper seat'
out="$(scan_with "$SKILL")"; rc=$?
claim "3a. a diff with no name passes (exit 0)" [ "$rc" -eq 0 ]
claim "3b. it names no machine" lacks "$out" "machine  grove-"

######################################################################
# row 4 — the bite: cut the segment group, and row 2 passes clean
######################################################################
body="$(cat "$SKILL")"
printf '%s\n' "${body//"$SEGMENTS"/}" > "$FIX/scan.cut.sh"
claim "4a. the cut copy lacks the segment group (the fixture took)" bash -c '! grep -qF -- "$1" "$2"' _ "$SEGMENTS" "$FIX/scan.cut.sh"
repo_with "# measured on $TWO, camper seat"
out="$(scan_with "$FIX/scan.cut.sh")"; rc=$?
claim "4b. without the group, the two-segment name passes clean (exit 0)" [ "$rc" -eq 0 ]

######################################################################
# row 5 — a forge's ssh user is no person; a personal address beside it still is
######################################################################
FORGE="git@""github.com"
PERSON="jane.doe""@gmail.com"
repo_with "push url: $FORGE:acme/repo.git"
out="$(scan_with "$SKILL")"; rc=$?
claim "5a. a forge's ssh user passes (exit 0)" [ "$rc" -eq 0 ]
repo_with "push url: $FORGE:acme/repo.git, ask $PERSON"
out="$(scan_with "$SKILL")"; rc=$?
claim "5b. a personal address on the same line still fails (exit 1)" [ "$rc" -eq 1 ]
claim "5c. the hit names the person, never the forge user" bash -c '[[ "$1" == *"email  $2"* && "$1" != *"email  $3"* ]]' _ "$out" "$PERSON" "$FORGE"

echo ""
echo "🌊 $passed held · $failed failed"
[[ "$failed" -eq 0 ]] || exit 1
exit 0
