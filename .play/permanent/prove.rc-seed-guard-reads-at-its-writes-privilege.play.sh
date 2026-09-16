#!/usr/bin/env bash
######################################################################
# .what = prove `2.5.zsh`'s rc SEED guard reads a seat home at the SAME
#         privilege its write uses — so it can never report "absent" about a
#         file it was merely forbidden to see
#
# 🛑 .why this clamp exists
#   - `2.5.zsh.provision.upsert` seeds an empty `~/.zshrc` on a seat that holds
#     no zsh startup file, so zsh's first-run wizard cannot open on a duct pane
#   - the write is `sudo -n install -m 644 /dev/null <seat>/.zshrc`, which
#     TRUNCATES rather than creates, and it runs as ROOT
#   - the guard ahead of it once read `[[ -f "$seat_home/.zshrc" ]]`, which runs
#     as the INVOKING SEAT
#   - a human seat's home is `drwxr-x---` (0750), so another seat cannot
#     traverse it — and `[[ -f ]]` then answers FALSE for "i cannot see" in
#     exactly the same way it answers FALSE for "it is absent"
#   - ⇒ the guard was BLIND precisely where the write was POTENT
#
# 📜 .measured 2026-09-14, grove-ahbode-v20260901 — a GROUND apply read
#   `/home/camper/.zshrc` as absent (the real answer was `Permission denied`)
#   and truncated a live 39300-byte rc to 0 bytes. every login on that seat then
#   landed in a bare zsh: no starship, no aliases, no repo:branch title
#   - ⚠️ `configure.verify`'s `zsh -n` parse row reported ✔ throughout, because
#     an EMPTY file is valid zsh. only its `cmp` row went red, so the page read
#     as partly green and the cause was not obvious from it
#
# ⇒ the general rule this clamps: A GUARD MUST READ AT THE PRIVILEGE ITS WRITE
#   USES. where the two differ, the guard reports "absent" about a file it was
#   forbidden to see — and a destructive write fires on that answer
#
# .what it does to the box
#   - builds ONE fixture under its own `mktemp -d`: a directory holding a
#     `.zshrc`, chmod'd `0000` so the invoking seat cannot traverse it while
#     root still can. that is the 0750 seam, reproduced with no second seat
#   - it NEVER touches a real seat's home, and NEVER runs the bundle
#   - the write is a round trip whose net effect is zero
#
# guarantee:
#   - the restore is a `trap … EXIT`, so it runs on a timeout, a crash, or a
#     bad exit — never only on the happy path
#   - it REFUSES rather than invent a subject: an absent `_.sh`, an absent
#     `$HOME/.zshrc`, or a box with no passwordless sudo each exit 2
#   - arms 0a/0b CALIBRATE both directions, so a guard that answers TRUE always
#     and a guard that answers FALSE always each fail
#   - arm 1 asserts the FIXTURE actually blocks the naive read before arm 2
#     measures against it (`gotcha.a-check-that-cries-wolf-gets-silenced`, q5)
#   - arm 4 reads the CALLER too, so a reintroduced inline `[[ -f ]]` in the
#     upsert fails even while the shared guard stays correct
#     (`rule.require.a-cue-is-not-a-claim`: two cues, and they cannot disagree)
#
# usage:
#   rhx play.run --play prove.rc-seed-guard-reads-at-its-writes-privilege
#
# exit:
#   0 = the guard reads at root, and the caller asks it
#   1 = it does not — a truncating write can fire on a blind answer
#   2 = the subject could not be read, so no claim was proven
######################################################################

set -uo pipefail

FAILS=0

_self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)" || _self=""
if   [[ -n "$_self" && -f "$_self/src/grove.provision._.sh" ]]; then _root="$_self"
elif [[ -f "$PWD/src/grove.provision._.sh" ]];                 then _root="$PWD"
else                                                                _root="$HOME/git/more/dev-env-setup"
fi

BUNDLE="$_root/src/grove.provision/2.shell/2.5.zsh"
GUARD_SRC="$BUNDLE/_.sh"
UPSERT_SRC="$BUNDLE/provision.upsert.sh"

echo ""
echo "🐢 prove: the rc seed guard reads at its write's privilege"
echo "   └─ subject: _grove_provision_2_5_zsh_seat_has_startup_file"
echo ""

######################################################################
# 0. decline unless every precondition holds
######################################################################
for f in "$GUARD_SRC" "$UPSERT_SRC"; do
  if [[ ! -f "$f" ]]; then
    echo "   ✋ no such file: $f" >&2
    echo "      ⇒ this play has no subject on this box" >&2
    exit 2
  fi
done

# shellcheck source=/dev/null
source "$GUARD_SRC" || { echo "   ✋ could not source $GUARD_SRC" >&2; exit 2; }

if ! command -v _grove_provision_2_5_zsh_seat_has_startup_file >/dev/null 2>&1; then
  echo "   ✋ the guard is not declared in $GUARD_SRC" >&2
  echo "      ⇒ its name changed, or it was deleted. the seed's only guard" >&2
  echo "        against a truncating write is gone" >&2
  exit 1
fi

if [[ ! -f "$HOME/.zshrc" ]]; then
  echo "   🌙 this seat holds no ~/.zshrc, so arm 0a has no subject" >&2
  echo "      fix: rhx grove.provision --what 2.5.zsh --mode apply" >&2
  exit 2
fi

# 🛑 .why a box with no passwordless sudo is a DECLINE and not a pass
#   - the guard's non-$HOME branch is `sudo -n test -f`, so it answers false
#     there — and the write beside it fails for the identical reason
#   - guard and write are then ONE mechanism and cannot disagree, so the seam
#     this play measures does not exist on that box
#   - ⇒ it has no claim to make, and a ✔ here would be a false one
if ! sudo -n true >/dev/null 2>&1; then
  echo "   🌙 no passwordless sudo on this seat" >&2
  echo "      ⇒ the guard and its write both run unprivileged here, so they" >&2
  echo "        cannot disagree and this seam has no subject to measure" >&2
  exit 2
fi

######################################################################
# the fixture, and its unconditional restore
#
# ⚠️ every path is under one `mktemp -d` — a fixed path in a shared tmp is a
#    hijack seam (`rule.forbid.fixed-paths-in-a-shared-tmp`)
######################################################################
FIX="$(mktemp -d)" || { echo "   ✋ could not make a scratch dir" >&2; exit 2; }

_restore() {
  [[ -n "${FIX:-}" && -d "$FIX" ]] || return 0
  chmod 0700 "$FIX" "$FIX/opaque" "$FIX/empty" 2>/dev/null || true
  rm -rf "$FIX" 2>/dev/null || true
}
trap _restore EXIT

mkdir -p "$FIX/opaque" "$FIX/empty" || { echo "   ✋ could not build the fixture" >&2; exit 2; }
printf '# a live rc a blind guard would truncate\n' > "$FIX/opaque/.zshrc"

# 0000 denies traverse to the owner too, and root bypasses it — the 0750 seam
# between two seats, reproduced with no second seat
chmod 0000 "$FIX/opaque" || { echo "   ✋ could not seal the fixture" >&2; exit 2; }

# assert the fixture LANDED before any arm measures against it
if ! sudo -n test -f "$FIX/opaque/.zshrc"; then
  echo "   🌙 the fixture rc did not land, so no arm has a subject" >&2
  exit 2
fi

echo "   ├─ arms"

######################################################################
# arm 0a — CALIBRATION: the guard SEES this seat's own rc
#
# .why a guard that answers FALSE always would pass arm 2 by luck
######################################################################
if _grove_provision_2_5_zsh_seat_has_startup_file "$HOME"; then
  echo "   │  ├─ 0a. own home, rc present  → present ✔ the guard is not blind"
else
  echo "   │  ├─ 0a. own home, rc present  → ABSENT  ✋" >&2
  echo "   │  │      ⇒ the guard cannot see a file in its own \$HOME, so every" >&2
  echo "   │  │        verdict below is worthless" >&2
  FAILS=$(( FAILS + 1 ))
fi

######################################################################
# arm 0b — CALIBRATION, the other way: an EMPTY readable home reads absent
#
# .why a guard that answers TRUE always would pass arms 0a and 2 together,
#      and would suppress the seed on every seat that genuinely needs one
######################################################################
if _grove_provision_2_5_zsh_seat_has_startup_file "$FIX/empty"; then
  echo "   │  ├─ 0b. empty home, readable  → PRESENT ✋" >&2
  echo "   │  │      ⇒ the guard answers present for a home that holds no" >&2
  echo "   │  │        startup file, so no seat is ever seeded and zsh's" >&2
  echo "   │  │        first-run wizard opens on the duct pane (term=eat)" >&2
  FAILS=$(( FAILS + 1 ))
else
  echo "   │  ├─ 0b. empty home, readable  → absent  ✔ it still reports a gap"
fi

######################################################################
# arm 1 — the FIXTURE is genuinely opaque to a naive read
#
# 🛑 .why this arm and not just arm 2
#   - arm 2 claims "the guard sees what a naive read cannot"
#   - if the fixture were readable after all, arm 2 would pass for the WRONG
#     reason and prove none of it (`…cries-wolf`, q5 — did the fixture take?)
######################################################################
if [[ -f "$FIX/opaque/.zshrc" ]]; then
  echo "   │  ├─ 1.  the fixture is opaque → READABLE ✋" >&2
  echo "   │  │      ⇒ the unprivileged read SUCCEEDED, so this box does not" >&2
  echo "   │  │        enforce directory traverse and the seam is not" >&2
  echo "   │  │        reproduced. arm 2 below proves none of its claim" >&2
  FAILS=$(( FAILS + 1 ))
else
  echo "   │  ├─ 1.  the fixture is opaque → blind   ✔ a bare [[ -f ]] says absent"
fi

######################################################################
# 🛑 arm 2 — THE BITE: the guard sees THROUGH the opaque home
#
# this is the arm that reddens under the 2026-09-14 defect. the old guard read
# `[[ -f ]]`, which arm 1 just proved answers "absent" here
######################################################################
if _grove_provision_2_5_zsh_seat_has_startup_file "$FIX/opaque"; then
  echo "   │  ├─ 2.  opaque home, rc there → present ✔ it reads at ROOT"
else
  echo "   │  ├─ 2.  opaque home, rc there → ABSENT  ✋ THE DEFECT IS BACK" >&2
  echo "   │  │      ⇒ the guard reads BELOW the privilege its write uses, so" >&2
  echo "   │  │        it reports 'absent' about a file it was merely forbidden" >&2
  echo "   │  │        to see — and \`install /dev/null\` TRUNCATES on that answer" >&2
  echo "   │  │      📜 this truncated a live 39300-byte rc on 2026-09-14" >&2
  FAILS=$(( FAILS + 1 ))
fi

######################################################################
# arm 3 — the WRITE-SIDE precondition also sees it
#
# .why a second, independent refusal
#   - `install /dev/null` truncates, so the write owns a precondition no
#     caller-side guard can be trusted to keep across a later edit
######################################################################
if sudo -n test -e "$FIX/opaque/.zshrc"; then
  echo "   │  ├─ 3.  the write's own test  → present ✔ it would refuse to fire"
else
  echo "   │  ├─ 3.  the write's own test  → ABSENT  ✋" >&2
  echo "   │  │      ⇒ the write cannot see its own target either, so no guard" >&2
  echo "   │  │        stands between a blind answer and a truncation" >&2
  FAILS=$(( FAILS + 1 ))
fi

######################################################################
# arm 4 — the CALLER asks the guard, rather than an inline read of its own
#
# 🛑 .why a second cue on one defect
#   - arms 0-3 grade the GUARD. this grades the UPSERT that calls it
#   - a future edit could leave the guard correct and reintroduce a bare
#     `[[ -f "$seat_home/.zsh… ]]` chain in the seat loop — arms 0-3 stay green
#     while the truncating write fires on a blind answer once more
#   - the two cues cannot disagree, so the second costs one arm and catches a
#     shape the first cannot see (`rule.require.a-cue-is-not-a-claim`)
#
# ⚠️ `-e "$seat_home/.zshrc"` in the own-home branch is NOT this shape: that is
#    the write's precondition, asked where no privilege is owed. the forbidden
#    shape is a `-f` PRESENCE test against a `.zsh*` name, which is the
#    question the shared guard exists to answer
######################################################################
inline="$(grep -nE '\[\[[^]]*-f[[:space:]]+"?\$(\{)?seat_home(\})?/\.zsh' "$UPSERT_SRC" || true)"
if [[ -z "$inline" ]]; then
  echo "   │  └─ 4.  the caller asks the guard        ✔ no inline presence test"
else
  echo "   │  └─ 4.  the caller asks the guard        ✋ an inline test is back" >&2
  printf '   │        %s\n' "$inline" >&2
  echo "   │        ⇒ a bare [[ -f ]] in the seat loop reads at the CALLER's" >&2
  echo "   │          privilege while the write below it runs as root" >&2
  FAILS=$(( FAILS + 1 ))
fi

######################################################################
# the restore, judged by a RE-READ rather than by the exit code of the rm
######################################################################
_restore
echo ""
if [[ -d "$FIX" ]]; then
  echo "   ✋ the restore left the fixture behind: $FIX" >&2
  echo "      ⇒ remove it by hand — it holds a directory nobody can traverse" >&2
  exit 1
fi
echo "   ✔ restore — the fixture is gone"
echo ""

if [[ "$FAILS" -eq 0 ]]; then
  echo "🌲 the rc seed guard reads at its write's privilege ✔"
  echo "   ├─ it sees a file behind a home it cannot traverse"
  echo "   ├─ and still reports a gap where one truly exists"
  echo "   └─ and the upsert asks IT, rather than a read of its own"
  exit 0
fi

echo "   ✋ $FAILS arm(s) disagree with the required verdict" >&2
echo "      ⇒ a truncating write can fire on a blind answer" >&2
exit 1
