#!/usr/bin/env bash
######################################################################
# .what = prove `git grove del` refuses a grove any crew in the ledger still names,
#         and saves the row and its Host block before it drops an uncrewed one
#
# .why  = 📜 2026-11-19: a cleanup judged a live camp grove dead and dropped its two
#         registry rows and its Host blocks. ~20 crews on that box then failed
#         `Permission denied (publickey)`, and the rows had to be rebuilt by hand from
#         tunnel state. the crews were in the ledger the whole time; del never read it
#
# .the rows
#   1. a crewed grove           — refused (exit 2), row and block kept, the crew named
#   2. its `.ground` seat       — refused too: a seat is judged by its box
#   3. an uncrewed grove        — dropped (exit 0), and the saved row + block are the
#                                 exact bytes that were dropped
#   4. a ledger it cannot read  — 💥 (exit 1), the row kept
#   5. no ledger on the machine — dropped, and it says no crew was checked
#   6. the bite                 — the same del with the guard line cut drops the crewed
#                                 grove, so row 1 holds only because of the guard
#
# .what it does to the box
#   - every write lands under one `mktemp -d` HOME, removed on exit. no ssh, no network
#
# usage:
#   rhx play.run --play prove.grove-del-refuses-a-crewed-grove
#
# exit:
#   0 = every claim held · 1 = a claim failed · 2 = the subject is unreadable
######################################################################

set -uo pipefail

echo "🔎 prove.grove-del-refuses-a-crewed-grove"
echo "   └─ subject: git grove del (bash_aliases.sh)"
echo ""

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
[[ -n "$ROOT" ]] || { echo "   └─ ✋ ConstraintError: not inside a git checkout" >&2; exit 2; }
ALIASES="$ROOT/src/grove.provision/2.shell/2.7.aliases/bash_aliases.sh"
[[ -f "$ALIASES" ]] || { echo "   └─ ✋ ConstraintError: the subject is absent: $ALIASES" >&2; exit 2; }
GUARD_LINE='  _git_grove_del_crews_refuse "$name" || return $?'
grep -qxF -- "$GUARD_LINE" "$ALIASES" || { echo "   └─ ✋ ConstraintError: the guard line is absent from $ALIASES" >&2; exit 2; }

failed=0; passed=0
claim() {
  local label="$1"; shift
  if "$@"; then echo "   ✔ $label"; passed=$((passed + 1)); return 0; fi
  echo "   💥 MalfunctionError: $label" >&2; failed=$((failed + 1))
}
has() { [[ "$1" == *"$2"* ]]; }

FIX="$(mktemp -d)" || { echo "   └─ 💥 MalfunctionError: could not build a fixture dir" >&2; exit 1; }
trap 'rm -rf "$FIX"' EXIT
export HOME="$FIX/home"
export GIT_FOREST_DIR="$HOME/.git.forest"
REG="$GIT_FOREST_DIR/groves"
OWN="$HOME/.ssh/config.d/grove.conf"
LEDGER="$FIX/crews.snapshot.json"
export GIT_GROVE_CREW_LEDGER="$LEDGER"

# .what = a fresh registry: a crewed box with its ground seat, and an uncrewed box,
#         each with a row and a Host block in the owned file
fixture_reset() {
  rm -rf "$HOME"; mkdir -p "$REG" "$HOME/.ssh/config.d"
  local name user
  : > "$OWN"
  for name in grove-fix-crewed grove-fix-crewed.ground grove-fix-idle; do
    user=camper; [[ "$name" == *.ground ]] && user=ground
    jq -n --arg n "$name" --arg u "$user" \
      '{name: $n, sshAlias: $n, user: $u, host: "localhost", port: 36999, exid: ($n | sub("\\.ground$"; "")), env: "camp", type: "ec2", status: "active"}' \
      > "$REG/$name.json"
    printf 'Host %s\n  HostName localhost\n  Port 36999\n  User %s\n\n' "$name" "$user" >> "$OWN"
  done
  cat > "$LEDGER" <<'JSON'
{"at":1,"crews":[
  {"tree":"svc-fix.beav.fix-one","grove":"cloud://grove-fix-crewed"},
  {"tree":"svc-fix.beav.fix-two","grove":"cloud://grove-fix-crewed"},
  {"tree":"svc-other.beav.feat-x","grove":"cloud://grove-fix-elsewhere"}
]}
JSON
}

# .what = run `git grove del <name>` from a given aliases file; stdout+stderr, then rc
del_with() { bash -c 'source "$1"; _git_grove_del "$2"' _ "$1" "$2" 2>&1; }

######################################################################
# row 1 — a crewed grove is refused
######################################################################
fixture_reset
out="$(del_with "$ALIASES" grove-fix-crewed)"; rc=$?
claim "1a. a grove two crews name is refused (exit 2)" [ "$rc" -eq 2 ]
claim "1b. the refusal is a ✋ that counts the crews" has "$out" "✋ ConstraintError: grove 'grove-fix-crewed' is still named by 2 crew(s) in the ledger"
claim "1c. it names each crew's tree" bash -c '[[ "$1" == *"svc-fix.beav.fix-one"* && "$1" == *"svc-fix.beav.fix-two"* ]]' _ "$out"
claim "1d. it names no crew of another grove" bash -c '[[ "$1" != *"svc-other"* ]]' _ "$out"
claim "1e. the row is kept" [ -f "$REG/grove-fix-crewed.json" ]
claim "1f. the Host block is kept" grep -qxF "Host grove-fix-crewed" "$OWN"
claim "1g. no copy was saved for a del that never ran" [ ! -d "$GIT_FOREST_DIR/.trash" ]

######################################################################
# row 2 — its ground seat is judged by the box
######################################################################
out="$(del_with "$ALIASES" grove-fix-crewed.ground)"; rc=$?
claim "2a. the .ground seat of a crewed box is refused (exit 2)" [ "$rc" -eq 2 ]
claim "2b. its row and block are kept" \
  bash -c '[[ -f "$1" ]] && grep -qxF "Host grove-fix-crewed.ground" "$2"' _ "$REG/grove-fix-crewed.ground.json" "$OWN"

######################################################################
# row 3 — an uncrewed grove drops, and its bytes are saved first
######################################################################
cp "$REG/grove-fix-idle.json" "$FIX/idle.before.json"
out="$(del_with "$ALIASES" grove-fix-idle)"; rc=$?
claim "3a. a grove no crew names is dropped (exit 0)" [ "$rc" -eq 0 ]
claim "3b. the row is gone, and its block" \
  bash -c '[[ ! -f "$1" ]] && ! grep -qxF "Host grove-fix-idle" "$2"' _ "$REG/grove-fix-idle.json" "$OWN"
saved_row="$(compgen -G "$GIT_FOREST_DIR/.trash/grove-fix-idle.*.json" | head -n 1)"
claim "3c. the saved row is byte-equal to the dropped one" bash -c '[[ -n "$1" ]] && cmp -s "$1" "$2"' _ "$saved_row" "$FIX/idle.before.json"
claim "3d. the saved block holds the dropped Host block" \
  bash -c 'grep -qxF "Host grove-fix-idle" "$1" && grep -qxF "  Port 36999" "$1"' _ "${saved_row%.json}.ssh"
claim "3e. the del names where it saved" has "$out" "💾 saved → $GIT_FOREST_DIR/.trash/grove-fix-idle."
claim "3f. the crewed rows beside it are untouched" \
  bash -c '[[ -f "$1" && -f "$2" ]] && grep -qxF "Host grove-fix-crewed" "$3"' _ "$REG/grove-fix-crewed.json" "$REG/grove-fix-crewed.ground.json" "$OWN"

######################################################################
# row 4 — a ledger it cannot read fails closed
######################################################################
fixture_reset
printf '{"crews": [ broken' > "$LEDGER"
out="$(del_with "$ALIASES" grove-fix-idle)"; rc=$?
claim "4a. an unreadable ledger refuses the del (exit 1)" [ "$rc" -eq 1 ]
claim "4b. it says so as a 💥" has "$out" "💥 MalfunctionError: the crew ledger could not be read"
claim "4c. the row is kept" [ -f "$REG/grove-fix-idle.json" ]

######################################################################
# row 5 — no ledger on this machine
######################################################################
fixture_reset
rm -f "$LEDGER"
out="$(del_with "$ALIASES" grove-fix-idle)"; rc=$?
claim "5a. with no ledger, an uncrewed del proceeds (exit 0)" [ "$rc" -eq 0 ]
claim "5b. and it says no crew was checked" has "$out" "no crew ledger at $LEDGER — no crew is checked"

######################################################################
# row 6 — the bite: cut the guard line, and the crewed grove drops
######################################################################
fixture_reset
grep -vxF -- "$GUARD_LINE" "$ALIASES" > "$FIX/aliases.cut.sh"
claim "6a. the cut copy lacks the guard line (the fixture took)" bash -c '! grep -qxF -- "$1" "$2"' _ "$GUARD_LINE" "$FIX/aliases.cut.sh"
out="$(del_with "$FIX/aliases.cut.sh" grove-fix-crewed)"; rc=$?
claim "6b. without the guard, the crewed grove is dropped (exit 0, row gone)" \
  bash -c '[[ "$1" -eq 0 && ! -f "$2" ]]' _ "$rc" "$REG/grove-fix-crewed.json"

echo ""
echo "🌊 $passed held · $failed failed"
[[ "$failed" -eq 0 ]] || exit 1
exit 0
