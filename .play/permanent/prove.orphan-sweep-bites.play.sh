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
#   - arms 0 and 3 DECLINE, never fail, when a foreign entry halted the run
#     before it reached a readable grove — see the discriminator below
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
declines=0

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

######################################################################
# 🛑 .the discriminator — a FOREIGN halt starves arms 0 and 3 of a subject
#
# 📜 measured 2026-09-30. arms 0 and 3 read the same run as arm 1, and the
#    sweep HALTS at its FIRST unaskable entry — so a locked credential on any
#    real grove stops the run before it reaches one it could read as `kept`.
#    arm 0 then found no `kept` line and blamed the READER, and cited the
#    2026-09-02 blindness defect by name.
#
#    the box that day held `grove-aether-v20260921`, whose `aether.camp`
#    credential was locked. the reader was sound; the rack was shut.
#
# ⚠️ both causes render as ONE empty match, and their repairs are opposite:
#      the reader is blind   → repair the reader
#      a foreign halt fired  → unlock that org's credential
#    ⇒ so the empty match is scored THREE-valued, never two
#      (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4 + m.16)
#
# 🛑 it must exclude THIS PLAY'S OWN fixture halt, which arm 1 requires. a
#    reader that counted the fixture would decline on every healthy box
######################################################################
_foreign_halt_in() {   # $1 = the sweep's output; echoes the first foreign halt
  printf '%s\n' "$1" \
    | grep 'could not ask aws' \
    | grep -v -e "$FIX_NOASK" -e "$FIX_ORPHAN" \
    | head -1
}

# 🛑 the discriminator's own fixture. a reader that cannot part the two cases
#    makes arms 0 and 3 unreadable, so a broken one is fatal rather than noted
_disc_ok=1
[[ -n "$(_foreign_halt_in "   ✋ grove-real-v1.ground — the reader could not ask aws")" ]] || _disc_ok=0
[[ -z "$(_foreign_halt_in "   ✋ $FIX_NOASK — the reader could not ask aws")"        ]] || _disc_ok=0
[[ -z "$(_foreign_halt_in "   ✔ the instance exists; kept")"                        ]] || _disc_ok=0

if [[ "$_disc_ok" -ne 1 ]]; then
  echo "   🌙 the foreign-halt discriminator does not cut both ways" >&2
  echo "      ⇒ arms 0 and 3 cannot be scored, so this play proves no claim" >&2
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
foreign="$(_foreign_halt_in "$out")"

if [[ "$out" == *"the instance exists; kept"* ]]; then
  echo "   │  ├─ 0. a LIVE grove reads 'kept'        ✔ the reader is not blind"
elif [[ -n "$foreign" ]]; then
  echo "   │  ├─ 0. a LIVE grove reads 'kept'        🌙 the run halted first"
  echo "   │  │     ⇒ a FOREIGN entry could not be asked about, and the sweep"
  echo "   │  │       halts at its first one — so this run never reached a grove"
  echo "   │  │       it could read as kept. that says NO WORD about the reader"
  echo "   │  │     halted on:$foreign"
  echo "   │  │     fix: unlock that org's camp credential, then re-run. a"
  echo "   │  │          FOREIGN org refuses a plain unlock and returns a 🔓"
  echo "   │  │          that proves no part of it — use the org-scoped verb:"
  echo "   │  │            rhx git.grove.rack.unlock --org <org> --env camp \\"
  echo "   │  │              --key AWS_PROFILE"
  declines=$(( declines + 1 ))
else
  echo "   │  ├─ 0. a LIVE grove reads 'kept'        ✋ no grove read as kept" >&2
  echo "   │  │     ⇒ no foreign halt fired, so the run DID reach every entry" >&2
  echo "   │  │       and read none as kept. the reader cannot see instances" >&2
  echo "   │  │       that exist — this is the 2026-09-02 defect" >&2
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
foreign2="$(_foreign_halt_in "$out2")"

named=0;   [[ "$out2" == *"$FIX_ORPHAN"* && "$out2" == *"no instance carries exid"* ]] && named=1
planned=0; [[ "$out2" == *"would be dropped"* ]] && planned=1
kept=0;    [[ "$out2" == *"the instance exists; kept"* ]] && kept=1

if [[ "$named" -eq 1 && "$planned" -eq 1 && "$kept" -eq 1 && "$rc2" -eq 0 ]]; then
  echo "   │  ├─ 3. a true orphan is named droppable  ✔ and live groves kept beside it"
elif [[ -n "$foreign2" ]]; then
  # 🛑 the same starvation as arm 0: the sweep halts before it reaches this
  #    play's own orphan fixture, so named/planned/kept are all unreadable
  echo "   │  ├─ 3. a true orphan is named droppable  🌙 the run halted first"
  echo "   │  │     ⇒ the halt fired on a FOREIGN entry, ahead of this play's"
  echo "   │  │       fixture — so named=$named planned=$planned kept=$kept are"
  echo "   │  │       artifacts of the halt, never verdicts about the sweep"
  echo "   │  │     halted on:$foreign2"
  declines=$(( declines + 1 ))
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

if [[ "$fails" -eq 0 && "$declines" -eq 0 ]]; then
  echo "🌲 the orphan sweep bites ✔"
  echo "   ├─ keeps a live grove, names a true orphan"
  echo "   └─ HALTS on an entry it could not ask about, and drops none"
  exit 0
fi

if [[ "$fails" -gt 0 ]]; then
  echo "   ✋ $fails arm(s) disagree with the required verdict" >&2
  [[ "$declines" -gt 0 ]] && echo "      ⚠️ and $declines arm(s) had no subject at all" >&2
  exit 1
fi

######################################################################
# 🛑 a DECLINE, never a pass — the claim is a CONJUNCTION
#
#   the arms that held are real and they are not the whole claim. an arm with
#   no subject leaves the conjunction unproven, so a 0 here would report a
#   sweep proven end to end on a run that never reached one
#   (`rule.forbid.failhide`)
######################################################################
echo "   🌙 $declines arm(s) could not be read on this box"
echo "      ├─ the halt discipline HELD: arms 1, 2, and 4 are green"
echo "      └─ ⇒ the keep and orphan paths are unproven here, so the sweep's"
echo "           claim is incomplete rather than refuted"
exit 2
