#!/usr/bin/env bash
######################################################################
# .what = prove `git grove del --orphaned` reports an ORPHAN as droppable, and
#         HALTS rather than drop when it could not ask aws at all
#
# 🛑 .why the second arm is the one that matters
#   - the sweep's design rests on a three-valued answer:
#       found            → keep
#       absent, ASKED    → orphan, droppable
#       could not ask    → NO VERDICT — halt, drop no entry
#   - a two-valued sweep folds the third into the second
#   - a camp credential lapses about hourly
#   - a two-valued sweep deletes the whole forest on any run that catches a
#     locked rack — silently, every row reads like a true orphan
#   - a green run proves none of this: on a healthy laptop with live creds,
#     every grove is `found`, so the other two arms stay unreachable and a
#     clean page is evidence about the keep path alone
#
# 🛑 .why this play exists rather than a hand check
#   - 📜 2026-09-02: a hand sweep asked `--tag Name=<grove>` and got "no
#     instance matched" for a box booted minutes earlier
#   - these instances carry NO `Name` tag, so the reader was blind and its
#     blindness read as absence
#   - the verdict was wrong in the DELETE direction, for every entry at once
#   - a tag-based reader cannot tell instances apart: `--orphaned --mode
#     apply` risks a drop of the entire registry, each row indistinguishable
#     from a true orphan
#
# .what it does to the box
#   - writes TWO registry entries under names no real grove can hold
#   - runs the sweep in PLAN mode only, then removes them
#   - never runs `--mode apply`, so no real entry can be dropped however this
#     play fails
#   - the write is a round trip whose net effect is zero
#
# guarantee:
#   - the restore is a `trap … EXIT`, so it runs on a timeout, a crash, or a
#     bad exit — never only on the happy path
#   - it REFUSES to run if either fixture name is already taken, rather than
#     overwrite a real entry and restore an invention
#   - it asserts the fixture LANDED before it measures against it
#     (`gotcha.a-check-that-cries-wolf-gets-silenced`, q5)
#   - arm 0 is the calibration: a LIVE grove must read `kept`. without it, a
#     blind reader would pass arm 3 perfectly — an orphan verdict for the
#     wrong reason (this is the exact 2026-09-02 defect)
#
# usage:
#   rhx play.run --play prove.orphan-sweep-bites
#
# exit:
#   0 = the sweep discriminates: keep, orphan, and halt
#   1 = it does not
#   2 = the subject could not be read, so no claim was proven
######################################################################

set -uo pipefail

DIR="$HOME/.git.forest/groves"
FIX_ORPHAN="zz-probe-orphan-doesnotexist"
FIX_NOASK="zz-probe-noask-doesnotexist"

echo "🔎 prove.orphan-sweep-bites"
echo "   └─ subject: git grove del --orphaned"
echo ""

######################################################################
# 0. decline unless every precondition holds
######################################################################
if ! command -v git_alias_grove &>/dev/null; then
  # shellcheck source=/dev/null
  source "$HOME/.bash_aliases" 2>/dev/null || true
fi
if ! command -v git_alias_grove &>/dev/null; then
  echo "   ✋ git_alias_grove is absent — the installed aliases are stale" >&2
  echo "      fix: rhx grove.provision --what 2.7.aliases --mode apply" >&2
  exit 2
fi

if [[ ! -d "$DIR" ]]; then
  echo "   🌙 no registry at $DIR" >&2
  echo "      ⇒ the sweep has no subject here" >&2
  exit 2
fi

# 🛑 .why this refuses a name already taken
#   - an overwrite-then-restore of a real entry destroys a record this play
#     never read
for n in "$FIX_ORPHAN" "$FIX_NOASK"; do
  if [[ -e "$DIR/$n.json" ]]; then
    echo "   ✋ $n.json already exists — refused, rather than overwrite it" >&2
    exit 2
  fi
done

######################################################################
# the fixtures, and their unconditional restore
######################################################################
_restore() {
  rm -f "$DIR/$FIX_ORPHAN.json" "$DIR/$FIX_NOASK.json"
}
trap _restore EXIT

fails=0

# an entry whose exid no instance carries — env `camp` is REAL, so the reader
# asks aws and hears "no match"
cat > "$DIR/$FIX_ORPHAN.json" <<JSON
{"name":"$FIX_ORPHAN","sshAlias":"$FIX_ORPHAN","exid":"$FIX_ORPHAN","env":"camp","type":"ec2","status":"active"}
JSON

# an entry whose env the rack cannot serve, so the reader CANNOT ASK
# reproduces the lapsed-credential case without a lock of the live session
cat > "$DIR/$FIX_NOASK.json" <<JSON
{"name":"$FIX_NOASK","sshAlias":"$FIX_NOASK","exid":"$FIX_NOASK","env":"zz-no-such-env","type":"ec2","status":"active"}
JSON

if [[ ! -f "$DIR/$FIX_ORPHAN.json" || ! -f "$DIR/$FIX_NOASK.json" ]]; then
  echo "   🌙 the fixtures did not land, so no arm has a subject" >&2
  exit 2
fi

echo "   ├─ arms"

######################################################################
# 🛑 .what = arm 0 — CALIBRATION: a live grove must still read `kept`
#
# .why
#   - without it, a reader blind in any new way passes arm 3 perfectly
#   - it calls the orphan an orphan for the wrong reason
#   - it calls every live grove an orphan too
######################################################################
out="$(git_alias_grove del --orphaned 2>&1)"; rc=$?

if [[ "$out" == *"the instance exists; kept"* ]]; then
  echo "   │  ├─ 0. a LIVE grove reads 'kept'        ✔ the reader is not blind"
else
  echo "   │  ├─ 0. a LIVE grove reads 'kept'        ✋ no grove read as kept" >&2
  echo "   │  │     ⇒ the reader cannot see instances that exist, so every" >&2
  echo "   │  │       verdict below is worthless. this is the 2026-09-02 defect" >&2
  fails=$(( fails + 1 ))
fi

######################################################################
# 🛑 .what = arm 1 — THE HALT: the no-ask entry must stop the sweep dead
#
# .why
#   - the halt must be NON-ZERO
#   - a halt that exits 0 reads to any caller as a clean sweep
#     (`rule.forbid.failhide`)
######################################################################
if [[ "$out" == *"could not ask aws"* && "$rc" -ne 0 ]]; then
  echo "   │  ├─ 1. an unaskable entry HALTS          ✔ rc=$rc, and it said why"
else
  echo "   │  ├─ 1. an unaskable entry HALTS          ✋ rc=$rc" >&2
  echo "   │  │     ⇒ a sweep that treats 'could not ask' as 'gone' deletes" >&2
  echo "   │  │       the whole forest on any lapsed credential" >&2
  fails=$(( fails + 1 ))
fi

######################################################################
# 🛑 .what = arm 2 — NO ENTRY IS DROPPED on that halt
#
# .why
#   - a halt after the deletes is worthless
#   - read the DISK, never the message
######################################################################
if [[ -f "$DIR/$FIX_ORPHAN.json" ]]; then
  echo "   │  ├─ 2. the halt dropped no entry         ✔ the registry is intact"
else
  echo "   │  ├─ 2. the halt dropped no entry         ✋ an entry is already gone" >&2
  echo "   │  │     ⇒ the sweep deletes BEFORE it halts, so the halt guards" >&2
  echo "   │  │       no part of the registry at all" >&2
  fails=$(( fails + 1 ))
fi

######################################################################
# arm 3 — with the unaskable entry removed, the ORPHAN is named as droppable
######################################################################
rm -f "$DIR/$FIX_NOASK.json"
out2="$(git_alias_grove del --orphaned 2>&1)"; rc2=$?

named=0;   [[ "$out2" == *"$FIX_ORPHAN"* && "$out2" == *"no instance carries exid"* ]] && named=1
planned=0; [[ "$out2" == *"would be dropped"* ]] && planned=1
kept=0;    [[ "$out2" == *"the instance exists; kept"* ]] && kept=1

if [[ "$named" -eq 1 && "$planned" -eq 1 && "$kept" -eq 1 && "$rc2" -eq 0 ]]; then
  echo "   │  ├─ 3. a true orphan is named droppable  ✔ and live groves kept beside it"
else
  echo "   │  ├─ 3. a true orphan is named droppable  ✋ named=$named planned=$planned kept=$kept rc=$rc2" >&2
  printf '   │  │     %s\n' "$out2" >&2
  fails=$(( fails + 1 ))
fi

######################################################################
# arm 4 — PLAN dropped no entry. the default mode may never write
######################################################################
if [[ -f "$DIR/$FIX_ORPHAN.json" ]]; then
  echo "   │  └─ 4. plan mode dropped no entry        ✔ plan is read-only"
else
  echo "   │  └─ 4. plan mode dropped no entry        ✋ plan deleted the entry" >&2
  echo "   │        ⇒ the default mode writes, so a bare invocation is" >&2
  echo "   │          destructive (rule.require.safe-by-default)" >&2
  fails=$(( fails + 1 ))
fi

######################################################################
# the restore, judged by a RE-READ rather than by the exit code of the rm
######################################################################
_restore
left=""
for n in "$FIX_ORPHAN" "$FIX_NOASK"; do
  [[ -e "$DIR/$n.json" ]] && left="$left $n"
done

echo ""
if [[ -n "$left" ]]; then
  echo "   ✋ the restore left fixtures behind:$left" >&2
  echo "      ⇒ remove them by hand — they are registry entries for groves" >&2
  echo "        that never existed" >&2
  exit 1
fi
echo "   ✔ restore — both fixtures removed"
echo ""

if [[ "$fails" -eq 0 ]]; then
  echo "🌲 the orphan sweep bites ✔"
  echo "   ├─ keeps a live grove, names a true orphan"
  echo "   └─ HALTS on an entry it could not ask about, and drops none"
  exit 0
fi

echo "   ✋ $fails arm(s) disagree with the required verdict" >&2
exit 1
